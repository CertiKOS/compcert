(* *******************  *)


(* *******************  *)

Require Import Coqlib Errors.
Require Import Integers Floats AST Linking.
Require Import Values Memory Events Globalenvs Smallstep.
Require Import Op Locations Mach Conventions Asm RealAsm.
Require Import PadInitData.
Import ListNotations.
Require AsmFacts.

Lemma transf_globdef_pres_id : forall def,
    fst def = fst (transf_globdef def).
Proof.
  unfold transf_globdef. destruct def. cbn. auto.
Qed.

Lemma genv_symb_pres: forall defs (ge1 ge2: Genv.t fundef unit),
    Genv.genv_next ge1 = Genv.genv_next ge2 ->
    Genv.genv_symb ge1 = Genv.genv_symb ge2 ->
    Genv.genv_symb (fold_left (Genv.add_global (V:=unit)) (map transf_globdef defs) ge1) =
    Genv.genv_symb (fold_left (Genv.add_global (V:=unit)) defs ge2).
Proof.
  induction defs as [| def defs].
  - intros ge1 ge2 GN GS.
    cbn. auto.
  - intros ge1 ge2 GN GS.
    cbn. apply IHdefs.
    + unfold Genv.add_global; cbn.
      congruence.
    + unfold Genv.add_global; cbn.    
      rewrite <- transf_globdef_pres_id. 
      congruence.
Qed.





Definition match_prog (p tp:Asm.program) :=
  tp = transf_program p.

Lemma transf_program_match:
  forall p tp, transf_program p = tp -> match_prog p tp.
Proof.
  intros. subst. red. 
  auto.
Qed.


Section PRESERVATION.
  Existing Instance inject_perm_all.
Context `{external_calls_prf: ExternalCalls}.

Local Existing Instance mem_accessors_default.


Variable p: Asm.program.
Variable tp: Asm.program.

Let ge := Genv.globalenv p.
Let tge := Genv.globalenv tp.

Hypothesis TRANSF: match_prog p tp.


Lemma find_symbol_transf: forall s,
    Genv.find_symbol tge s =
    Genv.find_symbol ge s.
Proof.
  red in TRANSF. unfold transf_program in TRANSF.
  subst. cbn.
  unfold Genv.globalenv, Genv.add_globals.
  unfold Genv.find_symbol. 
  intros. f_equal.
  apply genv_symb_pres.
  reflexivity.
  reflexivity.
Qed.


End PRESERVATION.
