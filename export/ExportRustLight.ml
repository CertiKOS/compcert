(** Export Clight as a Coq file *)

(* open Format *)
(* open Camlcoq *)
(* open AST *)
open! Ctypes
open AST
open Cop
open RustLight
open Format
open Camlcoq
open ExportBase
(* open Clight *)
open ExportCtypes


let prologue = "\
From Coq Require Import String List ZArith.\n\
From compcert Require Import Coqlib Integers Floats AST Ctypes Cop RustLight.\n\
Local Open Scope Z_scope.\n\
Local Open Scope string_scope.\n"

(* Expressions *)

let name_unop = function
  | Onotbool -> "Onotbool"
  | Onotint -> "Onotint"
  | Oneg -> "Oneg"
  | Oabsfloat -> "Oabsfloat"

let name_binop = function
  | Oadd -> "Oadd"
  | Osub -> "Osub"
  | Omul -> "Omul"
  | Odiv -> "Odiv"
  | Omod -> "Omod"
  | Oand -> "Oand"
  | Oor -> "Oor"
  | Oxor -> "Oxor"
  | Oshl -> "Oshl"
  | Oshr -> "Oshr"
  | Oeq -> "Oeq"
  | Cop.One -> "One"
  | Olt -> "Olt"
  | Ogt -> "Ogt"
  | Ole -> "Ole"
  | Oge -> "Oge"

let rec expr fmt = function
  | Econst_int(n, t) ->
      fprintf fmt "(Econst_int %a %a)" coqint n typ t
  | Econst_float(n, t) ->
      fprintf fmt "(Econst_float %a %a)" coqfloat n typ t
  | Econst_single(n, t) ->
      fprintf fmt "(Econst_single %a %a)" coqsingle n typ t
  | Econst_long(n, t) ->
      fprintf fmt "(Econst_long %a %a)" coqint64 n typ t
  | Evar(id, t) ->
      fprintf fmt "(Evar %a %a)" ident id typ t
  | Efield(a1, f, t) ->
      fprintf fmt "@[<hov 2>(Efield@ %a@ %a@ %a)@]" expr a1 ident f typ t
  | Etempvar(id, t) ->
      fprintf fmt "(Etempvar %a %a)" ident id typ t
  | Ederef(a1, t) ->
      fprintf fmt "@[<hov 2>(Ederef@ %a@ %a)@]" expr a1 typ t
  | Eaddrof(a1, t) ->
      fprintf fmt "@[<hov 2>(Eaddrof@ %a@ %a)@]" expr a1 typ t
  | Eunop(op, a1, t) ->
      fprintf fmt "@[<hov 2>(Eunop %s@ %a@ %a)@]"
         (name_unop op) expr a1 typ t
  | Ebinop(op, a1, a2, t) ->
      fprintf fmt "@[<hov 2>(Ebinop %s@ %a@ %a@ %a)@]"
         (name_binop op) expr a1 expr a2 typ t
  | Ecast(a1, t) ->
      fprintf fmt "@[<hov 2>(Ecast@ %a@ %a)@]" expr a1 typ t
  | Esizeof(t1, t) ->
      fprintf fmt "(Esizeof %a %a)" typ t1 typ t
  | Ealignof(t1, t) ->
      fprintf fmt "(Ealignof %a %a)" typ t1 typ t
  (* | Eif_then_else(c, e1, e2, ty) -> *)
  (*     fprintf fmt "@[<hov 2>(Eifthenelse %a@ %a@ %a)@]" expr c expr e1 expr e2 *)
  | Enull_check(e) ->
      fprintf fmt "@[<hov 2>(Enull_check %a)@]"
         expr e

let rec stmt fmt = function
  | S_skip ->
      fprintf fmt "S_skip"
  | S_assign(e1, e2) ->
      fprintf fmt "@[<hov 2>(S_assign@ %a@ %a)@]" expr e1 expr e2
  | S_set(id, e2) ->
      fprintf fmt "@[<hov 2>(S_set %a@ %a)@]" ident id expr e2
  | S_call(optid, e1, el) ->
      fprintf fmt "@[<hov 2>(S_call %a@ %a@ %a)@]"
        (print_option ident) optid expr e1 (print_list expr) el
  | S_builtin(optid, ef, tyl, el) ->
      fprintf fmt "@[<hov 2>(S_builtin %a@ %a@ %a@ %a)@]"
        (print_option ident) optid
        external_function ef
        typlist tyl
        (print_list expr) el
  | S_sequence(S_skip, s2) ->
      stmt fmt s2
  | S_sequence(s1, S_skip) ->
      stmt fmt s1
  | S_sequence(s1, s2) ->
      fprintf fmt "@[<hv 2>(S_sequence@ %a@ %a)@]" stmt s1 stmt s2
  | S_if_then_else(e, s1, s2) ->
      fprintf fmt "@[<hv 2>(S_if_then_else %a@ %a@ %a)@]" expr e stmt s1 stmt s2
  | S_exit(e) ->
      fprintf fmt "@[<hv 2>(S_exit %a)@]" expr e
  | S_return (None) ->
      fprintf fmt "@[<hv 2>(S_return)@]"
  | S_return (Some(e, t)) ->
      fprintf fmt "@[<hv 2>(S_return %a %a)@]" expr e typ t
  | S_break(maybe_lbl) ->
      fprintf fmt "@[<hv 2>(S_break %a)@]" (print_option coqZ) maybe_lbl
  | S_continue(maybe_lbl) ->
      fprintf fmt "@[<hv 2>(S_continue %a)@]" (print_option coqZ) maybe_lbl
  (* TODO fix *)
  | _ ->
      fprintf fmt "unimplemented!"

let print_function fmt (id, f) =
  fprintf fmt "Definition f%s := {|@ " (sanitize (extern_atom id));
  fprintf fmt "  fn_return := %a;@ " typ f.fn_return;
  (* fprintf fmt "  fn_callconv := %a;@ " callconv f.fn_callconv; *)
  fprintf fmt "  fn_params := %a;@ " (print_list (print_pair ident typ)) f.fn_params;
  fprintf fmt "  fn_vars := %a;@ " (print_list (print_pair ident typ)) f.fn_vars;
  fprintf fmt "  fn_temps := %a;@ " (print_list (print_pair ident typ)) f.fn_temps;
  (* TODO should do imports, but do the data structure fixing first *)
  (* fprintf fmt "  fn_imports := %a;@ " (print_list (print_pair ident typ)) f.fn_temps; *)
  fprintf fmt "  fn_body :=@ ";
  stmt fmt f.fn_body;
  fprintf fmt "@ |}.@ @ "

(* Naming the compiler-generated temporaries occurring in the program *)

let rec name_expr = function
  | Evar(id, t) -> ()
  | Etempvar(id, t) -> name_temporary id
  | Ederef(a1, t) -> name_expr a1
  | Efield(a1, f, t) -> name_expr a1
  | Econst_int(n, t) -> ()
  | Econst_float(n, t) -> ()
  | Econst_long(n, t) -> ()
  | Econst_single(n, t) -> ()
  | Eunop(op, a1, t) -> name_expr a1
  | Eaddrof(a1, t) -> name_expr a1
  | Ebinop(op, a1, a2, t) -> name_expr a1; name_expr a2
  | Ecast(a1, t) -> name_expr a1
  | Esizeof(t1, t) -> ()
  | Ealignof(t1, t) -> ()
  | Enull_check(e) -> name_expr e
  (* | Eif_then_else(c, e1, e2, _ty) -> name_expr c; name_expr e1; name_expr e2 *)

let rec name_stmt = function
  | S_skip -> ()
  | S_assign(e1, e2) -> name_expr e1; name_expr e2
  | S_set(id, e2) -> name_temporary id; name_expr e2
  | S_call(optid, e1, el) ->
      name_opt_temporary optid; name_expr e1; List.iter name_expr el
  | S_builtin(optid, ef, tyl, el) ->
      name_opt_temporary optid; List.iter name_expr el
  | S_sequence(s1, s2) -> name_stmt s1; name_stmt s2
  | S_if_then_else(e, s1, s2) -> name_expr e; name_stmt s1; name_stmt s2
  (* | Sloop(s1, s2) -> name_stmt s1; name_stmt s2 *)
  | S_break(Some(lbl)) -> () (* TODO  *)
  | S_break None -> ()
  | S_continue None -> ()
  | S_continue(Some(lbl)) -> () (* TODO  *)
  | S_return (Some e) -> name_expr (fst e)
  | S_return None -> ()
  | _ -> () (* TODO fix this  *)


let name_function f =
  List.iter (fun (id, ty) -> name_temporary id) f.fn_temps;
  name_stmt f.fn_body

let name_globdef (id, g) =
  match g with
  | Gfun(Ctypes.Internal f) -> name_function f
  | _ -> ()

let name_program p =
  List.iter name_globdef p.Ctypes.prog_defs

let print_globdef fmt (id, gd) =
  match gd with
  | Gfun(Ctypes.Internal f) -> print_function fmt (id, f)
  | Gfun(Ctypes.External _) -> ()
  | Gvar v -> print_variable typ fmt (id, v)

let print_ident_globdef p = function
  | (id, Gfun(Ctypes.Internal f)) ->
      fprintf p "(%a, Gfun(Internal f%s))" ident id (sanitize (extern_atom id))
  | (id, Gfun(Ctypes.External(ef, targs, tres, cc))) ->
      fprintf p "@[<hov 2>(%a,@ @[<hov 2>Gfun(External %a@ %a@ %a@ %a))@]@]"
        ident id external_function ef typlist targs typ tres callconv cc
  | (id, Gvar v) ->
      fprintf p "(%a, Gvar v%s)" ident id (sanitize (extern_atom id))

let print_program fmt r_prog sourcefile  glbl_mapping struct_mapping mod_name=
  Hashtbl.clear temp_names;
  name_program r_prog;

  fprintf fmt "@[<v 0>";
  fprintf fmt "%s" prologue;
  print_gen_info ~sourcefile ~normalized:false fmt;
  define_idents fmt;
  List.iter (print_globdef fmt) r_prog.Ctypes.prog_defs;
  fprintf fmt "Definition composites : list composite_definition :=@ ";
  print_list print_composite_definition fmt r_prog.prog_types;
  fprintf fmt "Definition global_definitions : list (ident * globdef fundef type) :=@ ";
  print_list print_ident_globdef fmt r_prog.Ctypes.prog_defs;
  fprintf fmt ".@ @ ";
  fprintf fmt "Definition public_idents : list ident :=@ ";
  print_list ident fmt r_prog.Ctypes.prog_public;
  fprintf fmt ".@ @ ";
  fprintf fmt "Definition prog : RustLight.r_program := @ ";
  fprintf fmt "  mkprogram composites global_definitions public_idents %a Logic.I.@ @ "
            ident r_prog.Ctypes.prog_main;
  fprintf fmt "@]@."
