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
Require SimplExpr.
Require Clight.
Require Cshmgen.
Local Open Scope error_monad_scope.

Print Ctypes.program.
Locate positive.
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
      do _unused <- check_typelist tl;
      check_ty ty
  | Ctypes.Tstruct _ a => check_attr a
  | Ctypes.Tunion _ a => check_attr a
  end
with check_typelist(tl : typelist) : res (unit) :=
  match tl with
  | Ctypes.Tnil => OK(tt)
  | Ctypes.Tcons ty tl =>
      do _unused <- check_ty ty;
      check_typelist tl
  end.

(* I'm keeping this around if in the future we wish to support
   multiple calling conventions. But for now, we only support one (SYSV) *)
Record r_calling_convention : Type := mkcallconv { cc_structret: bool }.

(* TODO rename to be consistent *)
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
  | LScons: option Z -> rstatement -> labeled_rstatements -> labeled_rstatements.


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
  (* this only includes global symbols, and does not include types *)
  fn_imports: PositiveSet.t;

  (* the external symbols that are types and used *)
  (* we use this in printing exports*)
  fn_ty_imports: PositiveSet.t;

  (* TODO not used, get rid of it *)
  fn_is_safe: bool;
}.

Print sum.

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


Definition void_pointer_int (ty: Ctypes.type) := Ecast (Econst_int (Int.repr 0) (Ctypes.Tint I32 Signed noattr)) ty.
(* Definition void_pointer (ty: Ctypes.type) := Eaddr_of () (Ctypes.Tpointer Ctypes.Tvoid noattr) *)

Definition gen_zero_const (ty: type) : res rexpr :=
  match ty with
  | Ctypes.Tlong _ _ => OK(Econst_long (Int64.repr 0) ty)
  | Ctypes.Tint _ _ _ => OK(Econst_int (Int.repr 0) ty)
  | Ctypes.Tfloat Ctypes.F64 _ => OK(Econst_float (Bits.b64_of_bits 0%Z) ty)
  | Ctypes.Tfloat Ctypes.F32 _ => OK(Econst_single (Bits.b32_of_bits 0%Z) ty)
  | Ctypes.Tpointer ty a => OK(void_pointer_int (Ctypes.Tpointer ty a))
  (* TODO may need array decay *)
  | ty => Error (msg (String.append "Encountered unexpected type that has no zero constant" (type_to_string ty)))
  end
  .

Print type.

Definition is_fn_ptr (ty: type) : bool :=
  match ty with
  | Tpointer (Tfunction _ _ _) _ => true
  | _ => false
  end.

Definition empty_r_fn : r_function := {|
                                 fn_return := Ctypes.Tvoid;
                                 fn_callconv := {| cc_structret := false; |};
                                 fn_params := nil;
                                 fn_vars := nil;
                                 fn_temps := nil;
                                 fn_body := S_skip;
                                 fn_imports := PositiveSet.empty;
                                 fn_ty_imports := PositiveSet.empty;
                                 fn_is_safe := false;
                               |}.


(* TODO not sure if I'm okay with the external function definition? The rust builtins may differ from C. *)
Definition r_fundef := Ctypes.fundef r_function.
(* generic over function type *)
Definition r_program := Ctypes.program r_function.

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

(* this is fine as an entry for global symbols. It's not like global symbols will appear outside this function *)
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
  (* TODO this probably isn't right if the LHS ident isn't imported ... *)
  | S_call _ r_expr l_rexpr => PositiveSet.union (handle_exprs in_scope_syms l_rexpr) (walk_r_expr r_expr)
  | S_exit r_expr => walk_r_expr r_expr
  end
with handle_ls_stmt (in_scope_syms: PositiveSet.t) (ls: labeled_rstatements) : PositiveSet.t :=
  match ls with
  | LSnil stmt => walk_r_body_for_symbols in_scope_syms stmt
  | LScons _ rstatement ls => PositiveSet.union (walk_r_body_for_symbols in_scope_syms rstatement) (handle_ls_stmt in_scope_syms ls)
  end.

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

(* what Im going to do for types (struct, union) *)
(* prog_types are file local types *)
(* prog_types are file local types, so add those to global_symbols *)
(* look through the types in the walk
   and add them to the tree if they're not in global_symbols
*)

Locate res.
Print cons.

Fixpoint get_ty_idents_from_ty (ty: type) : PositiveSet.t :=
  match ty with
  | Ctypes.Tvoid
  | Ctypes.Tint _ _ _
  | Ctypes.Tlong  _ _
  | Ctypes.Tfloat  _ _ => PositiveSet.empty
  | Tpointer ty' _ => get_ty_idents_from_ty ty'
  | Tarray ty' _ _ => get_ty_idents_from_ty ty'
  | Tstruct name _
  | Tunion name _ => PositiveSet.singleton name
  | Tfunction tl rty _ =>
      PositiveSet.union (get_ty_idents_from_ty rty) (get_ty_idents_from_tl tl)
  end
  with get_ty_idents_from_tl (tl: typelist) : PositiveSet.t :=
  match tl with
  | Tnil => PositiveSet.empty
  | Tcons ty tl' =>
      PositiveSet.union (get_ty_idents_from_ty ty) (get_ty_idents_from_tl tl')
  end
.

Fixpoint walk_r_expr_for_composite_types (expr: rexpr) : PositiveSet.t :=
  match expr with
    | Evar _ ty =>
        get_ty_idents_from_ty ty
    | Etempvar _ ty =>
        get_ty_idents_from_ty ty
    | Ederef exp ty =>
        PositiveSet.union (walk_r_expr_for_composite_types exp) (get_ty_idents_from_ty ty)
    | Eaddrof exp ty =>
        PositiveSet.union (walk_r_expr_for_composite_types exp) (get_ty_idents_from_ty ty)
    | Eunop _ exp ty =>
        PositiveSet.union (walk_r_expr_for_composite_types exp) (get_ty_idents_from_ty ty)
    | Ebinop _ exp1 exp2 ty =>
        PositiveSet.union (walk_r_expr_for_composite_types exp2)
        (PositiveSet.union (walk_r_expr_for_composite_types exp1) (get_ty_idents_from_ty ty))
    | Ecast exp ty =>
        PositiveSet.union (walk_r_expr_for_composite_types exp) (get_ty_idents_from_ty ty)
    | Efield exp _id ty =>
        PositiveSet.union (walk_r_expr_for_composite_types exp) (get_ty_idents_from_ty ty)
    | Ealignof ty ty'
    | Esizeof ty ty' => PositiveSet.union (get_ty_idents_from_ty ty) (get_ty_idents_from_ty ty')
    | Enull_check e => walk_r_expr_for_composite_types e
    | _ => PositiveSet.empty
  end.

Fixpoint walk_r_exprs_for_composite_types (exprs: list rexpr) : PositiveSet.t :=
  match exprs with
  | nil => PositiveSet.empty
  | t :: l => PositiveSet.union (walk_r_expr_for_composite_types t) (walk_r_exprs_for_composite_types l)
  end.


Fixpoint walk_r_stmt_for_composite_types (stmt: rstatement) : PositiveSet.t :=
  match stmt with
  | S_skip => PositiveSet.empty
  | S_assign rexpr_1 rexpr_2 =>
      PositiveSet.union (walk_r_expr_for_composite_types rexpr_1) (walk_r_expr_for_composite_types rexpr_2)
  | S_set id_1 rexpr =>
      walk_r_expr_for_composite_types rexpr
  | S_sequence s_1 s_2 =>
      PositiveSet.union (walk_r_stmt_for_composite_types s_1) (walk_r_stmt_for_composite_types s_2)
  | S_continue _ => PositiveSet.empty
  | S_loop _ s_1 s_2 =>
      PositiveSet.union (walk_r_stmt_for_composite_types s_1) (walk_r_stmt_for_composite_types s_2)
  | S_loop2 _ _ s_1 s_2 =>
      PositiveSet.union (walk_r_stmt_for_composite_types s_1) (walk_r_stmt_for_composite_types s_2)
  | S_match_int rexpr ls =>
      PositiveSet.union (walk_r_expr_for_composite_types rexpr) (walk_ls_for_composite_types ls)
  | S_builtin _ _ _ _ => PositiveSet.empty
  | S_if_then_else re s_1 s_2 =>
      PositiveSet.union (PositiveSet.union (walk_r_stmt_for_composite_types s_1) (walk_r_stmt_for_composite_types s_2)) (walk_r_expr_for_composite_types re)
  | S_break _int => PositiveSet.empty
  | S_return maybe_rexpr =>
      match maybe_rexpr with
      | None => PositiveSet.empty
      | Some (e, ty) => PositiveSet.union (walk_r_expr_for_composite_types e) (get_ty_idents_from_ty ty)
      end
  | S_call _ re l_rexpr =>
      let ty_re := walk_r_expr_for_composite_types re in
      let ty_args := walk_r_exprs_for_composite_types l_rexpr in
      PositiveSet.union ty_re ty_args
  | S_exit re => walk_r_expr_for_composite_types re
  end
with walk_ls_for_composite_types (ls: labeled_rstatements) : PositiveSet.t :=
  match ls with
  | LSnil stmt => walk_r_stmt_for_composite_types stmt
  | LScons _ rs ls' =>
      PositiveSet.union (walk_r_stmt_for_composite_types rs) (walk_ls_for_composite_types ls')
  end.

Fixpoint walk_r_fn_list_for_composite_types (args: list (ident * type)) : PositiveSet.t
  :=
  match args with
  | nil => PositiveSet.empty
  | (name, ty) :: args' =>
      PositiveSet.union (get_ty_idents_from_ty ty) (walk_r_fn_list_for_composite_types args')
  end.




Definition walk_r_fn_for_composite_types
  (ret_ty: type)
  (params: list (ident * type))
  (vars: list (ident * type))
  (tmps: list (ident * type))
  (body: rstatement)
  : PositiveSet.t
  :=

  let r_set := get_ty_idents_from_ty ret_ty in

  let arg_tys := walk_r_fn_list_for_composite_types params in

  let var_types := walk_r_fn_list_for_composite_types vars in

  let tmp_types := walk_r_fn_list_for_composite_types  tmps in

  let body_tys := walk_r_stmt_for_composite_types body in

  PositiveSet.union (PositiveSet.union (PositiveSet.union (PositiveSet.union r_set arg_tys) var_types) tmp_types) body_tys.

(* TODO these comments are old and I should go through and prune what is not useful*)
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
