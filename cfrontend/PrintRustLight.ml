open Format
open! Ctypes
open AST
open Camlcoq (*for extern_atom*)
open RustLight



let pretty_print_hashtbl tbl =
  Format.printf "UUID {@.";
  Hashtbl.iter (fun key value ->
      match value with
      | Some(s, _) -> Format.printf "UUID  %s -> Some %s@,\n" key s
      | None -> Format.printf "UUID  %s -> None @,\n" key
  ) tbl;
  Format.printf "UUID}@."

(*open Camlcoq
open PrintAST
open Ctypes
open Cop
open PrintCsyntax
open Clight*)
(* open RustLight *)

let temp_name (id: AST.ident) =
  try
    "tmp_id_" ^ Hashtbl.find string_of_atom id
  with Not_found ->
    Printf.sprintf "tmp_id_%d" (P.to_int id)

let destination : string option ref = ref None

let name_inttype_rust sz sg =
  match sz, sg with
  | I8, Signed -> "libc::c_schar"
  | I8, Unsigned -> "libc::c_uchar"
  | I16, Signed -> "libc::c_short"
  | I16, Unsigned -> "libc::c_ushort"
  | I32, Signed -> "libc::c_int"
  | I32, Unsigned -> "libc::c_uint"
  (* using bool here, unsure of correctness since libc doesn't have _Bool *)
  | IBool, _ -> "bool"

let name_floattype_rust sz =
  match sz with
  | F32 -> "libc::c_float"
  | F64 -> "libc::c_double"

let name_longtype_rust sz =
  match sz with
  | Signed -> "libc::c_longlong"
  | Unsigned -> "libc::c_ulonglong"

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
  | Ctypes.Tstruct(id, attr) -> (extern_atom id)
  | Ctypes.Tunion(id, attr) -> (extern_atom id)
  | Ctypes.Tfloat(sz, a) -> name_floattype_rust sz
  | Ctypes.Tlong(sz, a) -> name_longtype_rust sz
  | Ctypes.Tpointer(ty, _a) -> sprintf "*mut %s" (gen_ty_rust ty)
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
  let linkage = if C2C.atom_is_static id then "" else "pub " in
  (* TODO deal with extern. Can't just assume it's const or static *)

  (* need to do static analysis pass to conclude that this is actually static mut *)
  (* in rust, const a : u32 = 5; ensure (with the compiler) that a is not writable. Ever *)
  (* in c, const int a = 5; void f(){ *(&a) = 6; } works just fine*)

  (* TODO if static in C, should become `pub` here *)
  let name = linkage^"static mut "^name_bare in
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
  | Econst_int(n, ty) ->
    fprintf fmt "(%ld as %s)" (camlint_of_coqint n) (gen_ty_rust ty)
  | Econst_float(f, ty) ->
    fprintf fmt "(%.18g as %s)" (camlfloat_of_coqfloat f) (gen_ty_rust ty)
  | Econst_single(f, ty) ->
    fprintf fmt "(%.18g as %s)" (camlfloat_of_coqfloat32 f) (gen_ty_rust ty)
  | Econst_long(n, Ctypes.Tlong(Unsigned, _)) ->
    fprintf fmt "%LuLLU" (camlint64_of_coqint n)
  | Econst_long(n, _) ->
    fprintf fmt "%LdLL" (camlint64_of_coqint n)
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
  | RustLight.Efield (exp, id, ty) -> fprintf fmt "%a.%s" print_expr exp (extern_atom id)
  | RustLight.Ederef (exp, _ty) -> fprintf fmt "(*%a)" print_expr exp
  (* TODO broken for globals. Need to special case that. *)
  | RustLight.Eaddrof (exp, _) ->
    fprintf fmt "(std::ptr::addr_of_mut!(%a))" print_expr exp
  | RustLight.Ecast (expr, ty) ->
    (* somewhat complicated because we might want to use *)
    (* `as` on pointers *)
    (* or https://doc.rust-lang.org/std/mem/fn.transmute.html *)
    fprintf fmt "TODO casts are unimplemented"
  | RustLight.Esizeof (ty, ty') ->
    fprintf fmt "(std::mem::sizeof::<%s>() as %s)" (gen_ty_rust ty) (gen_ty_rust ty')
  | RustLight.Ealignof (ty, ty') ->
    fprintf fmt "(std::mem::alignof::<%s>() as %s)" (gen_ty_rust ty) (gen_ty_rust ty')

let rec print_arglist fmt arglist =
  match arglist with
  | [arg] ->
    fprintf fmt "%a" print_expr arg
  | arg :: al ->
    fprintf fmt "%a, " print_expr arg; print_arglist fmt al
  | nil -> ()


let rec print_stmt fmt body =
  match body with
  | S_skip -> fprintf fmt "/* skip stmt */@;";
  | S_assign(e1, e2) -> fprintf fmt "@[<hv 2>%a =@ %a;@]@;" print_expr e1 print_expr e2;
  | S_set(id, e) -> fprintf fmt "@[<hv 2>%s =@ %a;@]@;" (temp_name id) print_expr e;
  | S_return(Some exp) -> fprintf fmt "return %a;@;" print_expr exp
  | S_return(None) -> fprintf fmt "return;@;"
  | S_sequence(RustLight.S_skip, s2) -> print_stmt fmt s2
  | S_sequence(s1, RustLight.S_skip) -> print_stmt fmt s1
  | S_sequence(e1, e2) -> fprintf fmt "%a@;%a" print_stmt e1 print_stmt e2
  | S_continue(None) -> fprintf fmt "continue;"
  | S_continue(Some(lbl)) -> fprintf fmt "continue 'lbl_%ld;" (camlint_of_coqint lbl)
  | S_if_then_else(exp, s_true, S_skip)  -> (
      fprintf fmt "@[<v 2>if %a {@;%a@;<0 -2>}@]@;" print_expr exp print_stmt s_true
    )
  | S_if_then_else(exp, S_skip, s_false)  -> (
      fprintf fmt "@[<v 2>if !(%a) {@;%a@;<0 -2>}@]@;" print_expr exp print_stmt s_false
    )
  | S_if_then_else(exp, s_true, s_false)  -> (
      fprintf fmt "@[<v 2>if %a {@;%a@;<0 -2>} else {@;%a@;<0 -2>}@]@;"
        print_expr exp print_stmt s_true print_stmt s_false
    )
  | S_break(None) -> fprintf fmt "break; @;"
  | S_break(Some(lbl)) -> fprintf fmt "break 'lbl_%ld; @;" (camlint_of_coqint lbl)
  | S_builtin(maybe_ident, external_fn, lty,  lexp) -> fprintf fmt "unimplemented call stmt"
  | S_loop(None, stmt, S_skip) -> (
      fprintf fmt "@[<v 2>loop {@;%a@;<0 -2>}@]@;"
              print_stmt stmt
    )
  | S_loop(Some(lbl), stmt, S_skip) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]@;"
              (camlint_of_coqint lbl) print_stmt stmt
    )
  | S_loop(Some(lbl), stmt, stmt2) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;%a@;<0 -2>}@]@;"
              (camlint_of_coqint lbl) print_stmt stmt print_stmt stmt2
    )
  | S_match_int(expr, stmts) -> (
      fprintf fmt "@[<v 2>match %a {@;%a@;<0 -2>};@]@;" print_expr expr print_cases stmts;
    )
  (* the difference between these two cases is the assignment to a temporary var vs discard *)
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
      fprintf fmt "@[<v 2>_ => () @]@;";
  | LScons (n, body, stmts) ->
      fprintf fmt "@[<v 2>%s => {@;%a@;<0 -2>}@]@;" (Z.to_string n) print_stmt body;
      print_cases fmt stmts

(* fn name(param: ty, ) -> { body  }*)
let print_function fmt id fn =
  let fn_name = (extern_atom id) in
  let fn_params = fn.fn_params in
  let fn_linkage = if C2C.atom_is_static id then "" else "pub " in
  let fn_args = List.fold_left (fun acc (tid, tty) -> acc ^ (gen_name_and_ty_rust (extern_atom tid) tty) ^ ", ") ("") fn_params in
  (* let params = name_function_parameters extern_atom (extern_atom id) f.fn_params f.fn_callconv in *)
  (* TODO deal with visibility modifier *)
  fprintf fmt "#[no_mangle]@ %sunsafe extern \"C\" fn %s(%s) -> %s" fn_linkage fn_name fn_args (gen_ty_rust fn.fn_return);
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
  | Ctypes.External(_, _, _, _) ->  fprintf fmt ""


let print_globdef fmt (id, gd) =
  match gd with
  | Gfun fundef -> print_fundef fmt id fundef
  | Gvar v -> print_globvar fmt id v

let struct_or_union = function Struct -> "struct" | Union -> "union"

let print_member fmt = function
  | Member_plain(id, ty) ->
    fprintf fmt "@; %s," (gen_name_and_ty_rust (extern_atom id) ty)
  | _ -> ()

let define_composite fmt (Composite(id, su, m, a)) =
  (* let linkage = C2C.atom_is_static *)
  let maybe_aligned =
    match a.attr_alignas with
    | None -> ""
    | Some n -> sprintf ", align(%Ld)" (Int64.shift_left 1L (N.to_int n))
  in

  fprintf fmt "#[repr(C%s)]@;@[<v 2>pub%s %s {" maybe_aligned (struct_or_union su) (extern_atom id);
  List.iter (print_member fmt) m;
  fprintf fmt "@;<0 -2>}@]@; @;"

module StringSet = Set.Make(String)

let get_fn_foreign_syms mapping list_of_ids cur_sym_map =
  printf "UID list of ids %d\n" (List.length list_of_ids);
  List.fold_left
    (fun acc id ->
       let name = extern_atom id in
       let maybe_module = Hashtbl.find_opt mapping name in
       match maybe_module with
       | None -> printf "UID couldn't find module for symbol %s in mapping\n" name; acc
       | Some module_ ->
         let maybe_hs = Hashtbl.find_opt acc module_ in
         match maybe_hs with
         | None ->
           let new_hs = StringSet.singleton name in
           Hashtbl.replace acc module_ new_hs;
           acc
         | Some hs ->
           let new_hs = StringSet.add name hs in
           Hashtbl.replace acc module_ new_hs;
           acc
    )
    cur_sym_map list_of_ids


let [@warning "-42"] gen_imports
    (sym_mapping: (string, string) Hashtbl.t)

    (fn_defs: ((AST.ident * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) list))

    composite_mapping
    prog_types
    mod_name

  : ((string, StringSet.t) Hashtbl.t * _) =
  let imports_from_gbls_syms = List.fold_left
    (fun acc (elt: (AST.ident * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)) ->
       match elt with
       | id, Gvar v ->  if (List.length v.gvar_init == 0) then get_fn_foreign_syms sym_mapping [id] acc else acc
       | _id, Gfun f -> (
           match f with
           | Internal rf -> (
               get_fn_foreign_syms sym_mapping (List.map fst (Maps.PTree.elements rf.fn_imports)) acc
             )
           | External _ -> acc
       )
    )
    (Hashtbl.create 7) fn_defs in
  let defined_in_module  =
    List.filter (
      fun dfn ->
        let r = match dfn with | Composite(id, _,  _, _) -> extern_atom id in
        match Hashtbl.find_opt composite_mapping r with
        (* not possible? *)
        | None -> printf "UUID: NOT FOUND STRUCT %s" r; false
        (* might be external to module *)
        | Some (Some (mname, _)) -> printf "\nUUID: mod name %s, %s len modname: %d, nmame %d, eq %b\n" mod_name mname (String.length mod_name) (String.length mname) (mname = mod_name) ; mname = mod_name
        (* internal to module *)
        | Some (None) -> true
    ) prog_types in
  let imports_from_composite = List.fold_left (
    fun (acc : (string, StringSet.t) Hashtbl.t) elt -> (
        let r = match elt with | Composite(id, _,  _, _) -> extern_atom id in
        match Hashtbl.find_opt composite_mapping r with
        (* internal to module *)
        | Some(None) -> acc
        (* not possible? *)
        | None -> printf "NOT FOUND STRUCT %s" r; acc
        (* might be external to module *)
        | Some (Some (mname, _)) -> (
          if mname == mod_name then
            acc
          else
            match Hashtbl.find_opt acc mname with
            | Some hs -> Hashtbl.replace acc mname (StringSet.add r hs); acc
            | None -> acc
      )
  )) imports_from_gbls_syms prog_types in
  (imports_from_composite, defined_in_module)

let print_imports fmt (import_map: (string, StringSet.t) Hashtbl.t) (composite_import_map) =
  Hashtbl.iter (fun module_ impts ->
        fprintf fmt "@[";
        let elts = StringSet.elements impts in
        let size = List.length elts in
        (if size == 1 then
          let ele = List.hd elts in
          fprintf fmt "use crate::%s::%s;" module_ ele
        else (
          fprintf fmt "use crate::%s::{" module_;
          List.iter (fun x -> fprintf fmt "%s, " x) elts;
          fprintf fmt "};"
        ));
        fprintf fmt "@]@;"
      ) import_map;
  fprintf fmt "@;"

let print_program (sym_mapping: (string, string) Hashtbl.t) composite_mapping mod_name f (prog: RustLight.r_program) =
  let [@warning "-42"] p_defs = prog.prog_defs in
  let [@warning "-42"] p_types = prog.prog_types in

  let (imports, in_module_composite_dfns) = gen_imports sym_mapping p_defs composite_mapping p_types mod_name in

  fprintf f "@[<v 0>";

  (* do printing  *)

  print_imports f imports composite_mapping;

  List.iter (fun x -> printf "\nUUID IN MODULE %s: print struct %s\n" mod_name (match x with | Ctypes.Composite(id, _, _, _) -> extern_atom id)) in_module_composite_dfns;

  List.iter (define_composite f) in_module_composite_dfns;
  List.iter (print_globdef f) p_defs;
  fprintf f "@]@."

let change_directory dir_name =
  try
    Unix.chdir dir_name;  (* Change the current working directory *)
  with
  | Unix.Unix_error (err, _, _) ->
    Printf.printf "Error changing directory: %s\n" (Unix.error_message err)

let fix_mapping_types (mapping: (char list * char list) list) : (string, string) Hashtbl.t =
  let elts = List.map (fun (a, b) -> (String.of_seq (List.to_seq a), String.of_seq (List.to_seq b))) mapping in
  List.fold_left (fun acc (k, v) -> Hashtbl.replace acc k v; acc) (Hashtbl.create 7) elts

let fix_mapping_types_2 (mapping: (char list * ((char list * Ctypes.composite_definition) option)) list) : (string, (string * Ctypes.composite_definition) option) Hashtbl.t =
  let elts = List.map (fun (k, opt_v) ->
    let k_str = String.of_seq (List.to_seq k) in
    let v_opt = match opt_v with
      | None -> None
      | Some (v_list, dfn) ->
        let v_str = String.of_seq (List.to_seq v_list) in
        Some (v_str, dfn)
    in
    (k_str, v_opt)
  ) mapping in
  let tbl = Hashtbl.create 7 in
  List.iter (fun (k, v_opt) -> Hashtbl.add tbl k v_opt) elts;
  tbl


let print_if
    (clunky_sym_mapping: (char list * char list) list)
    (clunky_composite_mapping: (char list * ((char list * Ctypes.composite_definition) option)) list)
    (clunky_mod_name: char list)
    prog =
  match !destination with
  | None -> ()
    (* printf "%s" "Camels\n"; *)
  | Some f ->
    let sym_mapping = fix_mapping_types clunky_sym_mapping in
    let composite_mapping = fix_mapping_types_2 clunky_composite_mapping in
    let mod_name = List.to_seq clunky_mod_name |> String.of_seq in
    printf "\nUUID mod_name %s\n" mod_name;
    (* let len_mapping = Hashtbl.length mapping in *)
    printf "UUID hashtbl";
    pretty_print_hashtbl composite_mapping;
    change_directory "./rust_project/src/";
    let oc = open_out f in
    print_program sym_mapping composite_mapping mod_name (formatter_of_out_channel oc) prog;
    close_out oc;
    change_directory "../..";

(* TODOS undo the c2c hack *)
