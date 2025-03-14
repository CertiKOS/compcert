Require Import RustLight.
Require Import Cop.
Require Import Coq.Strings.String.
Require Import Errors.
Require Import Ctypes.
Require Import AST.
Require Import ZArith.
Require Import Integers.
Require Import List.
Require Import SimplExpr.
Import List.ListNotations.

Local Open Scope gensym_monad_scope_2.

(* we are being very conservative here. That's fine. *)
Definition expr_should_be_split (e: rexpr) : bool :=
  match e with
  | Econst_int n ty => true
  | Econst_float f ty => true
  | Econst_single f32 ty => true
  | Econst_long l ty => true
  | Evar id ty =>
      match ty with
      | Ctypes.Tfunction _ _ _ => true
      | _ => false
      end
  | Etempvar id ty =>
      match ty with
      | Ctypes.Tfunction _ _ _ => true
      | _ => false
      end
  (* a reborrow is usually fine, but we want to be conservative *)
  | Ederef e1 ty =>  true
  | Eunop op e1 ty => true
  | Ebinop op e1 e2 ty => true
  | Ecast e1 ty => true
  | Efield e1 id ty => true
  | Esizeof t1 ty => true
  | Ealignof t1 ty => true
  | Enull_check e1 => true
  | Eaddrof e1 ty => true
  end.


(* in order to reflect move semantics, sometimes we may need to split expressions based
   on the expression contents. *)
Fixpoint split_expr (e: rexpr) {struct e} : mon (sum rexpr ((rstatement) * rexpr)) :=
  (* TODO separate out into a function. so much repeated code... *)
  match e with
  | Econst_int _ _
  | Econst_float _ _
  | Econst_single _ _
  | Econst_long _ _
  | Evar _ _
  | Etempvar _ _ => ret(  inr (S_skip, e))
  | Ederef e1 ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Ederef e_final ty) in
          ret(res)
      end
  | Eunop op e1 ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Eunop op e_final ty) in
          ret(res)
      end
  | Ebinop op e1 e2 ty =>
      gdo inner_split_1 <- split_expr e1;
      gdo inner_split_2 <- split_expr e2;
      match (inner_split_1, inner_split_2) with
      | (inl _, inl _) => ret( inr (S_skip, e))
      | (inr (stmts, e_final1), inl _) =>
          let res := inr (stmts, Ebinop op e_final1 e2 ty) in
          ret(res)
      | (inl _, inr (stmts, e_final2)) =>
          let res := inr (stmts, Ebinop op e1 e_final2 ty) in
          ret(res)
      | (inr (stmts1, e_final1), inr (stmts2, e_final2)) =>
          let res := inr (S_sequence stmts1 stmts2, Ebinop op e_final1 e_final2 ty) in
          ret(res)
      end
  | Ecast e1 ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Ecast e_final ty) in
          ret(res)
      end
  | Efield e1 id ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Efield e_final id ty) in
          ret(res)
      end
  | Esizeof t1 ty => ret( inr (S_skip, e))
  | Ealignof t1 ty => ret( inr (S_skip, e))
  | Enull_check e1 =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Enull_check e_final) in
          ret(res)
      end
  | Eaddrof e1 ty_addrof =>
      if (expr_should_be_split e1) then
        let e1_ty := r_typeof e1 in
        gdo var_ident <- gensym e1_ty;
        let var_expr := Etempvar var_ident e1_ty in
        gdo inner_split <- split_expr e1;

        match inner_split with
        (* Inner expression doesn't need to be assigned more. *)
        | inl _ =>
          let assn_stmt := S_set var_ident e1 in
          let res := (assn_stmt, Eaddrof var_expr ty_addrof) in
          ret(inr res)
        | inr (inner_assns, e_inner_final) =>
          let assn_stmt := S_set var_ident e_inner_final in
          let assns := S_sequence inner_assns assn_stmt in
          let res := (assns, Eaddrof (Etempvar var_ident e1_ty) ty_addrof) in
          ret(inr res)
        end
      (* turns out we don't need to split the expression *)
      else ret (inl e)
  end.

Definition process_expr (expr_to_split: rexpr) (gen_stmt: rexpr -> rstatement)
  : SimplExpr.mon rstatement :=
  gdo the_split <- split_expr expr_to_split;
  match the_split with
  | inl e => SimplExpr.ret(gen_stmt e)
  | inr (stmts, e) =>
      let stmt := gen_stmt e in
      SimplExpr.ret(S_sequence stmts stmt)
  end.

(*Fixpoint tranls_match (l : labeled_rstatement) : *)

Fixpoint transl_stmt (s: rstatement) : mon rstatement :=
  match s with
  | S_continue _
  | S_break _
  | S_return None
  | S_skip => ret s
  | S_assign lval rval =>
      let gen_res := fun (e: rexpr) => S_assign lval e in
      process_expr rval gen_res
  | S_set x exp =>
      let gen_res := fun (e: rexpr) => S_set x e in
      process_expr exp gen_res
  | S_call x name al =>
      (* TODO this doesn't look right. Don't all the arguments need to be proccessed? and split? *)
      ret s
  | S_exit exp =>
      let gen_res := fun (e: rexpr) => S_exit e in
      process_expr exp gen_res
  | S_builtin _ _ _ _ => error(msg "Unimplemented")
  | S_sequence s1 s2 =>
      gdo tr_s1 <- transl_stmt s1;
      gdo tr_s2 <- transl_stmt s2;
      ret(S_sequence tr_s1 tr_s2)
  | S_if_then_else cond s1 s2 =>
      gdo tr_s1 <- transl_stmt s1;
      gdo tr_s2 <- transl_stmt s2;
      let gen_res := fun (e: rexpr) => S_if_then_else e tr_s1 tr_s2 in
      process_expr cond gen_res
  | S_return (Some (exp, ty)) =>
      let gen_res := fun (e: rexpr) => S_return (Some (e, ty)) in
      process_expr exp gen_res
  | S_loop n s1 s2 =>
      gdo tr_s1 <- transl_stmt s1;
      gdo tr_s2 <- transl_stmt s2;
      ret (S_loop n tr_s1 tr_s2)
  | S_loop2 n1 n2 s1 s2 =>
      gdo tr_s1 <- transl_stmt s1;
      gdo tr_s2 <- transl_stmt s2;
      ret (S_loop2 n1 n2 tr_s1 tr_s2)
  | S_match_int exp ls =>
      gdo tr_ls <- transl_labeled_rstmts ls;
      let gen_res := fun (e: rexpr) => S_match_int e tr_ls in
      process_expr exp gen_res
  end
  with
transl_labeled_rstmts (ls: labeled_rstatements) : mon labeled_rstatements :=
  match ls with
  | LSnil stmt =>
      gdo tr_stmt <- transl_stmt stmt;
      ret (LSnil (tr_stmt))
  | LScons n stmt ls' =>
      gdo tr_stmt <- transl_stmt stmt;
      gdo tr_ls' <- transl_labeled_rstmts ls';
      ret (LScons n tr_stmt tr_ls')
  end.

Definition transl_internal_function (r_fn: r_function) : res r_function :=
  let generator := reconstruct_generator r_fn.(fn_temps) in
  let split_expr_body_m := transl_stmt r_fn.(fn_body) generator in
  match split_expr_body_m with
  | SimplExpr.Err msg => Error msg
  | SimplExpr.Res split_r_body r_g i =>
      let tmp_vars := r_g.(SimplExpr.gen_trail) in
      OK({|
        fn_return := r_fn.(fn_return);
        fn_callconv := r_fn.(fn_callconv);
        fn_vars := r_fn.(fn_vars);
        fn_temps := tmp_vars;
        fn_body := split_r_body;
        fn_params := r_fn.(fn_params);
        fn_imports := r_fn.(fn_imports);
        fn_is_safe := r_fn.(fn_is_safe);
      |})
  end.

Local Open Scope error_monad_scope.
Definition transl_fundef
  (id: ident)
  (fn : r_fundef) : Errors.res r_fundef :=
  match fn with
    | Ctypes.Internal f =>
        do r_f <- transl_internal_function f;
        OK(Ctypes.Internal r_f)
    | Ctypes.External a b c d => OK(Ctypes.External a b c d)
  end.

Definition transl_globvar (id: ident) (ty: type) := OK ty.

Definition transl_program (r_prog: r_program) : res (r_program) :=

  (* TODO need to evalualte the initialization expression in case it involves say taking an address of a gloval variable from another file *)
  (* low priority *)
  do translated_fns  <-
      AST.transf_globdefs
        transl_fundef
        transl_globvar
        (* (cons (new_main_ident, new_main) c_prog.(prog_defs)); *)
        r_prog.(prog_defs);

  OK({|
    Ctypes.prog_defs := translated_fns;
    Ctypes.prog_public := r_prog.(prog_public);
    Ctypes.prog_main := r_prog.(prog_main);
    Ctypes.prog_types := r_prog.(prog_types);
    Ctypes.prog_comp_env := r_prog.(prog_comp_env);
    Ctypes.prog_comp_env_eq := r_prog.(prog_comp_env_eq);
  |}).

Local Close Scope error_monad_scope.
