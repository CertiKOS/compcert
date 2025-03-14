open Format
open! Ctypes
open AST
open Camlcoq (*for extern_atom*)
open RustLight
exception Panic of string

(* pulled from https://doc.rust-lang.org/book/appendix-01-keywords.html *)
module StringSet = Set.Make(String)
let rust_keywords  = StringSet.of_list [
  "as";
  "async";
  "await";
  "break";
  "const";
  "continue";
  "crate";
  "dyn";
  "else";
  "enum";
  "extern";
  "false";
  "fn";
  "for";
  "if";
  "impl";
  "in";
  "let";
  "loop";
  "match";
  "mod";
  "move";
  "mut";
  "pub";
  "ref";
  "return";
  "Self";
  "self";
  "static";
  "struct";
  "super";
  "trait";
  "true";
  "type";
  "union";
  "unsafe";
  "use";
  "where";
  "while";
  "abstract";
  "become";
  "box";
  "do";
  "final";
  "macro";
  "override";
  "priv";
  "try";
  "typeof";
  "unsized";
  "virtual";
  "yield"
]

(* HACK the proper solution is to add to this map in process_c *)
let extern_atom_r a =
  try
    let res = Hashtbl.find string_of_atom a in
    (* let _ = printf "NAMEVAR: %s\n" res in *)
    if res = "main" then "main_2" else
      (* if StringSet.mem res rust_keywords then "r#" ^ res else res *)
      res
  with Not_found ->
    "main"

(* open TODOs: *)
(* - IMPLICIT CONVERSIONS !*)
(*   - assignment void* to any pointer type  *)
(*   - promotions in binop *)
(*   - 0 to any pointer type in any expr or return  *)
(*   - if statements  *)
(*     - ptr  *)
(*     - unop or binop  *)
(*   - assignment coersions will require a cast *)

(* https://github.com/immunant/c2rust/issues/447 change linker portion to prefix libc with :: *)

(* another large task: *)
(* - redo rustlight IR to make it faithful to the rust grammar *)
(* - a large portion of the statements must become expressions *)

(* structs are not correct because they might be differently defined under the same name in different file. I think I need to store a rep of the struct in my hashmap. However, construct counter example first. *)
(* - array dereference. *)
(*   Need to think about binop and unop on array types. *)
(*    As soon as they're treated as pointers, *)
(*    they need to be converted into pointers which is problematic *)
(* - casting *)
(* - precedence *)
(* - struct attributes *)
(* - temp vars as "registers" *)
(* - not always lifting immutable variables to global scope *)
(* - improve janky identifier for explicit lifetimes and gotos *)
(* - glibc types should be special cased in a better way. Pass in headerfile information/add headerfile information to map *)
(* - enum test, somehow deal with stripped enum information *)
(* - relooper  *)

(* let is_ptr *)

(* TODO already exists in rustlight.v. How do I make it exportable *)
let type_of_expr e =
  match e with
  | Econst_int(_, ty) -> ty
  (* | Eif_then_else(_, _, _, ty) -> ty *)
  | Econst_float(_, ty) -> ty
  | Econst_single(_, ty) -> ty
  | Econst_long(_, ty) -> ty
  | Evar(_, ty) -> ty
  | Etempvar(_, ty) -> ty
  | Ederef(_, ty) -> ty
  | Eaddrof(_, ty) -> ty
  | Eunop(_, _, ty) -> ty
  | Ebinop(_, _, _, ty) -> ty
  | Ecast(_, ty) -> ty
  | Efield(_, _, ty) -> ty
  | Esizeof(_, ty) -> ty
  | Ealignof(_, ty) -> ty
  | Enull_check(_) -> Ctypes.Tint(Ctypes.IBool, Unsigned, noattr)

let is_composite ty =
  match ty with
  | Ctypes.Tvoid -> false
  | Ctypes.Tint(_sz, _sg, _a) -> false
    (* TODO ignoring the attributes for now. The volatile should be handled a layer up probably. Same for align? Either way going for the easy thing *)
    (* TODO deal with visibility modifier *)
  | Ctypes.Tarray(_ity, _num_ele, _attrs) -> true
  | Ctypes.Tstruct(_id, _attr) -> true
  | Ctypes.Tunion(_id, _attr) -> true
  | Ctypes.Tfloat(_sz, _a) -> false
  | Ctypes.Tlong(_sz, _a) -> false
  | Ctypes.Tpointer(_ty, _a) -> false
  (* function type*)
  | Ctypes.Tfunction(_tylist, _ty, _cc) -> true

let pretty_print_hashtbl tbl =
  Format.printf "UUID {@.";
  Hashtbl.iter (fun key value ->
      match value with
      | Some(s, _) -> Format.printf "UUID  %s -> Some %s@,\n" key s
      | None -> Format.printf "UUID  %s -> None @,\n" key
  ) tbl;
  Format.printf "UUID}@."

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
  (* using bool here, libc doesn't have _Bool so use primitive instead*)
  | IBool, _ -> "bool"

let name_floattype_rust sz =
  match sz with
  | F32 -> "libc::c_float"
  | F64 -> "libc::c_double"

let name_longtype_rust sz =
  match sz with
  | Signed -> "libc::size_t"
  | Unsigned -> "libc::size_t"

let rec map_tylist_to_list tylist =
  match tylist with
  | Tnil -> []
  | Tcons(ty, tyl) -> ty :: (map_tylist_to_list tyl)

let rec gen_ty_rust is_nested ty =
  match ty with
  | Ctypes.Tvoid -> if is_nested then "libc::c_void" else "()"
  | Ctypes.Tint(sz, sg, a) ->
    (* TODO ignoring the attributes for now. The volatile should be handled a layer up probably. Same for align? Either way going for the easy thing *)
    (* TODO deal with visibility modifier *)
    name_inttype_rust sz sg
  | Ctypes.Tarray(ity, num_ele, attrs) ->
    let fmted_ity = gen_ty_rust true ity in
    sprintf "[ %s; %ld]"  fmted_ity (camlint_of_coqint num_ele)
  | Ctypes.Tstruct(id, attr) -> (extern_atom_r id)
  | Ctypes.Tunion(id, attr) -> (extern_atom_r id)
  | Ctypes.Tfloat(sz, a) -> name_floattype_rust sz
  | Ctypes.Tlong(sz, a) -> name_longtype_rust sz
  (* raw pointer only right now *)
  (* TODO handle the attributes on a type *)
  | Ctypes.Tpointer(ty, _a) -> sprintf "*mut %s" (gen_ty_rust true ty)
  (* function pointers *)
  | Ctypes.Tfunction(tylist, ty, cc) ->
      let r_arglist = List.map (gen_ty_rust false) (map_tylist_to_list tylist) |> String.concat "," in
      (* TODO this makes for nicer code, but should we be mappign to c_void or unit everywhere? *)
      (* cvoid should only appear in function signatures by itself *)
      let rust_ret_ty = (gen_ty_rust false ty) in
      (* all C functions and C pointers look like this *)
      sprintf "(extern \"C\" fn(%s) -> %s)" r_arglist rust_ret_ty

let map_to_unsigned =
  function
  | Ctypes.Tarray(Ctypes.Tint(I8, _, attrs), num_ele, a) ->
    Ctypes.Tarray(Ctypes.Tint(I8, Unsigned, attrs), num_ele, a)
  | ty -> Format.printf "error! something besides expected type for %s\n" (gen_ty_rust false ty); ty

let gen_name_and_ty_rust name ty = name ^ " : " ^ (gen_ty_rust false ty)

let print_primitive_init fmt ty = function
  | Init_int8 n -> fprintf fmt"%ld" (camlint_of_coqint n)
  | Init_int16 n -> fprintf fmt "%ld" (camlint_of_coqint n)
  | Init_int32 n -> fprintf fmt "%ld" (camlint_of_coqint n)
  | Init_int64 n -> fprintf fmt "%Ld" (camlint64_of_coqint n)
  | Init_float32 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_float64 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_space n -> fprintf fmt "(0 as %s)" (gen_ty_rust false ty)
  (* this is hard because in the case of globals, the addr_of!  does not work. *)
  (* TODO *)
  (* - try with rust nightly and the new pointer type *)
  (* - copy c2rust *)
  | Init_addrof(symb, ofs) ->
    (* analogue to PrintCsyntax.ml:474 *)
    let ofs = camlint_of_coqint ofs in
    if ofs = 0l
    then fprintf fmt "std::ptr::addr_of_mut! { %s }" (extern_atom symb)
    else fprintf fmt "(std::ptr::addr_of_mut! { %s }).add(%ld)" (extern_atom symb) ofs

let re_string_literal = Str.regexp "__stringlit_[0-9]+"

(* TODO fix this. It's horribly inefficient *)
let rec find_comp_defn (tds: composite_definition list) id =
  match tds with
  | Composite(id_c, _su, m, a) :: l ->
    if id_c = id then Composite(id, _su, m, a) else find_comp_defn l id
  | nil -> raise (Panic "Couldn't find type")



let rec print_composite_init fmt tds arr ty =
  (*TODO both cases do the same thing. Make it more dry *)
  match ty with
  | Ctypes.Tstruct(id, _attrs) ->
    fprintf fmt "%s {" (extern_atom_r id);
    let Composite(_, _, membs, _attrs) = find_comp_defn tds id in
    let res = List.fold_left (fun acc memb ->
        match memb with
        | Member_plain(id_memb, ty_memb) -> (
          fprintf fmt "%s: " (extern_atom_r id_memb);
          let arr_res = print_composite_init fmt tds arr ty_memb in
          fprintf fmt ",";
          arr_res
        )
        | Member_bitfield(_) -> raise (Panic "Don't support bitfields yet")
      ) arr membs in
    fprintf fmt "}";
    res
  | Ctypes.Tunion(id, _attrs) ->
    fprintf fmt "%s {" (extern_atom_r id);
    let Composite(_, _, membs, _attrs) = find_comp_defn tds id in
    let res = List.fold_left (fun acc memb ->
        match memb with
        | Member_plain(id_memb, ty_memb) -> (
          fprintf fmt "%s: " (extern_atom_r id_memb);
          let arr_res = print_composite_init fmt tds arr ty_memb in
          fprintf fmt ",";
          arr_res
        )
        | Member_bitfield(_) -> raise (Panic "Don't support bitfields yet")
      ) arr membs in
    fprintf fmt "}";
    res
  | Ctypes.Tarray(ty_inner, num, _attrs) -> (
      fprintf fmt "[";

      let res =
      List.fold_left (fun acc _ ->
          let res = print_composite_init fmt tds acc ty_inner in
          fprintf fmt ", ";
          res
      ) arr (List.init (camlint_of_coqint num |> Int32.to_int) (fun x -> x)) in
      fprintf fmt "]";
      res
    )
  | _ -> (
      match arr with
      | ele :: l -> fprintf fmt "("; print_primitive_init fmt ty ele; fprintf fmt " as %s)" (gen_ty_rust false ty); l
      | nil -> fprintf fmt "(0 as %s)" (gen_ty_rust false ty); nil
  )

  (* match maybe_name with *)
  (* | Some name -> *)
  (*   fprintf fmt "%s {@ " name; *)
  (*   List.iter *)
  (*     ( *)
  (*       fun i -> *)
  (*         print_primitive_init fmt i; *)
  (*         match i with *)
  (*         | Init_space _ -> () *)
  (*         | _ -> fprintf fmt ",@ " *)
  (*     ) arr; *)
  (*   fprintf fmt "}" *)
  (* | None -> *)
  (*   fprintf fmt "[@ "; *)
  (*   List.iter *)
  (*     ( *)
  (*       fun i -> *)
  (*         print_primitive_init fmt i; *)
  (*         match i with *)
  (*         | Init_space _ -> () *)
  (*         | _ -> fprintf fmt ",@ " *)
  (*     ) arr; *)
  (*   fprintf fmt "]" *)

let string_of_init id =
  let b = Buffer.create (List.length id) in
  let add_init = function
  | Init_int8 n ->
      let c = Int32.to_int (camlint_of_coqint n) in
      if c >= 32 && c <= 126 && c <> Char.code '\"' && c <> Char.code '\\'
      then Buffer.add_char b (Char.chr c)
      else
        if Char.code '\000' == c then Buffer.add_string b "\\0"
        else if Char.code '\n' == c then Buffer.add_string b "\\n"
  | _ ->
      assert false
  in List.iter add_init id; Buffer.contents b

let print_globvar fmt tds id v =
  let name_bare = extern_atom_r id in
  let linkage = if C2C.atom_is_static id then "" else "pub " in
  (* need to do static analysis pass to conclude that this is actually static mut *)
  (* in rust, const a : u32 = 5; ensure (with the compiler) that a is not writable. Ever *)
  (* in c, const int a = 5; void f(){ *(&a) = 6; } works just fine*)
  (* TODO not sure if this is, however, UB *)

  let name = linkage^"static mut "^name_bare in
  match v.gvar_init with

  (* in C this would be extern variablename; *)
  (* in Rust, we have a separate function that does imports *)
  (* so this is a noop *)
  | [] -> ()
  | [Init_space _] ->
    fprintf fmt "%s = unsafe { std::mem::zeroed() }; @ @ " (gen_name_and_ty_rust name v.gvar_info)
  | _ ->
    begin match v.gvar_info, v.gvar_init with
      | (Ctypes.Tint _ | Ctypes.Tlong _ | Ctypes.Tfloat _ | Tpointer _ | Tfunction _),
        [i1] ->
          fprintf fmt "@[<hov 2>%s = unsafe {(" (gen_name_and_ty_rust name v.gvar_info);
          print_primitive_init fmt v.gvar_info i1; fprintf fmt " as %s) }" (gen_ty_rust false v.gvar_info)
      | _, il ->
          if Str.string_match re_string_literal (extern_atom_r id) 0
          && List.for_all (function Init_int8 _ -> true | _ -> false) il
          then
            (
              (* dereference here because string literals are pointers to byte arrays  *)
              (* transmute here because the literal isn't the expected type. In C it's signed and in rust it's unsigned *)
              (* We're black boxing the entire thing and just saying "this is what we expect it to be"  *)
              fprintf fmt "@[<hov 2>%s = unsafe { std::mem::transmute("
                (gen_name_and_ty_rust name v.gvar_info);
              fprintf fmt "*b\"%s\")}" (string_of_init (il))
            )
          else
            (
              fprintf fmt "@[<hov 2>%s = unsafe { " (gen_name_and_ty_rust name v.gvar_info);
              (* let maybe_struct_name = *)
              (* match g.var_info with *)
              (* | Ctypes.Tstruct(_, _) => *)
              (* | Ctypes.Tstruct(_, _) => *)
              (* in *)
              let _ = print_composite_init fmt tds il v.gvar_info in
              fprintf fmt " }"
            )
    end;
  fprintf fmt ";@]@ @ "

let rec print_expr fmt e =
  match e with
  (* | Eif_then_else(cond, if_branch, else_branch, _ty) ->( *)
  (*     fprintf fmt "@[<v 2>if %a {@ %a@;<0 -2>} else {@;%a@;<0 -2>}@]" *)
  (*       print_expr cond print_expr if_branch print_expr else_branch *)
  (*   ) *)
  | Econst_int(n, Ctypes.Tint(I32, Unsigned, _)) ->
    fprintf fmt "(%lu as libc::c_uint)" (camlint_of_coqint n)
  | Econst_int(n, Ctypes.Tint(IBool, _, _)) ->
    fprintf fmt "%s"
    begin match (camlint_of_coqint n) with
    | 0l -> "false"
    | 1l -> "true"
    | _ -> "ERROR bool is outside {0, 1}"
    end
  | Econst_int(n, ty) ->
    fprintf fmt "(%ld as %s)" (camlint_of_coqint n) (gen_ty_rust false ty)
  | Econst_float(f, ty) ->
    fprintf fmt "(%.18g as %s)" (camlfloat_of_coqfloat f) (gen_ty_rust false ty)
  | Econst_single(f, ty) ->
    fprintf fmt "(%.18g as %s)" (camlfloat_of_coqfloat32 f) (gen_ty_rust false ty)
  | Econst_long(n, Ctypes.Tlong(Unsigned, v)) ->
    fprintf fmt "(%Lu as %s)" (camlint64_of_coqint n) (gen_ty_rust false (Ctypes.Tlong(Unsigned, v)))
  | Econst_long(n, ty) ->
    fprintf fmt "(%Ld as %s)" (camlint64_of_coqint n) (gen_ty_rust false ty)
  | RustLight.Evar (id, _ty) -> fprintf fmt "%s" (extern_atom_r id) (* (_ty ==) *)
  | RustLight.Etempvar (id, _ty) -> fprintf fmt "%s" (temp_name id)
  | RustLight.Eunop (op_ty, exp, ty) ->
    (
      let op_name =
      begin match op_ty with
      (* conversion to bool *)
      | Cop.Onotbool -> "!"
      (* bitwise not is ! in rust *)
      | Cop.Onotint -> "!"
      | Cop.Oneg -> "-"
      | Cop.Oabsfloat -> "UNSUPPORTED OP"
      end
      in
      fprintf fmt "((%s%a) as %s)" op_name print_expr exp (gen_ty_rust false ty);
    )
  | RustLight.Ebinop (op_type, e1, e2, ty) -> (
    begin match (op_type, type_of_expr e1, type_of_expr e2) with
    | (_, Ctypes.Tpointer(_, _), Ctypes.Tint(_, _, _)) -> (
        handle_ptr_arithmetic fmt op_type e1 e2
      )
    | (_, Ctypes.Tint(_, _, _), Ctypes.Tpointer(_, _)) -> (
        handle_ptr_arithmetic fmt op_type e2 e1
      )
    | (_, Ctypes.Tlong(_, _), Ctypes.Tpointer(_, _)) -> (
        handle_ptr_arithmetic fmt op_type e2 e1
      )
    | (_, Ctypes.Tpointer(_, _), Ctypes.Tlong(_, _)) -> (
        handle_ptr_arithmetic fmt op_type e1 e2
      )
    | (Cop.Osub, Ctypes.Tpointer(_, _), Ctypes.Tpointer(_, _)) -> (
        fprintf fmt "(%a).offset_from(%a)" print_expr e1 print_expr e2
      )
    | (_, _, _) ->
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
    end
  )
  | RustLight.Efield (exp, id, ty) -> fprintf fmt "%a.%s" print_expr exp (extern_atom_r id)
  | RustLight.Ederef (exp, _ty (* type we derefernce into *)) -> (
    (* type we were before dereferencing *)
    let exp_ty = type_of_expr exp in
    match exp_ty with
    (* edge case for this because now this is dependent on what ty is *)
    | Tpointer(_, _) -> fprintf fmt "(*%a)" print_expr exp
    (* TODO is this needed? *)
    | Tarray(_, _, _) -> fprintf fmt "(%a)[0]" print_expr exp
    | _ -> fprintf fmt "unimplemented deref for this type"

  )



  (* get type of exp. If it's an array, use array dereference syntax.*)


  (* TODO broken for globals. Need to special case that. *)
  | RustLight.Eaddrof (exp, _) ->
    fprintf fmt "(std::ptr::addr_of_mut!(%a))" print_expr exp
  (* we know that we  *)
  | RustLight.Ecast(exp, ty) -> (
    let e_ty = type_of_expr exp in
    let e_ty_is_composite = is_composite e_ty in
    let to_ty_is_composite = is_composite ty in

    (* may only cast between scalar types  *)
    match (e_ty_is_composite, to_ty_is_composite) with
    | (false, false) -> fprintf fmt "(%a as %s)" print_expr exp (gen_ty_rust false ty)
    | (b1, b2) -> (
      match (e_ty, ty) with
      (* TODO go back in rustlight and make sure it's not a wild cast... *)
      | (Ctypes.Tarray(_ty_from, _, _), Ctypes.Tpointer(_ty_to, _))
        (* -> fprintf fmt "((%a).as_mut_ptr() as %s)" print_expr exp (gen_ty_rust false ty) *)
        -> fprintf fmt "(%a).as_mut_ptr()" print_expr exp
             (* (gen_ty_rust false _ty_from) (gen_ty_rust false _ty_to) *)
      | (Ctypes.Tfunction(_, _, _), Ctypes.Tpointer(_, _)) -> fprintf fmt "(%a as %s)" print_expr exp (gen_ty_rust false ty)
      | (Ctypes.Tstruct(a, _), Ctypes.Tstruct(b, _)) ->
        if a == b then fprintf fmt "%a" print_expr exp
        else
          printf "FOUND SOMETHING THAT ISNT RIGHT %b %b\n" b1 b2;
          fprintf fmt "ERROR casting %s to %s!!" (gen_ty_rust false e_ty) (gen_ty_rust false ty); ()
      | (_, _) -> printf "FOUND SOMETHING THAT ISNT RIGHT %b %b\n" b1 b2;
        fprintf fmt "ERROR casting %s to %s!!" (gen_ty_rust false e_ty) (gen_ty_rust false ty);
    )

    (* somewhat complicated because we might want to use *)
    (* `as` on pointers *)
    (* or https://doc.rust-lang.org/std/mem/fn.transmute.html *)
    (* fprintf fmt "TODO casts are unimplemented" *)
    )
  | RustLight.Esizeof (ty, ty') ->
    fprintf fmt "(std::mem::size_of::<%s>() as %s)" (gen_ty_rust false ty) (gen_ty_rust false ty')
  | RustLight.Ealignof (ty, ty') ->
    fprintf fmt "(std::mem::align_of::<%s>() as %s)" (gen_ty_rust false ty) (gen_ty_rust false ty')
  | RustLight.Enull_check(exp) ->
    fprintf fmt "((%a).is_null())" print_expr exp
  and handle_ptr_arithmetic fmt binop ptr_exp int_exp =
    let fn_name =
    begin match binop with
      | Cop.Oadd -> "add"
      | Cop.Osub -> "sub"
      | _ -> "ERROR"
    end in
    (* TODO should be reflected in semantics *)
    fprintf fmt "((%a).%s(%a as usize))" print_expr ptr_exp fn_name print_expr int_exp


let rec print_arglist fmt arglist =
  match arglist with
  | [arg] ->
    fprintf fmt "%a" print_expr arg
  | arg :: al ->
    fprintf fmt "%a, " print_expr arg; print_arglist fmt al
  | nil -> ()


let rec print_stmt fmt body =
  match body with
  | S_skip -> ()
    (* fprintf fmt "/* skip stmt */@;"; *)

  | S_assign(e1, e2) -> (
      fprintf fmt "@[<hv 2>%a =@ %a;@]"
        print_expr e1
        (* (gen_ty_rust (type_of_expr e1)) *)
        print_expr e2;
    )
  | S_set(id, e) -> fprintf fmt "@[<hv 2>%s =@ %a;@]" (temp_name id) print_expr e;
  | S_return(Some (exp, ty)) -> fprintf fmt "return %a;" print_expr exp
  | S_return(None) -> fprintf fmt "return;"
  | S_sequence(RustLight.S_skip, s2) -> print_stmt fmt s2
  | S_sequence(s1, RustLight.S_skip) -> print_stmt fmt s1
  | S_sequence(e1, e2) -> fprintf fmt "%a@;%a" print_stmt e1 print_stmt e2
  | S_continue(None) -> fprintf fmt "continue;"
  | S_continue(Some(lbl)) -> fprintf fmt "continue 'lbl_%ld;" (camlint_of_coqint lbl)
  | S_if_then_else(exp, s_true, S_skip)  -> (
      fprintf fmt "@[<v 2>if %a {@;%a@;<0 -2>}@]" print_expr exp print_stmt s_true
    )
  | S_if_then_else(exp, S_skip, s_false)  -> (
      fprintf fmt "@[<v 2>if !(%a) {@;%a@;<0 -2>}@]" print_expr exp print_stmt s_false
    )
  | S_if_then_else(exp, s_true, s_false)  -> (
      fprintf fmt "@[<v 2>if %a {@ %a@;<0 -2>} else {@;%a@;<0 -2>}@]"
        print_expr exp print_stmt s_true print_stmt s_false
    )
  | S_break(None) -> fprintf fmt "break;"
  | S_break(Some(lbl)) -> fprintf fmt "break 'lbl_%ld;" (camlint_of_coqint lbl)
  | S_builtin(maybe_ident, external_fn, lty,  lexp) -> fprintf fmt "unimplemented call stmt"
  | S_loop2(Some(outer), Some(inner), s1, s2) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]%a@;<0 -2>}@]"
              (camlint_of_coqint outer) (camlint_of_coqint inner) print_stmt s1 print_stmt s2
    )
  | S_loop2(None, None, _, _) -> (
      fprintf fmt "@[loop {}@]@;"
    )
  | S_loop2(Some(outer), None, S_skip, s2) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]"
              (camlint_of_coqint outer) print_stmt s2
    )
  (* | S_loop2(Some(outer), None, s1, S_skip) -> ( *)
  (*     fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]" *)
  (*             (camlint_of_coqint outer) print_stmt s1 *)
  (*   ) *)
  | S_loop2(_, _, _, _) -> let _ = Panic "Unexpected loop type" in ()
  | S_loop(None, stmt, S_skip) -> (
      fprintf fmt "@[<v 2>loop {@;%a@;<0 -2>}@]@;"
              print_stmt stmt
    )
  | S_loop(Some(lbl), stmt, S_skip) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]"
              (camlint_of_coqint lbl) print_stmt stmt
    )
  | S_loop(Some(lbl), stmt, stmt2) -> (
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;%a@;<0 -2>}@]"
              (camlint_of_coqint lbl) print_stmt stmt print_stmt stmt2
    )
  | S_match_int(expr, stmts) -> (
      fprintf fmt "@[<v 2>match %a {@;%a@;<0 -2>};@]" print_expr expr print_cases stmts;
    )
  (* the difference between these two cases is the assignment to a temporary var vs discard *)
  | S_call(Some(id), name, arg_list) -> (
      fprintf fmt "@[<hv 2>%s =@ %a@,(@[<hov 0>%a@]);@]"
        (temp_name id)
        print_expr name
        print_arglist arg_list
    )
  | S_exit(ecode) -> (
      fprintf fmt "@[<hv 2>::std::process::exit@,(@[<hov 0>%a@]);@]"
        print_expr ecode
    )
  | S_call(None, name, arg_list) -> (
      fprintf fmt "@[<hv 2>%a@,(@[<hov 0>%a@]);@]"
        print_expr name
        print_arglist arg_list
    )
  | _ -> fprintf fmt "unimplemented?!"

and print_cases fmt cases =
  match cases with
  | LSnil body ->
      fprintf fmt "@[<v 2>_ => {@;%a@;<0 -2>}@]@;" print_stmt body
  | LScons (n, body, stmts) ->
      (match n with
      | Some(n') -> fprintf fmt "@[<v 2>%s => {@;%a@;<0 -2>}@]@;" (Z.to_string n') print_stmt body
      | None -> fprintf fmt "@[<v 2>_ => {@;%a@;<0 -2>}@]@;" print_stmt body
      );
      print_cases fmt stmts

(* fn name(param: ty, ) -> { body  } *)
let print_function fmt id fn =
  let fn_name = extern_atom_r id in

  (* TODO this is cursed and will get better once we integrate with compcerto*)
  (* let fn_name =  *)
  (*   if unprocessed_name = "main" then "main_2" *)
  (*   else if (String.get unprocessed_name 0) = '$' then "main" *)
  (*   else unprocessed_name in *)
  let fn_params = fn.fn_params in
  let fn_linkage = if C2C.atom_is_static id then "" else "pub" in
  let fn_args =
    fn_params
    |> List.map (fun (tid, tty) -> gen_name_and_ty_rust (extern_atom_r tid) tty)
    |> List.map(fun x -> "mut " ^ x)
    |> String.concat ", "
  in

  (* HACK this should be reflected in the semantics of rustlight *)
  (* But, we haven't gotten there yet. Rustlight is still generic over c types which isn't right. *)
  let rty = if fn_name = "main" then "!" else gen_ty_rust false fn.fn_return in
  let needs_space = if String.length fn_linkage != 0 then " " else "" in

  (* let safety_qualifier = if fn.fn_is_safe then "" else "unsafe" in *)

  let externc = if fn_name = "main" then "" else ( "extern \"C\"") in
  let nomangle = if fn_name = "main" then "" else "#[no_mangle]" in


  fprintf fmt "%s@ @[<v 2>%s%s%s fn %s(%s) -> %s " nomangle fn_linkage needs_space externc fn_name fn_args rty;
  (* fprintf fmt "@ @[<v 2>{@ "; *)
  fprintf fmt "{@ @[<v 2>unsafe {@ ";
  (* In C we just reserve on the stack *)
  (* In Rust to avoid compilation errors we need the entire struct to be initialized before first use. *)
  (* We translate to that directly *)
  List.iter (fun (vid, vty) ->
      (* TODO can make this dryer *)
      (* initialized functions can only come from temporary variables *)
      (* so it's fine to not initialize them because they will be written to*)
      (* everything else will be initialized and valid *)
      let zero_initialize =
      match vty with
      | Ctypes.Tfunction(_, _, _) -> ""
      | _ -> " = std::mem::zeroed()"
      in
      fprintf fmt "let mut %s%s;@ "
        (gen_name_and_ty_rust (extern_atom_r vid) vty) zero_initialize ) fn.fn_vars;
  List.iter (fun (vid, vty) ->
      let zero_initialize =
      match vty with
      | Ctypes.Tfunction(_, _, _) -> ""
      | _ -> " = std::mem::zeroed()"
      in
      fprintf fmt "let mut %s%s;@ " (gen_name_and_ty_rust (temp_name vid) vty) zero_initialize) fn.fn_temps;

  print_stmt fmt fn.fn_body;

  fprintf fmt "@;<0 -2>}@]@;<0 -2>}@]@ "

let print_fundef fmt id fundef =
  match fundef with
  | Ctypes.Internal f -> print_function fmt id f
  | Ctypes.External(_, _, _, _) ->  fprintf fmt ""


let print_globdef fmt tds (id, gd) =
  match gd with
  | Gfun fundef -> print_fundef fmt id fundef
  | Gvar v -> print_globvar fmt tds id v

let struct_or_union = function Struct -> "struct" | Union -> "union"

let print_member fmt = function
  | Member_plain(id, ty) ->
    fprintf fmt "@; pub %s," (gen_name_and_ty_rust (extern_atom_r id) ty)
  | _ -> ()

let define_composite fmt (Composite(id, su, m, a)) =
  (* let linkage = C2C.atom_is_static *)
  let maybe_aligned =
    match a.attr_alignas with
    | None -> ""
    | Some n -> sprintf ", align(%Ld)" (Int64.shift_left 1L (N.to_int n))
  in

  (* either I define this locally or I'm importing it. Even if this is a local-only thing, it's hidden behind the module so this is fine *)
  (* TODO while this does reflect C semantics, Copy is morally wrong here. *)
  (* It would be better to clone explicitly where needed. *)
  fprintf fmt "#[repr(C%s)]@;#[derive(Clone, Copy)]@;@[<v 2>pub %s %s {" maybe_aligned (struct_or_union su) (extern_atom_r id);
  List.iter (print_member fmt) m;
  fprintf fmt "@;<0 -2>}@]@; @;"


let get_fn_foreign_syms mapping list_of_ids cur_sym_map =
  printf "UID list of ids %d\n" (List.length list_of_ids);
  List.fold_left
    (fun acc id ->
       let name = extern_atom_r id in
       let maybe_module = Hashtbl.find_opt mapping name in
       match maybe_module with
       (* TODO this is the exact line where we can insert libc symbols. It would be good to know what those symbols are, though. *)
       (* for now, just auto libc it *)
       | None -> (
           printf "UID couldn't find module for symbol %s in mapping. Assuming libc\n" name;
           let maybe_hs = Hashtbl.find_opt acc "libc" in
           match maybe_hs with
           | None ->
             let new_hs = StringSet.singleton name in
             Hashtbl.replace acc "libc" new_hs;
             acc
           | Some hs ->
             let new_hs = StringSet.add name hs in
             Hashtbl.replace acc "libc" new_hs;
             acc
         )
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
               get_fn_foreign_syms sym_mapping (PositiveSet.elements rf.fn_imports) acc
             )
           | External _ -> acc
       )
    )
    (Hashtbl.create 7) fn_defs in
  let defined_in_module  =
    List.filter (
      fun dfn ->
        let r = match dfn with | Composite(id, _,  _, _) -> extern_atom_r id in
        match Hashtbl.find_opt composite_mapping r with
        (* This can happen if the struct is anonymous. *)
        (* | None -> printf "UUID: NOT FOUND STRUCT %s" r; false *)
        | None -> printf "ANON struct %s" r; true
        (* might be external to module *)
        | Some (Some (mname, _)) ->
          printf "\nUUID: mod name %s, %s len modname: %d, nmame %d, eq %b\n"
            mod_name mname
            (String.length mod_name)
            (String.length mname)
            (mname = mod_name) ;
            mname = mod_name
        (* internal to module *)
        | Some (None) -> true
    ) prog_types in
  let imports_from_composite = List.fold_left (
    fun (acc : (string, StringSet.t) Hashtbl.t) elt -> (
        let r = match elt with | Composite(id, _,  _, _) -> extern_atom_r id in
        match Hashtbl.find_opt composite_mapping r with
        (* internal to module *)
        | Some(None) -> acc
        (* This can happen if the struct is anonymous ? *)
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
        let crate = if module_ == "libc" then "" else "crate::" in
        (if size == 1 then
          let ele = List.hd elts in
          fprintf fmt "use %s%s::%s;" crate module_ ele
        else (
          fprintf fmt "use %s%s::{" crate module_;
          List.iter (fun x -> fprintf fmt "%s, " x) elts;
          fprintf fmt "};"
        ));
        fprintf fmt "@]@;"
      ) import_map;
  fprintf fmt "@;"

let print_program (sym_mapping: (string, string) Hashtbl.t)
    composite_mapping mod_name f (prog: RustLight.r_program) =
  let [@warning "-42"] p_defs = prog.prog_defs in
  let [@warning "-42"] p_types = prog.prog_types in

  let (imports, in_module_composite_dfns) = gen_imports sym_mapping p_defs composite_mapping p_types mod_name in

  fprintf f "@[<v 0>";

  (* do printing  *)

  print_imports f imports composite_mapping;

  List.iter
    (fun x -> printf "\nUUID IN MODULE %s: print struct %s\n" mod_name
                (match x with | Ctypes.Composite(id, _, _, _) -> extern_atom_r id))
    in_module_composite_dfns;

  List.iter (define_composite f) in_module_composite_dfns;
  List.iter (print_globdef f p_types) p_defs;
  fprintf f "@]@."

let change_directory dir_name =
  try
    Unix.chdir dir_name;  (* Change the current working directory *)
  with
  | Unix.Unix_error (err, _, _) ->
    Printf.printf "Error changing directory: %s\n" (Unix.error_message err)

(* global syms  *)
let fix_mapping_types (mapping: (char list * char list) list) : (string, string) Hashtbl.t =
  let elts = List.map (fun (a, b) -> (String.of_seq (List.to_seq a), String.of_seq (List.to_seq b))) mapping in
  List.fold_left (fun acc (k, v) -> Hashtbl.replace acc k v; acc) (Hashtbl.create 7) elts

(* global composite defns *)
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

    (clunky_sym_mapping: str_map_globals)
    (clunky_composite_mapping: str_map_composites)
    (clunky_mod_name: char list)
    prog =
  match !destination with
  | None -> ()
  | Some f ->
    (* We need ocaml strings to print out variable names. *)
    (* We should do that all at once to avoid repeatedly converting. *)
    (* Since we have to iterate over all the data anyway, might as well convert *)
    (* to a more efficient representation *)
    let sym_mapping = fix_mapping_types clunky_sym_mapping in
    let composite_mapping = fix_mapping_types_2 clunky_composite_mapping in
    let mod_name = List.to_seq clunky_mod_name |> String.of_seq in
    printf "\nUUID mod_name %s\n" mod_name;
    (* let len_mapping = Hashtbl.length mapping in *)
    printf "UUID hashtbl";
    pretty_print_hashtbl composite_mapping;
    change_directory "./rust_project/src/";
    printf "DOIN opening out: %s\n" f;
    let oc = open_out f in
    printf "DOING success opening out\n";
    print_program sym_mapping composite_mapping mod_name (formatter_of_out_channel oc) prog;
    close_out oc;
    change_directory "../..";
