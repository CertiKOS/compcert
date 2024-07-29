open Format
open! Ctypes
open AST
open Camlcoq (*for extern_atom*)
open RustLight
(*open Camlcoq
open PrintAST
open Ctypes
open Cop
open PrintCsyntax
open Clight*)
(* open RustLight *)

  (* let lt = Unbounded in *)
  (* match lt with *)
  (* | Unbounded -> fprintf p "@[<v 0> It works hello world @]@wtwasdfjaksdfkjsdkjasdjfkasdfajsdkfaa\n\n\n\n\n\n\n" *)
  (* | Bounded (_, _) -> fprintf p "It extra works hello world\n" *)

let temp_name (id: AST.ident) =
  try
    "tmp_id_" ^ Hashtbl.find string_of_atom id
  with Not_found ->
    Printf.sprintf "tmp_id_%d" (P.to_int id)

let destination : string option ref = ref None

let define_composite p (Composite(id, su, m, a)) = ()


let name_inttype_rust sz sg =
  match sz, sg with
  | I8, Signed -> "libc::c_schar"
  | I8, Unsigned -> "libc::c_uchar"
  | I16, Signed -> "libc::c_short"
  | I16, Unsigned -> "libc::c_ushort"
  | I32, Signed -> "libc::c_int"
  | I32, Unsigned -> "libc::c_uint"
  (* using bool here, unsure of corretness *)
  | IBool, _ -> "bool"

let rec gen_ty_rust ty =
  match ty with
  | Ctypes.Tvoid -> "libc::c_void"
  | Ctypes.Tint(sz, sg, a) ->
    (* TODO ignoring the attributes for now. The volatile should be handled a layer up probably. Same for align? Either way going for the easy thing *)
    (* TODO deal with visibility modifier *)
    name_inttype_rust sz sg
  | Ctypes.Tarray(ity, num_ele, attrs) ->
    let fmted_ity = gen_ty_rust ity in
    sprintf "[ %s; %ld]"  fmted_ity (camlint_of_coqint num_ele)
  | _ -> "unimplemented!"

(* TODO control-flow precedence *)

let gen_name_and_ty_rust name ty = name ^ " : " ^ (gen_ty_rust ty)

let print_primitive_init fmt = function
  | Init_int8 n -> fprintf fmt"%ld" (camlint_of_coqint n)
  | Init_int16 n -> fprintf fmt "%ld" (camlint_of_coqint n)
  | Init_int32 n -> fprintf fmt "%ld" (camlint_of_coqint n)
  | Init_int64 n -> fprintf fmt "%LdLL" (camlint64_of_coqint n)
  | Init_float32 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_float64 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_space n -> fprintf fmt "/* skip %s */@ " (Z.to_string n)
  | Init_addrof(symb, ofs) -> () (* TODO *)
      (* let ofs = camlint_of_coqint ofs in *)
      (* if ofs = 0l *)
      (* then fprintf p "&%s" (extern_atom symb) *)
      (* else fprintf p "(void *\)((char *\)&%s + %ld)" (extern_atom symb) ofs *)

let print_globvar fmt id v =
  let name_bare = extern_atom id in
  (* TODO deal with extern. Can't just assume it's const or static *)

  (* need to do static analysis pass to conclude that this is actually static mut *)
  (* in rust, const a : u32 = 5; ensure (with the compiler) that a is not writable. Ever *)
  (* in c, const int a = 5; void f(){ *(&a) = 6; } works just fine*)

  (* TODO if static in C, should become `pub` here *)
  let name = "static mut "^name_bare in
  match v.gvar_init with
  (* no data, declared somewhere else *)
  | [] -> ()
    (* morally speaking, want a use statement *)
    (* we DONT need to redeclare it *)
    (* this means we need to track the crates (and generate a lib.rs) *)
    (* not there yet, however. *)
    (* so, do nothing. *)
    (* fprintf fmt "extern %s; @ @ " name; *)
  | [Init_space _] ->
    (* TODO pretty sure this is not right  *)
    fprintf fmt "%s; @ @ " (gen_name_and_ty_rust name v.gvar_info)
  | _ ->
    fprintf fmt "@[<hov 2>%s = " (gen_name_and_ty_rust name v.gvar_info);
    begin match v.gvar_info, v.gvar_init with
      | (Ctypes.Tint _ | Ctypes.Tlong _ | Ctypes.Tfloat _ | Tpointer _ | Tfunction _),
        [i1] -> print_primitive_init fmt i1
      | _, il -> () (* TODO this for string support  *)
    end;
  fprintf fmt ";@]@ @ "

let rec print_expr fmt e =
  match e with
  | Econst_int(n, Ctypes.Tint(I32, Unsigned, _)) ->
    fprintf fmt "%luU" (camlint_of_coqint n)
  | Econst_int(n, Ctypes.Tint(IBool, _, _)) ->
    fprintf fmt "%s"
    begin match (camlint_of_coqint n) with
    | 0l -> "false"
    | 1l -> "true"
    | _ -> "ERROR bool is outside {0, 1}"
    end
  (* TODO fix type issue*)
  | Econst_int(n, _) ->
    fprintf fmt "%ld" (camlint_of_coqint n)
  | Econst_float(f, _) ->
    fprintf fmt "%.18g" (camlfloat_of_coqfloat f)
  | Econst_single(f, _) ->
    fprintf fmt "%.18gf" (camlfloat_of_coqfloat32 f)
  | Econst_long(n, Ctypes.Tlong(Unsigned, _)) ->
    fprintf fmt "%LuLLU" (camlint64_of_coqint n)
  | Econst_long(n, _) ->
    fprintf fmt "%LdLL" (camlint64_of_coqint n)
  (* | RustLight.Empty -> fprintf fmt "/* TODO remove. Placeholder */" *)
  | RustLight.Evar (id, _ty) -> fprintf fmt "%s" (extern_atom id)
  | RustLight.Etempvar (id, _ty) -> fprintf fmt "%s" (temp_name id)
  | RustLight.Eunop (op_ty, exp, _ty) ->
    (
      let op_name =
      begin match op_ty with
      | Cop.Onotbool -> "!"
      | Cop.Onotint -> "!"
      | Cop.Oneg -> "-"
      | Cop.Oabsfloat -> "UNSUPPORTED OP"
      end
      in
      fprintf fmt "%s%a" op_name print_expr exp;
    )
  | RustLight.Ebinop (op_type, e1, e2, ty) ->
    (
      let op_name =
        begin match op_type with
        | Cop.Oadd -> "+"
        | Cop.Osub -> "-"
        | Cop.Omul -> "*"
        | Cop.Odiv -> "/"
        | Cop.Omod -> "%"
        | Cop.Oand -> "&"
        | Cop.Oor  -> "|"
        | Cop.Oxor -> "^"
        | Cop.Oshl -> "<<"
        | Cop.Oshr -> ">>"
        | Cop.Oeq  -> "=="
        | Cop.One  -> "!="
        | Cop.Olt  -> "<"
        | Cop.Ogt  -> ">"
        | Cop.Ole  -> "<="
        | Cop.Oge  -> ">="
        end
      in
      fprintf fmt "(%a %s %a)" print_expr e1 op_name print_expr e2
    )
  | RustLight.Ederef (_, _) -> fprintf fmt "unimplemented ederef"
  | RustLight.Eaddrof (_, _) -> fprintf fmt "unimplemented addrof"
  | RustLight.Ecast (_, _) -> fprintf fmt "unimplemented ecast"
  | RustLight.Efield (_, _, _) -> fprintf fmt "unimplemented efield"
  | RustLight.Esizeof (_, _) -> fprintf fmt "unimplemented esizeof"
  | RustLight.Ealignof (_, _) -> fprintf fmt "unimplemented ealignof"

let rec print_arglist fmt arglist =
  match arglist with
  | [arg] ->
    fprintf fmt "%a" print_expr arg
  | arg :: al ->
    fprintf fmt "%a, " print_expr arg; print_arglist fmt al
  | nil -> ()


let rec print_stmt fmt body =
  match body with
  | S_skip -> fprintf fmt "/* skip stmt */";
  | S_assign(e1, e2) -> fprintf fmt "@[<hv 2>%a =@ %a;@]@ " print_expr e1 print_expr e2;
  | S_set(id, e) -> fprintf fmt "@[<hv 2>%s =@ %a;@]@ " (temp_name id) print_expr e;
  | S_return(Some exp) -> fprintf fmt "return %a;@ " print_expr exp
  | S_return(None) -> fprintf fmt "return;@ "
  | S_sequence(RustLight.S_skip, s2) -> print_stmt fmt s2
  | S_sequence(s1, RustLight.S_skip) -> print_stmt fmt s1
  | S_sequence(e1, e2) -> fprintf fmt "%a@ %a" print_stmt e1 print_stmt e2
  | S_continue(None) -> fprintf fmt "continue;"
  | S_continue(Some(lbl)) -> fprintf fmt "continue 'lbl_%ld;" (camlint_of_coqint lbl)
  | S_if_then_else(exp, s_true, S_skip)  -> (
      fprintf fmt "@[<v 2>if %a {@ %a@;<0 -2>}@]" print_expr exp print_stmt s_true
    )
  | S_if_then_else(exp, S_skip, s_false)  -> (
      fprintf fmt "if !(%a) { @ %a; @ }" print_expr exp print_stmt s_false
    )
  | S_if_then_else(exp, s_true, s_false)  -> (
      fprintf fmt "if %a { %a; } else { %a; }"
        print_expr exp print_stmt s_true print_stmt s_false
    )
  | S_break(None) -> fprintf fmt "break; @,"
  | S_break(Some(lbl)) -> fprintf fmt "break 'lbl_%ld; @," (camlint_of_coqint lbl)
  | S_builtin(maybe_ident, external_fn, lty,  lexp) -> fprintf fmt "unimplemented call stmt"
  | S_loop(None, stmt, S_skip) -> (
      fprintf fmt "@[<v 2>loop {@ %a@;<0 -2>}@]"
              print_stmt stmt
    )
  | S_loop(Some(lbl), stmt, S_skip) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@ %a@;<0 -2>}@]"
              (camlint_of_coqint lbl) print_stmt stmt
    )
  | S_match_int(expr, stmts) -> (
      fprintf fmt "@[<v 2>match %a {@ %a@;<0 -2>};@]" print_expr expr print_cases stmts;
    )
  | S_call(Some(id), name, arg_list) -> (
      fprintf fmt "@[<hv 2>%s =@ %a@,(@[<hov 0>%a@]);@]"
        (temp_name id)
        print_expr name
        print_arglist arg_list
    )
  | S_call(None, name, arg_list) -> (
      fprintf fmt "@[<hv 2>%a@,(@[<hov 0>%a@]);@]"
        print_expr name
        print_arglist arg_list
    )
  | _ -> fprintf fmt "unimplemented?!"

and print_cases fmt cases =
  match cases with
  | LSnil ->
      fprintf fmt "@[<v 2>_ => () @]@,";
  | LScons (n, body, stmts) ->
      fprintf fmt "@[<v 2>%s => {@,%a@;<0 -2>}@]@," (Z.to_string n) print_stmt body;
      print_cases fmt stmts



(* fn name(param: ty, ) -> { body  }*)
let print_function fmt id fn =
  let fn_name = (extern_atom id) in
  let fn_params = fn.fn_params in
  let fn_args = List.fold_left (fun acc (tid, tty) -> acc ^ (gen_name_and_ty_rust (extern_atom tid) tty) ^ ", ") ("") fn_params in
  (* let params = name_function_parameters extern_atom (extern_atom id) f.fn_params f.fn_callconv in *)
  (* TODO deal with visibility modifier *)
  fprintf fmt "#[no_mangle]@ unsafe extern \"C\" fn %s(%s) -> %s" fn_name fn_args (gen_ty_rust fn.fn_return);
  fprintf fmt "@ @[<v 2>{@ ";
  (* TODO find an example that uses this *)
  List.iter (fun (vid, vty) -> fprintf fmt "let mut %s;@ " (gen_name_and_ty_rust (extern_atom vid) vty) ) fn.fn_vars;

  (* TODO find an example that uses this *)
  List.iter (fun (vid, vty) -> fprintf fmt "let mut %s;@ " (gen_name_and_ty_rust (temp_name vid) vty) ) fn.fn_temps;

  print_stmt fmt fn.fn_body;

  (* print statements + vars *)
  fprintf fmt "@;<0 -2>}@]@ @ "

let print_fundef fmt id fundef =
  match fundef with
  | Ctypes.Internal f -> print_function fmt id f
  (* don't need extern to be printed. However, do need use*)
  (* TODO print use keyword here *)
  | Ctypes.External(_, _, _, _) ->  ()


let print_globdef fmt (id, gd) =
  match gd with
  | Gfun fundef -> print_fundef fmt id fundef
  | Gvar v -> print_globvar fmt id v

let print_program f (prog: RustLight.r_program) =
  let [@warning "-42"] p_types = prog.prog_types in
  let [@warning "-42"] p_defs = prog.prog_defs in
  fprintf f "@[<v 0>";
  List.iter (define_composite f) p_types;
  List.iter (print_globdef f) p_defs;
  fprintf f "@]@."

let print_if (_, prog) =
  match !destination with
  | None -> ()
    (* printf "%s" "Camels\n"; *)
  | Some f ->
    let oc = open_out f in
    print_program (formatter_of_out_channel oc) prog;
    close_out oc;
