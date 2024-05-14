(* abstract syntax *)
(* brings in do notation? *)
(*
Require Import Ctypes.
Require Import Floats.
Require Import Maps.
Require Import Axioms Coqlib.
Require Import Values.
Require Import Integers.
Require Import AST.
Require Import Errors.
Require Import Cop.
Require Import Memory.
Require Import Globalenvs.
Require Import Memory.
Search Genv.t.
Locate ident.

Inductive HLIR : Type := Nil.

Inductive bool := True | False.

Inductive r_signedness : Type :=
  | Signed: r_signedness
  | Unsigned: r_signedness.

Inductive r_int_size : Type :=
  | I8: r_int_size
  | I16: r_int_size
  | I32: r_int_size
  | I64: r_int_size
  (* | I128: r_int_size *)
  | IBool: r_int_size.

Inductive r_float_size : Type :=
  | F32: r_float_size
  | F64: r_float_size.

Inductive pointer_type : Type :=
  | Praw_mut
  | Mraw_const
  | Mref
  | Mref_mut.

Inductive mutability : Type :=
  | mutable
  | immutable.

Inductive r_type : Type :=
  | Tunit: r_type
  | Tint: r_int_size -> r_signedness -> mutability -> r_type
  | Tfloat: r_float_size -> mutability -> r_type
  | Tpointer: r_type -> mutability -> pointer_type -> r_type
  | Tarray: r_type -> mutability -> pointer_type -> Z -> r_type
  | Tfunction: type_list -> mutability -> r_type  -> r_type
  | Tstruct: ident -> mutability -> r_type
  | Tunion: ident -> mutability -> r_type
with type_list : Type :=
  | Tnil: type_list
  | Tcons: r_type -> type_list -> type_list.

Search int.

Definition r_bitsize_r_int_size (sz: r_int_size) : Z :=
  match sz with
  | I8 => 8
  | I16 => 16
  | I32 => 32
  | I64 => 64
  (* | I128 => 32 *)
  | IBool => 1
  end.

Inductive r_expr : Type :=
  | REconst_int: int -> r_type -> r_expr
  | REconst_float32: float32 -> r_type -> r_expr
  | REconst_float64: float -> r_type -> r_expr
  | REvar: ident -> r_type -> r_expr
  | REtempvar: ident -> r_type -> r_expr
  | Ederef: r_expr -> r_type -> r_expr
  | Eaddrof: r_expr -> r_type -> r_expr
  | Efield: r_expr -> ident -> r_type -> r_expr
   (* TODO do we want to force the type of the cast to be into primitive? *)
  | Ecast: r_expr -> r_type -> r_expr
  .

Definition r_typeof (e: r_expr) : r_type :=
  match e with
  | REconst_int x ty => ty
  | REconst_float32 x ty => ty
  | REconst_float64 x ty => ty
  | REvar x ty => ty
  | REtempvar x ty => ty
  | Ederef x ty => ty
  | Eaddrof x ty => ty
  | Efield x x0 ty => ty
  | Ecast x ty => ty
  end.

Inductive r_statement : Type :=
  | RSskip : r_statement
  | RSassign : r_expr -> r_expr -> r_statement
  | RSet : r_expr -> r_expr -> r_statement
  | RScall : option ident -> r_expr -> list r_expr -> r_statement
  (* TODO compiler intrinsic / builtin *)
  | Ssequence : r_statement -> r_statement -> r_statement
  | Sifthenelse : r_expr -> r_statement -> r_statement -> r_statement
  | Sloop : r_statement -> r_statement -> r_statement
  | Sbreak : r_statement
  | Scontinue : r_statement
  | Sreturn : option r_expr -> r_statement

Record r_function : Type := mk_r_function {
  fn_return: r_type;
  (* TODO do we care about this fn_callconv: calling_convention; *)
  fn_params: list (ident * r_type);
  fn_vars: list (ident * r_type);
  fn_temps: list (ident * r_type);
  fn_body: r_statement
}.

Definition r_var_names (vars: list(ident * r_type)) : list ident :=
  List.map (@fst ident r_type) vars.

Locate Ctypes.program.
Print Ctypes.program.
Print Ctypes.Union.
Print Ctypes.composite.
Require Archi.
Require Import AST.
Print globdef.
Print globdef.

(* Record program (F : Type) : Type := Build_program *)
(*   { prog_defs : list (AST.ident * AST.globdef (fundef F) type); *)
(*     prog_public : list AST.ident; *)
(*     prog_main : AST.ident; *)
(*     prog_types : list composite_definition; *)
(*     prog_comp_env : composite_env; *)
(*     prog_comp_env_eq : build_composite_env prog_types = Errors.OK prog_comp_env } *)

Print composite_definition.
Print struct_or_union.
Print member.
Print member.

Inductive r_member : Type :=
  | RMember_plain (id: ident) (t: r_type).

Definition r_members : Type := list r_member.



(* Definition r_program := Ctypes.program r_function. *)

Inductive r_composite_definition : Type :=
  RComposite (id: ident) (su: struct_or_union) (m: r_members).

Print PTree.t.

(* TODO might not need this *)
Record r_composite : Type := {
  co_su: struct_or_union;
  co_members: r_members;
}.

Definition r_composite_env : Type := PTree.t r_composite.

Set Asymmetric Patterns.
Local Open Scope error_monad_scope.

Definition r_composite_of_def
     (env: r_composite_env) (id: ident) (su: struct_or_union) (m: r_members)
     : res r_composite :=
  match env!id, true return _ with
  | Some _, _ =>
      Error (MSG "Multiple definitions of struct or union " :: CTX id :: nil)
  | None, false =>
      Error (MSG "Incomplete struct or union " :: CTX id :: nil)
  | None, true =>
      OK {| co_su := su;
            co_members := m;
         |}
  end.

Fixpoint r_add_composite_definitions
  (env: r_composite_env) (defs: list r_composite_definition) : res r_composite_env :=

  match defs with
  | nil => OK env
  | RComposite id su m :: defs =>
      do co <- r_composite_of_def env id su m;
      r_add_composite_definitions (PTree.set id co env) defs
  end.



Definition r_build_composite_env (defs: list r_composite_definition) :=
  r_add_composite_definitions (PTree.empty _) defs.

Set Implicit Arguments.

Record r_program (F V: Type): Type := mk_r_program {
  prog_defs: list (AST.ident * AST.globdef F V);
  prog_public: list AST.ident;
  prog_main: ident;
  prog_types: list r_composite_definition;
  prog_comp_env: r_composite_env;
  prog_comp_env_eq : r_build_composite_env prog_types = Errors.OK prog_comp_env
}.
Print r_program.
Print prog_defs.

Definition r_program_applied : Type := r_program r_function r_type.


Definition program_applied := r_program r_function.

Record r_genv := { genv_genv :> Genv.t (fundef r_function) r_type; genv_cenv :> r_composite_env }.

Definition program_of_program (F V: Type) (p : r_program F V) : AST.program F V:=
  AST.mkprogram (prog_defs p) (prog_public p) (prog_main p ).

Coercion program_of_program: r_program >-> AST.program.
Print fundef.


Definition r_globalenv (p: r_program (fundef r_function) r_type) :=
  {| genv_genv := Genv.globalenv p; genv_cenv := p.(prog_comp_env) |}.

Definition r_env := PTree.t (block * r_type). (* map variable -> location & type *)

Definition r_empty_env: r_env := PTree.empty (block * r_type).

Inductive deref_loc (ty: r_type) (m: mem) (b: block) (ofs: ptrofs) : bitfield -> val -> Prop :=





Print r_program.
Print program.
Locate program.
Print Ctypes.program.
Print composite_definition.
Print member.
Print composite_env.
Print build_composite_env.
*)

  (* TODO understand signature | Smatch : expr -> r_labeled_statements -> r_statement *)
  (* TODO figure out goto and label. Rust doesn't have those. *)

(* reasons to define different rep *)
(* - flexible rep, since not exactly the same as C. ex: pointers, gotos, *)
(* - for future passes (e.g. lifting to safe code), want to represent *more* of rust's semantics *)
(* - *)
(* temp_env may be reused *)

(* Inductive fundef (F : Type) : Type := *)
(*     Internal : F -> fundef F | External : external_function -> fundef F *)

(* Record program (F V: Type) : Type := mkprogram { *)
(*   prog_defs: list (ident * globdef F V); *)
(*   prog_public: list ident; *)
(*   prog_main: ident *)
(* }. *)

