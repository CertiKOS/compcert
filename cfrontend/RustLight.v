Require Import Ctypes.
Require Import Floats.
Require Import Maps.
Require Import Axioms Coqlib.
Require Import Values.
Require Import Integers.
Require Import AST.
(* brings in do notation on errors *)
Require Import Errors.
Require Import Cop.
Require Import Memory.
Require Import Globalenvs.
Require Import Memory.
Require SimplExpr.
Require Clight.
Require Cshmgen.
Local Open Scope error_monad_scope.

Print Ctypes.program.
Locate Genv.t.

Print Ctypes.prog_public.

(* TODO *)
(* - precedence *)
(* - across the board handle attributes*)
(* - module *)
(* - pointer addition *)
(* - builtins*)
(* - cast *)
(* - goto *)
(* - slides: what am I doing about structs that don't fully initialize. *)
(* - slides: alignof and sizeof signatures TODO do they match? also have to use generics*)

Fixpoint m2m {A: Type} (m: res A) : SimplExpr.mon A :=
  match m with
  | OK(a) => SimplExpr.ret a
  | Error(m) => SimplExpr.error m
  end.

Declare Scope gensym_monad_scope_2.
Notation "'gdo' X <- A ; B" := (SimplExpr.bind A (fun X => B))
   (at level 200, X ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.

Notation "'gdo' ( X , Y ) <- A ; B" := (SimplExpr.bind2 A (fun X Y => B))
   (at level 200, X ident, Y ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.

Notation "'gdom' X <- A ; B" := (SimplExpr.bind (m2m A) (fun X => B))
   (at level 200, X ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.
Local Open Scope gensym_monad_scope_2.




Print composite_env. (* things in scope *)
Print composite.



(* most of these types are just glibc types *)
Inductive rexpr : Type :=
  | Econst_int: int -> type  -> rexpr
  | Econst_float: float -> type  -> rexpr
  | Econst_single: float32 -> type  -> rexpr
  | Econst_long: int64 -> type ->  rexpr
  | Evar: ident -> type ->  rexpr
  | Etempvar: ident -> type  -> rexpr
  | Ederef: rexpr -> type  -> rexpr (* pointers will be (for the moment) treated the same as in C*)
  | Eaddrof: rexpr -> type  -> rexpr (* straight forward push to addr_of!*)
  | Eunop: unary_operation -> rexpr -> type  -> rexpr
  | Ebinop: binary_operation -> rexpr -> rexpr -> type  -> rexpr
  | Ecast: rexpr -> type  -> rexpr
  | Efield: rexpr -> ident -> type  -> rexpr
  | Esizeof: type -> type  -> rexpr
  | Ealignof: type -> type  -> rexpr.

Locate unary_operation.

Search binary_operation.

Print tt.

Definition check_attr(ty: Ctypes.attr) : res (unit) :=
  match ty.(attr_volatile) with
  | false => OK(tt)
  | true => Error(msg "unsupported attribute volatile")
  end.

Print Ctypes.type.

Fixpoint check_ty (ty: Ctypes.type) : res (unit) :=
  match ty with
  | Ctypes.Tvoid => OK(tt)
  | Ctypes.Tint _ _ a => check_attr a
  | Ctypes.Tlong _ a => check_attr a
  | Ctypes.Tfloat _ a => check_attr a
  | Ctypes.Tpointer _ a => check_attr a
  | Ctypes.Tarray _ _ a => check_attr a
  | Ctypes.Tfunction tl ty _ =>
      do _ <- check_typelist tl;
      check_ty ty
  | Ctypes.Tstruct _ a => check_attr a
  | Ctypes.Tunion _ a => check_attr a
  end
with check_typelist(tl : typelist) : res (unit) :=
  match tl with
  | Ctypes.Tnil => OK(tt)
  | Ctypes.Tcons ty tl =>
      do _ <- check_ty ty;
      check_typelist tl
  end.


Fixpoint transl_expr (ce: composite_env) (a: Clight.expr) {struct a} : res (rexpr) :=
  match a with
  | Clight.Econst_int n ty =>
      do _ <- check_ty ty;
      OK(Econst_int n ty)
  | Clight.Econst_float n ty =>
      do _ <- check_ty ty;
      OK(Econst_float n ty)
  | Clight.Econst_single n ty =>
      do _ <- check_ty ty;
      OK(Econst_single n ty)
  | Clight.Econst_long n ty =>
      do _ <- check_ty ty;
      OK(Econst_long n ty)
  | Clight.Evar id ty =>
      do _ <- check_ty ty;
      OK(Evar id ty)
  | Clight.Etempvar id ty =>
      do _ <- check_ty ty;
      OK(Etempvar id ty)
  | Clight.Ederef b ty =>
      do _ <- check_ty ty;
      do tb <- transl_expr ce b;
      OK(Ederef tb ty)
  | Clight.Eaddrof b ty =>
      do _ <- check_ty ty;
      do tb <- transl_expr ce b;
      OK(Eaddrof tb ty)
  | Clight.Eunop op exp ty =>
      do _ <- check_ty ty;
      do tb <- transl_expr ce exp;
      OK(Eunop op tb ty)
  | Clight.Ebinop op exp1 exp2 ty =>
      do _ <- check_ty ty;
      do rexp1 <- transl_expr ce exp1;
      do rexp2 <- transl_expr ce exp2;
      (* TODO think about casting to different widths *)
      OK(Ebinop op rexp1 rexp2 ty)
  | Clight.Ecast exp ty =>
      do _ <- check_ty ty;
      do rexp <- transl_expr ce exp;
      OK(Ecast rexp ty)
  | Clight.Efield exp ident ty =>
      do _ <- check_ty ty;
      do rexp <- transl_expr ce exp;
      OK(Efield rexp ident ty)
  | Clight.Esizeof ty' ty =>
      do _ <- check_ty ty;
      OK(Esizeof ty' ty)
  | Clight.Ealignof ty' ty =>
      do _ <- check_ty ty;
      OK(Ealignof ty' ty)
  end.

Print SimplExpr.transl_stmt.

Record s_md : Type :=
  mk_s_md {
      ce: composite_env;
      tyret: type;
      nbrk: nat;
      ncnt: nat;
      cur_loop_lbl: option Z;
      cur_switch_lbl: option Z;
      next_lbl: option Z;
    }.

Print ce.



(* TODO rename to be consistent *)
Inductive rstatement: Type :=
  | S_skip : rstatement
  (* no let. That is a = b; *)
  | S_assign : rexpr -> rexpr -> rstatement
  (* a = b;*)
  | S_set : ident -> rexpr -> rstatement
  | S_call: option ident -> rexpr -> list rexpr -> rstatement
  | S_builtin: option ident -> external_function -> typelist -> list rexpr -> rstatement
  | S_sequence : rstatement -> rstatement -> rstatement
  | S_if_then_else : rexpr  -> rstatement -> rstatement -> rstatement
  | S_loop: option Z -> rstatement -> rstatement -> rstatement
  | S_break : option Z -> rstatement
  | S_continue : option Z -> rstatement
  | S_return : option rexpr -> rstatement
  (* match statements are very limited in scope *)
  (* we only match on ints *)
  (* and we assign to nothing *)
  | S_match_int : rexpr -> labeled_rstatements -> rstatement
with labeled_rstatements : Type :=
  | LSnil: labeled_rstatements
  | LScons: Z -> rstatement -> labeled_rstatements -> labeled_rstatements.

Locate int.

Fixpoint transl_arglist
  (ce: composite_env)
  (al: list Clight.expr)
  {struct al}:
  res (list rexpr) :=
  match al with
  | nil => OK(nil)
  | a1 :: a2 =>
      do arg <- transl_expr ce a1 ;
      do args <- transl_arglist ce a2 ;
      OK(arg :: args)
  end
.

Fixpoint transl_statement
  (md : s_md)
  (s: Clight.statement) {struct s}
  : SimplExpr.mon rstatement
  :=
  match md with
  | {|
      ce := ce;
      tyret := tyret;
      nbrk := nbrk; ncnt := ncnt;
      cur_loop_lbl := cur_loop_lbl;
      cur_switch_lbl := cur_switch_lbl;
      next_lbl := next_lbl;
    |} =>
    match s with
    | Clight.Sskip => SimplExpr.ret (S_skip)
    | Clight.Sassign lval rval =>
        gdom r_val <-
          do r_lval <- transl_expr ce lval;
          do r_rval <- transl_expr ce rval;
          OK(S_assign r_lval r_rval);
        SimplExpr.ret r_val
    | Clight.Sifthenelse exp s1 s2 =>
        gdom r_exp <- transl_expr ce exp;
        gdo r_s1 <- transl_statement md s1;
        gdo r_s2 <- transl_statement md s2;
        SimplExpr.ret (S_if_then_else r_exp r_s1 r_s2)
    | Clight.Sset x exp =>
        gdom r_exp <- transl_expr ce exp;
        SimplExpr.ret (S_set x r_exp)
    | Clight.Ssequence exp1 exp2 =>
        gdo r_exp1 <- transl_statement md exp1;
        gdo r_exp2 <- transl_statement md exp2;
        SimplExpr.ret (S_sequence r_exp1 r_exp2)
    | Clight.Sreturn None => SimplExpr.ret (S_return None)
    | Clight.Sreturn (Some exp) =>
        gdom r_exp <- transl_expr ce exp;
        SimplExpr.ret (S_return (Some r_exp))
    | Clight.Sswitch exp stmts =>
      let exp_typ := Clight.typeof exp in
      let dflt_case_ty := Ctypes.Tint IBool Signed noattr in
      let dflt_is_first :=
        match stmts with
        | Clight.LSnil => (Int.repr 0)
        | Clight.LScons None _ _ => (Int.repr 1)
        | Clight.LScons _ _ _ => (Int.repr 0)
        end in
      let dflt_case_val := Econst_int dflt_is_first dflt_case_ty in (*initial val *)
      gdo dflt_case_ident <- SimplExpr.gensym dflt_case_ty ;
      gdom r_exp <- transl_expr ce exp ;
      gdo exp_ident <- SimplExpr.gensym exp_typ;
      let exp_decl := S_set exp_ident r_exp in

      let dflt_case_decl := S_set dflt_case_ident dflt_case_val in

      let exp_ident_as_exp := Etempvar exp_ident exp_typ in

      let dflt_ident_as_exp := Etempvar dflt_case_ident dflt_case_ty in

      let switch_loop_lbl :=
        match next_lbl with
        | None => Some 0%Z
        | Some(n) => Some (n + 1)
        end in

      let u_s_md :=
        {|
          ce := ce;
          tyret := tyret;
          nbrk := nbrk;
          ncnt := ncnt;
          cur_loop_lbl := cur_loop_lbl;
          cur_switch_lbl := switch_loop_lbl;
          next_lbl := switch_loop_lbl;
        |} in

      gdo (dflt_case_inner_stmt, labeled_match_stmts) <-
        transl_switch u_s_md stmts exp_ident_as_exp exp_typ dflt_ident_as_exp dflt_case_ty S_skip LSnil ;

      let match_stmt := S_match_int exp_ident_as_exp labeled_match_stmts in

      let if_dflt_stmt := S_if_then_else (dflt_ident_as_exp) dflt_case_inner_stmt S_skip in

      let loop_body := S_sequence if_dflt_stmt match_stmt in

      let new_loop := S_loop switch_loop_lbl loop_body S_skip in

      SimplExpr.ret (S_sequence (S_sequence dflt_case_decl exp_decl) new_loop)
    | Clight.Scall x name al =>
        gdom name' <- transl_expr ce name ;
        gdom al' <- transl_arglist ce al ;
        SimplExpr.ret (S_call x name' al')
    | Clight.Sbuiltin x ef tyargs bl => SimplExpr.ret (S_skip)
    | Clight.Sloop s1 s2 =>
        let loop_lbl :=
          match next_lbl with
          | None => Some 0%Z
          | Some(n) => Some(n+1)
        end in
        let u_s_md :=
          {|
            ce := ce;
            tyret := tyret;
            nbrk := nbrk;
            ncnt := ncnt;
            cur_loop_lbl := loop_lbl;
            cur_switch_lbl := loop_lbl;
            next_lbl := loop_lbl;
          |} in
        gdo r_s1 <- transl_statement u_s_md s1;
        gdo r_s2 <- transl_statement u_s_md s2;
        SimplExpr.ret (S_loop loop_lbl r_s1 r_s2)
    | Clight.Sbreak => SimplExpr.ret (S_break cur_switch_lbl)
    | Clight.Scontinue => SimplExpr.ret (S_continue cur_loop_lbl)
    | Clight.Slabel lbl s => SimplExpr.ret (S_skip)
    | Clight.Sgoto lbl => SimplExpr.ret (S_skip)
  end
end
with transl_switch
  (smd: s_md)
  (s: Clight.labeled_statements)
  (switch_exp: rexpr)
  (switch_exp_ty: type)
  (dd_exp: rexpr)
  (dd_exp_ty: type)
  (dflt_stmt: rstatement)
  (cases: labeled_rstatements)
  {struct s}
  : SimplExpr.mon (rstatement * labeled_rstatements) :=
  (* TODO replace with let (ce, _, _...) := smd in.. *)
  match smd with
  | {|
      ce := ce;
      tyret := tyret;
      nbrk := nbrk; ncnt := ncnt;
      cur_loop_lbl := cur_loop_lbl;
      cur_switch_lbl := cur_switch_lbl;
      next_lbl := next_lbl;
    |} =>
    match s with
    (* empty, just return *)
    | Clight.LSnil => SimplExpr.ret (dflt_stmt, cases)
    (* normal case *)
    | Clight.LScons (Some cur_lbl) stmt ls =>
        (
          gdo body <- transl_statement smd stmt;
          match ls with
          | Clight.LSnil =>
              SimplExpr.ret (dflt_stmt, LScons cur_lbl (S_sequence body (S_break cur_switch_lbl)) cases)
          | Clight.LScons (Some next_lbl_) _ _ =>
              (
                let stmt_1 := S_assign switch_exp (Econst_int (Int.repr next_lbl_) switch_exp_ty) in
                let mod_body := S_sequence body stmt_1 in
                transl_switch smd ls switch_exp switch_exp_ty dd_exp dd_exp_ty dflt_stmt (LScons cur_lbl mod_body cases)
              )
          | Clight.LScons None _ _ =>
              (
                let stmt_1 := S_assign dd_exp (Econst_int (Int.repr 1) dd_exp_ty) in
                let mod_body := S_sequence body stmt_1 in
                transl_switch smd ls switch_exp switch_exp_ty dd_exp dd_exp_ty dflt_stmt (LScons cur_lbl mod_body cases)
              )
          end
        )
    (* default case *)
    | Clight.LScons None stmt ls =>
        (
          gdo body <- transl_statement smd stmt ;
          match ls with
          (* no next statement. Default is last. Break after default *)
          | Clight.LSnil => SimplExpr.ret (S_sequence body (S_break cur_switch_lbl), cases)
          (* there's more, get next label*)
          | Clight.LScons (Some lbl) _ _ =>
              (
                let stmt_1 := S_assign switch_exp (Econst_int (Int.repr lbl) switch_exp_ty) in
                let stmt_2 := S_assign dd_exp (Econst_int (Int.repr 0) dd_exp_ty) in
                let mod_body := S_sequence (S_sequence body stmt_1) stmt_2 in
                transl_switch smd ls switch_exp switch_exp_ty dd_exp dd_exp_ty mod_body cases
              )
          (* impossible to hit. Only can be one default *)
          (* TODO this should return an error since it's impossible to hit *)
          | Clight.LScons _ _ _ =>  SimplExpr.ret (S_sequence body (S_break cur_switch_lbl), cases)
          end
        )
    end
  end.


Record r_calling_convention : Type := mkcallconv { cc_structret: bool }.

Print type.

Locate globdef.
Print AST.globdef.
Print AST.globvar.
Print Ctypes.composite_definition.
Print ident.

Record r_function : Type := mkrfunction {
  fn_return: type;

  fn_callconv: r_calling_convention;
  (* args to function *)
  fn_params: list (ident * type);
  (* variables declared in function scope *)
  fn_vars: list (ident * type);
  (* temp vars *)
  fn_temps: list (ident * type);
  (* body *)
  fn_body: rstatement
}.

Print type.

Print mkcallconv.

Print bool.

Print type.

Locate type.


Definition empty_r_fn : r_function := {|
                                 fn_return := Ctypes.Tvoid;
                                 fn_callconv := {| cc_structret := false; |};
                                 fn_params := nil;
                                 fn_vars := nil;
                                 fn_temps := nil;
                                 fn_body := S_skip;
                               |}.





Print Ctypes.program.
Print AST.program.
Print mkprogram.

Print list.

Print ident.


Print Ctypes.program.

Print Cshmgen.transl_globvar.

Print AST.transform_partial_program2.

Print AST.program.

Print AST.transform_partial_program2.


Print Ctypes.program.

(* unit *)
Print tt.


Print Clight.program.

(* TODO not sure if I'm okay with the external function definition? The rust builtins may differ from C. *)
Definition r_fundef := Ctypes.fundef r_function.
(* generic over function type *)
Definition r_program := Ctypes.program r_function.
Print r_program.

(* TODO make signature explicit *)
Definition transl_globvar (id: ident) (ty: type) := OK ty.

Search positive.

Local Open Scope positive_scope.


Fixpoint get_max_ident_helper (idents: list ident) (max_ident: ident) : ident :=
  match idents with
  | nil => max_ident
  | hd :: tl =>
      (
        let new_max_ident := if (max_ident <? hd) then hd else max_ident in
        get_max_ident_helper tl new_max_ident
      )
  end.


Definition get_max_ident (idents: list ident) : res ident :=
  match idents with
  | nil  => Error nil
  | hd :: tl => OK(get_max_ident_helper tl hd)
  end.


Print positive.

Print map.

(* NOTE: assumed short atoms are in use, not canonical atoms *)
Definition reconstruct_generator (trail: list (ident * type)) : SimplExpr.generator :=
  let idents := map fst trail in
  let maybe_max_ident := get_max_ident idents in
  let max_ident :=
    (
        match maybe_max_ident with
        | OK(x) => xI x
        | _ => SimplExpr.first_unused_ident tt
        end
    )
  in
  SimplExpr.mkgenerator max_ident trail.

Definition transl_internal_fun (ce: composite_env) (f: Clight.function) : res r_function :=
  let return_type := (Clight.fn_return f) in
  let generator := reconstruct_generator f.(Clight.fn_temps) in
  let smd := {|
              ce := ce;
              tyret := return_type;
              nbrk := 1%nat;
              ncnt := 0%nat;
              cur_loop_lbl := None;
              cur_switch_lbl := None;
              next_lbl := None;
            |} in
  let body := transl_statement smd (Clight.fn_body f) generator in
  match body with
  | SimplExpr.Err msg => Error msg
  | SimplExpr.Res r_body r_g i =>
      let cc := Clight.fn_callconv f in
      match cc.(AST.cc_vararg) with
      (* variadic. _n means # of fixed args *)
      | Some _n => Error(msg "Variadics are currently unsupported when converting to rust")
      (* not variadic *)
      | None =>
          OK({|
                fn_return := return_type;
                fn_callconv := {| cc_structret := (AST.cc_structret cc) |};
                fn_params := f.(Clight.fn_params);
                fn_vars := f.(Clight.fn_vars);
                fn_temps := r_g.(SimplExpr.gen_trail);
                fn_body := r_body;
              |})
      end
  end.



Definition transl_fundef (ce: composite_env) (id: ident) (fn : Clight.fundef) : res r_fundef :=
  match fn with
    | Ctypes.Internal f =>
        do r_f <- transl_internal_fun ce f;
        OK(Ctypes.Internal r_f)
    | Ctypes.External a b c d => OK(Ctypes.External a b c d)
  end.

Print transform_partial_program2.

Print AST.transf_globdefs.

Print Ctypes.program.

Definition transl_program (c_prog: Clight.program) : res (r_program) :=
  do translated_fns <-  AST.transf_globdefs (transl_fundef c_prog.(prog_comp_env)) transl_globvar (c_prog.(prog_defs));
  let r_prog :=
    {|
      Ctypes.prog_defs := translated_fns;
      Ctypes.prog_public := c_prog.(prog_public);
      Ctypes.prog_main := c_prog.(prog_main);
      Ctypes.prog_types := c_prog.(prog_types);
      Ctypes.prog_comp_env := c_prog.(prog_comp_env);
      Ctypes.prog_comp_env_eq := c_prog.(prog_comp_env_eq);
    |} in
  OK(r_prog).

(* Error(msg "not implemented yet"). *)
