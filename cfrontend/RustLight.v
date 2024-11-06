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

Notation "x |> f" := (f x) (at level 50, left associativity).


Definition m2m {A: Type} (m: res A) : SimplExpr.mon A :=
  match m with
  | OK(a) => SimplExpr.ret a
  | Error(m) => SimplExpr.error m
  end.

Declare Scope gensym_monad_scope_2.
Notation "'gdo' X <- A ; B" := (SimplExpr.bind A (fun X => B))
   (at level 200, X ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.

Definition bind3 {A B C D: Type} (x: SimplExpr.mon (A * B * C)) (f: A -> B -> C -> SimplExpr.mon D) : SimplExpr.mon D :=
  SimplExpr.bind x (fun p => let '(a, b, c) := p in f a b c).

(* TODO how to merge these *)

Notation "'gdo' ( X , Y ) <- A ; B" := (SimplExpr.bind2 A (fun X Y => B))
   (at level 200, X ident, Y ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.

Notation "'gdo' ( X , Y , Z ) <- A ; B" := (bind3 A (fun X Y Z => B))
   (at level 200, X ident, Y ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.

Notation "'gdom' X <- A ; B" := (SimplExpr.bind (m2m A) (fun X => B))
   (at level 200, X ident, A at level 100, B at level 200)
   : gensym_monad_scope_2.
Local Open Scope gensym_monad_scope_2.




Print composite_env. (* things in scope *)
Print composite.



Inductive rexpr : Type :=
  | Econst_int: int -> type  -> rexpr
  | Econst_float: float -> type  -> rexpr
  | Econst_single: float32 -> type  -> rexpr
  | Econst_long: int64 -> type ->  rexpr
  | Evar: ident -> type ->  rexpr
  | Etempvar: ident -> type  -> rexpr
  | Ederef: rexpr -> type  -> rexpr (* pointers will be (for the moment) treated the same as in C*)
  | Eaddrof: rexpr -> type  -> rexpr (* straight forward push to addr_of!*)
  (* NOTE: unary operation only applies to booleans *)
  | Eunop: unary_operation -> rexpr -> type  -> rexpr
  | Ebinop: binary_operation -> rexpr -> rexpr -> type  -> rexpr
  | Ecast: rexpr -> type  -> rexpr
  | Efield: rexpr -> ident -> type  -> rexpr
  | Esizeof: type -> type  -> rexpr
  | Ealignof: type -> type  -> rexpr
  (* conditional (boolean) -> if expr -> else expr -> type of exprs -> rexpr *)
  | Eif_then_else: rexpr -> rexpr -> rexpr -> type -> rexpr
  (* check if null ptr. this ought to be a fn call but I need to move that to an expression first *)
  (* it's fine to special case for now. *)
  | Enull_check: rexpr -> rexpr.

Definition r_typeof (e: rexpr) : type :=
  match e with
  | Econst_int _ ty => ty
  | Econst_float _ ty => ty
  | Econst_single _ ty => ty
  | Econst_long _ ty => ty
  | Evar _ ty => ty
  | Etempvar _ ty => ty
  | Ederef _ ty => ty
  | Eaddrof _ ty => ty
  | Eunop _ _ ty => ty
  | Ebinop _ _ _ ty => ty
  | Ecast _ ty => ty
  | Efield _ _ ty => ty
  | Esizeof _ ty => ty
  | Ealignof _ ty => ty
  | Eif_then_else _ _ _ ty => ty
  | Enull_check _ => Ctypes.Tint Ctypes.IBool Signed noattr
  end.

Definition void_pointer_int (ty: Ctypes.type) := Econst_int (Int.repr 0) ty.
(* Definition void_pointer (ty: Ctypes.type) := Eaddr_of () (Ctypes.Tpointer Ctypes.Tvoid noattr) *)

(* output type of ! *)
Definition bang_type := Ctypes.Tint I32 Signed Ctypes.noattr.
Definition bang_type_unsigned := Ctypes.Tint I32 Unsigned Ctypes.noattr.
Definition cond_type := Ctypes.Tint IBool Unsigned Ctypes.noattr.



Locate unary_operation.

Search binary_operation.

Print tt.

Definition check_attr (ty: Ctypes.attr) : res (unit) :=
  match ty.(attr_volatile) with
  | false => OK(tt)
  | true => Error(msg "unsupported attribute volatile")
  end.

Print Ctypes.type.

(* checks if the type is supported. *)
(* we dont' support volatile right now *)
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

Record r_calling_convention : Type := mkcallconv { cc_structret: bool }.

(* TODO rename to be consistent *)
(* TODO we might need another IR, but we really need to move everything
   or almost everything here from a statement to an expression
   to be faithful to rust's grammar. *)
Inductive rstatement: Type :=
  | S_skip : rstatement
  (* no let. That is a = b; *)
  | S_assign : rexpr -> rexpr -> rstatement
  (* a = b;*)
  | S_set : ident -> rexpr -> rstatement
  (* assigned_var_name -> fn_name -> args -> statement *)
  | S_call: option ident -> rexpr -> list rexpr -> rstatement
  | S_exit: rexpr -> rstatement
  | S_builtin: option ident -> external_function -> typelist -> list rexpr -> rstatement
  | S_sequence : rstatement -> rstatement -> rstatement
  | S_if_then_else : rexpr  -> rstatement -> rstatement -> rstatement
  | S_loop: option Z -> rstatement -> rstatement -> rstatement
  | S_break : option Z -> rstatement
  | S_continue : option Z -> rstatement
  (* maybe (expression expected type of expression) -> stmt *)
  | S_return : option (rexpr * type) -> rstatement
  (* match statements are very limited in scope *)
  (* we only match on ints *)
  (* and we assign to nothing *)
  | S_match_int : rexpr -> labeled_rstatements -> rstatement
with labeled_rstatements : Type :=
  | LSnil: labeled_rstatements
  | LScons: Z -> rstatement -> labeled_rstatements -> labeled_rstatements.


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
  fn_body: rstatement;
  (* the external symbols that are used*)
  (* we use this in printing exports*)
  fn_imports: PTree.t unit;

  fn_is_safe: bool;
}.


Definition type_to_string (ty: type) : string :=
  match ty with
  | Ctypes.Tlong _ _=> "Tlong"
  | Ctypes.Tint _ _ _=> "Tint"
  | Ctypes.Tfloat _ _ => "Tfloat"
  | Ctypes.Tpointer _ _ => "Tpointer"
  | Ctypes.Tvoid => "Tvoid"
  | Ctypes.Tarray _ _ _ => "Tarray"
  | Ctypes.Tfunction _ _ _ => "Tfunction"
  | Ctypes.Tstruct _ _ => "Tstruct"
  | Ctypes.Tunion _ _ => "Tunion"
  end
  .

Inductive needs_coersion : Type :=
  (* cast on first expression, overall type *)
  | NC_first : (rexpr -> SimplExpr.mon rexpr) -> type -> needs_coersion
  (* cast on second expression, overall type *)
  | NC_second : (rexpr -> SimplExpr.mon rexpr) -> type -> needs_coersion
  | NC_neither : type -> needs_coersion
  | NC_both : (rexpr -> SimplExpr.mon rexpr) -> (rexpr -> SimplExpr.mon rexpr) -> type -> needs_coersion
  .





Definition gen_zero_const (ty: type) : res rexpr :=
  match ty with
  | Ctypes.Tlong _ _ => OK(Econst_long (Int64.repr 0) ty)
  | Ctypes.Tint _ _ _ => OK(Econst_int (Int.repr 0) ty)
  | Ctypes.Tfloat Ctypes.F64 _ => OK(Econst_float (Bits.b64_of_bits 0%Z) ty)
  | Ctypes.Tfloat Ctypes.F32 _ => OK(Econst_single (Bits.b32_of_bits 0%Z) ty)
  (* TODO not immediately needed but should add in null pointer*)
  | ty => Error (msg (String.append "Encountered unexpected type that has no zero constant" (type_to_string ty)))
  end
  .

Definition gen_cast_for_conditional
  (expr: rexpr)
  : SimplExpr.mon rexpr
  :=
  let ty := r_typeof expr in
  match ty with
  | Ctypes.Tlong _ _ =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop Ogt expr zero_const cond_type)
  (* do nothing here *)
  | Ctypes.Tint Ctypes.IBool _ _ =>
      SimplExpr.ret (expr)
  (* we need to translate from an integer to a boolean *)
  | Ctypes.Tint _ _ _attrs  =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop Ogt expr zero_const cond_type)
  | Ctypes.Tfloat Ctypes.F64 _attrs  =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop Ogt expr zero_const cond_type)
  | Ctypes.Tfloat Ctypes.F32 _attrs  =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop Ogt expr zero_const cond_type)
  | Ctypes.Tpointer ty _attrs  =>
      SimplExpr.ret (Enull_check expr)
  (* | Ctypes. *)
  | ty => SimplExpr.error (msg (String.append " Expected scalar or pointer type in condition. Got unexpected type: " (type_to_string ty)))
  end.

(* this does general type coersions*)
Definition i2etc
  (cur_type: type)
  (desired_type: type)
  (expr: rexpr)
  : SimplExpr.mon rexpr
  :=
  match (cur_type, desired_type) with
  | (Ctypes.Tint IBool _ _, Ctypes.Tint IBool _ _) => SimplExpr.ret expr
  | (Ctypes.Tint I8 Signed _, Ctypes.Tint I8 Signed _) => SimplExpr.ret expr
  | (Ctypes.Tint I8 Unsigned _, Ctypes.Tint I8 Unsigned _) => SimplExpr.ret expr
  | (Ctypes.Tint I16 Signed _, Ctypes.Tint I16 Signed _) => SimplExpr.ret expr
  | (Ctypes.Tint I16 Unsigned _, Ctypes.Tint I16 Unsigned _) => SimplExpr.ret expr
  | (Ctypes.Tint I32 Signed _, Ctypes.Tint I32 Signed _) => SimplExpr.ret expr
  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tint I32 Unsigned _) => SimplExpr.ret expr
  | (Ctypes.Tlong Unsigned _, Ctypes.Tlong Unsigned _) => SimplExpr.ret expr
  | (Ctypes.Tlong Signed _, Ctypes.Tlong Signed _) => SimplExpr.ret expr
  | (Ctypes.Tfloat F32 _, Ctypes.Tfloat F32 _) => SimplExpr.ret expr
  | (Ctypes.Tfloat F64 _, Ctypes.Tfloat F64 _) => SimplExpr.ret expr

  | (_, Ctypes.Tint IBool _ _) => gen_cast_for_conditional expr
  (* TODO may need to cast through some other types*)
  | (_, _) => SimplExpr.ret (Ecast expr desired_type)
  end.

(* there's a little bit of overlap with implicit_to_explicit_type_conversion *)
(* but fundamentally this decides what type coersion needs to be done *)
(* note: I can't just get away with using the resulting type and casting to that. *)
(*       this doesn't work for comparators like >= because a >= b where a is a float
         and b is a unsigned char requires promoting b to a float, then returning an int.
         I can't just cast a and b to ints. *)
Definition do_binop_coersion (t1: type) (t2: type) : needs_coersion :=
  let neither := NC_neither t1 in
  let first_to_second := NC_first (i2etc t1 t2) t2 in
  let second_to_first := NC_second (i2etc t2 t1) t1 in
  let both_to_int := NC_both (i2etc t1 bang_type) (i2etc t2 bang_type) bang_type in
  let first_through_int :=
      NC_first (fun expr => gdo exp1 <- i2etc t1 bang_type expr; i2etc bang_type t2 exp1) t2 in
  let second_through_int :=
      NC_second (fun expr => gdo exp1 <- i2etc t2 bang_type expr; i2etc bang_type t1 exp1 ) t1 in

  match (t1, t2) with
  (* same types do nothing *)
  | (Ctypes.Tint IBool _ _, Ctypes.Tint IBool _ _) =>   neither
  | (Ctypes.Tint I8 Signed _, Ctypes.Tint I8 Signed _) =>   neither
  | (Ctypes.Tint I8 Unsigned _, Ctypes.Tint I8 Unsigned _) =>   neither
  | (Ctypes.Tint I16 Signed _, Ctypes.Tint I16 Signed _) =>   neither
  | (Ctypes.Tint I16 Unsigned _, Ctypes.Tint I16 Unsigned _) =>   neither
  | (Ctypes.Tint I32 Signed _, Ctypes.Tint I32 Signed _) =>   neither
  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tint I32 Unsigned _) =>   neither
  | (Ctypes.Tlong Unsigned _, Ctypes.Tlong Unsigned _) =>   neither
  | (Ctypes.Tlong Signed _, Ctypes.Tlong Signed _) =>   neither
  | (Ctypes.Tfloat F32 _, Ctypes.Tfloat F32 _) =>   neither
  | (Ctypes.Tfloat F64 _, Ctypes.Tfloat F64 _) =>   neither

  (* btwn integers *)

  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tint I32 Signed _) => second_to_first
  | (Ctypes.Tint I32 Signed _, Ctypes.Tint I32 Unsigned _) => first_to_second
  | (Ctypes.Tint _ _ _, Ctypes.Tint I32 Signed _) => first_to_second
  | (Ctypes.Tint _ _ _, Ctypes.Tint I32 Unsigned _) => first_through_int

  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tint _ _ _) => second_through_int
  | (Ctypes.Tint I32 Signed _, Ctypes.Tint _ _ _) => second_to_first
  | (Ctypes.Tint _ _ _, Ctypes.Tint _ _ _) => both_to_int

  (* int <-> float *)
  | (Ctypes.Tint I32 _ _, Ctypes.Tfloat F32 _) => first_to_second
  | (Ctypes.Tint _ _ _, Ctypes.Tfloat F32 _) => first_through_int

  | (Ctypes.Tfloat F32 _, Ctypes.Tint I32 Unsigned _) => second_to_first
  | (Ctypes.Tfloat F32 _, Ctypes.Tint I32 Signed _) => second_to_first
  | (Ctypes.Tfloat F32 _, Ctypes.Tint _ _ _) => second_through_int

  (* float <-> double *)
  | (Ctypes.Tfloat F32 _, Ctypes.Tfloat F64 _) => first_to_second
  | (Ctypes.Tfloat F64 _, Ctypes.Tfloat F32 _) => second_to_first

  (* int <-> double *)
  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tfloat F64 _) => first_to_second
  | (Ctypes.Tint I32 Signed _, Ctypes.Tfloat F64 _) => first_to_second
  | (Ctypes.Tint _ _ _, Ctypes.Tfloat F64 _) => first_through_int

  | (Ctypes.Tfloat F64 _, Ctypes.Tint I32 Unsigned _) => second_to_first
  | (Ctypes.Tfloat F64 _, Ctypes.Tint I32 Signed _) => second_to_first
  | (Ctypes.Tfloat F64 _, Ctypes.Tint _ _ _) => second_through_int

  (* int <-> long *)
  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tlong _ _) => first_to_second
  | (Ctypes.Tint I32 Signed _, Ctypes.Tlong _ _) => first_to_second
  | (Ctypes.Tint _ _ _, Ctypes.Tlong _ _) => first_through_int

  | (Ctypes.Tlong _ _, Ctypes.Tint I32 Unsigned _) => second_to_first
  | (Ctypes.Tlong _ _, Ctypes.Tint I32 Signed _) => second_to_first
  | (Ctypes.Tlong _ _, Ctypes.Tint _ _ _) => second_through_int

  (* float and double <-> long *)
  | (Ctypes.Tlong _ _, Ctypes.Tfloat _ _) => first_to_second
  | (Ctypes.Tfloat _ _, Ctypes.Tlong _ _) => second_to_first
  | (_, _) => NC_neither t1

  (* array <-> pointer *)

  (* | (Tarray _ _ _, Tint _ _ _) => neither *)
  end.

(* TODO special case array derefences*)
Fixpoint transl_expr (ce: composite_env) (a: Clight.expr) {struct a} : SimplExpr.mon (rexpr) :=
  match a with
  | Clight.Econst_int n ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret (Econst_int n ty)
  | Clight.Econst_float n ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret(Econst_float n ty)
  | Clight.Econst_single n ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret(Econst_single n ty)
  | Clight.Econst_long n ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret(Econst_long n ty)
  | Clight.Evar id ty =>
      gdom _ <- check_ty ty;
      let res := Evar id ty in
      match ty with
      | Tarray ty' _ a => Ecast res (Tpointer ty' a)
      | _ => res
      end |>
      SimplExpr.ret
  | Clight.Etempvar id ty =>
      gdom _ <- check_ty ty;
      let res := Etempvar id ty in
      match ty with
      | Tarray ty' _ a => Ecast res (Tpointer ty' a)
      | _ => res
      end |>
      SimplExpr.ret
  | Clight.Ederef b ty =>
      gdom _ <- check_ty ty;
      gdo tb <- transl_expr ce b;
      SimplExpr.ret(Ederef tb ty)
  | Clight.Eaddrof b ty =>
      gdom _ <- check_ty ty;
      gdo tb <- transl_expr ce b;
      SimplExpr.ret(Eaddrof tb ty)
  | Clight.Eunop op exp ty =>
      gdom _ <- check_ty ty;
      let exp_typ := Clight.typeof exp in
      gdo translated_exp <- transl_expr ce exp;
      (* have to expand bool cast to if else statement *)
      match op with
      (* the ! operator maps scalar and pointer types to the int type. *)
      | Onotbool =>
          match exp_typ with
          | Ctypes.Tint _ _ _ =>
          (
          (* this is supposed to return int. int must be >= 16 bits according to c99 *)
          (* however in C2C.ml, C.IInt is 32bit width, so we use that here too. *)
          (* TODO I'm assuming we don't care about attributes. *)
          (*      But, I couldn't find anything in the c99 spec about this *)
            let r_ty := bang_type in
            let conditional := Ebinop Ogt translated_exp (Econst_int (Int.repr 0) exp_typ) cond_type in
            let if_expr := Econst_int (Int.repr 1)  bang_type in
            let else_expr := Econst_int (Int.repr 0 ) bang_type in
            SimplExpr.ret( Eif_then_else conditional if_expr else_expr r_ty)
          )
          | Ctypes.Tlong _ _ => (
            (* TODO separate out into function. It's the same exact code. *)
            let r_ty := bang_type in
            let conditional := Ebinop Ogt translated_exp (Econst_int (Int.repr 0) exp_typ) cond_type in
            let if_expr := Econst_int (Int.repr 1)  cond_type in
            let else_expr := Econst_int (Int.repr 0 ) cond_type in
            SimplExpr.ret( Eif_then_else conditional if_expr else_expr r_ty)
          )
          | Ctypes.Tfloat Ctypes.F64 _ => (
            (* TODO separate out into function or something. It's the same exact code varying only by float. *)
            let r_ty := bang_type in
            let conditional := Ebinop Ogt translated_exp (Econst_float (Bits.b64_of_bits 0%Z) exp_typ) cond_type in
            let if_expr := Econst_int (Int.repr 1)  cond_type in
            let else_expr := Econst_int (Int.repr 0 ) cond_type in
            SimplExpr.ret( Eif_then_else conditional if_expr else_expr r_ty)
          )
          | Ctypes.Tfloat Ctypes.F32 _ => (
            (* TODO separate out into function or something. It's the same exact code varying only by float. *)
            let r_ty := bang_type in
            let conditional := Ebinop Ogt translated_exp (Econst_single (Bits.b32_of_bits 0%Z) exp_typ) cond_type in
            let if_expr := Econst_int (Int.repr 1)  cond_type in
            let else_expr := Econst_int (Int.repr 0 ) cond_type in
            SimplExpr.ret( Eif_then_else conditional if_expr else_expr r_ty)
          )
          | Ctypes.Tpointer _ _ => (
            let r_ty := bang_type in
            let conditional := Enull_check translated_exp in
            let if_expr := Econst_int (Int.repr 1)  cond_type in
            let else_expr := Econst_int (Int.repr 0 ) cond_type in
            SimplExpr.ret( Eif_then_else conditional if_expr else_expr r_ty)
          )
          (* TODO consider the array type *)
          | _ => SimplExpr.error( msg "invalid type passed into ! expression. Expected scalar or pointer type.")
          (* TODO how are arrays handled*)
          end
      (* ) *)
      | _ => SimplExpr.ret(Eunop op translated_exp ty)
      end
  | Clight.Ebinop op exp1 exp2 ty =>
      gdom _ <- check_ty ty;
      gdo rexp1 <- transl_expr ce exp1;
      gdo rexp2 <- transl_expr ce exp2;
      gdo (c_rexp1, c_rexp2, rty) <-
        match do_binop_coersion (r_typeof rexp1) (r_typeof rexp2) with
        | NC_first f rty =>
            gdo res <- f rexp1;
            SimplExpr.ret(res, rexp2, rty)
        | NC_second f rty =>
            gdo res <- f rexp2;
            SimplExpr.ret(rexp1, res, rty)
        | NC_neither rty => SimplExpr.ret(rexp1, rexp2, rty)
        | NC_both f g rty =>
            gdo res1 <- f rexp1;
            gdo res2 <- g rexp2;
            SimplExpr.ret(res1, res2, rty)
        end;
      let needs_mapping_to_int :=
      match op with
        | Olt => true
        | Ogt => true
        | Ole => true
        | Oge => true
        | Oeq => true
        | One => true
        | _ => false
      end in
      if needs_mapping_to_int then
        (
        let conditional := Ebinop op c_rexp1
                             c_rexp2 cond_type in
        let if_expr := Econst_int (Int.repr 1) bang_type in
        let else_expr := Econst_int (Int.repr 0) bang_type in
        let final_binop := Eif_then_else conditional if_expr else_expr bang_type in
        i2etc bang_type ty final_binop
        (* TODO I'm pretty sure the resulting expression after the binop may need to be coerced*)
        )
      else
        let final_binop := Ebinop op c_rexp1 c_rexp2 rty in
        i2etc (r_typeof final_binop) (ty) final_binop
  | Clight.Ecast exp ty =>
      gdom _ <- check_ty ty;
      gdo rexp <- transl_expr ce exp;

      match ty with
      | Ctypes.Tint IBool _ _ =>
          let cur_ty := r_typeof rexp in
          gdom zero_const <- gen_zero_const cur_ty;
          SimplExpr.ret(Ebinop Ogt rexp zero_const ty)
      | _ => SimplExpr.ret(Ecast rexp ty)
      end
  | Clight.Efield exp ident ty =>
      gdom _ <- check_ty ty;
      gdo rexp <- transl_expr ce exp;
      SimplExpr.ret(Efield rexp ident ty)
  | Clight.Esizeof ty' ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret(Esizeof ty' ty)
  | Clight.Ealignof ty' ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret(Ealignof ty' ty)
  end.

Print SimplExpr.transl_stmt.

Record s_md : Type :=
  mk_s_md {
      get_var_type: ident -> res type;
      ce: composite_env;
      tyret: type;
      nbrk: nat;
      ncnt: nat;
      cur_loop_lbl: option Z;
      cur_switch_lbl: option Z;
      next_lbl: option Z;
      (* return type of the function *)
      f_rty: type;
    }.

Print ce.



Locate int.

Fixpoint transl_arglist
  (ce: composite_env)
  (al: list Clight.expr)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      gdo arg <- transl_expr ce a1 ;
      gdo args <- transl_arglist ce a2 ;
      SimplExpr.ret(arg :: args)
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
      f_rty := f_rty;
      get_var_type := get_var_type;
    |} =>
    match s with
    | Clight.Sskip => SimplExpr.ret (S_skip)
    | Clight.Sassign lval rval =>
        (* gdo r_val <- *)
          gdo r_lval <- transl_expr ce lval;
          gdo r_rval <- transl_expr ce rval;
          gdo coerced_type <- i2etc (r_typeof r_rval) (r_typeof r_lval) (r_rval) ;
          (* sometimes the types do not match *)
          SimplExpr.ret (S_assign r_lval coerced_type)
        (* SimplExpr.ret r_val *)
    | Clight.Sifthenelse exp s1 s2 =>
        gdo cond <- transl_expr ce exp;
        gdo casted_cond <- gen_cast_for_conditional cond;
        gdo r_s1 <- transl_statement md s1;
        gdo r_s2 <- transl_statement md s2;
        SimplExpr.ret (S_if_then_else casted_cond r_s1 r_s2)
    | Clight.Sset x exp =>
        gdo r_exp <- transl_expr ce exp;
        gdom expected_type <- get_var_type x;
        gdo casted_exp <- i2etc (r_typeof r_exp) expected_type r_exp ;
        SimplExpr.ret (S_set x casted_exp)
    | Clight.Ssequence exp1 exp2 =>
        gdo r_exp1 <- transl_statement md exp1;
        gdo r_exp2 <- transl_statement md exp2;
        SimplExpr.ret (S_sequence r_exp1 r_exp2)
    | Clight.Sreturn None => SimplExpr.ret (S_return None)
    | Clight.Sreturn (Some exp) =>
        let exp_ty := Clight.typeof exp in
        gdo r_exp <- transl_expr ce exp;
        gdo casted_exp <- i2etc exp_ty f_rty r_exp ;
        SimplExpr.ret (S_return (Some (casted_exp, exp_ty)))
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
      gdo r_exp <- transl_expr ce exp ;
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
          f_rty := f_rty;
          get_var_type := get_var_type;
        |} in

      gdo (dflt_case_inner_stmt, labeled_match_stmts) <-
        transl_switch u_s_md stmts exp_ident_as_exp exp_typ dflt_ident_as_exp dflt_case_ty S_skip LSnil ;

      let match_stmt := S_match_int exp_ident_as_exp labeled_match_stmts in

      let if_dflt_stmt := S_if_then_else (dflt_ident_as_exp) dflt_case_inner_stmt S_skip in

      let loop_body := S_sequence if_dflt_stmt match_stmt in

      let new_loop := S_loop switch_loop_lbl loop_body S_skip in

      SimplExpr.ret (S_sequence (S_sequence dflt_case_decl exp_decl) new_loop)
    | Clight.Scall x name al =>
        gdo name' <- transl_expr ce name ;
        gdo al' <- transl_arglist ce al ;
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
            f_rty := f_rty;
            get_var_type := get_var_type;
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
      get_var_type := get_var_type;
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



Print type.

Locate globdef.
Print AST.globdef.
Print AST.globvar.
Print Ctypes.composite_definition.
Print ident.


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
                                 fn_imports := PTree.empty _;
                                 fn_is_safe := false;
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

Print rstatement.

Definition merge_trees (a: PTree.t unit) (b: PTree.t unit) : PTree.t unit :=
  PTree.fold (fun (acc: PTree.t unit) (id: ident) (_unit : unit) => PTree.set id tt acc) a b.

  (* get ids tree 1*)
  (* get ids tree 2*)
  (* map them into new tree *)

Fixpoint walk_r_expr_for_symbols (in_scope_syms: PTree.t unit) (expr: rexpr) : PTree.t unit :=
  let walk_r_expr := walk_r_expr_for_symbols in_scope_syms in
  match expr with
    | Evar id _ =>
        match PTree.get id in_scope_syms with
        | None => PTree.set id tt (PTree.empty _)
        | Some tt => PTree.empty _
        end
    | Ederef exp _ => walk_r_expr exp
    | Eaddrof exp _ => walk_r_expr exp
    | Eunop _ exp _ => walk_r_expr exp
    | Ebinop _ exp1 exp2 _ty => merge_trees (walk_r_expr exp1) (walk_r_expr exp2)
    | Ecast exp _ty => walk_r_expr exp
    | Efield exp _id _ty => walk_r_expr exp
    | _ => PTree.empty _
  end.

Fixpoint handle_exprs (in_scope_syms: PTree.t unit) (stmts: list rexpr) : PTree.t unit :=
  match stmts with
  | nil => PTree.empty _
  | a :: b => merge_trees (walk_r_expr_for_symbols in_scope_syms a) (handle_exprs in_scope_syms b)
  end.

Locate PTree.


(* TODO instead of doing all this symbol pushing I can simply *)
(* use ce.genv_defs to check symbol defns when constructing this *)
(* TODO rename *)
Fixpoint walk_r_body_for_symbols (in_scope_syms: PTree.t unit) (stmt: rstatement) : PTree.t unit :=
  let walk_r_expr := walk_r_expr_for_symbols in_scope_syms in
  let walk_r_stmt := walk_r_body_for_symbols in_scope_syms in
  match stmt with
  | S_skip => PTree.empty _
  | S_assign rexpr_1 rexpr_2 => merge_trees (walk_r_expr rexpr_1) (walk_r_expr rexpr_2)
  | S_set _ rexpr => (walk_r_expr rexpr)
  | S_sequence s_1 s_2 => merge_trees (walk_r_stmt s_1) (walk_r_stmt s_2)
  | S_continue _ => PTree.empty _
  | S_loop _ s_1 s_2 => merge_trees (walk_r_stmt s_1) (walk_r_stmt s_2)
  | S_match_int rexpr ls =>
      merge_trees (walk_r_expr rexpr) (handle_ls_stmt in_scope_syms (ls))
  | S_builtin _ _ _ _ => PTree.empty _
  | S_if_then_else rexpr rstmt_1 rstmt_2 => merge_trees (merge_trees (walk_r_expr rexpr) (walk_r_stmt rstmt_1)) (walk_r_stmt rstmt_2)
  | S_break _int => PTree.empty _
  | S_return maybe_rexpr =>
      match maybe_rexpr with
      | Some (rexpr, _ty) => (walk_r_expr rexpr)
      | None => PTree.empty _
      end
  (* TODO think about shadowing. Might need to ensure there's no other variable, but can easily do this with function metadata *)
  (* TODO this is possible in the case of a function pointer in which case we don't need to import anything *)
  | S_call _ r_expr l_rexpr => merge_trees (handle_exprs in_scope_syms l_rexpr) (walk_r_expr r_expr)
  | S_exit r_expr => walk_r_expr r_expr
  end
with handle_ls_stmt (in_scope_syms: PTree.t unit) (ls: labeled_rstatements) : PTree.t unit :=
  match ls with
  | LSnil => PTree.empty _
  | LScons _ rstatement ls => merge_trees (walk_r_body_for_symbols in_scope_syms rstatement) (handle_ls_stmt in_scope_syms ls)
  end.


Locate map.

(* three things are done here: *)
(* - implement union for hashsets *)
(* - return a tree everywhere instead of a list *)
(* - change funciton type to ptree.t unit *)

Definition transl_internal_fun (ce: composite_env) (f: Clight.function) (glob_syms: list ident) : res r_function :=
  let return_type := (Clight.fn_return f) in
  let generator := reconstruct_generator f.(Clight.fn_temps) in
  let get_ty_of_var :=
    (fun (x: ident) =>
     let search_fn  := (fun acc p => if ident_eq (fst p) x then OK(snd p) else acc) in
     List.fold_left
                search_fn
                (f.(Clight.fn_params) ++  (f.(Clight.fn_vars)) ++ f.(Clight.fn_temps))
                (* TODO this does NOT handle global symbols. I need to worry about those by (1) propagating their type and (2) including them here. .*)
                (* name is not sufficient*)
                (Error(msg "Could not find variable referenced!"))
    ) in
  let smd := {|
              ce := ce;
              tyret := return_type;
              nbrk := 1%nat;
              ncnt := 0%nat;
              cur_loop_lbl := None;
              cur_switch_lbl := None;
              next_lbl := None;
              f_rty := return_type;
              get_var_type := get_ty_of_var;
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
          let in_scope_symbols := (map fst f.(Clight.fn_vars)) ++ glob_syms in
          let in_scope_symbols_tree := fold_left (fun (acc : PTree.t unit) (elt: ident) => PTree.set elt tt acc) in_scope_symbols (PTree.empty _) in
          OK({|
                fn_return := return_type;
                fn_callconv := {| cc_structret := (AST.cc_structret cc) |};
                fn_params := f.(Clight.fn_params);
                fn_vars := f.(Clight.fn_vars);
                fn_temps := r_g.(SimplExpr.gen_trail);
                fn_body := r_body;
                fn_imports := (walk_r_body_for_symbols in_scope_symbols_tree r_body);
                fn_is_safe := false;
              |})
      end
  end.

(* TODO forget external functions now. We don't care about them. *)
Definition transl_fundef (ce: composite_env) (glob_syms: list ident) (id: ident) (fn : Clight.fundef) : res r_fundef :=
  match fn with
    | Ctypes.Internal f =>
        do r_f <- transl_internal_fun ce f glob_syms;
        OK(Ctypes.Internal r_f)
    | Ctypes.External a b c d => OK(Ctypes.External a b c d)
  end.



Print transform_partial_program2.

Print AST.transf_globdefs.

Print Ctypes.program.

(* what Im going to do for types (struct, union) *)
(* prog_types are file local types *)
(* prog_types are file local types, so add those to global_symbols *)
(* look through the types in the walk
   and add them to the tree if they're not in global_symbols
*)

(* TODO this entire thing is morally wrong. This doesn't exist in C. Reasons why:*)
(* - main returns the never type
   -
 *)

(*
  for now we patch:
  - special case "main" to not return anything (implicitly return never type)
  - exit
  - pass in function on the end
*)

Definition gen_new_main'
  (old_main: globdef (Ctypes.fundef Clight.function) type)
  (old_main_ident: ident)
  (new_main_ident: ident)
  : res (globdef (Ctypes.fundef r_function) type) :=
  match old_main with
  | Gfun (Ctypes.Internal (old_main_fn)) => (
    let generator := reconstruct_generator nil in
    let exit_ty := old_main_fn.(Clight.fn_return) in
    do exit_ident <-
         match SimplExpr.gensym exit_ty generator with
         | SimplExpr.Err msg => Error msg
         | SimplExpr.Res r_body r_g i => OK(r_body)
         end ;
    let exit_fn_var := Evar old_main_ident exit_ty in
    let exit_fn_args := map (fun x => Evar (fst x) (snd x)) old_main_fn.(Clight.fn_params) in
    let s1 := S_call (Some exit_ident) exit_fn_var exit_fn_args in
    let s2 := S_exit (Etempvar exit_ident exit_ty) in

    OK(Gfun (
        Ctypes.Internal (
              mkrfunction
                Ctypes.Tvoid
                {| cc_structret := (AST.cc_structret (old_main_fn.(Clight.fn_callconv))); |}
                old_main_fn.(Clight.fn_params)
                nil
                (cons (exit_ident, exit_ty) nil)
                (S_sequence s1 s2)
                (PTree.empty _)
                true
              )

        ))
       )
  | _ => Error(msg "Incorrect type for main function")
  end.

Print cons.

Definition transl_program (c_prog: Clight.program) : res (r_program) :=
  (* symbols that we know to be in scope already *)
  let global_symbols :=
    map fst (filter (fun (prog_symbols: (_ * globdef (Ctypes.fundef Clight.function) type)) =>
       match (snd prog_symbols) with
       | Gfun (Ctypes.Internal _) => true
       | Gvar v => true
       | _ => false
       end)
     c_prog.(Ctypes.prog_defs)) in

  (* get the main replacement ident. *)
  let new_main_ident := SimplExpr.first_unused_ident tt in
  let old_main_ident := c_prog.(Ctypes.prog_main) in
  let old_main_fn := find (fun x => AST.ident_eq (fst x) old_main_ident)
                            (Ctypes.prog_defs c_prog) in

  match old_main_fn with
  | Some(omf) => (

      (* do new_main <- gen_new_main (snd omf) c_prog.(prog_main) (new_main_ident); *)
      do new_main <- gen_new_main' (snd omf) c_prog.(prog_main) (new_main_ident) ;


      (* TODO need to evalualte the initialization expression in case it involves say taking an address of a gloval variable from another file *)
      (* low priority *)
      do translated_fns  <-
          AST.transf_globdefs
            (transl_fundef c_prog.(prog_comp_env) global_symbols)
            transl_globvar
            (* (cons (new_main_ident, new_main) c_prog.(prog_defs)); *)
            c_prog.(prog_defs);
      let r_prog : r_program :=
        {|
          (* PUBLIC only fns *)
          Ctypes.prog_defs := cons (new_main_ident, new_main) translated_fns;
          Ctypes.prog_public := c_prog.(prog_public);
          Ctypes.prog_main := new_main_ident;
          Ctypes.prog_types := c_prog.(prog_types);
          Ctypes.prog_comp_env := c_prog.(prog_comp_env);
          Ctypes.prog_comp_env_eq := c_prog.(prog_comp_env_eq);
        |} in

      OK(r_prog)

  )
  | None => (
    Error(msg "Main function not found?")

  )
  end.
