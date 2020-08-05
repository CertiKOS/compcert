(* ******************* *)
(* Author: Yuting Wang *)
(* Date:   May 28, 2020 *)
(* ******************* *)

(** * Properties about Injections at the Asm Level *)

Require Import Coqlib Errors.
Require Import Integers Floats AST Linking.
Require Import Values Memory Events Globalenvs Smallstep.
Require Import Op Locations Mach Conventions Asm AsmFacts.
Require Import LocalLib.
Import ListNotations.

Open Scope Z_scope.

(** ** Definition of injection between register sets *)
Definition regset_inject (j:meminj) (rs rs' : regset) : Prop :=
  forall r, Val.inject j (rs r) (rs' r).


Lemma Pregmap_gsspec_alt : forall (A : Type) (i j : Pregmap.elt) (x : A) (m : Pregmap.t A),
    (m # j <- x) i  = (if Pregmap.elt_eq i j then x else m i).
Proof.
  intros. apply Pregmap.gsspec.
Qed.


Lemma regset_inject_incr : forall j j' rs rs',
    regset_inject j rs rs' ->
    inject_incr j j' ->
    regset_inject j' rs rs'.
Proof.
  unfold inject_incr, regset_inject. intros.
  specialize (H r).
  destruct (rs r); inversion H; subst; auto.
  eapply Val.inject_ptr. apply H0. eauto. auto.
Qed.

Lemma undef_regs_pres_inject : forall j rs rs' regs,
  regset_inject j rs rs' ->
  regset_inject j (Asm.undef_regs regs rs) (Asm.undef_regs regs rs').
Proof.
  unfold regset_inject. intros. apply val_inject_undef_regs.
  auto.
Qed.    

Lemma regset_inject_expand : forall j rs1 rs2 v1 v2 r,
  regset_inject j rs1 rs2 ->
  Val.inject j v1 v2 ->
  regset_inject j (rs1 # r <- v1) (rs2 # r <- v2).
Proof.
  intros. unfold regset_inject. intros.
  repeat rewrite Pregmap_gsspec_alt. 
  destruct (Pregmap.elt_eq r0 r); auto.
Qed.

Lemma regset_inject_expand_vundef_left : forall j rs1 rs2 r,
  regset_inject j rs1 rs2 ->
  regset_inject j (rs1 # r <- Vundef) rs2.
Proof.
  intros. unfold regset_inject. intros.
  rewrite Pregmap_gsspec_alt. destruct (Pregmap.elt_eq r0 r); auto.
Qed.

Lemma set_res_pres_inject : forall res j rs1 rs2,
    regset_inject j rs1 rs2 ->
    forall vres1 vres2,
    Val.inject j vres1 vres2 ->
    regset_inject j (set_res res vres1 rs1) (set_res res vres2 rs2).
Proof.
  induction res; auto; simpl; unfold regset_inject; intros.
  - rewrite Pregmap_gsspec_alt. destruct (Pregmap.elt_eq r x); subst.
    + rewrite Pregmap.gss. auto.
    + rewrite Pregmap.gso; auto.
  - exploit (Val.hiword_inject j vres1 vres2); eauto. intros. 
    exploit (Val.loword_inject j vres1 vres2); eauto. intros.
    apply IHres2; auto.
Qed.


Lemma nextinstr_pres_inject : forall j rs1 rs2 sz,
    regset_inject j rs1 rs2 ->
    regset_inject j (nextinstr rs1 sz) (nextinstr rs2 sz).
Proof.
  unfold nextinstr. intros. apply regset_inject_expand; auto.
  apply Val.offset_ptr_inject. auto.
Qed.  

Lemma nextinstr_nf_pres_inject : forall j rs1 rs2 sz,
    regset_inject j rs1 rs2 ->
    regset_inject j (nextinstr_nf rs1 sz) (nextinstr_nf rs2 sz).
Proof.
  intros. apply nextinstr_pres_inject.
  apply undef_regs_pres_inject. auto.
Qed. 


Lemma set_pair_pres_inject : forall j rs1 rs2 v1 v2 loc,
    regset_inject j rs1 rs2 ->
    Val.inject j v1 v2 ->
    regset_inject j (set_pair loc v1 rs1) (set_pair loc v2 rs2).
Proof.
  intros. unfold set_pair, Asm.set_pair. destruct loc; simpl.
  - apply regset_inject_expand; auto.
  - apply regset_inject_expand; auto.
    apply regset_inject_expand; auto.
    apply Val.hiword_inject; auto.
    apply Val.loword_inject; auto.
Qed.

Ltac solve_val_inject :=
  match goal with
  (* | [ H : Val.inject _ (Vint _) (Vlong _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vint _) (Vfloat _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vint _) (Vsingle _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vint _) (Vptr _ _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vptr _ _) (Vlong _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vptr _ _) (Vfloat _) |- _] => inversion H *)
  (* | [ H : Val.inject _ (Vptr _ _) (Vsingle _) |- _] => inversion H *)
  | [ H : Val.inject _ (Vfloat _) Vundef |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vint _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vlong _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vsingle _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vptr _ _) |- _] => inversion H
  | [ H : Val.inject _ (Vfloat _) (Vfloat _) |- _] => inv H; solve_val_inject
  | [ H : Val.inject _ (Vsingle _) Vundef |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vint _) |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vlong _) |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vsingle _) |- _] => inv H; solve_val_inject
  | [ H : Val.inject _ (Vsingle _) (Vptr _ _) |- _] => inversion H
  | [ H : Val.inject _ (Vsingle _) (Vfloat _) |- _] => inversion H
  | [ |- Val.inject _ (Val.of_bool ?v) (Val.of_bool ?v) ] => apply Val.vofbool_inject
  | [ |- Val.inject _ Vundef _ ] => auto
  end.

Ltac solve_regset_inject :=
  match goal with
  | [ H: regset_inject ?j ?rs1 ?rs2 |- regset_inject ?j (Asm.undef_regs ?uregs ?rs1) (Asm.undef_regs ?uregs ?rs2)] =>
    apply undef_regs_pres_inject; auto
  | [ |- regset_inject _ (Asm.undef_regs _ _) _ ] =>
    unfold Asm.undef_regs; solve_regset_inject
  | [ |- regset_inject _ _ (Asm.undef_regs _ _) ] =>
    unfold Asm.undef_regs; simpl; solve_regset_inject
  | [ |- regset_inject _ (?rs1 # ?r <- ?v1) (?rs2 # ?r <- ?v2) ] =>
    apply regset_inject_expand; [solve_regset_inject | solve_val_inject]
  | [ H: regset_inject ?j ?rs1 ?rs2 |- regset_inject ?j ?rs1 ?rs2 ] =>
    auto
  end.

Lemma compare_floats_inject: forall j v1 v2 v1' v2' rs rs',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_floats v1 v2 rs) (compare_floats v1' v2' rs').
Proof.
  intros. unfold compare_floats, Asm.compare_floats.
  destruct v1, v2, v1', v2'; try solve_regset_inject. 
Qed.

Lemma compare_floats32_inject: forall j v1 v2 v1' v2' rs rs',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_floats32 v1 v2 rs) (compare_floats32 v1' v2' rs').
Proof.
  intros. unfold compare_floats32, Asm.compare_floats32.
  destruct v1, v2, v1', v2'; try solve_regset_inject. 
Qed.

Ltac solve_opt_lessdef := 
  match goal with
  | [ |- Val.opt_lessdef (match ?rs1 ?r with
                     | _ => _
                     end) _ ] =>
    let EQ := fresh "EQ" in (destruct (rs1 r) eqn:EQ; solve_opt_lessdef)
  | [ |- Val.opt_lessdef None _ ] => constructor
  | [ |- Val.opt_lessdef (Some _) (match ?rs2 ?r with
                              | _ => _
                              end) ] =>
    let EQ := fresh "EQ" in (destruct (rs2 r) eqn:EQ; solve_opt_lessdef)
  | [ H1: regset_inject _ ?rs1 ?rs2, H2: ?rs1 ?r = _, H3: ?rs2 ?r = _ |- _ ] =>
    generalize (H1 r); rewrite H2, H3; clear H2 H3; inversion 1; subst; solve_opt_lessdef
  | [ |- Val.opt_lessdef (Some ?v) (Some ?v) ] => constructor
  end.

Lemma eval_testcond_inject: forall j c rs1 rs2,
    regset_inject j rs1 rs2 ->
    Val.opt_lessdef (Asm.eval_testcond c rs1) (Asm.eval_testcond c rs2).
Proof.
  intros. destruct c; simpl; try solve_opt_lessdef.
Qed.


Section WITHMEMORYMODEL.
  
Context `{memory_model: Mem.MemoryModel }.
Existing Instance inject_perm_all.


Lemma compare_ints_inject: forall j v1 v2 v1' v2' rs rs' m m',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_ints v1 v2 rs m) (compare_ints v1' v2' rs' m').
Proof.
  intros. unfold compare_ints, Asm.compare_ints.
  repeat apply regset_inject_expand; auto.
  - apply cmpu_inject; auto.
  - apply cmpu_inject; auto.
  - apply val_negative_inject. apply Val.sub_inject; auto.
  - apply sub_overflow_inject; auto.
Qed.

Lemma compare_longs_inject: forall j v1 v2 v1' v2' rs rs' m m',
    Val.inject j v1 v1' -> Val.inject j v2 v2' ->
    Mem.inject j (def_frame_inj m) m m' ->
    regset_inject j rs rs' -> 
    regset_inject j (compare_longs v1 v2 rs m) (compare_longs v1' v2' rs' m').
Proof.
  intros. unfold compare_longs, Asm.compare_longs.
  repeat apply regset_inject_expand; auto.
  - unfold Val.cmplu.
    exploit (cmplu_bool_lessdef j v1 v2 v1' v2' m m' Ceq); eauto. intros.
    inversion H3; subst.
    + simpl. auto. 
    + simpl. apply Val.vofbool_inject.
  - unfold Val.cmplu.
    exploit (cmplu_bool_lessdef j v1 v2 v1' v2' m m' Clt); eauto. intros.
    inversion H3; subst.
    + simpl. auto. 
    + simpl. apply Val.vofbool_inject.
  - apply val_negativel_inject. apply Val.subl_inject; auto.
  - apply subl_overflow_inject; auto.
Qed.


(** ** Definition of extensions between register sets *)

Definition regset_lessdef (rs rs' : regset) : Prop :=
  forall r, Val.lessdef (rs r) (rs' r).


Lemma regset_lessdef_refl: forall rs,
    regset_lessdef rs rs.
Proof.
  intros. red. intros. constructor.
Qed.

Lemma extcall_arg_match:
  forall rs rs' m m' l v,
  regset_lessdef rs rs' ->
  Mem.extends m m' ->
  extcall_arg rs m l v ->
  exists v', extcall_arg rs' m' l v' /\ Val.lessdef v v'.
Proof.
  intros. inv H1.
  exists (rs'#(preg_of r)); split. constructor. eauto. 
  red in H. generalize (H RSP). intros.
  edestruct Mem.loadv_extends as (v' & LOADV & VL).
  exact H0. exact H3.
  apply Val.offset_ptr_lessdef; eauto.
  exists v'; split; auto.
  econstructor. eauto. assumption.
Qed.

Lemma extcall_arg_pair_match:
  forall rs rs' m m' p v,
  regset_lessdef rs rs' ->
  Mem.extends m m' ->
  extcall_arg_pair rs m p v ->
  exists v', Asm.extcall_arg_pair rs' m' p v' /\ Val.lessdef v v'.
Proof.
  intros. inv H1.
- exploit extcall_arg_match; eauto. intros (v' & A & B). exists v'; split; auto. constructor; auto.
- exploit extcall_arg_match. eauto. eauto. eexact H2. intros (v1 & A1 & B1).
  exploit extcall_arg_match. eauto. eauto. eexact H3. intros (v2 & A2 & B2).
  exists (Val.longofwords v1 v2); split. constructor; auto. apply Val.longofwords_lessdef; auto.
Qed.

Lemma extcall_args_match:
  forall rs rs' m m', regset_lessdef rs rs' -> Mem.extends m m' ->
  forall ll vl,
  list_forall2 (extcall_arg_pair rs m) ll vl ->
  exists vl', list_forall2 (extcall_arg_pair rs' m') ll vl' /\ Val.lessdef_list vl vl'.
Proof.
  induction 3; intros.
  exists (@nil val); split. constructor. constructor.
  exploit extcall_arg_pair_match; eauto. intros [v1' [A B]].
  destruct IHlist_forall2 as [vl' [C D]].
  exists (v1' :: vl'); split; constructor; auto.
Qed.

Lemma extcall_arguments_match: 
  forall args rs rs' m m' sg,
    regset_lessdef rs rs' ->
    Mem.extends m m' ->
    extcall_arguments rs m sg args ->
    exists args',
      extcall_arguments rs' m' sg args' /\ Val.lessdef_list args args'.
Proof.
  unfold extcall_arguments; intros.
  eapply extcall_args_match; eauto.
Qed.

Lemma regset_lessdef_pregset: forall rs1 rs2 v1 v2 r,
    regset_lessdef rs1 rs2 ->
    Val.lessdef v1 v2 ->
    regset_lessdef (Pregmap.set r v1 rs1) (Pregmap.set r v2 rs2).
Proof.
  intros rs1 rs2 v1 v2 r RSL VL.
  red. intros. red in RSL.
  destruct (preg_eq r r0).
  - subst. repeat rewrite Pregmap.gss. auto.
  - repeat rewrite Pregmap.gso; auto.
Qed.

Lemma val_lessdef_set: forall rs1 rs2 v1 v2,
    (forall r, Val.lessdef (rs1 r) (rs2 r)) ->
    Val.lessdef v1 v2 ->
    (forall r1 r, Val.lessdef ((Pregmap.set r1 v1 rs1) r) ((Pregmap.set r1 v2 rs2) r)).
Proof.
  intros.
  eapply regset_lessdef_pregset; eauto.
Qed.


Lemma undef_regs_pres_lessdef : forall regs rs rs',
  regset_lessdef  rs rs' ->
  regset_lessdef (undef_regs regs rs) (undef_regs regs rs').
Proof.
  unfold regset_lessdef. 
  induction regs; cbn; auto.
  intros rs rs' H.
  eapply IHregs.
  eapply val_lessdef_set; eauto.
Qed.    

Lemma set_res_pres_lessdef : forall res rs1 rs2,
    regset_lessdef rs1 rs2 ->
    forall vres1 vres2,
    Val.lessdef vres1 vres2 ->
    regset_lessdef (set_res res vres1 rs1) (set_res res vres2 rs2).
Proof.
  induction res; auto; simpl; unfold regset_inject; intros.
  - eapply regset_lessdef_pregset; eauto.
  - apply IHres2; auto.
    apply IHres1; auto.
    eapply Val.hiword_lessdef; eauto.
    eapply Val.loword_lessdef; eauto.
Qed.

Lemma set_pair_pres_lessdef : forall rs1 rs2 v1 v2 loc,
    regset_lessdef rs1 rs2 ->
    Val.lessdef v1 v2 ->
    regset_lessdef (set_pair loc v1 rs1) (set_pair loc v2 rs2).
Proof.
  intros. unfold set_pair, Asm.set_pair. destruct loc; simpl.
  - apply regset_lessdef_pregset; eauto.
  - apply regset_lessdef_pregset; eauto.
    apply regset_lessdef_pregset; eauto.
    apply Val.hiword_lessdef; auto.
    apply Val.loword_lessdef; auto.
Qed.

Lemma nextinstr_pres_lessdef : forall rs1 rs2 sz,
    regset_lessdef rs1 rs2 ->
    regset_lessdef (nextinstr rs1 sz) (nextinstr rs2 sz).
Proof.
  intros. eapply regset_lessdef_pregset; eauto.
  eapply Val.offset_ptr_lessdef; eauto.
Qed.
  
Lemma nextinstr_nf_pres_lessdef : forall rs1 rs2 sz,
    regset_lessdef rs1 rs2 ->
    regset_lessdef (nextinstr_nf rs1 sz) (nextinstr_nf rs2 sz).
Proof.
  intros. unfold nextinstr_nf.
  eapply nextinstr_pres_lessdef; eauto.
  eapply undef_regs_pres_lessdef; eauto.
Qed.


Hint Resolve 
     val_lessdef_set
     set_res_pres_lessdef 
     undef_regs_pres_lessdef 
     set_pair_pres_lessdef
     regset_lessdef_pregset
     Val.lessdef_refl
     Val.zero_ext_lessdef Val.sign_ext_lessdef Val.longofintu_lessdef Val.longofint_lessdef
     Val.singleoffloat_lessdef Val.loword_lessdef Val.floatofsingle_lessdef Val.intoffloat_lessdef Val.maketotal_lessdef
     Val.intoffloat_lessdef Val.floatofint_lessdef Val.intofsingle_lessdef Val.singleofint_lessdef
     Val.longoffloat_lessdef Val.floatoflong_lessdef Val.longofsingle_lessdef Val.singleoflong_lessdef
     Val.neg_lessdef Val.negl_lessdef Val.add_lessdef Val.addl_lessdef
     Val.sub_lessdef  Val.subl_lessdef Val.mul_lessdef Val.mull_lessdef Val.mulhs_lessdef Val.mulhu_lessdef
     Val.mullhs_lessdef  Val.mullhu_lessdef Val.shr_lessdef Val.shrl_lessdef Val.or_lessdef Val.orl_lessdef
     Val.xor_lessdef Val.xorl_lessdef Val.and_lessdef Val.andl_lessdef Val.notl_lessdef
     Val.shl_lessdef Val.shll_lessdef Val.vzero_lessdef Val.notint_lessdef
     Val.shru_lessdef Val.shrlu_lessdef Val.ror_lessdef Val.rorl_lessdef
     Val.addf_lessdef Val.subf_lessdef Val.mulf_lessdef Val.divf_lessdef Val.negf_lessdef Val.absf_lessdef
     Val.addfs_lessdef Val.subfs_lessdef Val.mulfs_lessdef Val.divfs_lessdef Val.negfs_lessdef Val.absfs_lessdef
     val_of_optbool_lessdef Val.offset_ptr_lessdef
     nextinstr_pres_lessdef
     nextinstr_nf_pres_lessdef.

Lemma compare_floats_lessdef: forall v1 v2 v1' v2' rs rs',
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    regset_lessdef rs rs' -> 
    regset_lessdef (compare_floats v1 v2 rs) (compare_floats v1' v2' rs').
Proof.
  intros. unfold compare_floats, Asm.compare_floats.
  inv H; inv H0.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
Qed.

Lemma compare_floats32_lessdef: forall v1 v2 v1' v2' rs rs',
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    regset_lessdef rs rs' -> 
    regset_lessdef (compare_floats32 v1 v2 rs) (compare_floats32 v1' v2' rs').
Proof.
  intros. unfold compare_floats32, Asm.compare_floats32.
  inv H; inv H0.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
  - destruct v1', v2'; eauto.
    eapply regset_lessdef_pregset; eauto.
Qed.


Lemma cmplu_bool_lessdef : forall v1 v2 v1' v2' m m' c,
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    Val.opt_lessdef (Val.cmplu_bool (Mem.valid_pointer m) c v1 v2)
                (Val.cmplu_bool (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. destruct (Val.cmplu_bool (Mem.valid_pointer m) c v1 v2) eqn:EQ.
  - assert ((Val.cmplu_bool (Mem.valid_pointer m') c v1' v2') = Some b).
    { eapply Val.cmplu_bool_lessdef; eauto. }
    rewrite H1. constructor.
  - constructor.
Qed.

Lemma cmpu_lessdef : forall v1 v2 v1' v2' m m' c,
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    Mem.extends m m' ->
    Val.lessdef (Val.cmpu (Mem.valid_pointer m) c v1 v2)
                (Val.cmpu (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. unfold Val.cmpu.
  eapply Val.of_optbool_lessdef; eauto.
  intros. apply Val.cmpu_bool_lessdef with (Mem.valid_pointer m) v1 v2; eauto.
  intros. 
  eapply Mem.valid_pointer_extends; eauto.
Qed.

Lemma cmplu_lessdef : forall v1 v2 v1' v2' m m' c,
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    Mem.extends m m' ->
    Val.opt_val_lessdef (Val.cmplu (Mem.valid_pointer m) c v1 v2)
                        (Val.cmplu (Mem.valid_pointer m') c v1' v2').
Proof.
  intros. unfold Val.cmplu.
  destruct (Val.cmplu_bool (Mem.valid_pointer m) c v1 v2) eqn:EQ.
  cbn.
  - assert ((Val.cmplu_bool (Mem.valid_pointer m') c v1' v2') = Some b).
    { eapply Val.cmplu_bool_lessdef; eauto. }
    rewrite H2. constructor. apply Val.lessdef_refl.
  - cbn. constructor.
Qed.

Lemma val_negative_lessdef: forall v1 v2,
  Val.lessdef v1 v2 -> Val.lessdef (Val.negative v1) (Val.negative v2).
Proof.
  intros. unfold Val.negative. destruct v1; auto.
  inv H. auto.
Qed.

Lemma val_negativel_lessdef: forall v1 v2,
  Val.lessdef v1 v2 -> Val.lessdef (Val.negativel v1) (Val.negativel v2).
Proof.
  intros. unfold Val.negativel. destruct v1; auto.
  inv H. auto.
Qed.

Lemma sub_overflow_lessdef : forall v1 v2 v1' v2',
    Val.lessdef v1 v2 -> Val.lessdef v1' v2' -> 
    Val.lessdef (Val.sub_overflow v1 v1') (Val.sub_overflow v2 v2').
Proof.
  intros. unfold Val.sub_overflow. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Lemma subl_overflow_lessdef : forall v1 v2 v1' v2',
    Val.lessdef v1 v2 -> Val.lessdef v1' v2' -> 
    Val.lessdef (Val.subl_overflow v1 v1') (Val.subl_overflow v2 v2').
Proof.
  intros. unfold Val.subl_overflow. 
  destruct v1; auto. inv H. 
  destruct v1'; auto. inv H0. auto.
Qed.

Hint Resolve 
     val_negativel_lessdef val_negativel_lessdef
     sub_overflow_lessdef subl_overflow_lessdef.
     

Lemma compare_ints_lessdef: forall v1 v2 v1' v2' rs rs' m m',
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    Mem.extends m m' ->
    regset_lessdef rs rs' -> 
    regset_lessdef (compare_ints v1 v2 rs m) (compare_ints v1' v2' rs' m').
Proof.
  intros. unfold compare_ints, Asm.compare_ints.
  repeat apply regset_lessdef_pregset; auto.
  - apply cmpu_lessdef; auto.
  - apply cmpu_lessdef; auto.
  - apply val_negative_lessdef. apply Val.sub_lessdef; auto.
Qed.

Hint Resolve cmplu_lessdef.

Lemma compare_longs_lessdef: forall v1 v2 v1' v2' rs rs' m m',
    Val.lessdef v1 v1' -> Val.lessdef v2 v2' ->
    Mem.extends m m' ->
    regset_lessdef rs rs' -> 
    regset_lessdef (compare_longs v1 v2 rs m) (compare_longs v1' v2' rs' m').
Proof.
  intros. unfold compare_longs, Asm.compare_longs. 
  eapply regset_lessdef_pregset; eauto.
  eapply regset_lessdef_pregset; eauto.
  eapply regset_lessdef_pregset; eauto.
  eapply regset_lessdef_pregset; eauto.
Qed.

Ltac solve_opt_lessdef1 := 
  match goal with
  | [ |- Val.opt_lessdef (match ?rs1 ?r with
                     | _ => _
                     end) _ ] =>
    let EQ := fresh "EQ" in (destruct (rs1 r) eqn:EQ; solve_opt_lessdef1)
  | [ |- Val.opt_lessdef None _ ] => constructor
  | [ |- Val.opt_lessdef (Some _) (match ?rs2 ?r with
                              | _ => _
                              end) ] =>
    let EQ := fresh "EQ" in (destruct (rs2 r) eqn:EQ; solve_opt_lessdef1)
  | [ H1: regset_lessdef ?rs1 ?rs2, H2: ?rs1 ?r = _, H3: ?rs2 ?r = _ |- _ ] =>
    generalize (H1 r); rewrite H2, H3; clear H2 H3; inversion 1; subst; solve_opt_lessdef1
  | [ |- Val.opt_lessdef (Some ?v) (Some ?v) ] => constructor
  end.

Lemma eval_testcond_lessdef: forall c rs1 rs2,
    regset_lessdef rs1 rs2 ->
    Val.opt_lessdef (Asm.eval_testcond c rs1) (Asm.eval_testcond c rs2).
Proof.
  intros. destruct c; simpl; try solve_opt_lessdef1.
Qed.

Lemma eval_testcond_lessdef_some: forall c rs1 rs2 b,
    regset_lessdef rs1 rs2 ->
    eval_testcond c rs1 = Some b ->
    Asm.eval_testcond c rs2 = Some b.
Proof.
  intros.
  generalize (eval_testcond_lessdef c _ _ H).
  intros OL.
  inv OL. congruence. congruence.
Qed.



End WITHMEMORYMODEL.
