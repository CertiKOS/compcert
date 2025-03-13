(* open! Ctypes *)
open Camlcoq
open AST
open Format
open ExportBase
(* open Cop *)
open ExportCtypes
open ClightCFG

let rec print_sl fmt (sl: switch_list) =
  match sl with
  | SLcons(case_type, case_id, sl') -> (
    let case_portion =
      match case_type with
      | None -> "default case"
      | Some x -> "case " ^ (x |> camlint64_of_coqint |> Int64.to_int |> string_of_int)
    in
    fprintf fmt "(%s , %d)" case_portion (P.to_int case_id);
    print_sl fmt sl'

  )
  | SLnil(next_id) -> (
    fprintf fmt "(next id: %d)" (P.to_int next_id)

  )


let print_inst fmt (i: coq_Instruction) =
  match i with
  | Coq_i_skip -> ExportClight.stmt fmt Clight.Sskip
  | Coq_i_assign(lval, rval) ->
      let asgn = Clight.Sassign(lval, rval) in
      ExportClight.stmt fmt asgn;
  | Coq_i_set(lident, rval) ->
      let set = Clight.Sset(lident, rval) in
      ExportClight.stmt fmt set;
  | Coq_i_call(maybe_ident, e, el) ->
      let set = Clight.Scall(maybe_ident, e, el) in
      ExportClight.stmt fmt set;
  | Coq_i_builtin(maybe_ident, ef, tl, el) ->
      let set = Clight.Sbuiltin(maybe_ident, ef, tl, el) in
      ExportClight.stmt fmt set

let print_edge fmt (e: coq_BBEdge) =
  match e with
  | Coq_direct(next) -> fprintf fmt "direct %d" (P.to_int next)
  | Coq_conditional(e, lhs, rhs) -> fprintf fmt "conditional %a, true: %d false: %d" ExportClight.expr e (P.to_int lhs) (P.to_int rhs)
  | Coq_switch(e, sl) -> (
    fprintf fmt "switch %a" ExportClight.expr e;
    print_sl fmt sl
  )
  | Coq_stub -> fprintf fmt "stub"
  | Coq_terminate(e) ->
      match e with
      | None -> fprintf fmt "terminate"
      | Some(ie) -> fprintf fmt "terminate %a" ExportClight.expr ie

let print_cfg fmt (cfg: coq_BasicBlock BBMap.t) (entry: bb_uid) =
  fprintf fmt "entry: %d @ " (P.to_int entry);
  BBMap.fold
  (fun (key: bb_uid) (value: coq_BasicBlock) acc ->
    match value with
    | Coq_bb(bb_insts, bb_edge) -> (
      fprintf fmt "printing basic block %d. Instructions:" (P.to_int key);
      fprintf fmt "@ ";
      List.fold_left (fun acc inst -> print_inst fmt inst; fprintf fmt ", ") () bb_insts;
      fprintf fmt "@ ";
      fprintf fmt "printing basic block %d. Edge:" (P.to_int key);
      print_edge fmt bb_edge;
      fprintf fmt "@ ";
    );
    acc)
  cfg ()

let print_function fmt (id, f) =
  fprintf fmt "Definition f%s := {|@ " (sanitize (extern_atom id));
  (* fprintf fmt "  fn_return := %a;@ " typ f.fn_return; *)
  (* fprintf fmt "  fn_callconv := %a;@ " callconv f.fn_callconv; *)
  (* fprintf fmt "  fn_params := %a;@ " (print_list (print_pair ident typ)) f.fn_params; *)
  (* fprintf fmt "  fn_vars := %a;@ " (print_list (print_pair ident typ)) f.fn_vars; *)
  (* fprintf fmt "  fn_temps := %a;@ " (print_list (print_pair ident typ)) f.fn_temps; *)
  (* TODO should do imports, but do the data structure fixing first *)
  (* fprintf fmt "  fn_imports := %a;@ " (print_list (print_pair ident typ)) f.fn_temps; *)
  fprintf fmt "  fn_body :=@ ";
  print_cfg fmt (fst f.fn_body).map (fst f.fn_body).entry;
  fprintf fmt "@ |}.@ @ "

let print_globdef fmt (id, gd) =
  match gd with
  | Gfun(Ctypes.Internal f) -> print_function fmt (id, f)
  | Gfun(Ctypes.External _) -> ()
  | Gvar v -> print_variable typ fmt (id, v)

let print_program fmt clight_cfg_prog sourcefile
  =

    fprintf fmt "@[<v 0>";
    List.iter (print_globdef fmt) clight_cfg_prog.Ctypes.prog_defs;
    fprintf fmt "@]@."

