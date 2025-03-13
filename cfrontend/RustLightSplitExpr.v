Require Import RustLight.
Require Import Coq.Strings.String.
Require Import Errors.
Import List.ListNotations.

Definition transl_program (r_prog: r_program) : res (r_program) :=
  Error(Errors.msg "Unimplemented").


