(* *******************  *)
(* Author: Yuting Wang  *)
(* Date:   Dec 12th, 2019 *)
(* *******************  *)

(** * Separate compilation for permutation of definitions *)
Require Import Coqlib Errors Maps.
Require Import Integers Floats AST.
Require Import Values Memory Events Linking OrderedLinking.
Require Import Permutation Smallstep.
Require Import Globalenvs.
Require Import LocalLib.

Local Transparent Linker_prog_ordered.

(** matching modulo the permutation of definitions *)

Definition match_prog {F V} (p tp: AST.program F V) :=
  Permutation (prog_defs p) (prog_defs tp) 
  /\ prog_main p = prog_main tp
  /\ prog_public p = prog_public tp.

Lemma prog_option_defmap_perm: 
  forall {F V} {LF: Linker F} {LV: Linker V}
    (p1 tp1: program F V) x,
    list_norepet (prog_defs_names p1) ->
    Permutation (prog_defs p1) (prog_defs tp1) ->
    (prog_option_defmap p1) ! x = (prog_option_defmap tp1) ! x.
Proof.
  intros.
  unfold prog_option_defmap.
  apply Permutation_pres_ptree_get; eauto.
Qed.

Lemma link_prog_check_perm:
  forall {F V} {LF: Linker F} {LV: Linker V}
    (p1 p2 tp1 tp2: program F V) x a,
    list_norepet (prog_defs_names p1) ->
    list_norepet (prog_defs_names p2) ->
    prog_public p1 = prog_public tp1 ->
    prog_public p2 = prog_public tp2 ->
    Permutation (prog_defs p1) (prog_defs tp1) ->
    Permutation (prog_defs p2) (prog_defs tp2) ->
    link_prog_check p1 p2 x a = true ->
    link_prog_check tp1 tp2 x a = true.
Proof.
  intros until a.
  intros NORPT1 NORPT2 PUB1 PUB2 PERM1 PERM2 CHK.
  unfold link_prog_check in *.
  destr_in CHK.
  - repeat rewrite andb_true_iff in CHK. 
    destruct CHK as [[IN1 IN2] LK].
    destr_in LK; try congruence.
    erewrite <- prog_option_defmap_perm; eauto.
    rewrite Heqo.
    repeat rewrite andb_true_iff.
    rewrite <- PUB1.
    rewrite <- PUB2.
    intuition.
    rewrite Heqo0. auto.
  - erewrite <- prog_option_defmap_perm; eauto.
    rewrite Heqo. auto.
Qed.


Lemma link_prog_check_all_perm : 
  forall {F V} {LF: Linker F} {LV: Linker V}
    (p1 p2 tp1 tp2: program F V),
    list_norepet (prog_defs_names p1) ->
    list_norepet (prog_defs_names p2) ->
    prog_public p1 = prog_public tp1 ->
    prog_public p2 = prog_public tp2 ->
    Permutation (prog_defs p1) (prog_defs tp1) ->
    Permutation (prog_defs p2) (prog_defs tp2) ->
    PTree_Properties.for_all (prog_option_defmap p1)
                             (link_prog_check p1 p2) = true ->
    PTree_Properties.for_all (prog_option_defmap tp1)
                             (link_prog_check tp1 tp2) = true.
Proof.
  intros until tp2.
  intros NORPT1 NORPT2 PUB1 PUB2 PERM1 PERM2 FALL.
  rewrite PTree_Properties.for_all_correct in *.
  intros x a GET.
  generalize (in_prog_option_defmap _ _ GET); eauto.
  intros IN.
  apply Permutation_sym in PERM1.
  generalize (Permutation_in _ PERM1 IN).
  intros IN'.
  generalize (prog_option_defmap_norepet _ _ _ NORPT1 IN').
  intros GET'.
  generalize (FALL _ _ GET').
  intros CHK.
  apply link_prog_check_perm with p1 p2; eauto.
  apply Permutation_sym; auto.
Qed.
    
  

(** Commutativity between permutation and linking *)
Instance TransfPermuteOrderedLink1 {F V} {LV: Linker V}
  : @TransfLink _ _ (Linker_prog (fundef F) V) (Linker_prog_ordered F V) match_prog.
Proof.
  Local Transparent Linker_prog.
  red. unfold match_prog. cbn. 
  intros until p.
  intros LINK (PERM1 & MAINEQ1 & PUBEQ1) (PERM2 & MAINEQ2 & PUBEQ2).
  generalize LINK. intros LINK'.
  unfold link_prog in LINK.
  destr_in LINK. inv LINK. cbn.
  repeat (rewrite andb_true_iff in Heqb). 
  destruct Heqb as (((MAINEQ & NORPT1) & NORPT2) & CHECK).
  destruct ident_eq; try discriminate.
  destruct list_norepet_dec; try discriminate.
  destruct list_norepet_dec; try discriminate.
  unfold link_prog_ordered.
  assert (prog_main tp1 = prog_main tp2) as MAINEQ3 by congruence.
  rewrite MAINEQ3.
  destruct ident_eq; try congruence. cbn.
  assert (list_norepet (map fst (prog_defs tp1))) as NORPT3.
  { eapply Permutation_list_norepet_map; eauto. }
  destruct list_norepet_dec; try contradiction. cbn.
  assert (list_norepet (map fst (prog_defs tp2))) as NORPT4.
  { eapply Permutation_list_norepet_map; eauto. }
  destruct list_norepet_dec; try contradiction. cbn.  
  edestruct (@extract_defs_exists F V _ tp1 tp2) as (defs1 & t1 & EXTR); eauto.
  eapply prog_linkable_permutation; eauto.
  rewrite EXTR. 
  eexists; split; eauto.
  rewrite (link_prog_check_all_perm p1 p2 tp1 tp2); eauto. cbn.
  repeat (split; auto).
  generalize (PTree_extract_elements_permutation _ _ _ _ EXTR).
  intros PERM3. 
  apply Permutation_trans with (defs1 ++ PTree.elements t1).
  eapply Permutation_trans; [| exact PERM3].
  unfold prog_option_defmap.
  eapply PTree_combine_permutation; eauto.
  apply Permutation_app_comm.
  congruence.
  congruence.
Qed.

Instance TransfPermuteOrderedLink2 {F V} {LV: Linker V}
  : @TransfLink _ _ (Linker_prog_ordered F V) (Linker_prog (fundef F) V) match_prog.
Proof.
  Local Transparent Linker_prog.
  red. unfold match_prog. cbn. 
  intros until p.
  intros LINK (PERM1 & MAINEQ1 & PUBEQ1) (PERM2 & MAINEQ2 & PUBEQ2).
  generalize LINK. intros LINK'.
  unfold link_prog_ordered in LINK.
  destr_in LINK. destr_in LINK. destruct p0. inv LINK. cbn.
  repeat (rewrite andb_true_iff in Heqb). 
  destruct Heqb as (((MAINEQ & NORPT1) & NORPT2) & CHECK).
  destruct ident_eq; try discriminate.
  destruct list_norepet_dec; try discriminate.
  destruct list_norepet_dec; try discriminate.
  unfold link_prog.
  assert (prog_main tp1 = prog_main tp2) as MAINEQ3 by congruence.
  rewrite MAINEQ3.
  destruct ident_eq; try congruence. cbn.
  assert (list_norepet (map fst (prog_defs tp1))) as NORPT3.
  { eapply Permutation_list_norepet_map; eauto. }
  destruct list_norepet_dec; try contradiction. cbn.
  assert (list_norepet (map fst (prog_defs tp2))) as NORPT4.
  { eapply Permutation_list_norepet_map; eauto. }
  destruct list_norepet_dec; try contradiction. cbn.  
  eexists; split; eauto.
  rewrite (link_prog_check_all_perm p1 p2 tp1 tp2); eauto. cbn.
  repeat (split; auto).
  apply Permutation_sym.
  generalize (PTree_extract_elements_permutation _ _ _ _ Heqo).
  intros PERM3. 
  apply Permutation_trans with (l ++ PTree.elements t).
  eapply Permutation_trans; [| exact PERM3].
  unfold prog_option_defmap.
  eapply PTree_combine_permutation; eauto.
  apply Permutation_sym; auto.
  apply Permutation_sym; auto.
  apply Permutation_app_comm.
  congruence.
  congruence.
Qed.


Require Import Asm RealAsm.


Lemma transf_program_match:
  forall F V (p: AST.program F V), match_prog p p.
Proof.
  intros. red. 
  repeat (split; auto).
Qed.

(** Preservation of semantics under permutation *)
Section PRESERVATION.

Context `{external_calls_prf: ExternalCalls}.

Variable prog: Asm.program.
Variable tprog: Asm.program.
Hypothesis TRANSF: match_prog prog tprog.

Let ge := Genv.globalenv prog.
Let tge := Genv.globalenv tprog.





Lemma add_global_find_symbol: forall defs id g pubs,
    In (id, Some g) defs
    ->let genv' := (Genv.add_globals
                     (Genv.empty_genv fundef unit pubs)
                     defs) in 
     exists b, (Genv.genv_symb genv') ! id = Some b /\
          (Genv.genv_defs genv') ! b = Some g.
Admitted.

Lemma find_symbol_transf': forall id g,
    In (id, Some g) (prog_defs prog)
    -> In (id, Some g) (prog_defs tprog).
Admitted.
(* Lemma find_symbol_transf': forall s, *)
(*     Genv.find_symbol tge s = *)
(*     Genv.find_symbol ge s. *)
(* Proof. *)
(*   intros s. *)
(*   unfold ge. unfold tge. *)
(*   unfold Genv.globalenv. *)
(*   unfold Genv.find_symbol. *)
  

(* Admitted. *)


Axiom not_find_symbol_transf: forall s,
    match_prog prog tprog->
    Genv.find_symbol ge s = None
    -> Genv.find_symbol tge s = None.


Axiom find_symbol_transf: forall s,
    match_prog prog tprog->
    Genv.find_symbol tge s =
    Genv.find_symbol ge s.

Axiom find_funct_ptr_transf: forall v,
    match_prog prog tprog->
    Genv.find_funct_ptr tge v =
    Genv.find_funct_ptr ge v.

Axiom transf_program_correct:
  forward_simulation (RealAsm.semantics prog (Pregmap.init Vundef))
                     (RealAsm.semantics tprog (Pregmap.init Vundef)).

End PRESERVATION.
