Require Import RustLight.
Require Import Cop.
Require Import Coq.Strings.String.
Require Import Errors.
Require Import Ctypes.
Require Import AST.
Require Import ZArith.
Require Import Integers.
Require Import List.
Require Import Axioms Coqlib.
Import List.ListNotations.


Local Open Scope error_monad_scope.

Definition ret {A: Type} (x : A) : res A  := OK x.

Definition gen_new_main
  (old_main: globdef (Ctypes.fundef r_function) type)
  (old_main_ident: ident)
  (new_main_ident: ident)
  : res (globdef (Ctypes.fundef r_function) type) :=
  match old_main with
  | Gfun (Ctypes.Internal (old_main_fn)) => (
    let generator := reconstruct_generator nil in
    let exit_ty := old_main_fn.(fn_return) in
    do exit_ident <-
         match SimplExpr.gensym exit_ty generator with
         | SimplExpr.Err msg => Error msg
         | SimplExpr.Res r_body r_g i => OK(r_body)
         end ;
    let exit_fn_var := Evar old_main_ident exit_ty in
    let exit_fn_args := map (fun x => Evar (fst x) (snd x)) old_main_fn.(fn_params) in
    let s1 := S_call (Some exit_ident) exit_fn_var exit_fn_args in
    let s2 := S_exit (Etempvar exit_ident exit_ty) in

    OK(Gfun (
        Ctypes.Internal (
              mkrfunction
                Ctypes.Tvoid
                old_main_fn.(fn_callconv)
                old_main_fn.(fn_params)
                nil
                (cons (exit_ident, exit_ty) nil)
                (S_sequence s1 s2)
                (* TODO this is wrong *)
                (PositiveSet.empty)
                (PositiveSet.empty)
                true
              ))))
  | _ => Error(msg "Unexpected type for main function")
  end.

Definition transl_program (r_prog : r_program) : res (r_program)
  :=
  let old_main_ident := r_prog.(Ctypes.prog_main) in

  let old_main_fn :=
    List.find
    (fun x => AST.ident_eq (fst x) old_main_ident)
    (r_prog.(prog_defs)) in
  do (new_prog_defs, new_main_ident) <-
    match old_main_fn with
    | Some(omf) => (
      (* TODO I'm surprised this works. Feels like it shouldn't, morally speaking *)

      (* get the main replacement ident. *)
      let new_main_ident := SimplExpr.first_unused_ident tt in
      do new_main <- gen_new_main (snd omf) r_prog.(prog_main) (new_main_ident) ;
      ret (cons (new_main_ident, new_main) r_prog.(prog_defs), new_main_ident)
    )
    | None => (
      ret (r_prog.(prog_defs), old_main_ident)
    )
    end;

  OK({|
    Ctypes.prog_defs := new_prog_defs;
    Ctypes.prog_public := r_prog.(prog_public);
    Ctypes.prog_main := new_main_ident;
    Ctypes.prog_types := r_prog.(prog_types);
    Ctypes.prog_comp_env := r_prog.(prog_comp_env);
    Ctypes.prog_comp_env_eq := r_prog.(prog_comp_env_eq);
  |}).

