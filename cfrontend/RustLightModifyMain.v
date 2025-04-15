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

Fixpoint tl_to_tl (l: list type) : typelist :=
  match l with
  | h :: tl' => Tcons h (tl_to_tl tl')
  | nil => Tnil
  end.


(*
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
 *)

Definition gen_new_main
  (old_main: globdef (Ctypes.fundef Csyntax.function) type)
  (old_main_ident: ident)
  (new_main_ident: ident)
  : res r_function :=
  match old_main with
  | Gfun (Ctypes.Internal (old_main_fn)) => (
    let exit_ty := old_main_fn.(Csyntax.fn_return) in

    let r_call := fun maybe_lbl => (S_call maybe_lbl (Evar old_main_ident (Tfunction (tl_to_tl (List.map snd old_main_fn.(Csyntax.fn_params))) exit_ty old_main_fn.(Csyntax.fn_callconv))) (List.map (fun '(v, t) => Evar v t) old_main_fn.(Csyntax.fn_params))) in
    do (body, tmps) <-
    match exit_ty with
    | Ctypes.Tvoid => OK(r_call None, nil)

    | rty =>
      let generator := reconstruct_generator nil in

      do tmp_ident <-
           match SimplExpr.gensym exit_ty generator with
           | SimplExpr.Err msg => Error msg
           | SimplExpr.Res r_body r_g i => OK(r_body)
           end ;
      let call_stmt := r_call (Some tmp_ident) in
      let return_stmt := S_return (Some (Etempvar tmp_ident exit_ty, exit_ty)) in
      let body := S_sequence call_stmt return_stmt in
      OK(body, cons (tmp_ident, exit_ty) nil)
    end;



    (* TODO split this out. It's incomprehensible right now*)

    let r_cc := RustLight.mkcallconv false in
    let new_main_fn := {|
      fn_return := exit_ty;
      fn_callconv := r_cc;
      fn_params := old_main_fn.(Csyntax.fn_params);
      fn_vars := nil;
      fn_temps := tmps;
      fn_body := body;
      fn_imports := PositiveSet.singleton old_main_ident;
      fn_ty_imports := PositiveSet.empty;
      fn_is_safe := false;
    |}
    in

    OK(new_main_fn)
  )
  | _ => Error(msg "Unexpected type for main function")
  end.

Definition transl_program (r_prog : Csyntax.program) : res (r_function * ident)
  :=
  let old_main_ident := r_prog.(Ctypes.prog_main) in
  let maybe_old_main_fn :=
    List.find
    (fun x => AST.ident_eq (fst x) old_main_ident)
    (r_prog.(prog_defs)) in
  match maybe_old_main_fn with
  | None => Error(msg "Main function found previously, but now is missing?")
  | Some(omf) => (
    let new_main_ident := SimplExpr.first_unused_ident tt in
    do new_main_fn <- gen_new_main (snd omf) r_prog.(prog_main) (new_main_ident);
    OK(new_main_fn, new_main_ident)

  )
  end.
