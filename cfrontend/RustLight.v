Require Import Ctypes.
Require Import Floats.
Require Import Maps.
Require Import Axioms Coqlib.
Require Import Values.
Require Import Integers.
Require Import AST.
(* brings in do notation? *)
Require Import Errors.
Require Import Cop.
Require Import Memory.
Require Import Globalenvs.
Require Import Memory.
Require Clight.
Require Cshmgen.
Local Open Scope error_monad_scope.


(* potentially region based *)
(* rustlight will not use lifetimes at this point*)
Inductive lifetime : Type :=
  | Unbounded
  | Bounded: int ->  int -> lifetime.

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
  | Ealignof: type -> type  -> rexpr
  (* TODO delete Empty. Only here for convenience of construction*)
  | Empty: rexpr.

Locate unary_operation.

Search binary_operation.

Fixpoint transl_expr (ce: composite_env) (a: Clight.expr) {struct a} : res (rexpr) :=
  match a with
  | Clight.Econst_int n ty =>
      OK(Econst_int n ty)
  | Clight.Econst_float n ty =>
      OK(Econst_float n ty)
  | Clight.Econst_single n ty =>
      OK(Econst_single n ty)
  | Clight.Econst_long n ty =>
      OK(Econst_long n ty)
  | Clight.Evar id ty =>
      OK(Evar id ty)
  | Clight.Etempvar id ty =>
      OK(Etempvar id ty)
  | Clight.Ederef b ty =>
      do tb <- transl_expr ce b;
      OK(Ederef tb ty)
  | Clight.Eaddrof b ty =>
      do tb <- transl_expr ce b;
      OK(Eaddrof tb ty)
  | Clight.Eunop op exp ty =>
      do tb <- transl_expr ce exp;
      OK(Eunop op tb ty)
  | Clight.Ebinop op exp1 exp2 ty =>
      do rexp1 <- transl_expr ce exp1;
      do rexp2 <- transl_expr ce exp2;
      (* TODO think about casting to different widths *)
      OK(Ebinop op rexp1 rexp2 ty)
  | Clight.Ecast exp ty =>
      do rexp <- transl_expr ce exp;
      OK(Ecast rexp ty)
  | Clight.Efield exp ident ty =>
      do rexp <- transl_expr ce exp;
      OK(Efield rexp ident ty)
  | Clight.Esizeof ty' ty =>
      OK(Esizeof ty' ty)
  | Clight.Ealignof ty' ty =>
      OK(Ealignof ty' ty)
  end.

(* TODO rename to be consistent *)
Inductive rstatement: Type :=
  | S_skip : rstatement
  (* no let. That is a = b; *)
  | S_assign : rexpr -> rexpr -> rstatement
  (*let mut a = b;*)
  | S_set : ident -> rexpr -> rstatement
  | S_call: option ident -> rexpr -> list rexpr -> rstatement
  | S_builtin: option ident -> external_function -> typelist -> list rexpr -> rstatement
  | S_sequence : rstatement -> rstatement -> rstatement
  | S_if_then_else : rexpr  -> rstatement -> rstatement -> rstatement
  | S_loop: loop_lbl -> rstatement -> rstatement -> rstatement
  | S_break : loop_lbl -> rstatement
  | S_continue : rstatement
  | S_return : option rexpr -> rstatement
  (* match statements are very limited in scope *)
  (* we only match on ints *)
  (* and we assign to nothing *)
  | S_match_int : rexpr -> labeled_rstatements -> rstatement
with labeled_rstatements : Type :=
  | LSnil: labeled_rstatements
  | LScons: option Z -> rstatement -> labeled_rstatements -> labeled_rstatements
with loop_lbl : Type := | Loop_lbl: ident -> loop_lbl.

Fixpoint transl_statement (ce: composite_env) (tyret: type) (nbrk ncnt: nat)
                          (s: Clight.statement) {struct s} : res rstatement :=
  match s with
  | Clight.Sskip => OK(S_skip)
  | Clight.Sassign lval rval =>
      do r_lval <- transl_expr ce lval;
      do r_rval <- transl_expr ce rval;
      OK(S_assign r_lval r_rval)
  | Clight.Sifthenelse exp s1 s2 =>
      do r_exp <- transl_expr ce exp;
      do r_s1 <- transl_statement ce tyret nbrk ncnt s1;
      do r_s2 <- transl_statement ce tyret nbrk ncnt s2;
      OK(S_if_then_else r_exp r_s1 r_s2)
  | Clight.Sset x exp =>
      do r_exp <- transl_expr ce exp;
      OK(S_set x r_exp)
  | Clight.Ssequence exp1 exp2 =>
      do r_exp1 <- transl_statement ce tyret nbrk ncnt exp1;
      do r_exp2 <- transl_statement ce tyret nbrk ncnt exp2;
      OK (S_sequence r_exp1 r_exp2)
  | Clight.Sreturn None => OK(S_return None)
  | Clight.Sreturn (Some exp) =>
      do r_exp <- transl_expr ce exp;
      OK(S_return (Some r_exp))
  | Clight.Sswitch exp stmts =>
    OK(S_skip)

  | Clight.Scall x b cl => OK(S_skip)
  | Clight.Sbuiltin x ef tyargs bl => OK(S_skip)
  | Clight.Sloop s1 s2 => OK(S_skip)
  | Clight.Sbreak => OK(S_skip)
  | Clight.Scontinue => OK(S_skip)
  | Clight.Slabel lbl s => OK(S_skip)
  | Clight.Sgoto lbl => OK(S_skip)
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


(* transl_lbl_stmt (ce: composite_env) (tyret: type) (nbrk ncnt: nat) *)
(*                      (sl: Clight.labeled_statements) *)
(*                      {struct sl}: res lbl_stmt := *)
(*   match sl with *)
(*   | Clight.LSnil => *)
(*       OK LSnil *)
(*   | Clight.LScons n s sl' => *)
(*       do ts <- transl_statement ce tyret nbrk ncnt s; *)
(*       do tsl' <- transl_lbl_stmt ce tyret nbrk ncnt sl'; *)
(*       OK (LScons n ts tsl') *)
(*   end. *)




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

Definition transl_globvar (id: ident) (ty: type) := OK ty.

Definition transl_internal_fun (ce: composite_env) (f: Clight.function) : res r_function :=
  let return_type := (Clight.fn_return f) in
  do body <- transl_statement ce return_type 1%nat 0%nat (Clight.fn_body f);
  OK({|
        fn_return := return_type;
        fn_callconv := {| cc_structret := (AST.cc_structret (Clight.fn_callconv f)) |};
        fn_params := f.(Clight.fn_params);
        fn_vars := f.(Clight.fn_vars);
        fn_temps := f.(Clight.fn_temps);
        fn_body := body;
      |}).


Definition transl_fundef (ce: composite_env) (id: ident) (fn : Clight.fundef) : res r_fundef :=
  match fn with
    | Ctypes.Internal f =>
        do r_f <- transl_internal_fun ce f;
        OK(Ctypes.Internal r_f)
    | Ctypes.External a b c d => OK(Ctypes.External a b c d)
  end.

Print transform_partial_program2.

Print AST.transf_globdefs.

Definition transl_program (c_prog: Clight.program) : res (Clight.program * r_program) :=
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
  (* do r_prog <- transform_partial_program2 (transl_fundef c_prog.(prog_comp_env)) transl_globvar c_prog; *)
  OK(c_prog, r_prog).

(* Error(msg "not implemented yet"). *)
