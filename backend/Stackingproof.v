(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(** Correctness proof for the translation from Linear to Mach. *)

(** This file proves semantic preservation for the [Stacking] pass. *)

Require Import Coqlib Errors.
Require Import Integers AST Linking.
Require Import Values Memory Separation Events Globalenvs Smallstep.
Require Import LTL Op Locations Linear Mach.
Require Import Bounds Conventions Stacklayout Lineartyping.
Require Import Stacking.

Local Open Scope sep_scope.

Definition match_prog (p: Linear.program) (tp: Mach.program) :=
  match_program (fun _ f tf => transf_fundef f = OK tf) eq p tp.

Lemma transf_program_match:
  forall p tp, transf_program p = OK tp -> match_prog p tp.
Proof.
  intros. eapply match_transform_partial_program; eauto.
Qed.

(** * Basic properties of the translation *)

Lemma typesize_typesize:
  forall ty, AST.typesize ty = 4 * Locations.typesize ty.
Proof.
  destruct ty; auto.
Qed.

Remark size_type_chunk:
  forall ty, size_chunk (chunk_of_type ty) = AST.typesize ty.
Proof.
  destruct ty; reflexivity.
Qed.

Remark align_type_chunk:
  forall ty, align_chunk (chunk_of_type ty) = 4 * Locations.typealign ty.
Proof.
  destruct ty; reflexivity.
Qed.

Lemma slot_outgoing_argument_valid:
  forall f ofs ty sg,
  In (S Outgoing ofs ty) (regs_of_rpairs (loc_arguments sg)) -> slot_valid f Outgoing ofs ty = true.
Proof.
  intros. exploit loc_arguments_acceptable_2; eauto. intros [A B].
  unfold slot_valid. unfold proj_sumbool.
  rewrite zle_true by omega.
  rewrite pred_dec_true by auto.
  auto.
Qed.

Lemma load_result_inject:
  forall j ty v v',
  Val.inject j v v' -> Val.has_type v ty -> Val.inject j v (Val.load_result (chunk_of_type ty) v').
Proof.
  intros until v'; unfold Val.has_type, Val.load_result; destruct Archi.ptr64;
  destruct 1; intros; auto; destruct ty; simpl;
  try contradiction; try discriminate; econstructor; eauto.
Qed.

Section PRESERVATION.

Variable return_address_offset: Mach.function -> Mach.code -> ptrofs -> Prop.

Hypothesis return_address_offset_exists:
  forall f sg ros c,
  is_tail (Mcall sg ros :: c) (fn_code f) ->
  exists ofs, return_address_offset f c ofs.

Let step := Mach.step (*SACC:*)invalidate_frame1 return_address_offset.

Variable prog: Linear.program.
Variable tprog: Mach.program.
Hypothesis TRANSF: match_prog prog tprog.
Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.

Section FRAME_PROPERTIES.

Variable f: Linear.function.
Let b := function_bounds f.
Let fe := make_env b.
Variable tf: Mach.function.
Hypothesis TRANSF_F: transf_function f = OK tf.

Lemma unfold_transf_function:
  tf = Mach.mkfunction
         f.(Linear.fn_sig)
         (transl_body f fe)
         fe.(fe_size)
(*SACC:*)(*(Ptrofs.repr fe.(fe_ofs_link))*)
         (Ptrofs.repr fe.(fe_ofs_retaddr)).
Proof.
  generalize TRANSF_F. unfold transf_function.
  destruct (wt_function f); simpl negb.
  destruct (zlt Ptrofs.max_unsigned (fe_size (make_env (function_bounds f)))).
  intros; discriminate.
  intros. unfold fe. unfold b. congruence.
  intros; discriminate.
Qed.

Lemma transf_function_well_typed:
  wt_function f = true.
Proof.
  generalize TRANSF_F. unfold transf_function.
  destruct (wt_function f); simpl negb. auto. intros; discriminate.
Qed.

Lemma size_no_overflow: fe.(fe_size) <= Ptrofs.max_unsigned.
Proof.
  generalize TRANSF_F. unfold transf_function.
  destruct (wt_function f); simpl negb.
  destruct (zlt Ptrofs.max_unsigned (fe_size (make_env (function_bounds f)))).
  intros; discriminate.
  intros. unfold fe. unfold b. omega.
  intros; discriminate.
Qed.

Remark bound_stack_data_stacksize:
  f.(Linear.fn_stacksize) <= b.(bound_stack_data).
Proof.
  unfold b, function_bounds, bound_stack_data. apply Zmax1.
Qed.

(** * Memory assertions used to describe the contents of stack frames *)

Local Opaque Z.add Z.mul Z.divide.

(** Accessing the stack frame using [load_stack] and [store_stack]. *)

Lemma contains_get_stack:
  forall spec m ty sp ofs,
  m |= contains (chunk_of_type ty) sp ofs spec ->
  exists v, load_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr ofs) = Some v /\ spec v.
Proof.
  intros. unfold load_stack. 
  replace (Val.offset_ptr (Vptr sp Ptrofs.zero) (Ptrofs.repr ofs)) with (Vptr sp (Ptrofs.repr ofs)).
  eapply loadv_rule; eauto.
  simpl. rewrite Ptrofs.add_zero_l; auto.
Qed.

Lemma hasvalue_get_stack:
  forall ty m sp ofs v,
  m |= hasvalue (chunk_of_type ty) sp ofs v ->
  load_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr ofs) = Some v.
Proof.
  intros. exploit contains_get_stack; eauto. intros (v' & A & B). congruence.
Qed.

Lemma contains_set_stack:
  forall (spec: val -> Prop) v spec1 m ty sp ofs P,
  m |= contains (chunk_of_type ty) sp ofs spec1 ** P ->
  spec (Val.load_result (chunk_of_type ty) v) ->
  exists m',
      store_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr ofs) v = Some m'
  /\ m' |= contains (chunk_of_type ty) sp ofs spec ** P.
Proof.
  intros. unfold store_stack. 
  replace (Val.offset_ptr (Vptr sp Ptrofs.zero) (Ptrofs.repr ofs)) with (Vptr sp (Ptrofs.repr ofs)).
  eapply storev_rule; eauto.
  simpl. rewrite Ptrofs.add_zero_l; auto.
Qed.

(** SACC: [contains_ra] *)

(*SACC: substitutes load for loadbytesv in has_value*)
Program Definition contains_ra (b: block) (ofs: Z) (ra: val) : massert := {|
  m_pred := fun m =>
       0 <= ofs <= Ptrofs.max_unsigned
       /\ Mem.range_perm m b ofs (ofs + size_chunk Mptr) Cur Freeable
       /\ (align_chunk Mptr | ofs)
       /\ Mem.loadbytesv Mptr m (Vptr b (Ptrofs.repr ofs)) = Some ra;
  m_footprint := fun b' ofs' => b' = b /\ ofs <= ofs' < ofs + size_chunk Mptr;
  m_invar_stack := false;
|}.
Next Obligation.
  destr_in H4. clear H1.
  repeat apply conj; auto.
- red; intros; eapply Mem.perm_unchanged_on; eauto. simpl; auto.
- erewrite Mem.loadbytes_unchanged_on; eauto. simpl. rewrite Ptrofs.unsigned_repr by omega. auto. 
Qed.
Next Obligation.
  eauto with mem. 
Qed.

(*SACC:*)
Lemma wt_encoded_ra_same_64:
  forall v, Archi.ptr64 = true -> 
       Val.has_type v Tptr ->
       Mem.encoded_ra (encode_val Mptr v) = Some v.
Proof.
  clear step.
  unfold Tptr, Mem.encoded_ra, Mptr.
  intros v ARCH WT.
  destr_in WT.
  destruct v; simpl in WT; try congruence; try easy.
Qed.

(*SACC:*)
Lemma wt_encoded_ra_same_32:
  forall v, Archi.ptr64 = false -> 
       Val.has_type v Tptr ->
       v <> Vundef ->
       Mem.encoded_ra (encode_val Mptr v) = Some v.
Proof.
  clear step.
  unfold Tptr, Mem.encoded_ra, Mptr.
  intros v ARCH WT.
  destr_in WT.
  destruct v; simpl in WT; try easy.
  + simpl. rewrite proj_inj_bytes. unfold Vptrofs; rewrite Heqb0. f_equal. f_equal.
    rewrite decode_encode_int.
    erewrite Ptrofs.agree32_to_int_eq. eauto.
    etransitivity. apply Ptrofs.agree32_repr. auto.
    rewrite Z.mod_small.
    rewrite Int.repr_unsigned. auto. apply Int.unsigned_range.
  + simpl. rewrite WT. rewrite proj_bytes_inj_value. rewrite proj_inj_value. reflexivity.
Qed.
  
Lemma wt_encoded_ra_same:
  forall v, Val.has_type v Tptr ->
       v <> Vundef ->
       Mem.encoded_ra (encode_val Mptr v) = Some v.
Proof.
  destruct Archi.ptr64 eqn:ARCH.
  intros. eapply wt_encoded_ra_same_64; eauto.
  intros. eapply wt_encoded_ra_same_32; eauto.
Qed.

Lemma store_rule':
  forall m b ofs v (spec1: val -> Prop) P,
    m |= contains Mptr b ofs spec1 ** P ->
    Val.has_type v Tptr ->
    v <> Vundef ->
    exists m',
      Mem.store Mptr m b ofs v = Some m' /\ m' |= contains_ra b ofs v ** P.
Proof.
  intros m b0 ofs v spec1 P ((D & E & v0 & G & I) & B & C) VPTR VNU.
  assert (WRITABLE: Mem.valid_access m Mptr b0 ofs Writable) by eauto with mem.
  destruct (Mem.valid_access_store _ _ _ _ v WRITABLE) as [m' STORE].
  exists m'; split; auto. simpl. intuition auto.
- eapply Mem.store_valid_access_1; eauto.
- eapply E.
- erewrite Mem.loadbytes_store_same; eauto. 2: rewrite Ptrofs.unsigned_repr; eauto.
  eapply wt_encoded_ra_same; eauto.
- apply (m_invar P) with m; auto. 
  + eapply Mem.store_unchanged_on; eauto.
    intros; red; intros. apply (C b0 i); simpl; auto.
  + intros.
    eapply Mem.store_stack_unchanged; eauto.
Qed.

(*SACC:*)
Lemma contains_ra_set_stack:
  forall v spec1 m sp ofs P,
  m |= contains Mptr sp ofs spec1 ** P ->
  Val.has_type v Tptr ->
  v <> Vundef ->
  exists m',
      store_stack m (Vptr sp Ptrofs.zero) Tptr (Ptrofs.repr ofs) v = Some m'
  /\ m' |= contains_ra sp ofs v ** P.
Proof.
  intros v spec1 m sp ofs P CONT VPTR VNU.
  unfold store_stack. 
  replace (Val.offset_ptr (Vptr sp Ptrofs.zero) (Ptrofs.repr ofs)) with (Vptr sp (Ptrofs.repr ofs)).
  simpl Mem.storev.
  rewrite Ptrofs.unsigned_repr; eauto.
  eapply store_rule'; eauto.
  destruct CONT as ((A & _) & _); auto.
  simpl. rewrite Ptrofs.add_zero_l; auto.
Qed.

(** [contains_locations j sp pos bound sl ls] is a separation logic assertion
  that holds if the memory area at block [sp], offset [pos], size [4 * bound],
  reflects the values of the stack locations of kind [sl] given by the
  location map [ls], up to the memory injection [j].

  Two such [contains_locations] assertions will be used later, one to
  reason about the values of [Local] slots, the other about the values of
  [Outgoing] slots. *)

Program Definition contains_locations (j: meminj) (sp: block) (pos bound: Z) (sl: slot) (ls: locset) : massert := {|
  m_pred := fun m =>
    (8 | pos) /\ 0 <= pos /\ pos + 4 * bound <= Ptrofs.modulus /\
    Mem.range_perm m sp pos (pos + 4 * bound) Cur Freeable /\
    forall ofs ty, 0 <= ofs -> ofs + typesize ty <= bound -> (typealign ty | ofs) ->
    exists v, Mem.load (chunk_of_type ty) m sp (pos + 4 * ofs) = Some v
           /\ Val.inject j (ls (S sl ofs ty)) v;
  m_footprint := fun b ofs =>
    b = sp /\ pos <= ofs < pos + 4 * bound;
(*SACC:*)m_invar_stack := false;
|}.
Next Obligation.
  intuition auto. 
- red; intros. eapply Mem.perm_unchanged_on; eauto. simpl; auto.
- exploit H5; eauto. intros (v & A & B). exists v; split; auto.
  eapply Mem.load_unchanged_on; eauto.
  simpl; intros. rewrite size_type_chunk, typesize_typesize in H9. 
  split; auto. omega.
Qed.
Next Obligation.
  eauto with mem.
Qed.

Remark valid_access_location:
  forall m sp pos bound ofs ty p,
  (8 | pos) ->
  Mem.range_perm m sp pos (pos + 4 * bound) Cur Freeable ->
  0 <= ofs -> ofs + typesize ty <= bound -> (typealign ty | ofs) ->
  Mem.valid_access m (chunk_of_type ty) sp (pos + 4 * ofs) p.
Proof.
  intros; split.
- red; intros. apply Mem.perm_implies with Freeable; auto with mem. 
  apply H0. rewrite size_type_chunk, typesize_typesize in H4. omega.
- rewrite align_type_chunk. apply Z.divide_add_r. 
  apply Zdivide_trans with 8; auto.
  exists (8 / (4 * typealign ty)); destruct ty; reflexivity.
  apply Z.mul_divide_mono_l. auto.
Qed.

Lemma get_location:
  forall m j sp pos bound sl ls ofs ty,
  m |= contains_locations j sp pos bound sl ls ->
  0 <= ofs -> ofs + typesize ty <= bound -> (typealign ty | ofs) ->
  exists v,
     load_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr (pos + 4 * ofs)) = Some v
  /\ Val.inject j (ls (S sl ofs ty)) v.
Proof.
  intros. destruct H as (D & E & F & G & H).
  exploit H; eauto. intros (v & U & V). exists v; split; auto.
  unfold load_stack; simpl. rewrite Ptrofs.add_zero_l, Ptrofs.unsigned_repr; auto.
  unfold Ptrofs.max_unsigned. generalize (typesize_pos ty). omega.
Qed.

Lemma set_location:
  forall m j sp pos bound sl ls P ofs ty v v',
  m |= contains_locations j sp pos bound sl ls ** P ->
  0 <= ofs -> ofs + typesize ty <= bound -> (typealign ty | ofs) ->
  Val.inject j v v' ->
  exists m',
     store_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr (pos + 4 * ofs)) v' = Some m'
  /\ m' |= contains_locations j sp pos bound sl (Locmap.set (S sl ofs ty) v ls) ** P.
Proof.
  intros. destruct H as (A & B & C). destruct A as (D & E & F & G & H).
  edestruct Mem.valid_access_store as [m' STORE]. 
  eapply valid_access_location; eauto. 
  assert (PERM: Mem.range_perm m' sp pos (pos + 4 * bound) Cur Freeable).
  { red; intros; eauto with mem. }
  exists m'; split.
- unfold store_stack; simpl. rewrite Ptrofs.add_zero_l, Ptrofs.unsigned_repr; eauto.
  unfold Ptrofs.max_unsigned. generalize (typesize_pos ty). omega.
- simpl. intuition auto.
+ unfold Locmap.set. 
  destruct (Loc.eq (S sl ofs ty) (S sl ofs0 ty0)); [|destruct (Loc.diff_dec (S sl ofs ty) (S sl ofs0 ty0))].
* (* same location *)
  inv e. rename ofs0 into ofs. rename ty0 into ty.
  exists (Val.load_result (chunk_of_type ty) v'); split.
  eapply Mem.load_store_similar_2; eauto. omega. 
  apply Val.load_result_inject; auto.
* (* different locations *)
  exploit H; eauto. intros (v0 & X & Y). exists v0; split; auto.
  rewrite <- X; eapply Mem.load_store_other; eauto.
  destruct d. congruence. right. rewrite ! size_type_chunk, ! typesize_typesize. omega.
* (* overlapping locations *)
  destruct (Mem.valid_access_load m' (chunk_of_type ty0) sp (pos + 4 * ofs0)) as [v'' LOAD].
  apply Mem.valid_access_implies with Writable; auto with mem. 
  eapply valid_access_location; eauto.
  exists v''; auto.
+ apply (m_invar P) with m; auto. 
  eapply Mem.store_unchanged_on; eauto.
  intros i; rewrite size_type_chunk, typesize_typesize. intros; red; intros.
  eelim C; eauto. simpl. split; auto. omega.
  intros; eapply Mem.store_stack_unchanged; eauto. 
Qed.

Lemma initial_locations:
  forall j sp pos bound P sl ls m,
  m |= range sp pos (pos + 4 * bound) ** P ->
  (8 | pos) ->
  (forall ofs ty, ls (S sl ofs ty) = Vundef) ->
  m |= contains_locations j sp pos bound sl ls ** P.
Proof.
  intros. destruct H as (A & B & C). destruct A as (D & E & F). split.
- simpl; intuition auto. red; intros; eauto with mem. 
  destruct (Mem.valid_access_load m (chunk_of_type ty) sp (pos + 4 * ofs)) as [v LOAD].
  eapply valid_access_location; eauto.
  red; intros; eauto with mem.
  exists v; split; auto. rewrite H1; auto.
- split; assumption.
Qed.

Lemma contains_locations_exten:
  forall ls ls' j sp pos bound sl,
  (forall ofs ty, ls' (S sl ofs ty) = ls (S sl ofs ty)) ->
  massert_imp (contains_locations j sp pos bound sl ls)
              (contains_locations j sp pos bound sl ls').
Proof.
  intros; split; simpl; intros; auto.
  intuition auto. rewrite H. eauto.
Qed.

Lemma contains_locations_incr:
  forall j j' sp pos bound sl ls,
  inject_incr j j' ->
  massert_imp (contains_locations j sp pos bound sl ls)
              (contains_locations j' sp pos bound sl ls).
Proof.
  intros; split; simpl; intros; auto.
  intuition auto. exploit H5; eauto. intros (v & A & B). exists v; eauto.
Qed.

(** [contains_callee_saves j sp pos rl ls] is a memory assertion that holds
  if block [sp], starting at offset [pos], contains the values of the
  callee-save registers [rl] as given by the location map [ls],
  up to the memory injection [j].  The memory layout of the registers in [rl]
  is the same as that implemented by [save_callee_save_rec]. *)

Fixpoint contains_callee_saves (j: meminj) (sp: block) (pos: Z) (rl: list mreg) (ls: locset) : massert :=
  match rl with
  | nil => pure True
  | r :: rl =>
      let ty := mreg_type r in
      let sz := AST.typesize ty in
      let pos1 := align pos sz in
      contains (chunk_of_type ty) sp pos1 (fun v => Val.inject j (ls (R r)) v)
      ** contains_callee_saves j sp (pos1 + sz) rl ls
  end.

Lemma contains_callee_saves_incr:
  forall j j' sp ls,
  inject_incr j j' ->
  forall rl pos,
  massert_imp (contains_callee_saves j sp pos rl ls)
              (contains_callee_saves j' sp pos rl ls).
Proof.
  induction rl as [ | r1 rl]; simpl; intros.
- reflexivity.
- apply sepconj_morph_1; auto. apply contains_imp. eauto.
Qed.

Lemma contains_callee_saves_exten:
  forall j sp ls ls' rl pos,
  (forall r, In r rl -> ls' (R r) = ls (R r)) ->
  massert_eqv (contains_callee_saves j sp pos rl ls)
              (contains_callee_saves j sp pos rl ls').
Proof.
  induction rl as [ | r1 rl]; simpl; intros.
- reflexivity.
- apply sepconj_morph_2; auto. rewrite H by auto. reflexivity.
Qed.

(*SACC:*)
Lemma m_invar_stack_contains_callee_saves:
  forall l j b delta ls,
    m_invar_stack (contains_callee_saves j b delta l ls) = false.
Proof.
  induction l; simpl; intros; eauto.
Qed.

(** Separation logic assertions describing the stack frame at [sp].
  It must contain:
  - the values of the [Local] stack slots of [ls], as per [contains_locations]
  - the values of the [Outgoing] stack slots of [ls], as per [contains_locations]
  - the [parent] pointer representing the back link to the caller's frame
  - the [retaddr] pointer representing the saved return address
  - the initial values of the used callee-save registers as given by [ls0],
    as per [contains_callee_saves].

In addition, we use a nonseparating conjunction to record the fact that
we have full access rights on the stack frame, except the part that
represents the Linear stack data. *)

Definition frame_contents_1 (j: meminj) (sp: block) (ls ls0: locset) (parent retaddr: val) :=
    contains_locations j sp fe.(fe_ofs_local) b.(bound_local) Local ls
 ** contains_locations j sp fe_ofs_arg b.(bound_outgoing) Outgoing ls
(*SACC:*)(* ** hasvalue Mptr sp fe.(fe_ofs_link) parent*)
(*SACC:*)(* ** hasvalue Mptr sp fe.(fe_ofs_retaddr) retaddr*)
(*SACC:*) ** contains_ra sp fe.(fe_ofs_retaddr) retaddr
 ** contains_callee_saves j sp fe.(fe_ofs_callee_save) b.(used_callee_save) ls0.

Definition frame_contents (j: meminj) (sp: block) (ls ls0: locset) (parent retaddr: val) :=
  mconj (frame_contents_1 j sp ls ls0 parent retaddr)
        (range sp 0 fe.(fe_stack_data) **
         range sp (fe.(fe_stack_data) + b.(bound_stack_data)) fe.(fe_size)).

(*SACC:*)
Lemma frame_contents_invar_stack j sp ls ls0 parent retaddr:
  m_invar_stack (frame_contents j sp ls ls0 parent retaddr) = false.
Proof.
  simpl.
  rewrite m_invar_stack_contains_callee_saves.
  reflexivity.
Qed.

(** Accessing components of the frame. *)

Lemma frame_get_local:
  forall ofs ty j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  slot_within_bounds b Local ofs ty -> slot_valid f Local ofs ty = true ->
  exists v,
     load_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr (offset_local fe ofs)) = Some v
  /\ Val.inject j (ls (S Local ofs ty)) v.
Proof.
  unfold frame_contents, frame_contents_1; intros. unfold slot_valid in H1; InvBooleans.
  apply mconj_proj1 in H. apply sep_proj1 in H. apply sep_proj1 in H.
  eapply get_location; eauto. 
Qed.

Lemma frame_get_outgoing:
  forall ofs ty j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  slot_within_bounds b Outgoing ofs ty -> slot_valid f Outgoing ofs ty = true ->
  exists v,
     load_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr (offset_arg ofs)) = Some v
  /\ Val.inject j (ls (S Outgoing ofs ty)) v.
Proof.
  unfold frame_contents, frame_contents_1; intros. unfold slot_valid in H1; InvBooleans.
  apply mconj_proj1 in H. apply sep_proj1 in H. apply sep_pick2 in H.
  eapply get_location; eauto. 
Qed.

(*SACC:
Lemma frame_get_parent:
  forall j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  load_stack m (Vptr sp Ptrofs.zero) Tptr (Ptrofs.repr fe.(fe_ofs_link)) = Some parent.
Proof.
  unfold frame_contents, frame_contents_1; intros.
  apply mconj_proj1 in H. apply sep_proj1 in H. apply sep_pick3 in H. rewrite <- chunk_of_Tptr in H.
  eapply hasvalue_get_stack; eauto.
Qed.
*)

Lemma frame_get_retaddr:
  forall j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
(*SACC:*)Mem.loadbytesv Mptr m (Val.offset_ptr (Vptr sp Ptrofs.zero) (Ptrofs.repr fe.(fe_ofs_retaddr))) = Some retaddr.
Proof.
  unfold frame_contents, frame_contents_1; intros.
  apply mconj_proj1 in H. apply sep_proj1 in H. apply sep_pick3 in H.
  destruct H as (A & B & C & D).
  Local Opaque fe_ofs_retaddr. 
  simpl Val.offset_ptr. rewrite Ptrofs.add_zero_l, D. auto. 
Qed.

(** Assigning a [Local] or [Outgoing] stack slot. *)

Lemma frame_set_local:
  forall ofs ty v v' j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  slot_within_bounds b Local ofs ty -> slot_valid f Local ofs ty = true ->
  Val.inject j v v' ->
  exists m',
     store_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr (offset_local fe ofs)) v' = Some m'
  /\ m' |= frame_contents j sp (Locmap.set (S Local ofs ty) v ls) ls0 parent retaddr ** P.
Proof.
  intros. unfold frame_contents in H.
  exploit mconj_proj1; eauto. unfold frame_contents_1. 
  rewrite ! sep_assoc; intros SEP.
  unfold slot_valid in H1; InvBooleans. simpl in H0. 
  exploit set_location; eauto. intros (m' & A & B).
  exists m'; split; auto.
  assert (forall i k p, Mem.perm m sp i k p -> Mem.perm m' sp i k p).
  {  intros. unfold store_stack in A; simpl in A. eapply Mem.perm_store_1; eauto. }
  eapply frame_mconj. eauto.
  unfold frame_contents_1; rewrite ! sep_assoc; exact B.
  eapply sep_preserved.
  eapply sep_proj1. eapply mconj_proj2. eassumption.
  intros; eapply range_preserved; eauto.
  intros; eapply range_preserved; eauto.
Qed.

Lemma frame_set_outgoing:
  forall ofs ty v v' j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  slot_within_bounds b Outgoing ofs ty -> slot_valid f Outgoing ofs ty = true ->
  Val.inject j v v' ->
  exists m',
     store_stack m (Vptr sp Ptrofs.zero) ty (Ptrofs.repr (offset_arg ofs)) v' = Some m'
  /\ m' |= frame_contents j sp (Locmap.set (S Outgoing ofs ty) v ls) ls0 parent retaddr ** P.
Proof.
  intros. unfold frame_contents in H.
  exploit mconj_proj1; eauto. unfold frame_contents_1.
  rewrite ! sep_assoc, sep_swap. intros SEP. 
  unfold slot_valid in H1; InvBooleans. simpl in H0. 
  exploit set_location; eauto. intros (m' & A & B).
  exists m'; split; auto.
  assert (forall i k p, Mem.perm m sp i k p -> Mem.perm m' sp i k p).
  {  intros. unfold store_stack in A; simpl in A. eapply Mem.perm_store_1; eauto. }
  eapply frame_mconj. eauto.
  unfold frame_contents_1; rewrite ! sep_assoc, sep_swap; eauto.
  eapply sep_preserved.
  eapply sep_proj1. eapply mconj_proj2. eassumption.
  intros; eapply range_preserved; eauto.
  intros; eapply range_preserved; eauto.
Qed.

(** Invariance by change of location maps. *)

Lemma frame_contents_exten:
  forall ls ls0 ls' ls0' j sp parent retaddr P m,
  (forall sl ofs ty, ls' (S sl ofs ty) = ls (S sl ofs ty)) ->
  (forall r, In r b.(used_callee_save) -> ls0' (R r) = ls0 (R r)) ->
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  m |= frame_contents j sp ls' ls0' parent retaddr ** P.
Proof.
  unfold frame_contents, frame_contents_1; intros.
  rewrite <- ! (contains_locations_exten ls ls') by auto.
  erewrite  <- contains_callee_saves_exten by eauto.
  assumption.
Qed.

(** Invariance by assignment to registers. *)

Corollary frame_set_reg:
  forall r v j sp ls ls0 parent retaddr m P,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  m |= frame_contents j sp (Locmap.set (R r) v ls) ls0 parent retaddr ** P.
Proof.
  intros. apply frame_contents_exten with ls ls0; auto.
Qed.

Corollary frame_undef_regs:
  forall j sp ls ls0 parent retaddr m P rl,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  m |= frame_contents j sp (LTL.undef_regs rl ls) ls0 parent retaddr ** P.
Proof.
Local Opaque sepconj.
  induction rl; simpl; intros.
- auto.
- apply frame_set_reg; auto. 
Qed.

Corollary frame_set_regpair:
  forall j sp ls0 parent retaddr m P p v ls,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  m |= frame_contents j sp (Locmap.setpair p v ls) ls0 parent retaddr ** P.
Proof.
  intros. destruct p; simpl.
  apply frame_set_reg; auto.
  apply frame_set_reg; apply frame_set_reg; auto.
Qed.

Corollary frame_set_res:
  forall j sp ls0 parent retaddr m P res v ls,
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  m |= frame_contents j sp (Locmap.setres res v ls) ls0 parent retaddr ** P.
Proof.
  induction res; simpl; intros.
- apply frame_set_reg; auto.
- auto.
- eauto.
Qed.

(** Invariance by change of memory injection. *)

Lemma frame_contents_incr:
  forall j sp ls ls0 parent retaddr m P j',
  m |= frame_contents j sp ls ls0 parent retaddr ** P ->
  inject_incr j j' ->
  m |= frame_contents j' sp ls ls0 parent retaddr ** P.
Proof.
  unfold frame_contents, frame_contents_1; intros.
  rewrite <- (contains_locations_incr j j') by auto.
  rewrite <- (contains_locations_incr j j') by auto.
  erewrite  <- contains_callee_saves_incr by eauto.
  assumption.
Qed.

(** * Agreement between location sets and Mach states *)

(** Agreement with Mach register states *)

Definition agree_regs (j: meminj) (ls: locset) (rs: regset) : Prop :=
  forall r, Val.inject j (ls (R r)) (rs r).

(** Agreement over locations *)

Record agree_locs (ls ls0: locset) : Prop :=
  mk_agree_locs {

    (** Unused registers have the same value as in the caller *)
    agree_unused_reg:
       forall r, ~(mreg_within_bounds b r) -> ls (R r) = ls0 (R r);

    (** Incoming stack slots have the same value as the
        corresponding Outgoing stack slots in the caller *)
    agree_incoming:
       forall ofs ty,
       In (S Incoming ofs ty) (regs_of_rpairs (loc_parameters f.(Linear.fn_sig))) ->
       ls (S Incoming ofs ty) = ls0 (S Outgoing ofs ty)
}.

(** Auxiliary predicate used at call points *)

Definition agree_callee_save (ls ls0: locset) : Prop :=
  forall l,
  match l with
  | R r => is_callee_save r = true
  | S _ _ _ => True
  end ->
  ls l = ls0 l.

(** ** Properties of [agree_regs]. *)

(** Values of registers *)

Lemma agree_reg:
  forall j ls rs r,
  agree_regs j ls rs -> Val.inject j (ls (R r)) (rs r).
Proof.
  intros. auto.
Qed.

Lemma agree_reglist:
  forall j ls rs rl,
  agree_regs j ls rs -> Val.inject_list j (reglist ls rl) (rs##rl).
Proof.
  induction rl; simpl; intros.
  auto. constructor; auto using agree_reg.
Qed.

Hint Resolve agree_reg agree_reglist: stacking.

(** Preservation under assignments of machine registers. *)

Lemma agree_regs_set_reg:
  forall j ls rs r v v',
  agree_regs j ls rs ->
  Val.inject j v v' ->
  agree_regs j (Locmap.set (R r) v ls) (Regmap.set r v' rs).
Proof.
  intros; red; intros.
  unfold Regmap.set. destruct (RegEq.eq r0 r). subst r0.
  rewrite Locmap.gss; auto.
  rewrite Locmap.gso; auto. red. auto.
Qed.

Lemma agree_regs_set_pair:
  forall j p v v' ls rs,
  agree_regs j ls rs ->
  Val.inject j v v' ->
  agree_regs j (Locmap.setpair p v ls) (set_pair p v' rs).
Proof.
  intros. destruct p; simpl.
- apply agree_regs_set_reg; auto.
- apply agree_regs_set_reg. apply agree_regs_set_reg; auto. 
  apply Val.hiword_inject; auto. apply Val.loword_inject; auto.
Qed.

Lemma agree_regs_set_res:
  forall j res v v' ls rs,
  agree_regs j ls rs ->
  Val.inject j v v' ->
  agree_regs j (Locmap.setres res v ls) (set_res res v' rs).
Proof.
  induction res; simpl; intros.
- apply agree_regs_set_reg; auto.
- auto.
- apply IHres2. apply IHres1. auto.
  apply Val.hiword_inject; auto.
  apply Val.loword_inject; auto.
Qed.

Lemma agree_regs_exten:
  forall j ls rs ls' rs',
  agree_regs j ls rs ->
  (forall r, ls' (R r) = Vundef \/ ls' (R r) = ls (R r) /\ rs' r = rs r) ->
  agree_regs j ls' rs'.
Proof.
  intros; red; intros.
  destruct (H0 r) as [A | [A B]].
  rewrite A. constructor.
  rewrite A; rewrite B; auto.
Qed.

Lemma agree_regs_undef_regs:
  forall j rl ls rs,
  agree_regs j ls rs ->
  agree_regs j (LTL.undef_regs rl ls) (Mach.undef_regs rl rs).
Proof.
  induction rl; simpl; intros.
  auto.
  apply agree_regs_set_reg; auto.
Qed.

(** Preservation under assignment of stack slot *)

Lemma agree_regs_set_slot:
  forall j ls rs sl ofs ty v,
  agree_regs j ls rs ->
  agree_regs j (Locmap.set (S sl ofs ty) v ls) rs.
Proof.
  intros; red; intros. rewrite Locmap.gso; auto. red. auto.
Qed.

(** Preservation by increasing memory injections *)

Lemma agree_regs_inject_incr:
  forall j ls rs j',
  agree_regs j ls rs -> inject_incr j j' -> agree_regs j' ls rs.
Proof.
  intros; red; intros; eauto with stacking.
Qed.

(** Preservation at function entry. *)

Lemma agree_regs_call_regs:
  forall j ls rs,
  agree_regs j ls rs ->
  agree_regs j (call_regs ls) rs.
Proof.
  intros.
  unfold call_regs; intros; red; intros; auto.
Qed.

(** ** Properties of [agree_locs] *)

(** Preservation under assignment of machine register. *)

Lemma agree_locs_set_reg:
  forall ls ls0 r v,
  agree_locs ls ls0 ->
  mreg_within_bounds b r ->
  agree_locs (Locmap.set (R r) v ls) ls0.
Proof.
  intros. inv H; constructor; auto; intros.
  rewrite Locmap.gso. auto. red. intuition congruence.
Qed.

Lemma caller_save_reg_within_bounds:
  forall r,
  is_callee_save r = false -> mreg_within_bounds b r.
Proof.
  intros; red; intros. congruence.
Qed.

Lemma agree_locs_set_pair:
  forall ls0 p v ls,
  agree_locs ls ls0 ->
  forall_rpair (fun r => is_callee_save r = false) p ->
  agree_locs (Locmap.setpair p v ls) ls0.
Proof.
  intros.
  destruct p; simpl in *.
  apply agree_locs_set_reg; auto. apply caller_save_reg_within_bounds; auto.
  destruct H0.
  apply agree_locs_set_reg; auto. apply agree_locs_set_reg; auto.
  apply caller_save_reg_within_bounds; auto. apply caller_save_reg_within_bounds; auto. 
Qed.

Lemma agree_locs_set_res:
  forall ls0 res v ls,
  agree_locs ls ls0 ->
  (forall r, In r (params_of_builtin_res res) -> mreg_within_bounds b r) ->
  agree_locs (Locmap.setres res v ls) ls0.
Proof.
  induction res; simpl; intros.
- eapply agree_locs_set_reg; eauto.
- auto.
- apply IHres2; auto using in_or_app.
Qed.

Lemma agree_locs_undef_regs:
  forall ls0 regs ls,
  agree_locs ls ls0 ->
  (forall r, In r regs -> mreg_within_bounds b r) ->
  agree_locs (LTL.undef_regs regs ls) ls0.
Proof.
  induction regs; simpl; intros.
  auto.
  apply agree_locs_set_reg; auto.
Qed.

Lemma agree_locs_undef_locs_1:
  forall ls0 regs ls,
  agree_locs ls ls0 ->
  (forall r, In r regs -> is_callee_save r = false) ->
  agree_locs (LTL.undef_regs regs ls) ls0.
Proof.
  intros. eapply agree_locs_undef_regs; eauto.
  intros. apply caller_save_reg_within_bounds. auto.
Qed.

Lemma agree_locs_undef_locs:
  forall ls0 regs ls,
  agree_locs ls ls0 ->
  existsb is_callee_save regs = false ->
  agree_locs (LTL.undef_regs regs ls) ls0.
Proof.
  intros. eapply agree_locs_undef_locs_1; eauto. 
  intros. destruct (is_callee_save r) eqn:CS; auto. 
  assert (existsb is_callee_save regs = true).
  { apply existsb_exists. exists r; auto. }
  congruence.
Qed.

(** Preservation by assignment to local slot *)

Lemma agree_locs_set_slot:
  forall ls ls0 sl ofs ty v,
  agree_locs ls ls0 ->
  slot_writable sl = true ->
  agree_locs (Locmap.set (S sl ofs ty) v ls) ls0.
Proof.
  intros. destruct H; constructor; intros.
- rewrite Locmap.gso; auto. red; auto.
- rewrite Locmap.gso; auto. red. left. destruct sl; discriminate.
Qed.

(** Preservation at return points (when [ls] is changed but not [ls0]). *)

Lemma agree_locs_return:
  forall ls ls0 ls',
  agree_locs ls ls0 ->
  agree_callee_save ls' ls ->
  agree_locs ls' ls0.
Proof.
  intros. red in H0. inv H; constructor; auto; intros.
- rewrite H0; auto. unfold mreg_within_bounds in H. tauto.
- rewrite H0; auto.
Qed.

(** Preservation at tailcalls (when [ls0] is changed but not [ls]). *)

Lemma agree_locs_tailcall:
  forall ls ls0 ls0',
  agree_locs ls ls0 ->
  agree_callee_save ls0 ls0' ->
  agree_locs ls ls0'.
Proof.
  intros. red in H0. inv H; constructor; auto; intros.
- rewrite <- H0; auto. unfold mreg_within_bounds in H. tauto.
- rewrite <- H0; auto.
Qed.

(** ** Properties of [agree_callee_save]. *)

Lemma agree_callee_save_return_regs:
  forall ls1 ls2,
  agree_callee_save (return_regs ls1 ls2) ls1.
Proof.
  intros; red; intros.
  unfold return_regs. destruct l; auto. rewrite H; auto.
Qed.

Lemma agree_callee_save_set_result:
  forall sg v ls1 ls2,
  agree_callee_save ls1 ls2 ->
  agree_callee_save (Locmap.setpair (loc_result sg) v ls1) ls2.
Proof.
  intros; red; intros. rewrite Locmap.gpo. apply H; auto. 
  assert (X: forall r, is_callee_save r = false -> Loc.diff l (R r)).
  { intros. destruct l; auto. simpl; congruence. }
  generalize (loc_result_caller_save sg). destruct (loc_result sg); simpl; intuition auto.
Qed.

(** ** Properties of destroyed registers. *)

Definition no_callee_saves (l: list mreg) : Prop :=
  existsb is_callee_save l = false.

Remark destroyed_by_op_caller_save:
  forall op, no_callee_saves (destroyed_by_op op).
Proof.
  unfold no_callee_saves; destruct op; reflexivity.
Qed.

Remark destroyed_by_load_caller_save:
  forall chunk addr, no_callee_saves (destroyed_by_load chunk addr).
Proof.
  unfold no_callee_saves; destruct chunk; reflexivity.
Qed.

Remark destroyed_by_store_caller_save:
  forall chunk addr, no_callee_saves (destroyed_by_store chunk addr).
Proof.
Local Transparent destroyed_by_store.
  unfold no_callee_saves, destroyed_by_store; intros; destruct chunk; try reflexivity; destruct Archi.ptr64; reflexivity.
Qed.

Remark destroyed_by_cond_caller_save:
  forall cond, no_callee_saves (destroyed_by_cond cond).
Proof.
  unfold no_callee_saves; destruct cond; reflexivity.
Qed.

Remark destroyed_by_jumptable_caller_save:
  no_callee_saves destroyed_by_jumptable.
Proof.
  red; reflexivity.
Qed.

Remark destroyed_by_setstack_caller_save:
  forall ty, no_callee_saves (destroyed_by_setstack ty).
Proof.
  unfold no_callee_saves; destruct ty; reflexivity.
Qed.

Remark destroyed_at_function_entry_caller_save:
  no_callee_saves destroyed_at_function_entry.
Proof.
  red; reflexivity.
Qed.

Hint Resolve destroyed_by_op_caller_save destroyed_by_load_caller_save
    destroyed_by_store_caller_save
    destroyed_by_cond_caller_save destroyed_by_jumptable_caller_save
    destroyed_at_function_entry_caller_save: stacking.

Remark destroyed_by_setstack_function_entry:
  forall ty, incl (destroyed_by_setstack ty) destroyed_at_function_entry.
Proof.
Local Transparent destroyed_by_setstack destroyed_at_function_entry.
  unfold incl; destruct ty; simpl; tauto.
Qed.

Remark transl_destroyed_by_op:
  forall op e, destroyed_by_op (transl_op e op) = destroyed_by_op op.
Proof.
  intros; destruct op; reflexivity.
Qed.

Remark transl_destroyed_by_load:
  forall chunk addr e, destroyed_by_load chunk (transl_addr e addr) = destroyed_by_load chunk addr.
Proof.
  intros; destruct chunk; reflexivity.
Qed.

Remark transl_destroyed_by_store:
  forall chunk addr e, destroyed_by_store chunk (transl_addr e addr) = destroyed_by_store chunk addr.
Proof.
  intros; destruct chunk; reflexivity.
Qed.

(** * Correctness of saving and restoring of callee-save registers *)

(** The following lemmas show the correctness of the register saving
  code generated by [save_callee_save]: after this code has executed,
  the register save areas of the current frame do contain the
  values of the callee-save registers used by the function. *)

Section SAVE_CALLEE_SAVE.

Variable j: meminj.
Variable cs: list stackframe.
Variable fb: block.
Variable sp: block.
Variable ls: locset.

Hypothesis ls_temp_undef:
  forall ty r, In r (destroyed_by_setstack ty) -> ls (R r) = Vundef.

Hypothesis wt_ls: forall r, Val.has_type (ls (R r)) (mreg_type r).

Lemma save_callee_save_rec_correct:
  forall k l pos rs m P,
  (forall r, In r l -> is_callee_save r = true) ->
  m |= range sp pos (size_callee_save_area_rec l pos) ** P ->
  agree_regs j ls rs ->
  exists rs', exists m',
     star step tge
        (State cs fb (Vptr sp Ptrofs.zero) (save_callee_save_rec l pos k) rs m)
     E0 (State cs fb (Vptr sp Ptrofs.zero) k rs' m')
  /\ m' |= contains_callee_saves j sp pos l ls ** P
  /\ (forall ofs k p, Mem.perm m sp ofs k p -> Mem.perm m' sp ofs k p)
  /\ agree_regs j ls rs'.
Proof.
Local Opaque mreg_type.
  induction l as [ | r l]; simpl; intros until P; intros CS SEP AG.
- exists rs, m. 
  split. apply star_refl.
  split. rewrite sep_pure; split; auto. eapply sep_drop; eauto.
  split. auto. 
  auto.
- set (ty := mreg_type r) in *.
  set (sz := AST.typesize ty) in *.
  set (pos1 := align pos sz) in *.
  assert (SZPOS: sz > 0) by (apply AST.typesize_pos).
  assert (SZREC: pos1 + sz <= size_callee_save_area_rec l (pos1 + sz)) by (apply size_callee_save_area_rec_incr).
  assert (POS1: pos <= pos1) by (apply align_le; auto).
  assert (AL1: (align_chunk (chunk_of_type ty) | pos1)).
  { unfold pos1. apply Zdivide_trans with sz.
    unfold sz; rewrite <- size_type_chunk. apply align_size_chunk_divides.
    apply align_divides; auto. }
  apply range_drop_left with (mid := pos1) in SEP; [ | omega ].
  apply range_split with (mid := pos1 + sz) in SEP; [ | omega ].
  unfold sz at 1 in SEP. rewrite <- size_type_chunk in SEP.
  apply range_contains in SEP; auto.
  exploit (contains_set_stack (fun v' => Val.inject j (ls (R r)) v') (rs r)).
  eexact SEP.
  apply load_result_inject; auto. apply wt_ls. 
  clear SEP; intros (m1 & STORE & SEP).
  set (rs1 := undef_regs (destroyed_by_setstack ty) rs).
  assert (AG1: agree_regs j ls rs1).
  { red; intros. unfold rs1. destruct (In_dec mreg_eq r0 (destroyed_by_setstack ty)).
    erewrite ls_temp_undef by eauto. auto.
    rewrite undef_regs_other by auto. apply AG. }
  rewrite sep_swap in SEP. 
  exploit (IHl (pos1 + sz) rs1 m1); eauto.
  intros (rs2 & m2 & A & B & C & D).
  exists rs2, m2. 
  split. eapply star_left; eauto. constructor. exact STORE. auto. traceEq.
  split. rewrite sep_assoc, sep_swap. exact B.
  split. intros. apply C. unfold store_stack in STORE; simpl in STORE. eapply Mem.perm_store_1; eauto.
  auto.
Qed.

End SAVE_CALLEE_SAVE.

Remark LTL_undef_regs_same:
  forall r rl ls, In r rl -> LTL.undef_regs rl ls (R r) = Vundef.
Proof.
  induction rl; simpl; intros. contradiction.
  unfold Locmap.set. destruct (Loc.eq (R a) (R r)). auto.
  destruct (Loc.diff_dec (R a) (R r)); auto.
  apply IHrl. intuition congruence.
Qed.

Remark LTL_undef_regs_others:
  forall r rl ls, ~In r rl -> LTL.undef_regs rl ls (R r) = ls (R r).
Proof.
  induction rl; simpl; intros. auto.
  rewrite Locmap.gso. apply IHrl. intuition. red. intuition.
Qed.

Remark LTL_undef_regs_slot:
  forall sl ofs ty rl ls, LTL.undef_regs rl ls (S sl ofs ty) = ls (S sl ofs ty).
Proof.
  induction rl; simpl; intros. auto.
  rewrite Locmap.gso. apply IHrl. red; auto.
Qed.

Remark undef_regs_type:
  forall ty l rl ls,
  Val.has_type (ls l) ty -> Val.has_type (LTL.undef_regs rl ls l) ty.
Proof.
  induction rl; simpl; intros.
- auto.
- unfold Locmap.set. destruct (Loc.eq (R a) l). red; auto.
  destruct (Loc.diff_dec (R a) l); auto. red; auto.
Qed.

Lemma save_callee_save_correct:
  forall j ls ls0 rs sp cs fb k m P,
  m |= range sp fe.(fe_ofs_callee_save) (size_callee_save_area b fe.(fe_ofs_callee_save)) ** P ->
  (forall r, Val.has_type (ls (R r)) (mreg_type r)) ->
  agree_callee_save ls ls0 ->
  agree_regs j ls rs ->
  let ls1 := LTL.undef_regs destroyed_at_function_entry (LTL.call_regs ls) in
  let rs1 := undef_regs destroyed_at_function_entry rs in
  exists rs', exists m',
     star step tge
        (State cs fb (Vptr sp Ptrofs.zero) (save_callee_save fe k) rs1 m)
     E0 (State cs fb (Vptr sp Ptrofs.zero) k rs' m')
  /\ m' |= contains_callee_saves j sp fe.(fe_ofs_callee_save) b.(used_callee_save) ls0 ** P
  /\ (forall ofs k p, Mem.perm m sp ofs k p -> Mem.perm m' sp ofs k p)
  /\ agree_regs j ls1 rs'.
Proof.
  intros until P; intros SEP TY AGCS AG; intros ls1 rs1.
  exploit (save_callee_save_rec_correct j cs fb sp ls1).
- intros. unfold ls1. apply LTL_undef_regs_same. eapply destroyed_by_setstack_function_entry; eauto.
- intros. unfold ls1. apply undef_regs_type. apply TY. 
- exact b.(used_callee_save_prop).
- eexact SEP.
- instantiate (1 := rs1). apply agree_regs_undef_regs. apply agree_regs_call_regs. auto.
- clear SEP. intros (rs' & m' & EXEC & SEP & PERMS & AG').
  exists rs', m'. 
  split. eexact EXEC.
  split. rewrite (contains_callee_saves_exten j sp ls0 ls1). exact SEP.
  intros. apply b.(used_callee_save_prop) in H.
    unfold ls1. rewrite LTL_undef_regs_others. unfold call_regs. 
    apply AGCS; auto.
    red; intros.
    assert (existsb is_callee_save destroyed_at_function_entry = false)
       by  (apply destroyed_at_function_entry_caller_save).
    assert (existsb is_callee_save destroyed_at_function_entry = true).
    { apply existsb_exists. exists r; auto. }
    congruence.
  split. exact PERMS. exact AG'.
Qed.

(** As a corollary of the previous lemmas, we obtain the following
  correctness theorem for the execution of a function prologue
  (allocation of the frame + saving of the link and return address +
  saving of the used callee-save registers). *)

Lemma function_prologue_correct:
  forall j ls ls0 ls1 rs rs1 m1 m1' m2 (*SACC:*)m2' sp parent ra cs fb k P,
(*SACC:*)m_invar_stack P = false ->
  agree_regs j ls rs ->
  agree_callee_save ls ls0 ->
  (forall r, Val.has_type (ls (R r)) (mreg_type r)) ->
  ls1 = LTL.undef_regs destroyed_at_function_entry (LTL.call_regs ls) ->
  rs1 = undef_regs destroyed_at_function_entry rs ->
  Mem.alloc m1 0 f.(Linear.fn_stacksize) = (m2', sp) ->
(*SACC:*)Mem.record_stack_blocks m2' (make_singleton_frame_adt sp (Linear.fn_stacksize f) (fe_size fe)) = Some m2 ->
  Val.has_type parent Tptr -> Val.has_type ra Tptr -> ra <> Vundef ->
(*SACC:*)top_tframe_tc (Mem.stack m1') ->
(*SACC:*)stack_equiv (Mem.stack m1) (Mem.stack m1') ->
  m1' |= minjection j ((*SACC:*)flat_frameinj (length (Mem.stack m1))) m1 ** globalenv_inject ge j ** P ->
  exists j', exists rs', exists m2', exists sp', exists m3', exists m4', exists m5',
     Mem.alloc m1' 0 tf.(fn_stacksize) = (m2', sp')
(*SACC:*)(*/\ store_stack m2' (Vptr sp' Ptrofs.zero) Tptr tf.(fn_link_ofs) parent = Some m3'*)
  /\ store_stack m2' (Vptr sp' Ptrofs.zero) Tptr tf.(fn_retaddr_ofs) ra = Some m3'
(*SACC:*)/\ Mem.record_stack_blocks m3' (make_singleton_frame_adt sp' (fn_stacksize tf) (fn_stacksize tf)) = Some m4'
  /\ star step tge
         (State cs fb (Vptr sp' Ptrofs.zero) (save_callee_save fe k) rs1 m4')
      E0 (State cs fb (Vptr sp' Ptrofs.zero) k rs' m5')
  /\ agree_regs j' ls1 rs'
  /\ agree_locs ls1 ls0
  /\ m5' |= frame_contents j' sp' ls1 ls0 parent ra ** minjection j' ((*SACC:*)flat_frameinj (length (Mem.stack m2))) m2 ** globalenv_inject ge j' ** P
  /\ j' sp = Some(sp', fe.(fe_stack_data))
  /\ inject_incr j j'.
Proof.
  intros until P; intros STACK AGREGS AGCS WTREGS LS1 RS1 ALLOC RECORD TYPAR TYRA VNU TTNP SE SEP.
  rewrite unfold_transf_function.
  unfold fn_stacksize, fn_retaddr_ofs.
  (* Stack layout info *)
  Local Opaque b fe.
  generalize (frame_env_range b) (frame_env_aligned b). replace (make_env b) with fe by auto. simpl. 
  intros LAYOUT1 LAYOUT2.
  (* Allocation step *)
  destruct (Mem.alloc m1' 0 (fe_size fe)) as [m2'' sp'] eqn:ALLOC'.
  exploit alloc_parallel_rule_2_flat.
  eexact SEP. eexact ALLOC. eexact ALLOC'. 
  instantiate (1 := fe_stack_data fe). tauto.
  reflexivity. 
  instantiate (1 := fe_stack_data fe + bound_stack_data b). rewrite Z.max_comm. reflexivity.
  generalize (bound_stack_data_pos b) size_no_overflow; omega.
  tauto.
  tauto.
  rename SEP into SEP_INIT. intros (j' & SEP & INCR & SAME).
  (* Remember the freeable permissions using a mconj *)
  assert (SEPCONJ:
    m2'' |= mconj (range sp' 0 (fe_stack_data fe) ** range sp' (fe_stack_data fe + bound_stack_data b) (fe_size fe))
                 (range sp' 0 (fe_stack_data fe) ** range sp' (fe_stack_data fe + bound_stack_data b) (fe_size fe))
           ** minjection j' (flat_frameinj (length (Mem.stack m2'))) m2' ** globalenv_inject ge j' ** P).
  { apply mconj_intro; rewrite sep_assoc; assumption. }
  (* Dividing up the frame *)
  apply (frame_env_separated b) in SEP. replace (make_env b) with fe in SEP by auto.
  (* Store of parent *)
  rewrite sep_swap3 in SEP.
  apply (range_contains Mptr) in SEP; [|tauto].
  exploit (contains_ra_set_stack ra (fun _ => True) m2'').
  eexact SEP.
  auto.
  auto.
  clear SEP; intros (m3' & STORE_PARENT & SEP).
  rewrite sep_swap3 in SEP.
  assert (SEP' : m3' |= minjection j' (flat_frameinj (length (Mem.stack m2'))) m2' **
                     range sp' (fe_ofs_local fe) (fe_ofs_local fe + 4 * bound_local b) **
                     range sp' fe_ofs_arg (fe_ofs_arg + 4 * bound_outgoing b) **
                     contains_ra sp' (fe_ofs_retaddr fe) ra **
                     range sp' (fe_ofs_callee_save fe) (size_callee_save_area b (fe_ofs_callee_save fe)) **
                     globalenv_inject ge j' ** P).
  {
    rewrite sep_swap12.
    rewrite sep_swap23.
    rewrite sep_swap34.
    rewrite sep_swap45. auto.
  }
  (* Store of return address *)
  exploit record_stack_block_parallel_rule_2. 
  eapply SAME.
  2: apply SEP'.
  auto.
  {
    intro INF.
    erewrite store_stack_unchanged in INF. 2: eauto.
    erewrite Mem.alloc_stack_unchanged in INF; eauto.
    eapply Mem.in_stack_valid in INF. eapply Mem.fresh_block_alloc in INF; eauto.
  }
  eauto.
  {
    intros. eapply Mem.perm_implies. eapply Mem.perm_alloc_2; eauto.
    constructor.
  }
  {
    intros ofs k0 p PERM.
    unfold store_stack in STORE_PARENT. simpl in STORE_PARENT.
    eapply Mem.perm_store_2 in PERM. 2: eauto.
    eapply Mem.perm_alloc_inv in PERM. 2: eauto. 
    rewrite pred_dec_true in PERM; auto.
    instantiate (1 := fn_stacksize tf).
    rewrite unfold_transf_function; simpl; auto.
  }
  {
    intros.
    destruct (j bb) eqn:JBB.
    destruct p.
    exploit INCR. eauto. rewrite H. intro A; inv A.
    eapply Mem.valid_block_inject_2 in JBB; eauto. 2: apply SEP_INIT.
    eapply Mem.fresh_block_alloc in JBB; eauto. easy.
    destruct SAME as [SAME INJSEP].
    generalize (INJSEP _ _ _ JBB H). intros (NVB1 & NVB2).
    destruct (peq bb sp); auto.
    exfalso; apply NVB1. eapply Mem.valid_block_alloc_inv in ALLOC.
    destruct ALLOC; eauto. congruence.
    eapply Mem.valid_block_inject_1; eauto.
    apply SEP.
  }
  {
    unfold store_stack in STORE_PARENT. repeat rewrite_stack_blocks.
    auto.
  }
  repeat rewrite_stack_blocks. rewrite (store_stack_unchanged _ _ _ _ _ _ STORE_PARENT).
  repeat rewrite_stack_blocks. eauto.
  intros (m5' & RSB & SEP2).
  (* Saving callee-save registers *)
  assert (SEP3 : m5'
         |= range sp' (fe_ofs_local fe) (fe_ofs_local fe + 4 * bound_local b) **
            range sp' fe_ofs_arg (fe_ofs_arg + 4 * bound_outgoing b) **
            contains_ra sp' (fe_ofs_retaddr fe) ra **
            range sp' (fe_ofs_callee_save fe) (size_callee_save_area b (fe_ofs_callee_save fe)) **
            minjection j' (flat_frameinj (length (Mem.stack m2))) m2 **
            globalenv_inject ge j' ** P).
  {
    rewrite <- ! (sep_swap (minjection j' _ m2)). auto.
  }
  clear SEP2 SEP' SEP.
  rename SEP3 into SEP.
  rewrite sep_swap4 in SEP.
  exploit (save_callee_save_correct j' ls ls0 rs); eauto.
  apply agree_regs_inject_incr with j; auto.
  replace (LTL.undef_regs destroyed_at_function_entry (call_regs ls)) with ls1 by auto.
  replace (undef_regs destroyed_at_function_entry rs) with rs1 by auto.
  simpl.
  clear SEP; intros (rs2 & m6' & SAVE_CS & SEP & PERMS & AGREGS').
  rewrite sep_swap4 in SEP.
  (* Materializing the Local and Outgoing locations *)
  exploit (initial_locations j'). eexact SEP. tauto. 
  instantiate (1 := Local). instantiate (1 := ls1). 
  intros; rewrite LS1. rewrite LTL_undef_regs_slot. reflexivity.
  clear SEP; intros SEP.
  rewrite sep_swap in SEP.
  exploit (initial_locations j'). eexact SEP. tauto. 
  instantiate (1 := Outgoing). instantiate (1 := ls1). 
  intros; rewrite LS1. rewrite LTL_undef_regs_slot. reflexivity.
  clear SEP; intros SEP.
  rewrite sep_swap in SEP.
  (* Now we frame this *)
  assert (SEPFINAL: m6' |= frame_contents j' sp' ls1 ls0 parent ra ** minjection j' (flat_frameinj (length (Mem.stack m2))) m2 ** globalenv_inject ge j' ** P).
  { 
    assert (forall ofs k p, Mem.perm m2'' sp' ofs k p -> Mem.perm m6' sp' ofs k p) as PERMS'.
    { intros. apply PERMS. 
        unfold store_stack in STORE_PARENT.
        eapply Mem.record_stack_block_perm'. eauto.
        simpl in STORE_PARENT.
        eapply Mem.perm_store_1 in H; eauto.
    }
    assert (  m6' |= range sp' 0 (fe_stack_data fe) ** range sp' (fe_stack_data fe + bound_stack_data b) (fe_size fe)) as RANGE.
    {
      split. eapply range_preserved. apply SEPCONJ. auto.
      split. eapply range_preserved. apply SEPCONJ. auto.
      red; intros b0 ofs R1 R2. simpl in R1, R2.
      generalize (bound_stack_data_pos b). omega.
    }
    eapply frame_mconj.
    - split. split; apply RANGE. 
      split. eapply SEP.
      intros bb o. simpl.
      intros FP1 FP2.      
      destruct SEPCONJ as (? & ? & DISJ).
      apply (DISJ bb o). simpl. auto.
      change (m_footprint (minjection j' (flat_frameinj (length (Mem.stack m2')))  m2') bb o \/ m_footprint (globalenv_inject ge j' ** P) bb o).
      change (m_footprint (minjection j' (flat_frameinj (length (Mem.stack m2)))  m2) bb o \/ m_footprint (globalenv_inject ge j' ** P) bb o) in FP2.
      destruct FP2 as [FP2|FP2]; auto.
      left.
      simpl. simpl in FP2.
      destruct FP2 as (b0 & delta & EQ & PERM).
      exists b0, delta; rewrite EQ; split; auto.
      eapply Mem.record_stack_block_perm in PERM; eauto.
    - unfold frame_contents_1; rewrite ! sep_assoc. exact SEP.
    - eapply sep_preserved. eapply sep_proj1. eapply mconj_proj2. eexact SEPCONJ.
      intros; apply range_preserved with m2''; auto.
      intros; apply range_preserved with m2''; auto.
  }
  clear SEP SEPCONJ.
(* Conclusions *)
  exists j', rs2, m2'', sp', m3', m5', m6'. eexists.
  split. auto.
  split. auto.
  split. rewrite unfold_transf_function in RSB. simpl in RSB. auto.
  split. subst. eexact SAVE_CS.
  split. subst. exact AGREGS'.
  split. rewrite LS1. apply agree_locs_undef_locs; [|reflexivity].
  constructor; intros. unfold call_regs. apply AGCS. 
  unfold mreg_within_bounds in H; tauto.
  unfold call_regs. apply AGCS. auto.
  split. exact SEPFINAL.
  split. apply SAME.
  exact INCR.
Qed.

(** The following lemmas show the correctness of the register reloading
  code generated by [reload_callee_save]: after this code has executed,
  all callee-save registers contain the same values they had at
  function entry. *)

Section RESTORE_CALLEE_SAVE.

Variable j: meminj.
Variable cs: list stackframe.
Variable fb: block.
Variable sp: block.
Variable ls0: locset.
Variable m: mem.

Definition agree_unused (ls0: locset) (rs: regset) : Prop :=
  forall r, ~(mreg_within_bounds b r) -> Val.inject j (ls0 (R r)) (rs r).

Lemma restore_callee_save_rec_correct:
  forall l ofs rs k,
  m |= contains_callee_saves j sp ofs l ls0 ->
  agree_unused ls0 rs ->
  (forall r, In r l -> mreg_within_bounds b r) ->
  exists rs',
    star step tge
      (State cs fb (Vptr sp Ptrofs.zero) (restore_callee_save_rec l ofs k) rs m)
   E0 (State cs fb (Vptr sp Ptrofs.zero) k rs' m)
  /\ (forall r, In r l -> Val.inject j (ls0 (R r)) (rs' r))
  /\ (forall r, ~(In r l) -> rs' r = rs r)
  /\ agree_unused ls0 rs'.
Proof.
Local Opaque mreg_type.
  induction l as [ | r l]; simpl; intros.
- (* base case *)
  exists rs. intuition auto. apply star_refl.
- (* inductive case *)
  set (ty := mreg_type r) in *.
  set (sz := AST.typesize ty) in *.
  set (ofs1 := align ofs sz).
  assert (SZPOS: sz > 0) by (apply AST.typesize_pos).
  assert (OFSLE: ofs <= ofs1) by (apply align_le; auto).
  assert (BOUND: mreg_within_bounds b r) by eauto.
  exploit contains_get_stack.
    eapply sep_proj1; eassumption.
  intros (v & LOAD & SPEC).
  exploit (IHl (ofs1 + sz) (rs#r <- v)).
    eapply sep_proj2; eassumption.
    red; intros. rewrite Regmap.gso. auto. intuition congruence.
    eauto.
  intros (rs' & A & B & C & D).
  exists rs'.
  split. eapply star_step; eauto. 
    econstructor. exact LOAD. traceEq.
  split. intros.
    destruct (In_dec mreg_eq r0 l). auto. 
    assert (r = r0) by tauto. subst r0.
    rewrite C by auto. rewrite Regmap.gss. exact SPEC.
  split. intros. 
    rewrite C by tauto. apply Regmap.gso. intuition auto.
  exact D.
Qed.

End RESTORE_CALLEE_SAVE.

Lemma restore_callee_save_correct:
  forall m j sp ls ls0 pa ra P rs k cs fb,
  m |= frame_contents j sp ls ls0 pa ra ** P ->
  agree_unused j ls0 rs ->
  exists rs',
    star step tge
       (State cs fb (Vptr sp Ptrofs.zero) (restore_callee_save fe k) rs m)
    E0 (State cs fb (Vptr sp Ptrofs.zero) k rs' m)
  /\ (forall r,
        is_callee_save r = true -> Val.inject j (ls0 (R r)) (rs' r))
  /\ (forall r,
        is_callee_save r = false -> rs' r = rs r).
Proof.
  intros.
  unfold frame_contents, frame_contents_1 in H. 
  apply mconj_proj1 in H. rewrite ! sep_assoc in H. apply sep_pick4 in H. 
  exploit restore_callee_save_rec_correct; eauto.
  intros; unfold mreg_within_bounds; auto.
  intros (rs' & A & B & C & D).
  exists rs'.
  split. eexact A.
  split; intros.
  destruct (In_dec mreg_eq r (used_callee_save b)).
  apply B; auto.
  rewrite C by auto. apply H0. unfold mreg_within_bounds; tauto.
  apply C. red; intros. apply (used_callee_save_prop b) in H2. congruence.
Qed.

(** As a corollary, we obtain the following correctness result for
  the execution of a function epilogue (reloading of used callee-save
  registers + reloading of the link and return address + freeing
  of the frame). *)

Lemma function_epilogue_correct:
  forall m' j sp' ls ls0 pa ra P m rs sp m1 k cs fb,
(*SACC:*)m_invar_stack P = false ->
  m' |= frame_contents j sp' ls ls0 pa ra ** minjection j ((*SACC:*)flat_frameinj (length (Mem.stack m))) m ** P ->
  agree_regs j ls rs ->
  agree_locs ls ls0 ->
  j sp = Some(sp', fe.(fe_stack_data)) ->
  Mem.free m sp 0 f.(Linear.fn_stacksize) = Some m1 ->
(*SACC:*)stack_equiv (Mem.stack m) (Mem.stack m') ->
  exists rs1, exists m1',
(*SACC:*)(* load_stack m' (Vptr sp' Ptrofs.zero) Tptr tf.(fn_link_ofs) = Some pa *)
(*SACC:*)(*/\ load_stack m' (Vptr sp' Ptrofs.zero) Tptr tf.(fn_retaddr_ofs) = Some ra *)
(*SACC:*)Mem.loadbytesv Mptr m' (Val.offset_ptr (Vptr sp' Ptrofs.zero) tf.(fn_retaddr_ofs)) = Some ra
(*SACC:*)/\ Mem.free m' sp' 0 (fe_size fe) = Some m1'
  /\ Mem.free m' sp' 0 tf.(fn_stacksize) = Some m1'
  /\ star step tge
       (State cs fb (Vptr sp' Ptrofs.zero) (restore_callee_save fe k) rs m')
    E0 (State cs fb (Vptr sp' Ptrofs.zero) k rs1 m')
  /\ agree_regs j (return_regs ls0 ls) rs1
  /\ agree_callee_save (return_regs ls0 ls) ls0
  /\ m1' |= minjection j ((*SACC:*)flat_frameinj (length (Mem.stack m1))) m1 ** P
(*SACC:*)/\ stack_equiv (Mem.stack m1) (Mem.stack m1').
Proof.
  intros until fb; intros STACK SEP AGR AGL INJ FREE SE.
  (* Can free *)
  exploit free_parallel_rule.
  apply mconj_proj2 in SEP. rewrite <- sep_assoc. eauto. eauto.
  eexact INJ.
  auto. rewrite Z.max_comm; reflexivity.
  intros (m1' & FREE' & SEP').
  (* Reloading the callee-save registers *)
  exploit restore_callee_save_correct.
    eexact SEP.
    instantiate (1 := rs). 
    red; intros. destruct AGL. rewrite <- agree_unused_reg0 by auto. apply AGR.
  intros (rs' & LOAD_CS & CS & NCS).
  (* Reloading the back link and return address *)
  unfold frame_contents in SEP; apply mconj_proj1 in SEP.
  unfold frame_contents_1 in SEP; rewrite ! sep_assoc in SEP.
  assert (LOAD_RETADDR: Mem.loadbytesv Mptr m' (Val.offset_ptr (Vptr sp' Ptrofs.zero) (Ptrofs.repr (fe_ofs_retaddr fe))) = Some ra).
  {
    exploit sep_pick3. apply SEP. intros (A & B & C & D). simpl Val.offset_ptr. rewrite Ptrofs.add_zero_l. auto.
  }
  clear SEP.
  Local Opaque Mem.loadbytesv.
  (* Conclusions *)
  rewrite unfold_transf_function; simpl in *.
  exists rs', m1'.
  split. assumption.
  split. assumption.
  split. eassumption.
  split. eassumption.
  split. red; unfold return_regs; intros. 
    destruct (is_callee_save r) eqn:C.
    apply CS; auto.
    rewrite NCS by auto. apply AGR.
  split. red; unfold return_regs; intros.
    destruct l; auto. rewrite H; auto.
  split. rewrite_stack_blocks; assumption.
  repeat rewrite_stack_blocks; eauto.
Qed.

End FRAME_PROPERTIES.

(** * Call stack invariants *)

(** This is the memory assertion that captures the contents of the stack frames
  mentioned in the call stacks. *)

Fixpoint stack_contents (j: meminj) (cs: list Linear.stackframe) (cs': list Mach.stackframe) ((*SACC:*)stk : stack) : massert :=
  match cs, cs' with
  | nil, nil => pure True
  | Linear.Stackframe f _ ls c :: cs, Mach.Stackframe fb sp' ra c' :: cs' =>
      frame_contents f j sp' ls (parent_locset cs) (parent_sp (*SACC:*)stk) (parent_ra cs')
      ** stack_contents j cs cs' ((*SACC:*)tl stk)
  | _, _ => pure False
  end.

(*SACC:*)
Lemma stack_contents_invar_stack cs :
  forall j cs' stk, m_invar_stack (stack_contents j cs cs' stk) = false.
Proof.
  induction cs; destruct cs' ; simpl; intros; auto.
  + destruct a; auto.
  + destruct a; auto.
    destruct s; auto.
    match goal with
        [ |- context [m_invar_stack (?U ** ?V)] ] =>
        replace (m_invar_stack (U ** V))
                with (m_invar_stack U || m_invar_stack V)
          by reflexivity
    end.
    rewrite frame_contents_invar_stack.
    simpl.
    auto.
Qed.

(** [match_stacks] captures additional properties (not related to memory)
  of the Linear and Mach call stacks. *)

Inductive match_stacks (j: meminj):
       list Linear.stackframe -> list stackframe -> signature -> Prop :=
  | match_stacks_empty: forall sg,
      tailcall_possible sg ->
      match_stacks j nil nil sg
  | match_stacks_cons: forall f sp ls c cs fb sp' ra c' cs' sg trf
        (TAIL: is_tail c (Linear.fn_code f))
        (FINDF: Genv.find_funct_ptr tge fb = Some (Internal trf))
        (TRF: transf_function f = OK trf)
        (TRC: transl_code (make_env (function_bounds f)) c = c')
        (INJ: j sp = Some(sp', (fe_stack_data (make_env (function_bounds f)))))
        (TY_RA: Val.has_type ra Tptr)
        (AGL: agree_locs f ls (parent_locset cs))
        (ARGS: forall ofs ty,
           In (S Outgoing ofs ty) (regs_of_rpairs (loc_arguments sg)) ->
           slot_within_bounds (function_bounds f) Outgoing ofs ty)
        (STK: match_stacks j cs cs' (Linear.fn_sig f)),
      match_stacks j
                   (Linear.Stackframe f (Vptr sp Ptrofs.zero) ls c :: cs)
                   (Stackframe fb sp' ra c' :: cs')
                   sg.

(** Invariance with respect to change of memory injection. *)

Lemma stack_contents_change_meminj:
  forall m j j', inject_incr j j' ->
  forall cs cs' (*SACC:*)stk P,
  m |= stack_contents j cs cs' stk ** P ->
  m |= stack_contents j' cs cs' stk ** P.
Proof.
Local Opaque sepconj.
  induction cs as [ | [] cs]; destruct cs' as [ | [] cs']; simpl; intros; auto.
  rewrite sep_assoc in *.
  apply frame_contents_incr with (j := j); auto.
  rewrite sep_swap. apply IHcs. rewrite sep_swap. assumption.
Qed.

Lemma match_stacks_change_meminj:
  forall j j', inject_incr j j' ->
  forall cs cs' sg,
  match_stacks j cs cs' sg ->
  match_stacks j' cs cs' sg.
Proof.
  induction 2; intros.
- constructor; auto.
- econstructor; eauto.
Qed.

(** Invariance with respect to change of signature. *)

Lemma match_stacks_change_sig:
  forall sg1 j cs cs' sg,
  match_stacks j cs cs' sg ->
  tailcall_possible sg1 ->
  match_stacks j cs cs' sg1.
Proof.
  induction 1; intros.
  econstructor; eauto.
  econstructor; eauto. intros. elim (H0 _ H1).
Qed.

(** Typing properties of [match_stacks]. *)

(*SACC: comments this
Lemma match_stacks_type_sp:
  forall j cs cs' sg stk,
  match_stacks j cs cs' sg ->
  Val.has_type (parent_sp cs') Tptr.
Proof.
  induction 1; unfold parent_sp. apply Val.Vnullptr_has_type. apply Val.Vptr_has_type.
Qed.*)

Lemma match_stacks_type_retaddr:
  forall j cs cs' sg,
  match_stacks j cs cs' sg ->
  Val.has_type (parent_ra cs') Tptr.
Proof.
  induction 1; unfold parent_ra. apply Val.Vnullptr_has_type. auto.
Qed.

(** * Syntactic properties of the translation *)

(** Preservation of code labels through the translation. *)

Section LABELS.

Remark find_label_save_callee_save:
  forall lbl l ofs k,
  Mach.find_label lbl (save_callee_save_rec l ofs k) = Mach.find_label lbl k.
Proof.
  induction l; simpl; auto.
Qed.

Remark find_label_restore_callee_save:
  forall lbl l ofs k,
  Mach.find_label lbl (restore_callee_save_rec l ofs k) = Mach.find_label lbl k.
Proof.
  induction l; simpl; auto.
Qed.

Lemma transl_code_eq:
  forall fe i c, transl_code fe (i :: c) = transl_instr fe i (transl_code fe c).
Proof.
  unfold transl_code; intros. rewrite list_fold_right_eq. auto.
Qed.

Lemma find_label_transl_code:
  forall fe lbl c,
  Mach.find_label lbl (transl_code fe c) =
    option_map (transl_code fe) (Linear.find_label lbl c).
Proof.
  induction c; simpl; intros.
- auto.
- rewrite transl_code_eq.
  destruct a; unfold transl_instr; auto.
  destruct s; simpl; auto.
  destruct s; simpl; auto.
  unfold restore_callee_save. rewrite find_label_restore_callee_save. auto.
  simpl. destruct (peq lbl l). reflexivity. auto.
  unfold restore_callee_save. rewrite find_label_restore_callee_save. auto.
Qed.

Lemma transl_find_label:
  forall f tf lbl c,
  transf_function f = OK tf ->
  Linear.find_label lbl f.(Linear.fn_code) = Some c ->
  Mach.find_label lbl tf.(Mach.fn_code) =
    Some (transl_code (make_env (function_bounds f)) c).
Proof.
  intros. rewrite (unfold_transf_function _ _ H).  simpl.
  unfold transl_body. unfold save_callee_save. rewrite find_label_save_callee_save.
  rewrite find_label_transl_code. rewrite H0. reflexivity.
Qed.

End LABELS.

(** Code tail property for Linear executions. *)

Lemma find_label_tail:
  forall lbl c c',
  Linear.find_label lbl c = Some c' -> is_tail c' c.
Proof.
  induction c; simpl.
  intros; discriminate.
  intro c'. case (Linear.is_label lbl a); intros.
  injection H; intro; subst c'. auto with coqlib.
  auto with coqlib.
Qed.

(** Code tail property for translations *)

Lemma is_tail_save_callee_save:
  forall l ofs k,
  is_tail k (save_callee_save_rec l ofs k).
Proof.
  induction l; intros; simpl. auto with coqlib.
  constructor; auto. 
Qed.

Lemma is_tail_restore_callee_save:
  forall l ofs k,
  is_tail k (restore_callee_save_rec l ofs k).
Proof.
  induction l; intros; simpl. auto with coqlib.
  constructor; auto. 
Qed.

Lemma is_tail_transl_instr:
  forall fe i k,
  is_tail k (transl_instr fe i k).
Proof.
  intros. destruct i; unfold transl_instr; auto with coqlib.
  destruct s; auto with coqlib.
  destruct s; auto with coqlib.
  unfold restore_callee_save.  eapply is_tail_trans. 2: apply is_tail_restore_callee_save. auto with coqlib.
  unfold restore_callee_save.  eapply is_tail_trans. 2: apply is_tail_restore_callee_save. auto with coqlib.
Qed.

Lemma is_tail_transl_code:
  forall fe c1 c2, is_tail c1 c2 -> is_tail (transl_code fe c1) (transl_code fe c2).
Proof.
  induction 1; simpl. auto with coqlib.
  rewrite transl_code_eq.
  eapply is_tail_trans. eauto. apply is_tail_transl_instr.
Qed.

Lemma is_tail_transf_function:
  forall f tf c,
  transf_function f = OK tf ->
  is_tail c (Linear.fn_code f) ->
  is_tail (transl_code (make_env (function_bounds f)) c) (fn_code tf).
Proof.
  intros. rewrite (unfold_transf_function _ _ H). simpl.
  unfold transl_body, save_callee_save. 
  eapply is_tail_trans. 2: apply is_tail_save_callee_save.
  apply is_tail_transl_code; auto.
Qed.

(** * Semantic preservation *)

(** Preservation / translation of global symbols and functions. *)

Lemma symbols_preserved:
  forall (s: ident), Genv.find_symbol tge s = Genv.find_symbol ge s.
Proof (Genv.find_symbol_match TRANSF).

Lemma senv_preserved:
  Senv.equiv ge tge.
Proof (Genv.senv_match TRANSF).

Lemma functions_translated:
  forall v f,
  Genv.find_funct ge v = Some f ->
  exists tf,
  Genv.find_funct tge v = Some tf /\ transf_fundef f = OK tf.
Proof (Genv.find_funct_transf_partial TRANSF).

Lemma function_ptr_translated:
  forall b f,
  Genv.find_funct_ptr ge b = Some f ->
  exists tf,
  Genv.find_funct_ptr tge b = Some tf /\ transf_fundef f = OK tf.
Proof (Genv.find_funct_ptr_transf_partial TRANSF).

Lemma sig_preserved:
  forall f tf, transf_fundef f = OK tf -> Mach.funsig tf = Linear.funsig f.
Proof.
  intros until tf; unfold transf_fundef, transf_partial_fundef.
  destruct f; intros; monadInv H.
  rewrite (unfold_transf_function _ _ EQ). auto.
  auto.
Qed.

Lemma find_function_translated:
  forall j ls rs m ros f,
  agree_regs j ls rs ->
  m |= globalenv_inject ge j ->
  Linear.find_function ge ros ls = Some f ->
  exists bf, exists tf,
     find_function_ptr tge ros rs = Some bf
  /\ Genv.find_funct_ptr tge bf = Some tf
  /\ transf_fundef f = OK tf.
Proof.
  intros until f; intros AG [bound [_ [?????]]] FF.
  destruct ros; simpl in FF.
- exploit Genv.find_funct_inv; eauto. intros [b EQ]. rewrite EQ in FF.
  rewrite Genv.find_funct_find_funct_ptr in FF.
  exploit function_ptr_translated; eauto. intros [tf [A B]].
  exists b; exists tf; split; auto. simpl.
  generalize (AG m0). rewrite EQ. intro INJ. inv INJ.
  rewrite DOMAIN in H2. inv H2. simpl. auto. eapply FUNCTIONS; eauto.
- destruct (Genv.find_symbol ge i) as [b|] eqn:?; try discriminate.
  exploit function_ptr_translated; eauto. intros [tf [A B]].
  exists b; exists tf; split; auto. simpl.
  rewrite symbols_preserved. auto.
Qed.

(** Preservation of the arguments to an external call. *)

Section EXTERNAL_ARGUMENTS.

Variable j: meminj.
Variable cs: list Linear.stackframe.
Variable cs': list stackframe.
Variable sg: signature.
Variables bound bound': block.
Hypothesis MS: match_stacks j cs cs' sg.
Variable ls: locset.
Variable rs: regset.
Hypothesis AGR: agree_regs j ls rs.
Hypothesis AGCS: agree_callee_save ls (parent_locset cs).
Variable m': mem.
(*SACC:*)Variable stk: stack.
Hypothesis SEP: m' |= stack_contents j cs cs' (*SACC:*)stk.
(*SACC:*)Hypothesis curstack : stack.
(*SACC:*)Hypothesis CSA: call_stack_agree (stack_blocks_of_callstack tge cs') (tl curstack).

Lemma transl_external_argument:
  forall l,
  In l (regs_of_rpairs (loc_arguments sg)) ->
  exists v, extcall_arg rs m' (parent_sp (*SACC:*)curstack) l v /\ Val.inject j (ls l) v.
Proof.
  intros.
  assert (loc_argument_acceptable l) by (apply loc_arguments_acceptable_2 with sg; auto).
  destruct l; red in H0.
- exists (rs r); split. constructor. auto.
- destruct sl; try contradiction.
  inv MS.
+ elim (H1 _ H).
+ simpl in SEP.
  assert (slot_valid f Outgoing pos ty = true).
  { destruct H0. unfold slot_valid, proj_sumbool. 
    rewrite zle_true by omega. rewrite pred_dec_true by auto. reflexivity. }
  assert (slot_within_bounds (function_bounds f) Outgoing pos ty) by eauto.
  exploit frame_get_outgoing; eauto. intros (v & A & B).
  exists v; split.
  simpl in CSA; inv CSA. rewrite FINDF in H4. repeat destr_in H4. 
  unfold parent_sp. destr. inv H6.
  constructor. simpl in H6. subst s0. simpl.
  unfold current_frame_sp. simpl. rewrite BLOCKS. auto.
  red in AGCS. rewrite AGCS; auto.
Qed.

Lemma transl_external_argument_2:
  forall p,
  In p (loc_arguments sg) ->
  exists v, extcall_arg_pair rs m' (parent_sp (*SACC:*)curstack) p v /\ Val.inject j (Locmap.getpair p ls) v.
Proof.
  intros. destruct p as [l | l1 l2].
- destruct (transl_external_argument l) as (v & A & B). eapply in_regs_of_rpairs; eauto; simpl; auto.
  exists v; split; auto. constructor; auto. 
- destruct (transl_external_argument l1) as (v1 & A1 & B1). eapply in_regs_of_rpairs; eauto; simpl; auto.
  destruct (transl_external_argument l2) as (v2 & A2 & B2). eapply in_regs_of_rpairs; eauto; simpl; auto.
  exists (Val.longofwords v1 v2); split. 
  constructor; auto.
  apply Val.longofwords_inject; auto.
Qed.

Lemma transl_external_arguments_rec:
  forall locs,
  incl locs (loc_arguments sg) ->
  exists vl,
      list_forall2 (extcall_arg_pair rs m' (parent_sp (*SACC:*)curstack)) locs vl
   /\ Val.inject_list j (map (fun p => Locmap.getpair p ls) locs) vl.
Proof.
  induction locs; simpl; intros.
  exists (@nil val); split. constructor. constructor.
  exploit transl_external_argument_2; eauto with coqlib. intros [v [A B]].
  exploit IHlocs; eauto with coqlib. intros [vl [C D]].
  exists (v :: vl); split; constructor; auto.
Qed.

Lemma transl_external_arguments:
  exists vl,
      extcall_arguments rs m' (parent_sp (*SACC:*)curstack) sg vl
   /\ Val.inject_list j (map (fun p => Locmap.getpair p ls) (loc_arguments sg)) vl.
Proof.
  unfold extcall_arguments.
  apply transl_external_arguments_rec.
  auto with coqlib.
Qed.

End EXTERNAL_ARGUMENTS.

(** Preservation of the arguments to a builtin. *)

Section BUILTIN_ARGUMENTS.

Variable f: Linear.function.
Let b := function_bounds f.
Let fe := make_env b.
Variable tf: Mach.function.
Hypothesis TRANSF_F: transf_function f = OK tf.
Variable j: meminj.
(*SACC:*)Variable g: frameinj.
Variables m m': mem.
Variables ls ls0: locset.
Variable rs: regset.
Variables sp sp': block.
Variables parent retaddr: val.
Hypothesis INJ: j sp = Some(sp', fe.(fe_stack_data)).
Hypothesis AGR: agree_regs j ls rs.
Hypothesis SEP: m' |= frame_contents f j sp' ls ls0 parent retaddr ** minjection j (*SACC:*)g m ** globalenv_inject ge j.

Lemma transl_builtin_arg_correct:
  forall a v,
  eval_builtin_arg ge ls (Vptr sp Ptrofs.zero) m a v ->
  (forall l, In l (params_of_builtin_arg a) -> loc_valid f l = true) ->
  (forall sl ofs ty, In (S sl ofs ty) (params_of_builtin_arg a) -> slot_within_bounds b sl ofs ty) ->
  exists v',
     eval_builtin_arg ge rs (Vptr sp' Ptrofs.zero) m' (transl_builtin_arg fe a) v'
  /\ Val.inject j v v'.
Proof.
  assert (SYMB: forall id ofs, Val.inject j (Senv.symbol_address ge id ofs) (Senv.symbol_address ge id ofs)).
  { assert (G: meminj_preserves_globals ge j).
    { eapply globalenv_inject_preserves_globals. eapply sep_proj2. eapply sep_proj2. eexact SEP. }
    intros; unfold Senv.symbol_address; simpl; unfold Genv.symbol_address.
    destruct (Genv.find_symbol ge id) eqn:FS; auto.
    destruct G. econstructor. eauto. rewrite Ptrofs.add_zero; auto. }
Local Opaque fe.
  induction 1; simpl; intros VALID BOUNDS.
- assert (loc_valid f x = true) by auto.
  destruct x as [r | [] ofs ty]; try discriminate.
  + exists (rs r); auto with barg.
  + exploit frame_get_local; eauto. intros (v & A & B). 
    exists v; split; auto. constructor; auto.
- econstructor; eauto with barg.
- econstructor; eauto with barg.
- econstructor; eauto with barg.
- econstructor; eauto with barg.
- set (ofs' := Ptrofs.add ofs (Ptrofs.repr (fe_stack_data fe))).
  apply sep_proj2 in SEP. apply sep_proj1 in SEP. exploit loadv_parallel_rule; eauto.
  instantiate (1 := Val.offset_ptr (Vptr sp' Ptrofs.zero) ofs').
  simpl. rewrite ! Ptrofs.add_zero_l. econstructor; eauto.
  intros (v' & A & B). exists v'; split; auto. constructor; auto. 
- econstructor; split; eauto with barg.
  unfold Val.offset_ptr. rewrite ! Ptrofs.add_zero_l. econstructor; eauto.
- apply sep_proj2 in SEP. apply sep_proj1 in SEP. exploit loadv_parallel_rule; eauto.
  intros (v' & A & B). exists v'; auto with barg.
- econstructor; split; eauto with barg. 
- destruct IHeval_builtin_arg1 as (v1 & A1 & B1); auto using in_or_app.
  destruct IHeval_builtin_arg2 as (v2 & A2 & B2); auto using in_or_app.
  exists (Val.longofwords v1 v2); split; auto with barg.
  apply Val.longofwords_inject; auto.
Qed.

Lemma transl_builtin_args_correct:
  forall al vl,
  eval_builtin_args ge ls (Vptr sp Ptrofs.zero) m al vl ->
  (forall l, In l (params_of_builtin_args al) -> loc_valid f l = true) ->
  (forall sl ofs ty, In (S sl ofs ty) (params_of_builtin_args al) -> slot_within_bounds b sl ofs ty) ->
  exists vl',
     eval_builtin_args ge rs (Vptr sp' Ptrofs.zero) m' (List.map (transl_builtin_arg fe) al) vl'
  /\ Val.inject_list j vl vl'.
Proof.
  induction 1; simpl; intros VALID BOUNDS.
- exists (@nil val); split; constructor.
- exploit transl_builtin_arg_correct; eauto using in_or_app. intros (v1' & A & B).
  exploit IHlist_forall2; eauto using in_or_app. intros (vl' & C & D).
  exists (v1'::vl'); split; constructor; auto.
Qed.

End BUILTIN_ARGUMENTS.

(** The proof of semantic preservation relies on simulation diagrams
  of the following form:
<<
           st1 --------------- st2
            |                   |
           t|                  +|t
            |                   |
            v                   v
           st1'--------------- st2'
>>
  Matching between source and target states is defined by [match_states]
  below.  It implies:
- Satisfaction of the separation logic assertions that describe the contents 
  of memory.  This is a separating conjunction of facts about:
-- the current stack frame
-- the frames in the call stack
-- the injection from the Linear memory state into the Mach memory state
-- the preservation of the global environment.
- Agreement between, on the Linear side, the location sets [ls]
  and [parent_locset s] of the current function and its caller,
  and on the Mach side the register set [rs].
- The Linear code [c] is a suffix of the code of the
  function [f] being executed.
- Well-typedness of [f].
*)

(*SACC:*)
Definition fn_stack_requirements (i: ident) : Z :=
  match Genv.find_symbol tge i with
    Some b =>
    match Genv.find_funct_ptr tge b with
    | Some (Internal f) => fn_stacksize f
    | _ => 0
    end
  | None => 0
  end.

Inductive match_states: Linear.state -> Mach.state -> Prop :=
  | match_states_intro:
      forall cs f sp c ls m cs' fb sp' rs m' j tf
        (STACKS: match_stacks j cs cs' f.(Linear.fn_sig))
        (TRANSL: transf_function f = OK tf)
        (FIND: Genv.find_funct_ptr tge fb = Some (Internal tf))
        (AGREGS: agree_regs j ls rs)
        (AGLOCS: agree_locs f ls (parent_locset cs))
        (INJSP: j sp = Some(sp', fe_stack_data (make_env (function_bounds f))))
        (* SACC:
        (INJUNIQUE: forall b delta, j b = Some (sp', delta) -> b = sp)
        (INJ_INIT_SP: block_prop (fun b => j b = Some (b,0)) init_sp)
        (HAMOA: has_at_most_one_antecedent j init_sp)
        (INCR_init: inject_incr (Mem.flat_inj (Mem.nextblock init_m)) j)
        (INCR_sep: inject_separated (Mem.flat_inj (Mem.nextblock init_m)) j init_m init_m)
        (MACH: Ple (Mem.nextblock init_m) (Mem.nextblock m'))*)
        (TAIL: is_tail c (Linear.fn_code f))
        (SEP: m' |= frame_contents f j sp' ls (parent_locset cs) (parent_sp ((*SACC:*)Mem.stack m')) (parent_ra cs')
                 ** stack_contents j cs cs' ((*SACC:*)tl (Mem.stack m'))
                 ** minjection j ((*SACC:*)flat_frameinj (length (Mem.stack m))) m
                 ** globalenv_inject ge j)
  (*SACC:*)(SE: stack_equiv (Mem.stack m) (Mem.stack m')),
      match_states (Linear.State cs f (Vptr sp Ptrofs.zero) c ls m)
                   (Mach.State cs' fb (Vptr sp' Ptrofs.zero) (transl_code (make_env (function_bounds f)) c) rs m')
  | match_states_call:
      forall cs f ls m cs' fb rs m' j tf (*SACC:*)sz
        (STACKS: match_stacks j cs cs' (Linear.funsig f))
        (TRANSL: transf_fundef f = OK tf)
        (FIND: Genv.find_funct_ptr tge fb = Some tf)
  (*SACC:*)(SZEQ: exists i, Genv.invert_symbol tge fb = Some i /\ sz = fn_stack_requirements i)
        (AGREGS: agree_regs j ls rs)
        (AGLOCS: agree_callee_save ls (parent_locset cs))
        (*SACC:
        (INCR_init: inject_incr (Mem.flat_inj (Mem.nextblock init_m)) j)
        (INCR_sep: inject_separated (Mem.flat_inj (Mem.nextblock init_m)) j init_m init_m)
        (MACH: Ple (Mem.nextblock init_m) (Mem.nextblock m'))
        (INJ_INIT_SP: block_prop (fun b => j b = Some (b,0)) init_sp)
        (HAMOA: has_at_most_one_antecedent j init_sp)*)
        (SEP: m' |= stack_contents j cs cs' ((*SACC:*)tl (Mem.stack m'))
                 ** minjection j ((*SACC:*)flat_frameinj (length (Mem.stack m))) m
                 ** globalenv_inject ge j)
  (*SACC:*)(SE: stack_equiv (Mem.stack m) (Mem.stack m')),
      match_states (Linear.Callstate cs f ls m (*SACC:*)sz)
                   (Mach.Callstate cs' fb rs m')
  | match_states_return:
      forall cs ls m cs' rs m' j sg
        (STACKS: match_stacks j cs cs' sg)
        (AGREGS: agree_regs j ls rs)
        (AGLOCS: agree_callee_save ls (parent_locset cs))
        (*SACC:
        (INCR_init: inject_incr (Mem.flat_inj (Mem.nextblock init_m)) j)
        (INCR_sep: inject_separated (Mem.flat_inj (Mem.nextblock init_m)) j init_m init_m)
        (MACH: Ple (Mem.nextblock init_m) (Mem.nextblock m'))
        (INJ_INIT_SP: block_prop (fun b => j b = Some (b,0)) init_sp)
        (HAMOA: has_at_most_one_antecedent j init_sp)*)
        (SEP: m' |= stack_contents j cs cs' ((*SACC:*)tl (Mem.stack m'))
                 ** minjection j ((*SACC:*)flat_frameinj (length (Mem.stack m))) m
                 ** globalenv_inject ge j)
   (*SACC:*)(SE: stack_equiv (Mem.stack m) (Mem.stack m')),
      match_states (Linear.Returnstate cs ls m)
                  (Mach.Returnstate cs' rs m').

(*SACC:*)
Lemma tailcall_stage_rule:
  forall m1 m1' m2 j g P,
    m2 |= minjection j g m1 ** P ->
    Mem.tailcall_stage m1 = Some m1' ->
    Mem.top_frame_no_perm m2 ->
    m_invar_stack P = false ->
    exists m2', Mem.tailcall_stage m2 = Some m2' /\
           m2' |= minjection j g m1' ** P.
Proof.
  intros m1 m1' m2 j g P SEP TC TFNP INVAR.
  exploit Mem.tailcall_stage_inject; eauto. apply SEP. intros (m2' & TC' & INJ').
  eexists; split; eauto.
  destruct SEP as (INJ & PM & DISJ).
  split; [|split].
  - simpl in *. auto.
  - eapply m_invar. eauto.
    eauto using Mem.tailcall_stage_unchanged_on.
    congruence.
  - red; intros. eapply DISJ. 2: eauto. simpl in H |- *.
    decompose [ex and] H.
    repeat eexists;  eauto.
    revert H3; rewrite_perms. auto.
Qed.

Theorem transf_step_correct:
  forall s1 t s2, Linear.step (*SACC:*)fn_stack_requirements ge s1 t s2 ->
  forall (WTS: wt_state s1) s1' 
         (CSC: call_stack_consistency tge s1')
         (MS: match_states s1 s1'),
  exists s2', plus step tge s1' t s2' /\ match_states s2 s2'.
Proof.
  induction 1; intros;
  try inv MS;
  try rewrite transl_code_eq;
  try (generalize (function_is_within_bounds f _ (is_tail_in TAIL));
       intro BOUND; simpl in BOUND);
  unfold transl_instr.

- (* Lgetstack *)
  destruct BOUND as [BOUND1 BOUND2].
  exploit wt_state_getstack; eauto. intros SV.
  unfold destroyed_by_getstack; destruct sl.
+ (* Lgetstack, local *)
  exploit frame_get_local; eauto. intros (v & A & B).
  econstructor; split.
  apply plus_one. apply exec_Mgetstack. exact A.
  econstructor; eauto with coqlib.
  apply agree_regs_set_reg; auto.
  apply agree_locs_set_reg; auto.
+ (* Lgetstack, incoming *)
  unfold slot_valid in SV. InvBooleans.
  exploit incoming_slot_in_parameters; eauto. intros IN_ARGS.
  inversion STACKS; clear STACKS.
  elim (H1 _ IN_ARGS).
  subst s cs'.
  exploit frame_get_outgoing.
  apply sep_proj2 in SEP. simpl in SEP. rewrite sep_assoc in SEP. eexact SEP.
  eapply ARGS; eauto.
  eapply slot_outgoing_argument_valid; eauto.
  intros (v & A & B).
  econstructor; split.
  * apply plus_one. eapply exec_Mgetparam; eauto.
    inv CSC. inv CSA. simpl. rewrite FINDF in REC. repeat destr_in REC. simpl.
    unfold current_frame_sp. simpl.
    rewrite BLOCKS0. eauto.
  * econstructor; eauto with coqlib. econstructor; eauto.
    apply agree_regs_set_reg. apply agree_regs_set_reg. auto. auto.
    erewrite agree_incoming by eauto. exact B.
    apply agree_locs_set_reg; auto. apply agree_locs_undef_locs; auto.
+ (* Lgetstack, outgoing *)
  exploit frame_get_outgoing; eauto. intros (v & A & B).
  econstructor; split.
  apply plus_one. apply exec_Mgetstack. exact A.
  econstructor; eauto with coqlib.
  apply agree_regs_set_reg; auto.
  apply agree_locs_set_reg; auto.

- (* Lsetstack *)
  exploit wt_state_setstack; eauto. intros (SV & SW).
  set (ofs' := match sl with
               | Local => offset_local (make_env (function_bounds f)) ofs
               | Incoming => 0 (* dummy *)
               | Outgoing => offset_arg ofs
               end).
  eapply frame_undef_regs with (rl := destroyed_by_setstack ty) in SEP.
  assert (A: exists m'',
              store_stack m' (Vptr sp' Ptrofs.zero) ty (Ptrofs.repr ofs') (rs0 src) = Some m''
           /\ m'' |= frame_contents f j sp' (Locmap.set (S sl ofs ty) (rs (R src))
                                               (LTL.undef_regs (destroyed_by_setstack ty) rs))
                                            (parent_locset s) (parent_sp (Mem.stack m')) (parent_ra cs')
                  ** stack_contents j s cs' (tl (Mem.stack m')) ** minjection j (flat_frameinj (length (Mem.stack m))) m ** globalenv_inject ge j).
  { unfold ofs'; destruct sl; try discriminate.
    eapply frame_set_local; eauto.
    eapply frame_set_outgoing; eauto. }
  clear SEP; destruct A as (m'' & STORE & SEP).
  econstructor; split.
  + apply plus_one. destruct sl; try discriminate.
    econstructor. eexact STORE. eauto.
    econstructor. eexact STORE. eauto.
  + econstructor; eauto. 
    * apply agree_regs_set_slot. apply agree_regs_undef_regs. auto.
    * apply agree_locs_set_slot. apply agree_locs_undef_locs. auto. apply destroyed_by_setstack_caller_save. auto.
    * eauto with coqlib.
    * unfold store_stack in *; simpl in *; rewrite_stack_blocks; eauto.
    * unfold store_stack in *; simpl in *; rewrite_stack_blocks; eauto.

- (* Lop *)
  assert (exists v',
          eval_operation ge (Vptr sp' Ptrofs.zero) (transl_op (make_env (function_bounds f)) op) rs0##args m' = Some v'
       /\ Val.inject j v v').
  eapply eval_operation_inject; eauto.
  eapply globalenv_inject_preserves_globals. eapply sep_proj2. eapply sep_proj2. eapply sep_proj2. eexact SEP.
  eapply agree_reglist; eauto.
  apply sep_proj2 in SEP. apply sep_proj2 in SEP. apply sep_proj1 in SEP. exact SEP.
  destruct H0 as [v' [A B]].
  econstructor; split.
  apply plus_one. econstructor.
  instantiate (1 := v'). rewrite <- A. apply eval_operation_preserved.
  exact symbols_preserved. eauto.
  econstructor; eauto with coqlib.
  apply agree_regs_set_reg; auto.
  rewrite transl_destroyed_by_op.  apply agree_regs_undef_regs; auto.
  apply agree_locs_set_reg; auto. apply agree_locs_undef_locs. auto. apply destroyed_by_op_caller_save.
  apply frame_set_reg. apply frame_undef_regs. exact SEP. 

- (* Lload *)
  assert (exists a',
          eval_addressing ge (Vptr sp' Ptrofs.zero) (transl_addr (make_env (function_bounds f)) addr) rs0##args = Some a'
       /\ Val.inject j a a').
  eapply eval_addressing_inject; eauto.
  eapply globalenv_inject_preserves_globals. eapply sep_proj2. eapply sep_proj2. eapply sep_proj2. eexact SEP.
  eapply agree_reglist; eauto.
  destruct H1 as [a' [A B]].
  exploit loadv_parallel_rule.
  apply sep_proj2 in SEP. apply sep_proj2 in SEP. apply sep_proj1 in SEP. eexact SEP.
  eauto. eauto. 
  intros [v' [C D]].
  econstructor; split.
  apply plus_one. econstructor.
  instantiate (1 := a'). rewrite <- A. apply eval_addressing_preserved. exact symbols_preserved.
  eexact C. eauto.
  econstructor; eauto with coqlib.
  apply agree_regs_set_reg. rewrite transl_destroyed_by_load. apply agree_regs_undef_regs; auto. auto.
  apply agree_locs_set_reg. apply agree_locs_undef_locs. auto. apply destroyed_by_load_caller_save. auto. 

- (* Lstore *)
  assert (exists a',
          eval_addressing ge (Vptr sp' Ptrofs.zero) (transl_addr (make_env (function_bounds f)) addr) rs0##args = Some a'
       /\ Val.inject j a a').
  eapply eval_addressing_inject; eauto.
  eapply globalenv_inject_preserves_globals. eapply sep_proj2. eapply sep_proj2. eapply sep_proj2. eexact SEP.
  eapply agree_reglist; eauto.
  destruct H1 as [a' [A B]].
  rewrite sep_swap3 in SEP.
  exploit storev_parallel_rule. eexact SEP. eauto. eauto. apply AGREGS. 
  clear SEP; intros (m1' & C & SEP).
  rewrite sep_swap3 in SEP.
  econstructor; split.
  apply plus_one. econstructor.
  instantiate (1 := a'). rewrite <- A. apply eval_addressing_preserved. exact symbols_preserved.
  eexact C. eauto.
  econstructor. eauto. eauto. eauto. 
  rewrite transl_destroyed_by_store. apply agree_regs_undef_regs; auto.
  apply agree_locs_undef_locs. auto. apply destroyed_by_store_caller_save.
  auto. eauto with coqlib.
  repeat rewrite_stack_blocks; eauto. eapply frame_undef_regs; eauto.
  repeat rewrite_stack_blocks; eauto.

- (* Lcall *)
  exploit find_function_translated; eauto.
    eapply sep_proj2. eapply sep_proj2. eapply sep_proj2. eexact SEP.
  intros [bf [tf' [A [B C]]]].
  exploit is_tail_transf_function; eauto. intros IST.
  rewrite transl_code_eq in IST. simpl in IST.
  exploit return_address_offset_exists. eexact IST. intros [ra D].
  assert (SEP' :
            Mem.push_new_stage m' |=
                               frame_contents f j sp' rs (parent_locset s) (parent_sp (Mem.stack (Mem.push_new_stage m')))
                               (parent_ra cs') **
                               stack_contents j s cs' (tl (Mem.stack m')) **
                               minjection j (flat_frameinj (length (Mem.stack (Mem.push_new_stage m)))) (Mem.push_new_stage m) **
                               globalenv_inject ge j).
  {
    repeat rewrite_stack_blocks.
    rewrite sep_swap3 in SEP |- *.
    apply push_rule in SEP.
    eapply sep_imp. apply SEP.
    red; split; auto. split; auto. 
    rewrite ! m_invar_stack_sepconj.
    rewrite stack_contents_invar_stack.
    rewrite frame_contents_invar_stack.
    reflexivity.
  }
  econstructor; split.
  + apply plus_one. econstructor; eauto.
  + econstructor; eauto.
    * econstructor; eauto with coqlib.
      apply Val.Vptr_has_type.
      intros; red.
        apply Zle_trans with (size_arguments (Linear.funsig f')); auto.
        apply loc_arguments_bounded; auto.
    * exists fid; split; auto.
      destruct ros; simpl in *; eauto.
      repeat destr_in A.
      destruct IFI as (bb & oo & IFI & IFI').
      exploit globalenv_inject_preserves_globals. apply SEP. intros (MPG1 & MPG2 & MPG3).
      generalize (AGREGS m0).
      rewrite IFI, Heqv. inversion 1; subst.
      erewrite MPG1 in H4; eauto. inv H4.
      eapply Genv.find_invert_symbol; eauto.
      rewrite symbols_preserved; eauto.
      subst. 
      eapply Genv.find_invert_symbol; eauto.
    * simpl; red; auto.
    * simpl. rewrite sep_assoc. revert SEP'. repeat rewrite_stack_blocks. auto.
    * repeat rewrite_stack_blocks; eauto.
      repeat constructor. auto.

- (* Ltailcall *)
  rewrite (sep_swap (stack_contents j s cs' _)) in SEP.
  inv CSC. rewrite FIND in FIND0; inv FIND0.
  rename tf0 into tf. 
  exploit function_epilogue_correct; eauto.
  rewrite m_invar_stack_sepconj. rewrite stack_contents_invar_stack. reflexivity.
  clear SEP. intros (rs1 & m1' & P & Q & R & S & T & U & SEP & SE').
  edestruct tailcall_stage_rule as (m2' & TC' & SEP'); eauto.
  {
    inv CSA.
    eapply Mem.free_top_tframe_no_perm; eauto.
  }
  rewrite m_invar_stack_sepconj. rewrite stack_contents_invar_stack. reflexivity.
  rewrite sep_swap in SEP.
  exploit find_function_translated; eauto.
    eapply sep_proj2. eapply sep_proj2. eexact SEP.
  intros [bf [tf' [A [B C]]]].
  econstructor; split.
  + eapply plus_right. eexact S. econstructor; eauto. traceEq.
  + assert (TAILCALL: tailcall_possible (Linear.funsig f')).
    {
      apply zero_size_arguments_tailcall_possible. eapply wt_state_tailcall; eauto.
    }
    exploit match_stacks_change_sig; eauto.
    intros MS'.
    econstructor; eauto.
     * exists fid; split; auto.
       destruct ros; simpl in *; eauto.
       repeat destr_in A.
       destruct IFI as (bb & oo & IFI & IFI').
       exploit globalenv_inject_preserves_globals. apply SEP. intros (MPG1 & MPG2 & MPG3).
       generalize (U (Locations.R m0)), (AGREGS m0), (T m0).
       destr_in IFI.
       simpl. rewrite IFI, Heqv. rewrite Heqb0. inversion 3; subst.
       erewrite MPG1 in H8; eauto. inv H8.
       eapply Genv.find_invert_symbol; eauto.
       rewrite symbols_preserved; eauto.
       simpl. rewrite IFI, Heqv. rewrite Heqb0. inversion 3; subst.
       erewrite MPG1 in H8; eauto. inv H8.
       eapply Genv.find_invert_symbol; eauto.
       rewrite symbols_preserved; eauto.
       subst. 
       eapply Genv.find_invert_symbol; eauto.
     * rewrite sep_swap12.
       revert SEP'. 
       repeat rewrite_stack_blocks. 
       intros D E; rewrite D, E. simpl; auto.
     * revert SE'. repeat rewrite_stack_blocks.
       clear; intros A B; rewrite A, B; intro SE; inv SE; constructor; auto.
       split; simpl; auto.
       destruct LF2 as (C & D); red in C; red in D; repeat destr_in C; constructor; auto.

- (* Lbuiltin *)
  destruct BOUND as [BND1 BND2].
  exploit transl_builtin_args_correct.
    eauto. eauto. rewrite sep_swap in SEP; apply sep_proj2 in SEP; eexact SEP.
    eauto. rewrite <- forallb_forall. eapply wt_state_builtin; eauto.
    exact BND2.
  intros [vargs' [P Q]].
  rewrite <- sep_assoc, sep_comm, sep_assoc in SEP.
  exploit external_call_parallel_rule; eauto.
  apply push_rule; eauto.
  rewrite ! m_invar_stack_sepconj.
  rewrite frame_contents_invar_stack, stack_contents_invar_stack; reflexivity.
  clear SEP; intros (j' & res' & m1' & EC & RES & SEP & INCR & ISEP).
  exploit unrecord_stack_block_parallel_rule. 
  3: eassumption. 2: eassumption.
  rewrite ! m_invar_stack_sepconj.
  rewrite frame_contents_invar_stack, stack_contents_invar_stack; reflexivity.
  intros (m2' & USB & SEP').
  econstructor; split.
  + apply plus_one. econstructor; eauto.
    eapply eval_builtin_args_preserved with (ge1 := ge); eauto. 
    exact symbols_preserved.
    eapply external_call_symbols_preserved; eauto. apply senv_preserved.
  + eapply match_states_intro with (j := j'); eauto with coqlib.
    eapply match_stacks_change_meminj; eauto.
    apply agree_regs_set_res; auto. apply agree_regs_undef_regs; auto. eapply agree_regs_inject_incr; eauto.
    apply agree_locs_set_res; auto. apply agree_locs_undef_regs; auto.
    apply frame_set_res. apply frame_undef_regs. apply frame_contents_incr with j; auto. 
    rewrite sep_swap2. apply stack_contents_change_meminj with j; auto. rewrite sep_swap2.
    repeat rewrite_stack_blocks. simpl.
    rewrite sep_comm, sep_assoc, sep_comm, sep_assoc, sep_assoc.
    exact SEP'.
    repeat rewrite_stack_blocks; simpl; auto.

- (* Llabel *)
  econstructor; split.
  apply plus_one; apply exec_Mlabel.
  econstructor; eauto with coqlib.

- (* Lgoto *)
  econstructor; split.
  apply plus_one; eapply exec_Mgoto; eauto.
  apply transl_find_label; eauto.
  econstructor; eauto.
  eapply find_label_tail; eauto.

- (* Lcond, true *)
  econstructor; split.
  apply plus_one. eapply exec_Mcond_true; eauto.
  eapply eval_condition_inject with (m1 := m). eapply agree_reglist; eauto. 
  apply sep_pick3 in SEP; exact SEP. auto.
  eapply transl_find_label; eauto.
  econstructor; eauto. 
  eapply find_label_tail; eauto.

- (* Lcond, false *)
  econstructor; split.
  apply plus_one. eapply exec_Mcond_false; eauto.
  eapply eval_condition_inject with (m1 := m). eapply agree_reglist; eauto. apply sep_pick3 in SEP; exact SEP. auto.
  econstructor. eauto. eauto. eauto.
  apply agree_regs_undef_regs; auto.
  apply agree_locs_undef_locs. auto. apply destroyed_by_cond_caller_save.
  auto. eauto with coqlib.
  apply frame_undef_regs; auto.
  assumption.

- (* Ljumptable *)
  assert (rs0 arg = Vint n).
  { generalize (AGREGS arg). rewrite H. intro IJ; inv IJ; auto. }
  econstructor; split.
  apply plus_one; eapply exec_Mjumptable; eauto.
  apply transl_find_label; eauto.
  econstructor. eauto. eauto. eauto.
  apply agree_regs_undef_regs; auto.
  apply agree_locs_undef_locs. auto. apply destroyed_by_jumptable_caller_save.
  auto. eapply find_label_tail; eauto.
  apply frame_undef_regs; auto.
  assumption.

- (* Lreturn *)
  rewrite (sep_swap (stack_contents j s cs' _)) in SEP.
  inv CSC. rewrite FIND0 in FIND; inv FIND.
  exploit function_epilogue_correct; eauto.
  rewrite m_invar_stack_sepconj, stack_contents_invar_stack; reflexivity.
  intros (rs' & m1' & A & B & C & D & E & F & G).
  econstructor; split.
  + eapply plus_right. eexact D. econstructor; eauto. traceEq.
  + econstructor; eauto.
    rewrite_stack_blocks. simpl.
    rewrite sep_swap; apply G.
    apply G.

- (* internal function *)
  revert TRANSL. unfold transf_fundef, transf_partial_fundef.
  destruct (transf_function f) as [tfn|] eqn:TRANSL; simpl; try congruence.
  intros EQ; inversion EQ; clear EQ; subst tf.
  rewrite sep_comm, sep_assoc in SEP. 
  exploit function_prologue_correct; eauto.
  apply stack_contents_invar_stack.
  red; intros; eapply wt_callstate_wt_regs; eauto.
  revert H0.
  destruct SZEQ as (i & IS & EQ); subst.
  unfold fn_stack_requirements.
  erewrite Genv.invert_find_symbol; eauto.
  rewrite FIND.
  erewrite (unfold_transf_function _ _ TRANSL); eauto.
  eapply type_parent_sp; eauto.
  eapply match_stacks_type_retaddr; eauto.
  inv CSC; inv CFD; simpl; discriminate.
  inv CSC; auto.
  clear SEP;
  intros (j' & rs' & m2' & sp' & m3' & m4' & m5' & A & B & C & D & E & F & SEP & J & K).
  rewrite (sep_comm (globalenv_inject ge j')) in SEP.
  rewrite (sep_swap (minjection j' (flat_frameinj
              (length (Mem.stack m''))) m'')) in SEP.
  econstructor; split.
  + eapply plus_left. econstructor; eauto.
    rewrite (unfold_transf_function _ _ TRANSL). unfold fn_code. unfold transl_body.
    eexact D. traceEq.
  + eapply match_states_intro with (j := j'); eauto with coqlib.
    * eapply match_stacks_change_meminj; eauto.
    * admit. (*rewrite sep_swap in SEP. rewrite sep_swap. eapply stack_contents_change_meminj; eauto.*)
    * repeat rewrite_stack_blocks. destruct IST as (IST1 & IST2). rewrite IST1.
      repeat rewrite_stack_blocks. rewrite IST2.
      intros.
      rewrite EQ1, EQ3 in SE. simpl in *. inv SE; repeat constructor; auto.
      simpl.
      destruct SZEQ as (i & INVERT & EQ).
      subst.
      unfold fn_stack_requirements.
      erewrite Genv.invert_find_symbol; eauto.
      rewrite FIND. reflexivity.
      simpl. apply LF2.
- (* external function *)
  simpl in TRANSL. inversion TRANSL; subst tf.
  exploit transl_external_arguments; eauto. apply sep_proj1 in SEP; eauto. intros [vl [ARGS VINJ]].
  rewrite sep_comm, sep_assoc in SEP.
  exploit external_call_parallel_rule; eauto.
  intros (j' & res' & m1' & A & B & C & D & E).
  econstructor; split.
  apply plus_one. eapply exec_function_external; eauto.
  eapply external_call_symbols_preserved; eauto. apply senv_preserved.
  eapply match_states_return with (j := j').
  eapply match_stacks_change_meminj; eauto.
  apply agree_regs_set_pair. apply agree_regs_inject_incr with j; auto. auto.
  apply agree_callee_save_set_result; auto.
  apply stack_contents_change_meminj with j; auto. 
  rewrite sep_comm, sep_assoc; auto.

- (* return *)
  inv STACKS. simpl in AGLOCS. simpl in SEP. rewrite sep_assoc in SEP. 
  econstructor; split.
  apply plus_one. apply exec_return.
  econstructor; eauto.
  apply agree_locs_return with rs0; auto.
  apply frame_contents_exten with rs0 (parent_locset s); auto. 
Qed.

Lemma transf_initial_states:
  forall st1, Linear.initial_state prog st1 ->
  exists st2, Mach.initial_state tprog st2 /\ match_states st1 st2.
Proof.
  intros. inv H.
  exploit function_ptr_translated; eauto. intros [tf [FIND TR]].
  econstructor; split.
  econstructor.
  eapply (Genv.init_mem_transf_partial TRANSF); eauto.
  rewrite (match_program_main TRANSF).
  rewrite symbols_preserved. eauto.
  set (j := Mem.flat_inj (Mem.nextblock m0)).
  eapply match_states_call with (j := j); eauto.
  constructor. red; intros. rewrite H3, loc_arguments_main in H. contradiction.
  red; simpl; auto.
  red; simpl; auto.
  simpl. rewrite sep_pure. split; auto. split;[|split].
  eapply Genv.initmem_inject; eauto.
  simpl. exists (Mem.nextblock m0); split. apply Ple_refl.
  unfold j, Mem.flat_inj; constructor; intros.
    apply pred_dec_true; auto.
    destruct (plt b1 (Mem.nextblock m0)); congruence.
    change (Mem.valid_block m0 b0). eapply Genv.find_symbol_not_fresh; eauto.
    change (Mem.valid_block m0 b0). eapply Genv.find_funct_ptr_not_fresh; eauto.
    change (Mem.valid_block m0 b0). eapply Genv.find_var_info_not_fresh; eauto.
  red; simpl; tauto.
Qed.

Lemma transf_final_states:
  forall st1 st2 r,
  match_states st1 st2 -> Linear.final_state st1 r -> Mach.final_state st2 r.
Proof.
  intros. inv H0. inv H. inv STACKS.
  assert (R: exists r, loc_result signature_main = One r).
  { destruct (loc_result signature_main) as [r1 | r1 r2] eqn:LR.
  - exists r1; auto.
  - generalize (loc_result_type signature_main). rewrite LR. discriminate.
  }
  destruct R as [rres EQ]. rewrite EQ in H1. simpl in H1.
  generalize (AGREGS rres). rewrite H1. intros A; inv A.
  econstructor; eauto.
Qed.

Lemma wt_prog:
  forall i fd, In (i, Gfun fd) prog.(prog_defs) -> wt_fundef fd.
Proof.
  intros.
  exploit list_forall2_in_left. eexact (proj1 TRANSF). eauto.
  intros ([i' g] & P & Q & R). simpl in *. inv R. destruct fd; simpl in *.
- monadInv H2. unfold transf_function in EQ.
  destruct (wt_function f). auto. discriminate.
- auto.
Qed.

Theorem transf_program_correct:
  forward_simulation (Linear.semantics prog) (Mach.semantics return_address_offset tprog).
Proof.
  set (ms := fun s s' => wt_state s /\ match_states s s').
  eapply forward_simulation_plus with (match_states := ms).
- apply senv_preserved.
- intros. exploit transf_initial_states; eauto. intros [st2 [A B]].
  exists st2; split; auto. split; auto.
  apply wt_initial_state with (prog := prog); auto. exact wt_prog.
- intros. destruct H. eapply transf_final_states; eauto.
- intros. destruct H0.
  exploit transf_step_correct; eauto. intros [s2' [A B]].
  exists s2'; split. exact A. split.
  eapply step_type_preservation; eauto. eexact wt_prog. eexact H.
  auto.
Qed.

End PRESERVATION.
