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

Inductive lifetime : Type :=
  | Unbounded
  | Bounded: int ->  int -> lifetime.

Inductive expr : Type :=
  | Econst_int: int -> type -> lifetime -> expr       (**r integer literal *)
  | Econst_float: float -> type -> lifetime -> expr   (**r double float literal *)
  | Econst_single: float32 -> type -> lifetime -> expr (**r single float literal *)
  | Econst_long: int64 -> type -> lifetime -> expr    (**r long integer literal *)
  | Evar: ident -> type -> lifetime -> expr           (**r variable *)
  | Etempvar: ident -> type -> lifetime -> expr       (**r temporary variable *)
  | Ederef: expr -> type -> lifetime -> expr          (**r pointer dereference (unary [*]) *)
  | Eaddrof: expr -> type -> lifetime -> expr         (**r address-of operator ([&]) *)
  | Eunop: unary_operation -> expr -> type -> lifetime -> expr  (**r unary operation *)
  | Ebinop: binary_operation -> expr -> expr -> type -> lifetime -> expr (**r binary operation *)
  | Ecast: expr -> type -> lifetime -> expr   (**r type cast ([(ty) e]) *)
  | Efield: expr -> ident -> type -> lifetime -> expr (**r access to a member of a struct or union *)
  | Esizeof: type -> type -> lifetime -> expr         (**r size of a type *)
  | Ealignof: type -> type -> lifetime -> expr.       (**r alignment of a type *)

Inductive mutability : Type :=
  | Mutable
  | Immutable.

Definition typeof (e: expr) : type :=
  match e with
  | Econst_int _ ty _ => ty
  | Econst_float _ ty _ => ty
  | Econst_single _ ty _ => ty
  | Econst_long _ ty _ => ty
  | Evar _ ty _ => ty
  | Etempvar _ ty _ => ty
  | Ederef _ ty _ => ty
  | Eaddrof _ ty _ => ty
  | Eunop _ _ ty _ => ty
  | Ebinop _ _ _ ty _ => ty
  (* code for transmute intrinsic *)
  | Ecast _ ty _ => ty
  | Efield _ _ ty _ => ty
  | Esizeof _ ty _ => ty
  | Ealignof _ ty _ => ty
  end.

Inductive statement : Type :=
  | Sskip : statement                   (**r do nothing *)
  | Sassign : expr -> expr -> statement (**r assignment [lvalue = rvalue] *)
  | Sset : ident -> expr -> statement   (**r assignment [tempvar = rvalue] *)
  | Scall: option ident -> expr -> list expr -> statement (**r function call *)
  | Sbuiltin: option ident -> external_function -> typelist -> list expr -> statement (**r builtin invocation *)
  | Ssequence : statement -> statement -> statement  (**r sequence *)
  | Sifthenelse : expr  -> statement -> statement -> statement (**r conditional *)
  | Sloop: statement -> statement -> statement (**r infinite loop *)
  | Sbreak : statement                      (**r [break] statement *)
  | Scontinue : statement                   (**r [continue] statement *)
  | Sreturn : option expr -> statement      (**r [return] statement *)
  | Smatch : expr -> match_stmt  -> statement  (**r [switch] statement *)
with match_stmt : Type :=            (**r cases of a [switch] *)
  | LSunderscore: statement
  | LScons: Z -> statement -> match_stmt -> match_stmt.
.


(** The C loops are derived forms. *)

Definition Swhile (e: expr) (s: statement) :=
  Sloop (Ssequence (Sifthenelse e Sskip Sbreak) s) Sskip.

Definition Sdowhile (s: statement) (e: expr) :=
  Sloop s (Sifthenelse e Sskip Sbreak).

Definition Sfor (s1: statement) (e2: expr) (s3: statement) (s4: statement) :=
  Ssequence s1 (Sloop (Ssequence (Sifthenelse e2 Sskip Sbreak) s3) s4).

Print statement.

(** ** Functions *)

(** A function definition is composed of its return type ([fn_return]),
  the names and types of its parameters ([fn_params]), the names
  and types of its local variables ([fn_vars]), and the body of the
  function (a statement, [fn_body]). *)

Print program.

Record genv := { genv_genv :> Genv.t fundef type; genv_cenv :> composite_env }.

Definition globalenv (p: program) :=
  {| genv_genv := Genv.globalenv p; genv_cenv := p.(prog_comp_env) |}.

(** The local environment maps local variables to block references and
  types.  The current value of the variable is stored in the
  associated memory block. *)

Definition env := PTree.t (block * type). (* map variable -> location & type *)

Definition empty_env: env := (PTree.empty (block * type)).

(** The temporary environment maps local temporaries to values. *)

Definition temp_env := PTree.t val.

(** [deref_loc ty m b ofs bf v] computes the value of a datum
  of type [ty] residing in memory [m] at block [b], offset [ofs],
  and bitfield designation [bf].
  If the type [ty] indicates an access by value, the corresponding
  memory load is performed.  If the type [ty] indicates an access by
  reference or by copy, the pointer [Vptr b ofs] is returned. *)

Inductive deref_loc (ty: type) (m: mem) (b: block) (ofs: ptrofs) :
                                             bitfield -> val -> Prop :=
  | deref_loc_value: forall chunk v,
      access_mode ty = By_value chunk ->
      Mem.loadv chunk m (Vptr b ofs) = Some v ->
      deref_loc ty m b ofs Full v
  | deref_loc_reference:
      access_mode ty = By_reference ->
      deref_loc ty m b ofs Full (Vptr b ofs)
  | deref_loc_copy:
      access_mode ty = By_copy ->
      deref_loc ty m b ofs Full (Vptr b ofs)
  | deref_loc_bitfield: forall sz sg pos width v,
      load_bitfield ty sz sg pos width m (Vptr b ofs) v ->
      deref_loc ty m b ofs (Bits sz sg pos width) v.
