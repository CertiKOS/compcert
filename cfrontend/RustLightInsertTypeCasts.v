Require Import RustLight.
Require Import Cop.
Require Import Coq.Strings.String.
Require Import Errors.
Require Import Ctypes.
Require Import AST.
Require Import ZArith.
Require Import Integers.
Require Import Axioms Coqlib.
Require Import List.
Import List.ListNotations.

Local Open Scope error_monad_scope.

Declare Scope error_monad_ext_scope.

Definition ret {A: Type} (x : A) : res A  := OK x.

(* TODO this is duplicated. dedup. *)
Definition bind3 {A B C D: Type} (x: res (A * B * C)) (f: A -> B -> C -> res D) : res D :=
  bind x (fun '(a, b, c) => f a b c).

Notation "'do' ( X , Y , Z ) <- A ; B" := (bind3 A (fun X Y Z => B))
   (at level 200, X ident, Y ident, Z ident, A at level 100, B at level 200)
   : error_monad_ext_scope.

Local Open Scope error_monad_ext_scope.

Definition is_zero_const (e: rexpr) : bool := false.

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


Inductive needs_coersion : Type :=
  (* cast on first expression, overall type *)
  | NC_first : (rexpr -> res rexpr) -> type -> needs_coersion
  (* cast on second expression, overall type *)
  | NC_second : (rexpr -> res rexpr) -> type -> needs_coersion
  | NC_neither : type -> needs_coersion
  | NC_both : (rexpr -> res rexpr) -> (rexpr -> res rexpr) -> type -> needs_coersion.

Definition gen_cast_for_conditional
  (expr: rexpr)
  : res rexpr
  :=
  let ty := r_typeof expr in
  (* TODO move zero_const up a level*)
  match ty with
  | Ctypes.Tlong _ _ =>
      do zero_const <- gen_zero_const ty;
      ret (Ebinop Cop.One expr zero_const cond_type)
  (* do nothing here *)
  | Ctypes.Tint Ctypes.IBool _ _ =>
      ret (expr)
  (* we need to translate from an integer to a boolean *)
  | Ctypes.Tint _ _ _attrs  =>
      do zero_const <- gen_zero_const ty;
      ret (Ebinop Cop.One expr zero_const cond_type)
  | Ctypes.Tfloat Ctypes.F64 _attrs  =>
      do zero_const <- gen_zero_const ty;
      ret (Ebinop Cop.One expr zero_const cond_type)
  | Ctypes.Tfloat Ctypes.F32 _attrs  =>
      do zero_const <- gen_zero_const ty;
      ret (Ebinop Cop.One expr zero_const cond_type)
  | Ctypes.Tpointer ty _attrs  =>
      ret(Eunop Onotbool (Enull_check expr) cond_type)
  | ty => Error(msg (String.append " Expected scalar or pointer type in condition. Got unexpected type: " (type_to_string ty)))
  end.

(* this does general type coersions*)
(* "implict to explicit type coersion" *)
Definition i2etc
  (cur_type: type)
  (desired_type: type)
  (expr: rexpr)
  : res rexpr
  :=
  match (cur_type, desired_type) with
  | (Ctypes.Tint I8 Signed _, Ctypes.Tint I8 Signed _)
  | (Ctypes.Tint I8 Unsigned _, Ctypes.Tint I8 Unsigned _)
  | (Ctypes.Tint I16 Signed _, Ctypes.Tint I16 Signed _)
  | (Ctypes.Tint I16 Unsigned _, Ctypes.Tint I16 Unsigned _)
  | (Ctypes.Tint I32 Signed _, Ctypes.Tint I32 Signed _)
  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tint I32 Unsigned _)
  | (Ctypes.Tlong Unsigned _, Ctypes.Tlong Unsigned _)
  | (Ctypes.Tlong Signed _, Ctypes.Tlong Signed _)
  | (Ctypes.Tfloat F32 _, Ctypes.Tfloat F32 _)
  | (Ctypes.Tfloat F64 _, Ctypes.Tfloat F64 _) => ret expr
  | (_, Ctypes.Tint IBool _ _) => gen_cast_for_conditional expr
  | (Ctypes.Tint IBool _ a, Ctypes.Tfloat F32 _)
  | (Ctypes.Tint IBool _ a, Ctypes.Tfloat F64 _) =>
      ret (Ecast (Ecast expr (Ctypes.Tint I8 Unsigned a)) desired_type)
  (* handle pointer decay. In rust this is done by going from an array type to a pointer type *)
  (* this is the decay part *)
  (* then directly casting from the nested array type to a pointer type*)
  | (Ctypes.Tarray ty_from _len _attrs, Ctypes.Tpointer ty_to _attrs') =>
      let new_ty := Ctypes.Tpointer ty_from _attrs in
      let casted := Ecast expr new_ty in
      ret(Ecast casted desired_type)
  | (_a, _b) =>
       ret (Ecast expr desired_type)
  end.

(*Definition do_binop_coersion (t1: type) (t2: type) (t1_is_zero: bool) (t2_is_zero: bool) : needs_coersion :=*)
Definition do_binop_coersion (t1: type) (t2: type) : needs_coersion :=
  let neither := NC_neither t1 in
  let first_to_second := NC_first (i2etc t1 t2) t2 in
  let second_to_first := NC_second (i2etc t2 t1) t1 in
  let both_to_int := NC_both (i2etc t1 bang_type) (i2etc t2 bang_type) bang_type in
  let first_through_int :=
      NC_first (fun expr => do exp1 <- i2etc t1 bang_type expr; i2etc bang_type t2 exp1) t2 in
  let second_through_int :=
      NC_second (fun expr => do exp1 <- i2etc t2 bang_type expr; i2etc bang_type t1 exp1 ) t1 in

  match (t1, t2) with
  (* same types do nothing *)
  | (Ctypes.Tint IBool _ _, Ctypes.Tint IBool _ _)
  | (Ctypes.Tint I8 Signed _, Ctypes.Tint I8 Signed _)
  | (Ctypes.Tint I8 Unsigned _, Ctypes.Tint I8 Unsigned _)
  | (Ctypes.Tint I16 Signed _, Ctypes.Tint I16 Signed _)
  | (Ctypes.Tint I16 Unsigned _, Ctypes.Tint I16 Unsigned _)
  | (Ctypes.Tint I32 Signed _, Ctypes.Tint I32 Signed _)
  | (Ctypes.Tint I32 Unsigned _, Ctypes.Tint I32 Unsigned _)
  | (Ctypes.Tlong Unsigned _, Ctypes.Tlong Unsigned _)
  | (Ctypes.Tlong Signed _, Ctypes.Tlong Signed _)
  | (Ctypes.Tfloat F32 _, Ctypes.Tfloat F32 _)
  | (Ctypes.Tfloat F64 _, Ctypes.Tfloat F64 _) => neither

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
  | (Ctypes.Tlong Signed _, Ctypes.Tlong Unsigned _) => first_to_second
  | (Ctypes.Tlong Unsigned _, Ctypes.Tlong Signed _) => second_to_first

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
  | (Ctypes.Tpointer Ctypes.Tvoid _attr, (Ctypes.Tpointer ty' attr') as target_ty) =>
    match ty' with
    | Ctypes.Tvoid => NC_neither t1
    | _ => NC_first (i2etc t1 target_ty) target_ty
    end
  | ((Ctypes.Tpointer ty' _) as target_ty, Ctypes.Tpointer Ctypes.Tvoid _) =>
    match ty' with
    | Ctypes.Tvoid => NC_neither t1
    | _ => NC_second (i2etc t2 target_ty) target_ty
    end
  (*| ((Ctypes.Tpointer _ _) as target_ty, _) =>*)
  (*  NC_second (i2etc t2 target_ty) target_ty*)
  (*| (_, (Ctypes.Tpointer _ _) as target_ty) =>*)
  (*  NC_first (i2etc t1 target_ty) target_ty*)
  | (_, _) => NC_neither t1
  end.

Fixpoint insert_cast_expr (e: rexpr) : res rexpr
  :=
  match e with
  | Econst_int _n _ty
  | Econst_single _n _ty
  | Econst_long _n _ty
  | Econst_float _n _ty =>
      ret(e)
  | Evar id ty
  | Etempvar id ty =>
      match ty with
      | Tarray ty' _ a => ret(Ecast e (Tpointer ty' a))
      | _ => ret(e)
      end
  | Ederef b ty =>
      do tb <- insert_cast_expr b;
      ret(Ederef tb ty)
  | Eaddrof b ty =>
      do tb <- insert_cast_expr b;
      ret(Eaddrof tb ty)
  | Efield exp ident ty =>
      do texp <- insert_cast_expr exp;
      ret(Efield texp ident ty)
  | Ecast exp ty =>
      do texp <- insert_cast_expr exp;
      match ty with
      | Ctypes.Tint IBool _ _ =>
          let cur_ty := r_typeof exp in
          do zero_const <- gen_zero_const cur_ty;
          ret(Ebinop Ogt texp zero_const ty)
      | _ => ret(Ecast texp ty)
      end
  (* TODO I assume that this is fine. We might need to insert a cast maybe? *)
  | Esizeof ty' ty
  | Ealignof ty' ty =>
      ret(e)
  | Eunop op exp ty =>
      let exp_typ := r_typeof exp in
      do texp <- insert_cast_expr exp;
      let builder := (fun c =>
        ret(Ecast (Ebinop Oeq texp c cond_type) bang_type)
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
            ret( Ecast (Enull_check texp) bang_type )
          )
          (* TODO consider the array type *)
          (* TODO how are arrays handled*)
          | _ => Error( msg "invalid type passed into ! expression. Expected scalar or pointer type.")
          end
      | _ => ret(Eunop op texp ty)
      end
  | Ebinop op exp1 exp2 ty =>
      do unused <- check_ty ty;
      do rexp1 <- insert_cast_expr exp1;
      do rexp2 <- insert_cast_expr exp2;
      (* TODO this is obfuscated. Can just do the casting directly *)
      do (c_rexp1, c_rexp2, rty) <-
        match do_binop_coersion (r_typeof rexp1) (r_typeof rexp2) with
        | NC_first f rty =>
            do res <- f rexp1;
            ret(res, rexp2, rty)
        | NC_second f rty =>
            do res <- f rexp2;
            ret(rexp1, res, rty)
        | NC_neither rty => ret(rexp1, rexp2, rty)
        | NC_both f g rty =>
            do res1 <- f rexp1;
            do res2 <- g rexp2;
            ret(res1, res2, rty)
        end;
      let needs_mapping_to_int :=
      match op with
        | Olt | Ogt | Ole | Oge | Oeq | Cop.One => true
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
  | Enull_check _ty => ret(e)
  end.

Print bang_type.

Print type.

Definition insert_arg_cast
  (arg: rexpr)
  : rexpr
  :=
  match r_typeof arg with
  | Ctypes.Tint Ctypes.I32 Ctypes.Unsigned a => arg
  | Ctypes.Tint _ _ a => Ecast arg (Ctypes.Tint Ctypes.I32 Ctypes.Signed a)
  | Ctypes.Tfloat F32 a => Ecast arg (Ctypes.Tfloat F64 a)
  | _ => arg
  end.

Print bang_type.

Fixpoint insert_cast_arglist
  (al: list rexpr)
  {struct al}:
  res (list rexpr) :=
  match al with
  | nil => ret nil
  | a1 :: a2 =>
      do arg <- insert_cast_expr a1 ;
      do args <- insert_cast_arglist a2 ;

      let res :=
      match r_typeof arg with
      | Ctypes.Tfloat F32 a => (Ecast arg (Ctypes.Tfloat F64 a))
      | Ctypes.Tint _ a _ => (Ecast arg bang_type)
      | _ => arg
      end
      in


      ret (res :: args)
  end.

Fixpoint insert_cast_arglist_with_ty_info
  (al: list rexpr)
  (tyl: typelist)
  {struct al}:
  res (list rexpr) :=
  match al with
  | nil => ret nil
  | a1 :: a2 =>
      match tyl with
      | Tnil =>
        (
          insert_cast_arglist al
        )
      | Tcons ty tyl' =>
      (
          do arg <- insert_cast_expr a1 ;
          do casted_arg <- i2etc (r_typeof arg) ty arg ;
          do args <- insert_cast_arglist_with_ty_info a2 tyl';
          ret (casted_arg :: args)
      )
      end
  end.

Print rexpr.

Fixpoint insert_cast_stmt (gvt: ident -> res type) (f_rty: type) (stmt: rstatement) : res rstatement :=
  match stmt with
  | S_skip => ret (S_skip)
  | S_assign lval rval =>
      do r_lval <- insert_cast_expr lval;
      do r_rval <- insert_cast_expr rval;
      do coerced_type <- i2etc (r_typeof r_rval) (r_typeof r_lval) (r_rval) ;
      let s := nuke_equalities coerced_type in
      ret(S_assign r_lval s)
  | S_set x exp =>
      do r_exp <- insert_cast_expr exp;
      do expected_type <- gvt x;
      do casted_exp <- i2etc (r_typeof r_exp) expected_type r_exp ;
      let s_casted_exp := nuke_equalities casted_exp in
      ret(S_set x s_casted_exp)
      (* let gen_res := fun (e: rexpr) => S_set x e in *)
      (* (* TODO evaluate if this is needed *) *)
      (* process_expr s_casted_exp gen_res *)
  | S_if_then_else exp s1 s2 =>
      do cond <- insert_cast_expr exp;
      do casted_cond <- gen_cast_for_conditional cond;
      let s_cond := nuke_equalities casted_cond in
      do r_s1 <- insert_cast_stmt gvt f_rty s1;
      do r_s2 <- insert_cast_stmt gvt f_rty s2;
      ret(S_if_then_else s_cond r_s1 r_s2)
  | S_sequence exp1 exp2 =>
      do r_exp1 <- insert_cast_stmt gvt f_rty exp1;
      do r_exp2 <- insert_cast_stmt gvt f_rty exp2;
      ret (S_sequence r_exp1 r_exp2)
  | S_return None => ret(stmt)
  | S_return (Some (exp, ty)) =>
    let exp_ty := r_typeof exp in
    do r_exp <- insert_cast_expr exp;
    do casted_exp <- i2etc exp_ty f_rty r_exp ;
    let s_casted_exp := nuke_equalities casted_exp in
    ret(S_return (Some( (s_casted_exp, exp_ty) )))
  (* implicit type coersion can happen in function args *)
  | S_call x name al =>
      do name' <- insert_cast_expr name ;
      match r_typeof name' with
      | Tfunction tyl t cc =>
        (
          do al' <- insert_cast_arglist_with_ty_info al tyl;
          ret (S_call x name' al')
        )
      | Tpointer ((Tfunction tyl t cc) as fnty) a =>
        (
          do al' <- insert_cast_arglist_with_ty_info al tyl;
          ret (S_call x (Ederef name' fnty) al')
        )
      | _ =>
        (
          do al' <- insert_cast_arglist al ;
          ret (S_call x name' al')
        )
      end
 | S_match_int exp lrs =>
     do re <- insert_cast_expr exp;
     do tr_lrs <- insert_cast_labeled_rstatements gvt f_rty lrs;
     ret (S_match_int re tr_lrs)
  (* TODO not currently implemented *)
  | S_builtin x ef tyargs bl => Error(msg "INVALID BUILTIN")
  | S_loop l1 s1 s2 =>
      do rs1 <- insert_cast_stmt gvt f_rty s1;
      do rs2 <- insert_cast_stmt gvt f_rty s2;
      ret(S_loop l1 rs1 rs2)
  | S_loop2 l1 l2 s1 s2 =>
      do rs1 <- insert_cast_stmt gvt f_rty s1;
      do rs2 <- insert_cast_stmt gvt f_rty s2;
      ret(S_loop2 l1 l2 rs1 rs2)
  | S_exit e =>
      do re <- insert_cast_expr e;
      ret (S_exit re)
  | (S_break _)
  | (S_continue _) => ret(stmt)
  end

  with
    insert_cast_labeled_rstatements
    (gvt: ident -> res type)
    (f_rty: type)
    (lrs: labeled_rstatements) : res labeled_rstatements
    :=
    match lrs with
    | LSnil rs =>
        do tr_rs <- insert_cast_stmt gvt f_rty rs;
        ret(LSnil tr_rs)
    | LScons c s lrs' =>
        do tr_rs <- insert_cast_stmt gvt f_rty s;
        do rest <- insert_cast_labeled_rstatements gvt f_rty lrs';
        ret (LScons c tr_rs rest)
    end.

(* TODO this has terrible runtime, should probably replace with FMap *)
Definition get_ty_of_var_rust
  (r_fn: r_function) (x: ident): res type
  :=
  let search_fn := (fun acc p => if ident_eq (fst p) x then OK(snd p) else acc) in
  List.fold_left search_fn (r_fn.(RustLight.fn_params) ++ r_fn.(RustLight.fn_vars) ++ r_fn.(RustLight.fn_temps)) (Error(msg "Could not find variable referenced!")).


Definition transl_internal_function (r_fn: r_function) : res r_function :=
  let ty_map := get_ty_of_var_rust r_fn in
  let f_rty := r_fn.(fn_return) in
  let body := r_fn.(fn_body) in
  do new_body <- insert_cast_stmt ty_map f_rty body;
  ret {|
    fn_return := r_fn.(fn_return);
    fn_callconv := r_fn.(fn_callconv);
    fn_vars := r_fn.(fn_vars);
    fn_temps := r_fn.(fn_temps);
    fn_body := new_body;
    fn_params := r_fn.(fn_params);
    fn_ty_imports := r_fn.(fn_ty_imports);
    fn_imports := r_fn.(fn_imports);
    fn_is_safe := r_fn.(fn_is_safe);
  |}.

Definition transl_fundef_r
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

  do translated_fns <-
    AST.transf_globdefs
      transl_fundef_r
      transl_globvar
      r_prog.(prog_defs);

  let r_prog : r_program :=
    {|
      (* PUBLIC only fns *)
      Ctypes.prog_defs := translated_fns;
      Ctypes.prog_public := r_prog.(prog_public);
      Ctypes.prog_main := r_prog.(prog_main);
      Ctypes.prog_types := r_prog.(prog_types);
      Ctypes.prog_comp_env := r_prog.(prog_comp_env);
      Ctypes.prog_comp_env_eq := r_prog.(prog_comp_env_eq);
    |} in
  OK(r_prog).

