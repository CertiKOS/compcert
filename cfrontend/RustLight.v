Require Import Ctypes.
Require Import ZArith.
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

(* Require Import FSets. *)
(* Require Import FMaps. *)


Print Ctypes.prog_public.

Module PositiveSet <: FSets.FSetInterface.S := FSets.FSetPositive.PositiveSet.
Print Module PositiveSet.
Print PositiveSet.elt.

Require Import Coq.Strings.String.
Require Import Coq.Structures.OrderedTypeEx.  (* For String_as_OT *)
Require Import Coq.FSets.FMapList.
Module StrMap := Coq.FSets.FMapList.Make(String_as_OT).
Print StrMap.
Definition str_map_globals := StrMap.t string.
Definition str_map_composites := StrMap.t (option (string * Ctypes.composite_definition)).




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

(* Notation "x |> f" := (f x) (at level 50, left associativity). *)


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
Locate unary_operation.
Print unary_operation.



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
  (* | Eif_then_else: rexpr -> rexpr -> rexpr -> type -> rexpr *)
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
  | Enull_check _ => Ctypes.Tint Ctypes.IBool Signed noattr
  end.

Print sum.


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

(* I'm keeping this around if in the future we wish to support
   multiple calling conventions. But for now, we only support one (SYSV) *)
Record r_calling_convention : Type := mkcallconv { cc_structret: bool }.

(* TODO rename to be consistent *)
(* TODO we might need another IR, but we really need to move everything
   or almost everything here from a statement to an expression
   to be faithful to rust's grammar. *)
Inductive rstatement: Type :=
  | S_skip : rstatement
  (* no let. That is a = b; *)
  | S_assign : rexpr -> rexpr -> rstatement
  (* a = b; ONLY for tempvars *)
  | S_set : ident -> rexpr -> rstatement
  (* assigned_var_name -> fn_name -> args -> statement *)
  | S_call: option ident -> rexpr -> list rexpr -> rstatement
  | S_exit: rexpr -> rstatement
  | S_builtin: option ident -> external_function -> typelist -> list rexpr -> rstatement
  | S_sequence : rstatement -> rstatement -> rstatement
  | S_if_then_else : rexpr  -> rstatement -> rstatement -> rstatement
  | S_loop: option Z -> rstatement -> rstatement -> rstatement
  (* outer lbl -> inner lbl -> block 1 -> block 2*)
  (* loop 'outer_lbl {loop 'inner_lbl {block 1; break; } block 2} *)
  (* TODO rm option *)
  | S_loop2: option Z -> option Z -> rstatement -> rstatement -> rstatement
  | S_break : option Z -> rstatement
  | S_continue : option Z -> rstatement
  (* maybe (expression expected type of expression) -> stmt *)
  | S_return : option (rexpr * type) -> rstatement
  (* match statements are very limited in scope *)
  (* we only match on ints *)
  (* and we assign to nothing *)
  | S_match_int : rexpr -> labeled_rstatements -> rstatement
with labeled_rstatements : Type :=
  | LSnil: rstatement -> labeled_rstatements
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
  fn_imports: PositiveSet.t;

  (* TODO not used, get rid of it *)
  fn_is_safe: bool;
}.

Print sum.

(* we are being very conservative here. That's fine. *)
Definition expr_should_be_split (e: rexpr) : bool :=
  match e with
  | Econst_int n ty => true
  | Econst_float f ty => true
  | Econst_single f32 ty => true
  | Econst_long l ty => true
  | Evar id ty =>
      match ty with
      | Ctypes.Tfunction _ _ _=> true
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
Fixpoint split_expr (e: rexpr) {struct e} : SimplExpr.mon (sum rexpr ((rstatement) * rexpr)) :=
  (* TODO separate out into a function. so much repeated code... *)
  match e with
  | Econst_int n ty => SimplExpr.ret( inr (S_skip, e))
  | Econst_float f ty => SimplExpr.ret( inr (S_skip, e))
  | Econst_single f32 ty => SimplExpr.ret( inr (S_skip, e))
  | Econst_long l ty => SimplExpr.ret( inr (S_skip, e))
  | Evar id ty => SimplExpr.ret( inr (S_skip, e))
  | Etempvar id ty => SimplExpr.ret(  inr (S_skip, e))
  | Ederef e1 ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => SimplExpr.ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Ederef e_final ty) in
          SimplExpr.ret(res)
      end
  | Eunop op e1 ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => SimplExpr.ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Eunop op e_final ty) in
          SimplExpr.ret(res)
      end
  | Ebinop op e1 e2 ty =>
      gdo inner_split_1 <- split_expr e1;
      gdo inner_split_2 <- split_expr e2;
      match (inner_split_1, inner_split_2) with
      | (inl _, inl _) => SimplExpr.ret( inr (S_skip, e))
      | (inr (stmts, e_final1), inl _) =>
          let res := inr (stmts, Ebinop op e_final1 e2 ty) in
          SimplExpr.ret(res)
      | (inl _, inr (stmts, e_final2)) =>
          let res := inr (stmts, Ebinop op e1 e_final2 ty) in
          SimplExpr.ret(res)
      | (inr (stmts1, e_final1), inr (stmts2, e_final2)) =>
          let res := inr (S_sequence stmts1 stmts2, Ebinop op e_final1 e_final2 ty) in
          SimplExpr.ret(res)
      end

  | Ecast e1 ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => SimplExpr.ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Ecast e_final ty) in
          SimplExpr.ret(res)
      end
  | Efield e1 id ty =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => SimplExpr.ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Efield e_final id ty) in
          SimplExpr.ret(res)
      end
  | Esizeof t1 ty => SimplExpr.ret( inr (S_skip, e))
  | Ealignof t1 ty => SimplExpr.ret( inr (S_skip, e))
  (* | Eif_then_else cond e_then e_else ty => *)
  (*     gdo split_1 <- split_expr cond; *)
  (*     gdo split_2 <- split_expr e_then; *)
  (*     gdo split_3 <- split_expr e_else; *)
  (*     match (split_1, split_2, split_3) with *)
  (*     | (inl _, inl _, inl _) => SimplExpr.ret( inr (S_skip, e)) *)
  (*     | (inr (stmts1, e1), inl _, inl _) => *)
  (*         let res := inr (stmts1, Eif_then_else e1 e_then e_else ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     | (inl _, inr (stmts2, e2), inl _) => *)
  (*         let res := inr (stmts2, Eif_then_else cond e2 e_else ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     | (inl _, inl _, inr (stmts3, e3)) => *)
  (*         let res := inr (stmts3, Eif_then_else cond e_then e3 ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     | (inl _, inr (stmts2, e2), inr (stmts3, e3)) => *)
  (*         let res := inr (S_sequence stmts2 stmts3, Eif_then_else cond e2 e3 ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     | (inr (stmts1, e1), inl _, inr (stmts3, e3)) => *)
  (*         let res := inr (S_sequence stmts1 stmts3, Eif_then_else e1 e_then e3 ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     | (inr (stmts1, e1), inr (stmts2, e2), inl _) => *)
  (*         let res := inr (S_sequence stmts1 stmts2, Eif_then_else e1 e2 e_else ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     | (inr (stmts1, e1), inr (stmts2, e2), inr (stmts3, e3)) => *)
  (*         let res := inr (S_sequence stmts1 (S_sequence stmts2 stmts3), *)
  (*                        Eif_then_else e1 e2 e3 ty) in *)
  (*         SimplExpr.ret(res) *)
  (*     end *)
  | Enull_check e1 =>
      gdo inner_split <- split_expr e1;
      match inner_split with
      | inl _ => SimplExpr.ret( inr (S_skip, e))
      | inr (stmts, e_final) =>
          let res := inr (stmts, Enull_check e_final) in
          SimplExpr.ret(res)
      end
  | Eaddrof e1 ty_addrof =>
      if (expr_should_be_split e1) then
        let e1_ty := r_typeof e1 in
        gdo var_ident <- SimplExpr.gensym e1_ty;
        let var_expr := Etempvar var_ident e1_ty in
        gdo inner_split <- split_expr e1;

        match inner_split with
        (* Inner expression doesn't need to be assigned more. *)
        | inl _ =>

          let assn_stmt := S_set var_ident e1 in
          let res := (assn_stmt, Eaddrof var_expr ty_addrof) in
          SimplExpr.ret(inr res)
        | inr (inner_assns, e_inner_final) =>
          let assn_stmt := S_set var_ident e_inner_final in
          let assns := S_sequence inner_assns assn_stmt in
          let res := (assns, Eaddrof var_expr ty_addrof) in
          SimplExpr.ret(inr res)
        end
      (* turns out we don't need to split the expression *)
      else SimplExpr.ret (inl e)
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



Definition gen_zero_const_clight (ty: type) : res Clight.expr :=
  match ty with
  | Ctypes.Tlong _ _ => OK(Clight.Econst_long (Int64.repr 0) ty)
  | Ctypes.Tint _ _ _ => OK(Clight.Econst_int (Int.repr 0) ty)
  | Ctypes.Tfloat Ctypes.F64 _ => OK(Clight.Econst_float (Bits.b64_of_bits 0%Z) ty)
  | Ctypes.Tfloat Ctypes.F32 _ => OK(Clight.Econst_single (Bits.b32_of_bits 0%Z) ty)
  (* TODO not immediately needed but should add in null pointer*)
  | ty => Error (msg (String.append "Encountered unexpected type that has no zero constant" (type_to_string ty)))
  end
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
  (* TODO move zero_const up a level*)
  match ty with
  | Ctypes.Tlong _ _ =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop One expr zero_const cond_type)
  (* do nothing here *)
  | Ctypes.Tint Ctypes.IBool _ _ =>
      SimplExpr.ret (expr)
  (* we need to translate from an integer to a boolean *)
  | Ctypes.Tint _ _ _attrs  =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop One expr zero_const cond_type)
  | Ctypes.Tfloat Ctypes.F64 _attrs  =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop One expr zero_const cond_type)
  | Ctypes.Tfloat Ctypes.F32 _attrs  =>
      gdom zero_const <- gen_zero_const ty;
      SimplExpr.ret (Ebinop One expr zero_const cond_type)
  | Ctypes.Tpointer ty _attrs  =>
      SimplExpr.ret(Eunop Onotbool (Enull_check expr) cond_type)
      (* let r_ty := bang_type in *)
      (* gdom zero_const <- gen_zero_const r_ty; *)
      (* let if_expr := Econst_int (Int.repr 0)  r_ty in *)
      (* let else_expr := Econst_int (Int.repr 1 ) r_ty in *)
      (* SimplExpr.ret (Ebinop One (Eif_then_else (Enull_check expr) if_expr else_expr r_ty ) zero_const cond_type) *)
  (* | Ctypes. *)
  | ty => SimplExpr.error (msg (String.append " Expected scalar or pointer type in condition. Got unexpected type: " (type_to_string ty)))
  end.

Fixpoint i2etc_measure (t : type) : nat :=
  match t with
  | Ctypes.Tarray ty_from _ _ => 1 + (i2etc_measure ty_from)
  | _ => 0
  end.

Print type.

Definition is_fn_ptr (ty: type) : bool :=
  match ty with
  | Tpointer (Tfunction _ _ _) _ => true
  | _ => false
  end.

Fixpoint nuke_equalities (e: rexpr) : rexpr :=
  match e with
  | Econst_int _ _ => e
  | Econst_float _ _ => e
  | Econst_single _ _ => e
  | Econst_long _ _ => e
  | Evar _ _ => e
  | Etempvar _ _ => e
  | Ederef e' ty => Ederef (nuke_equalities e') ty
  | Eaddrof e' ty => Eaddrof (nuke_equalities e') ty
  | Eunop op e' ty => Eunop op (nuke_equalities e') ty
  | Ebinop op e' e'' ty => Ebinop op (nuke_equalities e') (nuke_equalities e'') ty
  | Ecast e' ty =>
      let not_fn_ptr := negb (is_fn_ptr ty) in
      let types_match := type_eq (r_typeof e') ty in
      if andb not_fn_ptr types_match then e' else e
  | Efield e' id ty => Efield (nuke_equalities e') id ty
  | Esizeof _ _ => e
  | Ealignof _ _ => e
  (* | Eif_then_else e' e'' e''' ty => *)
  (*     Eif_then_else (nuke_equalities e') (nuke_equalities e'') (nuke_equalities e''') ty *)
  | Enull_check e' => Enull_check (nuke_equalities e')
  end.

(* this does general type coersions*)
(* "implict to explicit type coersion" *)
Definition i2etc
  (cur_type: type)
  (desired_type: type)
  (expr: rexpr)
  (* {measure i2etc_measure cur_type} *)
  : SimplExpr.mon rexpr
  :=
  match (cur_type, desired_type) with

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
  | (Ctypes.Tint IBool _ a, Ctypes.Tfloat F32 _) =>
      SimplExpr.ret (Ecast (Ecast expr (Ctypes.Tint I8 Unsigned a)) desired_type)
  | (Ctypes.Tint IBool _ a, Ctypes.Tfloat F64 _) =>
      SimplExpr.ret (Ecast (Ecast expr (Ctypes.Tint I8 Unsigned a)) desired_type)
  (* handle pointer decay. In rust this is done by going from an array type to a pointer type *)
  (* this is the decay part *)
  (* then directly casting from the nested array type to a pointer type*)
  | (Ctypes.Tarray ty_from _len _attrs, Ctypes.Tpointer ty_to _attrs') =>
      let new_ty := Ctypes.Tpointer ty_from _attrs in
      let casted := Ecast expr new_ty in
      SimplExpr.ret(Ecast casted desired_type)
      (* i2etc new_ty desired_type casted *)
  | (a, b) =>
       SimplExpr.ret(Ecast expr desired_type)
  end.
(* Proof. *)
(*   intros cur_type desired_type expr ty_from _len _attrs teq ty_to _attrs' teq0. *)
(*   destruct (type_eq cur_type desired_type) eqn:E ; cbn; lia. *)
(* Qed. *)

(* Print i2etc_terminate. *)


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
  (* array <-> pointer *)

  (* TODO not dry *)
  (* TODO may need to also cast the float or whatever to integer *)
  | (Ctypes.Tarray ty_inner _num attr, Ctypes.Tfloat _ _) =>
      let target_ty := Ctypes.Tpointer ty_inner attr in
      NC_first (i2etc t1 target_ty) target_ty
  | (Ctypes.Tarray ty_inner _num attr, Ctypes.Tint _ _ _) =>
      let target_ty := Ctypes.Tpointer ty_inner attr in
      NC_first (i2etc t1 target_ty) target_ty
  | (Ctypes.Tarray ty_inner _num attr, Ctypes.Tlong _ _) =>
      let target_ty := Ctypes.Tpointer ty_inner attr in
      NC_first (i2etc t1 target_ty) target_ty

  | ( Ctypes.Tfloat _ _, Ctypes.Tarray ty_inner _num attr) =>
      let target_ty := Ctypes.Tpointer ty_inner attr in
      NC_second (i2etc t2 target_ty) target_ty
  | ( Ctypes.Tint _ _ _, Ctypes.Tarray ty_inner _num attr) =>
      let target_ty := Ctypes.Tpointer ty_inner attr in
      NC_second (i2etc t2 target_ty) target_ty
  | ( Ctypes.Tlong _ _ , Ctypes.Tarray ty_inner _num attr) =>
      let target_ty := Ctypes.Tpointer ty_inner attr in
      NC_second (i2etc t2 target_ty) target_ty

  | (_, _) => NC_neither t1
  end.

(* NOTE: CE is just types *)
Fixpoint transl_syntax_expr (ce: composite_env) (a: Clight.expr) {struct a}
  : SimplExpr.mon (rexpr) :=
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
      SimplExpr.ret(Evar id ty)
  | Clight.Etempvar id ty =>
      gdom _ <- check_ty ty;
      SimplExpr.ret(Etempvar id ty)
  | Clight.Ederef b ty =>
      gdom _ <- check_ty ty;
      gdo tb <- transl_syntax_expr ce b;
      SimplExpr.ret(Ederef tb ty)
  | Clight.Eaddrof b ty =>
      gdom _ <- check_ty ty;
      gdo tb <- transl_syntax_expr ce b;
      SimplExpr.ret(Eaddrof tb ty)
  | Clight.Eunop op exp ty =>
      gdom _ <- check_ty ty;
      gdo translated_exp <- transl_syntax_expr ce exp;
      SimplExpr.ret(Eunop op translated_exp ty)
  | Clight.Ebinop op exp1 exp2 ty =>
      gdom _ <- check_ty ty;
      gdo rexp1 <- transl_syntax_expr ce exp1;
      gdo rexp2 <- transl_syntax_expr ce exp2;
      SimplExpr.ret(Ebinop op rexp1 rexp2 ty)
  | Clight.Ecast exp ty =>
      gdom _ <- check_ty ty;
      gdo rexp <- transl_syntax_expr ce exp;
      SimplExpr.ret(Ecast rexp ty)
  | Clight.Efield exp ident ty =>
      gdom _ <- check_ty ty;
      gdo rexp <- transl_syntax_expr ce exp;
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

Fixpoint insert_cast_expr (e: rexpr) : SimplExpr.mon (rexpr)
  :=
  match e with
  | Econst_int _n _ty
  | Econst_single _n _ty
  | Econst_long _n _ty
  | Econst_float _n _ty =>
      SimplExpr.ret(e)
  (* add in a cast if we need to decay an array down to a pointer *)
  | Evar id ty
  | Etempvar id ty =>
      match ty with
      | Tarray ty' _ a => SimplExpr.ret(Ecast e (Tpointer ty' a))
      | _ => SimplExpr.ret(e)
      end
  | Ederef b ty =>
      gdo tb <- insert_cast_expr b;
      SimplExpr.ret(Ederef tb ty)
  | Eaddrof b ty =>
      gdo tb <- insert_cast_expr b;
      SimplExpr.ret(Eaddrof tb ty)
  | Efield exp ident ty =>
      gdo texp <- insert_cast_expr exp;
      SimplExpr.ret(Efield texp ident ty)

  | Ecast exp ty =>
      gdo texp <- insert_cast_expr exp;
      match ty with
      | Ctypes.Tint IBool _ _ =>
          let cur_ty := r_typeof exp in
          gdom zero_const <- gen_zero_const cur_ty;
          SimplExpr.ret(Ebinop Ogt texp zero_const ty)
      | _ => SimplExpr.ret(Ecast texp ty)
      end
  (* TODO I assume that this is fine. We might need to insert a cast maybe? *)
  | Esizeof ty' ty
  | Ealignof ty' ty =>
      SimplExpr.ret(e)

  | Eunop op exp ty =>
      let exp_typ := r_typeof exp in
      gdo texp <- insert_cast_expr exp;
      let builder := (fun c =>
        SimplExpr.ret(Ecast (Ebinop Oeq texp c cond_type) bang_type)
      ) in
      (* have to expand bool cast to if else statement *)
      match op with
      (* the ! operator maps scalar and pointer types to the int type. *)
      | Onotbool =>
          match exp_typ with
          | Ctypes.Tint _ _ _ =>
          (
            (* this is supposed to return int. int must be >= 16 bits according to c99 *)
            (* however in C2C.ml, C.Int is 32bit width, so we use that here too. *)
            (* TODO I'm assuming we don't care about attributes. *)
            (*      But, I couldn't find anything in the c99 spec about this *)
            let c := (Econst_int (Int.repr 0) exp_typ) in
            builder c
          )
          | Ctypes.Tlong _ _ => (
            let c := (Econst_int (Int.repr 0) exp_typ) in
            builder c
          )
          | Ctypes.Tfloat Ctypes.F64 _ => (
            let c := Econst_float (Bits.b64_of_bits 0%Z) exp_typ in
            builder c
          )
          | Ctypes.Tfloat Ctypes.F32 _ => (
            let c := Econst_single (Bits.b32_of_bits 0%Z) exp_typ in
            builder c
          )
          | Ctypes.Tpointer _ _ => (
            SimplExpr.ret( Ecast (Enull_check texp) bang_type )
          )
          (* TODO consider the array type *)
          (* TODO how are arrays handled*)
          | _ => SimplExpr.error( msg "invalid type passed into ! expression. Expected scalar or pointer type.")
          end
      | _ => SimplExpr.ret(Eunop op texp ty)
      end

  | Ebinop op exp1 exp2 ty =>
      gdom _ <- check_ty ty;
      gdo rexp1 <- insert_cast_expr exp1;
      gdo rexp2 <- insert_cast_expr exp2;
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
        | Olt | Ogt | Ole | Oge | Oeq | One => true
        | _ => false
      end in
      if needs_mapping_to_int then
        (
          (* the idea is the same as unop. Perform comparison, then cast the output rust bool
             to an int to match the C semantics *)
          let conditional := Ebinop op c_rexp1 c_rexp2 cond_type in
          let final_binop := Ecast conditional bang_type in
          i2etc bang_type ty final_binop
        )
      else
        let final_binop := Ebinop op c_rexp1 c_rexp2 rty in
        i2etc (r_typeof final_binop) (ty) final_binop

  (* this shouldn't exist *)
  | Enull_check _ty => SimplExpr.ret(e)
  end.




Locate int.

Fixpoint transl_syntax_arglist
  (ce: composite_env)
  (al: list Clight.expr)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      gdo arg <- transl_syntax_expr ce a1 ;
      gdo args <- transl_syntax_arglist ce a2 ;
      SimplExpr.ret(arg :: args)
  end.

Fixpoint insert_cast_arglist
  (al: list rexpr)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      gdo arg <- insert_cast_expr a1 ;
      gdo args <- insert_cast_arglist a2 ;
      SimplExpr.ret((Ecast arg bang_type) :: args)
  end.


Print typelist.

Fixpoint transl_syntax_arglist_with_ty_info
  (ce: composite_env)
  (al: list Clight.expr)
  (tyl: typelist)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      match tyl with
      | Tnil =>
        (
          gdo arg <- transl_syntax_expr ce a1 ;
          gdo args <- transl_syntax_arglist_with_ty_info ce a2 Tnil ;
          SimplExpr.ret(arg :: args)
        )
      | Tcons ty tyl' =>
      (
          gdo arg <- transl_syntax_expr ce a1 ;
          (* TODO laso don't need this *)
          (* gdo casted_arg <- i2etc (r_typeof arg) ty arg ; *)
          gdo args <- transl_syntax_arglist_with_ty_info ce a2 tyl';
          SimplExpr.ret(arg :: args)
      )
      end
  end.

Fixpoint insert_cast_arglist_with_ty_info
  (al: list rexpr)
  (tyl: typelist)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      match tyl with
      | Tnil =>
        (
          gdo arg <- insert_cast_expr a1 ;
          gdo args <- insert_cast_arglist_with_ty_info a2 Tnil ;
          SimplExpr.ret(arg :: args)
        )
      | Tcons ty tyl' =>
      (
          gdo arg <- insert_cast_expr a1 ;
          gdo casted_arg <- i2etc (r_typeof arg) ty arg ;
          gdo args <- insert_cast_arglist_with_ty_info a2 tyl';
          SimplExpr.ret(casted_arg :: args)
      )
      end
  end.

Print typelist.

Fixpoint transl_syntax_statement
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
          gdo r_lval <- transl_syntax_expr ce lval;
          gdo r_rval <- transl_syntax_expr ce rval;
          let gen_res := fun (e: rexpr) => S_assign r_lval e in
          process_expr r_rval gen_res
        (* SimplExpr.ret r_val *)
    | Clight.Sset x exp =>
        gdo r_exp <- transl_syntax_expr ce exp;
        let gen_res := fun (e: rexpr) => S_set x e in
        process_expr r_exp gen_res
    | Clight.Sifthenelse exp s1 s2 =>
        gdo cond <- transl_syntax_expr ce exp;
        gdo r_s1 <- transl_syntax_statement md s1;
        gdo r_s2 <- transl_syntax_statement md s2;
        let gen_res := fun (e: rexpr) => S_if_then_else e r_s1 r_s2 in
        process_expr cond gen_res
    | Clight.Ssequence exp1 exp2 =>
        gdo r_exp1 <- transl_syntax_statement md exp1;
        gdo r_exp2 <- transl_syntax_statement md exp2;
        SimplExpr.ret (S_sequence r_exp1 r_exp2)
    | Clight.Sreturn None => SimplExpr.ret (S_return None)
    | Clight.Sreturn (Some exp) =>
        let exp_ty := Clight.typeof exp in
        gdo r_exp <- transl_syntax_expr ce exp;
        let gen_res := fun (e: rexpr) => S_return (Some (e, exp_ty)) in
        process_expr r_exp gen_res
    (* TODO still need to handle casting and splitting expressions for this case *)
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
      gdo r_exp <- transl_syntax_expr ce exp ;
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

      (* TODO this is where the break should be *)
      let do_default := S_skip in

      gdo (dflt_case_inner_stmt, labeled_match_stmts) <-
        transl_switch u_s_md stmts exp_ident_as_exp exp_typ dflt_ident_as_exp dflt_case_ty S_skip (LSnil do_default);

      let match_stmt := S_match_int exp_ident_as_exp labeled_match_stmts in

      let if_dflt_stmt := S_if_then_else (dflt_ident_as_exp) dflt_case_inner_stmt S_skip in

      let loop_body := S_sequence if_dflt_stmt match_stmt in

      let new_loop := S_loop switch_loop_lbl loop_body S_skip in

      SimplExpr.ret (S_sequence (S_sequence dflt_case_decl exp_decl) new_loop)
    | Clight.Scall x name al =>
        gdo name' <- transl_syntax_expr ce name ;
        match r_typeof name' with
        | Tfunction tyl t cc =>
          (
            gdo al' <- transl_syntax_arglist_with_ty_info ce al tyl;
            SimplExpr.ret (S_call x name' al')
          )
        | _ =>
          (
            gdo al' <- transl_syntax_arglist ce al ;
            SimplExpr.ret (S_call x name' al')
          )
        end
    | Clight.Sbuiltin x ef tyargs bl => SimplExpr.error(msg "INVALID BUILTIN")
    | Clight.Sloop ns1 ns2 =>
        let (outer, inner) :=
          match next_lbl with
          | None => (0%Z, 1%Z)
          | Some(n) => (n+1, n+2)
        end in
        match (ns1, ns2) with
        | (Clight.Sskip, Clight.Sskip) => (
          SimplExpr.ret( S_loop2 None None S_skip S_skip)
        )
        | (Clight.Sskip, s2) => (
          let u_s_md_2 :=
            {|
              ce := ce;
              tyret := tyret;
              nbrk := nbrk;
              ncnt := ncnt;
              cur_loop_lbl := Some(outer);
              cur_switch_lbl := Some(outer);
              next_lbl := Some(outer);
              f_rty := f_rty;
              get_var_type := get_var_type;
            |} in
          gdo r_s2 <- transl_syntax_statement u_s_md_2 s2;
          SimplExpr.ret( S_loop2 (Some(outer)) None S_skip r_s2)
        )
        (* finnicky so I'm bailing *)
        (* | (s1, Clight.Sskip) => ( *)
        (*   let u_s_md_1 := *)
        (*     {| *)
        (*       ce := ce; *)
        (*       tyret := tyret; *)
        (*       nbrk := nbrk; *)
        (*       ncnt := ncnt; *)
        (*       cur_loop_lbl := Some(outer); *)
        (*       cur_switch_lbl := Some(outer); *)
        (*       next_lbl := Some(outer); *)
        (*       f_rty := f_rty; *)
        (*       get_var_type := get_var_type; *)
        (*     |} in *)
        (*   gdo r_s1 <- transl_statement u_s_md_1 s1; *)
        (*   SimplExpr.ret( S_loop2 (Some(outer)) None r_s1 S_skip) *)
        (* ) *)
        | (s1, s2) => (
          let u_s_md_1 :=
            {|
              ce := ce;
              tyret := tyret;
              nbrk := nbrk;
              ncnt := ncnt;
              cur_loop_lbl := Some(inner);
              cur_switch_lbl := Some(outer);
              next_lbl := Some(inner);
              f_rty := f_rty;
              get_var_type := get_var_type;
            |} in
          let u_s_md_2 :=
            {|
              ce := ce;
              tyret := tyret;
              nbrk := nbrk;
              ncnt := ncnt;
              cur_loop_lbl := Some(outer);
              cur_switch_lbl := Some(outer);
              next_lbl := Some(outer);
              f_rty := f_rty;
              get_var_type := get_var_type;
            |} in
          gdo r_s1 <- transl_syntax_statement u_s_md_1 s1;
          gdo r_s2 <- transl_syntax_statement u_s_md_2 s2;
          SimplExpr.ret (S_loop2 (Some(outer)) (Some(inner)) (S_sequence r_s1 (S_break (Some(inner)))) r_s2)
        )
        end
    | Clight.Sbreak => SimplExpr.ret (S_break cur_switch_lbl)
    | Clight.Scontinue => SimplExpr.ret (S_break cur_loop_lbl)
    | Clight.Slabel lbl s => SimplExpr.error (msg "INVALID BUILTIN")
    | Clight.Sgoto lbl => SimplExpr.error (msg "INVALID BUILTIN")
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
          gdo body <- transl_syntax_statement smd stmt;
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
          gdo body <- transl_syntax_statement smd stmt ;
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
                                 fn_imports := PositiveSet.empty;
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

Print PositiveSet.

(* get ids tree 1*)
(* get ids tree 2*)
(* map them into new tree *)
Fixpoint walk_r_expr_for_symbols (in_scope_syms: PositiveSet.t) (expr: rexpr) : PositiveSet.t :=
  let walk_r_expr := walk_r_expr_for_symbols in_scope_syms in
  match expr with
    | Evar id _ =>
        if (PositiveSet.mem id in_scope_syms) then
          PositiveSet.empty
        else PositiveSet.singleton id
    | Ederef exp _ => walk_r_expr exp
    | Eaddrof exp _ => walk_r_expr exp
    | Eunop _ exp _ => walk_r_expr exp
    | Ebinop _ exp1 exp2 _ty => PositiveSet.union (walk_r_expr exp1) (walk_r_expr exp2)
    | Ecast exp _ty => walk_r_expr exp
    | Efield exp _id _ty => walk_r_expr exp
    | _ => PositiveSet.empty
  end.

Fixpoint handle_exprs (in_scope_syms: PositiveSet.t ) (stmts: list rexpr) : PositiveSet.t :=
  match stmts with
  | nil => PositiveSet.empty
  | a :: b =>
      PositiveSet.union
        (walk_r_expr_for_symbols in_scope_syms a)
        (handle_exprs in_scope_syms b)
  end.

Fixpoint walk_r_body_for_symbols
  (in_scope_syms: PositiveSet.t)
  (stmt: rstatement)
  : PositiveSet.t :=
  let walk_r_expr := walk_r_expr_for_symbols in_scope_syms in
  let walk_r_stmt := walk_r_body_for_symbols in_scope_syms in
  match stmt with
  | S_skip => PositiveSet.empty
  | S_assign rexpr_1 rexpr_2 => PositiveSet.union (walk_r_expr rexpr_1) (walk_r_expr rexpr_2)
  | S_set id_1 rexpr =>
      (
        let t1 :=
          if PositiveSet.mem id_1 in_scope_syms
          then PositiveSet.empty
          else PositiveSet.singleton id_1
        in
        PositiveSet.union t1 (walk_r_expr rexpr)
      )
  | S_sequence s_1 s_2 => PositiveSet.union (walk_r_stmt s_1) (walk_r_stmt s_2)
  | S_continue _ => PositiveSet.empty
  | S_loop _ s_1 s_2 => PositiveSet.union (walk_r_stmt s_1) (walk_r_stmt s_2)
  | S_loop2 _ _ s_1 s_2 => PositiveSet.union (walk_r_stmt s_1) (walk_r_stmt s_2)
  | S_match_int rexpr ls =>
      PositiveSet.union (walk_r_expr rexpr) (handle_ls_stmt in_scope_syms (ls))
  | S_builtin _ _ _ _ => PositiveSet.empty
  | S_if_then_else rexpr rstmt_1 rstmt_2 => PositiveSet.union (PositiveSet.union (walk_r_expr rexpr) (walk_r_stmt rstmt_1)) (walk_r_stmt rstmt_2)
  | S_break _int => PositiveSet.empty
  | S_return maybe_rexpr =>
      match maybe_rexpr with
      | Some (rexpr, _ty) => (walk_r_expr rexpr)
      | None => PositiveSet.empty
      end
  (* TODO think about shadowing. Might need to ensure there's no other variable, but can easily do this with function metadata *)
  (* TODO this is possible in the case of a function pointer in which case we don't need to import anything. Should verify this to be the case, though *)
  | S_call _ r_expr l_rexpr => PositiveSet.union (handle_exprs in_scope_syms l_rexpr) (walk_r_expr r_expr)
  | S_exit r_expr => walk_r_expr r_expr
  end
with handle_ls_stmt (in_scope_syms: PositiveSet.t) (ls: labeled_rstatements) : PositiveSet.t :=
  match ls with
  | LSnil stmt => walk_r_body_for_symbols in_scope_syms stmt
  | LScons _ rstatement ls => PositiveSet.union (walk_r_body_for_symbols in_scope_syms rstatement) (handle_ls_stmt in_scope_syms ls)
  end.

Fixpoint insert_cast_stmt (gvt_unapplied: (list (ident * type)) -> ident -> res type) (f_rty: type) (stmt: rstatement) : SimplExpr.mon rstatement :=
  gdo new_tmps <- SimplExpr.get_trail tt;
  let gvt := gvt_unapplied new_tmps in
  match stmt with
  | S_skip => SimplExpr.ret (S_skip)
  | S_assign lval rval =>
      gdo r_lval <- insert_cast_expr lval;
      gdo r_rval <- insert_cast_expr rval;
      gdo coerced_type <- i2etc (r_typeof r_rval) (r_typeof r_lval) (r_rval) ;
      let s := nuke_equalities coerced_type in
      SimplExpr.ret(S_assign r_lval s)
      (* let gen_res := fun (e: rexpr) => S_assign r_lval e in *)
      (* process_expr s gen_res *)
  | S_set x exp =>
      gdo r_exp <- insert_cast_expr exp;
      gdom expected_type <- gvt x;
      gdo casted_exp <- i2etc (r_typeof r_exp) expected_type r_exp ;
      let s_casted_exp := nuke_equalities casted_exp in
      SimplExpr.ret(S_set x s_casted_exp)
      (* let gen_res := fun (e: rexpr) => S_set x e in *)
      (* (* TODO evaluate if this is needed *) *)
      (* process_expr s_casted_exp gen_res *)
  | S_if_then_else exp s1 s2 =>
      gdo cond <- insert_cast_expr exp;
      gdo casted_cond <- gen_cast_for_conditional cond;
      let s_cond := nuke_equalities casted_cond in
      gdo r_s1 <- insert_cast_stmt gvt_unapplied f_rty s1;
      gdo r_s2 <- insert_cast_stmt gvt_unapplied f_rty s2;
      SimplExpr.ret(S_if_then_else s_cond r_s1 r_s2)
  | S_sequence exp1 exp2 =>
      gdo r_exp1 <- insert_cast_stmt gvt_unapplied f_rty exp1;
      gdo r_exp2 <- insert_cast_stmt gvt_unapplied f_rty exp2;
      SimplExpr.ret (S_sequence r_exp1 r_exp2)
  | S_return None => SimplExpr.ret(stmt)
  | S_return (Some (exp, ty)) =>
    let exp_ty := r_typeof exp in
    gdo r_exp <- insert_cast_expr exp;
    gdo casted_exp <- i2etc exp_ty f_rty r_exp ;
    let s_casted_exp := nuke_equalities casted_exp in
    SimplExpr.ret(S_return (Some( (s_casted_exp, exp_ty) )))
  (* implicit type coersion can happen in function args *)
  | S_call x name al =>
      gdo name' <- insert_cast_expr name ;
      match r_typeof name' with
      | Tfunction tyl t cc =>
        (
          gdo al' <- insert_cast_arglist_with_ty_info al tyl;
          SimplExpr.ret (S_call x name' al')
        )
      | _ =>
        (
          gdo al' <- insert_cast_arglist al ;
          SimplExpr.ret (S_call x name' al')
        )
      end
  (* TODO this should be implemented *)
  (* | S_switch exp stmts => *)
  (*     SimplExpr.ret(stmt) *)
  (* TODO not currently implemented *)
  | S_builtin x ef tyargs bl => SimplExpr.error(msg "INVALID BUILTIN")
  | S_loop l1 s1 s2 =>
      gdo rs1 <- insert_cast_stmt gvt_unapplied f_rty s1;
      gdo rs2 <- insert_cast_stmt gvt_unapplied f_rty s2;
      SimplExpr.ret(S_loop l1 rs1 rs2)
  | S_loop2 l1 l2 s1 s2 =>
      gdo rs1 <- insert_cast_stmt gvt_unapplied f_rty s1;
      gdo rs2 <- insert_cast_stmt gvt_unapplied f_rty s2;
      SimplExpr.ret(S_loop2 l1 l2 rs1 rs2)
  | _ => SimplExpr.ret(stmt)
  end.


Locate map.

(* three things are done here: *)
(* - implement union for hashsets *)
(* - return a tree everywhere instead of a list *)
(* - change funciton type to ptree.t unit *)


Fixpoint nat_to_string (n : nat) : string :=
  match n with
  | 0%nat => "0"
  | S p => "0" ++ (nat_to_string (p))
  end.

Print PositiveSet.

Definition transl_internal_fun (ce: composite_env) (f: Clight.function) (glob_syms: list ident) : res r_function :=
  let return_type := (Clight.fn_return f) in
  let generator := reconstruct_generator f.(Clight.fn_temps) in
  let get_ty_of_var_rust :=
    (fun (tmps: list (ident * type)) (x: ident) =>
     let search_fn  := (fun acc p => if ident_eq (fst p) x then OK(snd p) else acc) in
     List.fold_left
                search_fn
                (f.(Clight.fn_params) ++  (f.(Clight.fn_vars)) ++ tmps)
                (* TODO this does NOT handle global symbols. I need to worry about those by (1) propagating their type and (2) including them here. .*)
                (* name is not sufficient*)
                (Error(msg "Could not find variable referenced!"))
    ) in
  let get_ty_of_var := get_ty_of_var_rust (f.(Clight.fn_temps)) in
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
  let translated_syntax_body := transl_syntax_statement smd (Clight.fn_body f) in

  let inserted_cast_body :=
    SimplExpr.bind translated_syntax_body (insert_cast_stmt get_ty_of_var_rust return_type) in
  match inserted_cast_body generator with
  | SimplExpr.Err msg => Error msg
  | SimplExpr.Res r_body r_g i =>
      let tmp_vars := r_g.(SimplExpr.gen_trail) in
      let cc := Clight.fn_callconv f in
      match cc.(AST.cc_vararg) with
      (* variadic. _n means # of fixed args *)
      | Some _n => Error(msg "Variadics are currently unsupported when converting to rust")
      (* not variadic *)
      | None => (
          let in_scope_symbols := (map fst f.(Clight.fn_vars)) ++ (map fst f.(Clight.fn_params)) ++ (map fst tmp_vars) ++ glob_syms in
          let in_scope_symbols_tree := fold_left (fun (acc : PositiveSet.t) (elt: ident) => PositiveSet.add elt acc)
                                         in_scope_symbols (PositiveSet.empty) in
          let len := List.length in_scope_symbols in


          (* TODO this can be removed *)
          (* let sanity_check := *)
          (*   fold_left (fun (acc : bool) (elt: ident) => *)
          (*     match PositiveSet.get elt in_scope_symbols_tree with *)
          (*     | Some(tt) => acc *)
          (*     | None => false *)
          (*     end *)
          (*     ) *)
          (*     in_scope_symbols *)
          (*     (true) in *)
          (* match sanity_check with *)
          (* | true => *)
              (* Error(msg ("number of symbols: " ++ (nat_to_string len))) *)
            OK({|
                  fn_return := return_type;
                  fn_callconv := {| cc_structret := (AST.cc_structret cc) |};
                  fn_params := f.(Clight.fn_params);
                  fn_vars := f.(Clight.fn_vars);
                  fn_temps := r_g.(SimplExpr.gen_trail);
                  fn_body := r_body;
                  (* fn_imports := (walk_r_body_for_symbols in_scope_symbols_tree r_body); *)
                  fn_imports := (walk_r_body_for_symbols in_scope_symbols_tree r_body);
                  (* fn_imports := (PTree.empty _); *)
                  fn_is_safe := false;
                |})
        (*   | false => Error(msg "sanity check failed") *)
        (* end) *)
      )
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
                (PositiveSet.empty)
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

  (* TODO need to evalualte the initialization expression in case it involves say taking an address of a gloval variable from another file *)
  (* low priority *)
  do translated_fns  <-
      AST.transf_globdefs
        (transl_fundef c_prog.(prog_comp_env) global_symbols)
        transl_globvar
        (* (cons (new_main_ident, new_main) c_prog.(prog_defs)); *)
        c_prog.(prog_defs);

  let old_main_ident := c_prog.(Ctypes.prog_main) in
  let old_main_fn := find (fun x => AST.ident_eq (fst x) old_main_ident)
                        (Ctypes.prog_defs c_prog) in

  match old_main_fn with
  | Some(omf) => (
      (* get the main replacement ident. *)
      let new_main_ident := SimplExpr.first_unused_ident tt in

      (* do new_main <- gen_new_main (snd omf) c_prog.(prog_main) (new_main_ident); *)
      do new_main <- gen_new_main' (snd omf) c_prog.(prog_main) (new_main_ident) ;


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
    (* Error(msg "Main function not found?") *)
    let r_prog : r_program :=
      {|
        (* PUBLIC only fns *)
        Ctypes.prog_defs := translated_fns;
        Ctypes.prog_public := c_prog.(prog_public);
        Ctypes.prog_main := old_main_ident;
        Ctypes.prog_types := c_prog.(prog_types);
        Ctypes.prog_comp_env := c_prog.(prog_comp_env);
        Ctypes.prog_comp_env_eq := c_prog.(prog_comp_env_eq);
      |} in

    OK(r_prog)

  )
  end.

(* plan for initialization to 0 for structs *)
(* statement for each primitive field initialized to 0 *)
(* if is not a primitive, add a new variable, recursively add initialization to 0 *)

(* plan for temp address of global variable *)
(* (1) if the type of the expression being evaluated is a pointer type,
       create create underlying expression as a new static global variable *)
(*     then the existing addr_of infra should work on the variable. *)
       (* if it literally is &a, then it's fine already. But if it's a string? *)
(*     TODO may need to think about double pointers (which...doesn't really make sense)
 *)

(* for temporaries in particular: check if the root of hte expression is addr_of!. if it's not then *)
(* we have to separate it out into a separate expression *)
