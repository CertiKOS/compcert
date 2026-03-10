[@@@ocaml.warning "-66"]
[@@@ocaml.warning "-42"]

open Format
open! Ctypes
open AST
open Camlcoq (*for extern_atom*)
open RustLight
open! LibcSymbols
open! Linking

exception Panic of string

let todo () = failwith "\nTODO\n"
let unimplemented s = failwith (Printf.sprintf "Not yet implemented %s" s)

(* let a: member = todo () ;; *)

(* TODO a lot of the clunky tuples could be replaced with modules *)

let remove_c_extension path =
  let base = Filename.basename path in
  base

(* pulled from https://doc.rust-lang.org/book/appendix-01-keywords.html *)
module StringSet = Set.Make (String)

(* let libc_symbol_set = StringSet.of_list libc_list *)
let libc_symbol_set = StringSet.of_list [ "malloc"; "free" ]

let rust_keywords =
  StringSet.of_list
    [
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
      "yield";
    ]

(* HACK the proper solution is to add to this map in process_c *)
let extern_atom_r a =
  try
    let res = Hashtbl.find string_of_atom a in
    (* let _ = printf "NAMEVAR: %s\n" res in *)
    if res = "main" then "main_inner"
    else if res = "_" then "_RENAMING_UNDERSCORE"
    else if StringSet.mem res rust_keywords then "r#" ^ res
    else res
    (* res *)
  with Not_found ->
    (* TODO shouldn't need this anymore *)
    "main"

let get_len_of_char_arr (t : coq_type) =
  match t with
  | Tarray (_, l, _) -> Some (camlint_of_coqint l |> Int32.to_int)
  | _ -> None

let is_anon_defn (s : string) : bool =
  let len = String.length s in
  let rec check_digits i =
    if i = len then true
    else
      let c = String.get s i in
      if c >= '0' && c <= '9' then check_digits (i + 1) else false
  in
  len >= 2 && String.get s 0 = '_' && check_digits 1

(* HACK *)
(* we give a pass for all anonymous structs inside anonymous structs *)
(* it shouldn't be possible otherwise *)
let rec check_s_or_u_in_ty ty1 ty2 =
  match (ty1, ty2) with
  | Tstruct (i', a'), Tstruct (j', b') | Tunion (i', a'), Tunion (j', b') ->
      i' = j'
      || (is_anon_defn (extern_atom_r i') && is_anon_defn (extern_atom_r j'))
  | Tfunction (tl, rty, _cc), Tfunction (tl', rty', _cc') -> true
  | Tpointer (ty, _cc), Tpointer (ty', _cc') -> check_s_or_u_in_ty ty ty'
  | _ -> ty1 = ty2

and check_s_or_u_in_tylist tl1 tl2 =
  match (tl1, tl2) with
  | Tcons (ty1, tl1'), Tcons (ty2, tl2') ->
      check_s_or_u_in_ty ty1 ty2 && check_s_or_u_in_tylist tl1' tl2'
  | Tnil, Tnil -> true
  | _ -> false

let rec membs_equal l1 l2 =
  match (l1, l2) with
  | h :: t, h' :: t' -> (
      match (h, h') with
      | Member_plain (i1, ty1), Member_plain (i2, ty2) ->
          i1 = i2 && check_s_or_u_in_ty ty1 ty2 && membs_equal t t'
      (* TODO this fails on bitfields, which is fine for now *)
      | _ -> false)
  | [], [] -> true
  | _ -> false

let equal_sans_anonstruct (s1 : composite_definition)
    (s2 : composite_definition) : bool =
  match (s1, s2) with
  | ( Composite (i1, s_or_u1, membs1, attrs1),
      Composite (i2, s_or_u2, membs2, attrs2) ) ->
      i1 = i2 && s_or_u1 = s_or_u2 && attrs1 = attrs2
      && membs_equal membs1 membs2

let get_representative (s1 : composite_definition) (m1 : char list)
    (s2 : composite_definition) (m2 : char list) :
    char list * composite_definition =
  match (s1, s2) with
  | ( Composite (i1, s_or_u1, membs1, attrs1),
      Composite (i2, s_or_u2, membs2, attrs2) ) ->
      if i1 < i2 then (m1, s1) else (m2, s2)

let check_mod_for_extra_types
    (* ident -> (module, defn)*)
      (composite_mapping :
        (string, (string * Ctypes.composite_definition) option) Hashtbl.t)
    (in_module_composite_defns : (ident, composite_definition) Hashtbl.t)
    (cur_mod : string) : (ident, ident * string) Hashtbl.t =
  let rval, new_inmod_defns =
    Hashtbl.fold
      (fun (name : ident)
           (Composite (_, s_or_u, membs, atrs) : composite_definition)
           (acc, new_vals) ->
        if extern_atom_r name |> is_anon_defn then (
          printf "WORKING ON %s" (extern_atom_r name);
          let mapped_ident, m_name =
            Hashtbl.fold
              (fun (c_name : string) maybe_defn (least_ident, least_ident_mod)
                 ->
                match maybe_defn with
                | Some (c_mod, Composite (c_id, s_or_u', membs', atrs')) ->
                    printf "CONSIDERING %s %b" (extern_atom_r c_id) (c_id < name);
                    if
                      s_or_u = s_or_u' && membs_equal membs membs'
                      && c_id < least_ident
                    then (
                      printf "YES";
                      (c_id, c_mod))
                    else (
                      printf "NO";
                      (least_ident, least_ident_mod))
                | _ -> (least_ident, least_ident_mod))
              composite_mapping (name, "none")
          in
          if mapped_ident <> name then (
            Hashtbl.add acc name (mapped_ident, m_name);
            if m_name = cur_mod then
              Hashtbl.add new_vals mapped_ident
                (Composite (mapped_ident, s_or_u, membs, atrs));
            (acc, new_vals))
          else (acc, new_vals))
        else (acc, new_vals))
      in_module_composite_defns
      (Hashtbl.create 5, Hashtbl.create 5)
  in
  Hashtbl.iter
    (fun n i -> Hashtbl.replace in_module_composite_defns n i)
    new_inmod_defns;
  rval

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

(* let is_ptr *)

(* TODO already exists in rustlight.v. How do I make it exportable *)
let type_of_expr e =
  match e with
  | Econst_int (_, ty) -> ty
  (* | Eif_then_else(_, _, _, ty) -> ty *)
  | Econst_float (_, ty) -> ty
  | Econst_single (_, ty) -> ty
  | Econst_long (_, ty) -> ty
  | Evar (_, ty) -> ty
  | Etempvar (_, ty) -> ty
  | Ederef (_, ty) -> ty
  | Eaddrof (_, ty) -> ty
  | Eunop (_, _, ty) -> ty
  | Ebinop (_, _, _, ty) -> ty
  | Ecast (_, ty) -> ty
  | Efield (_, _, ty) -> ty
  | Esizeof (_, ty) -> ty
  | Ealignof (_, ty) -> ty
  | Enull_check _ -> Ctypes.Tint (Ctypes.IBool, Unsigned, noattr)

let is_composite ty =
  match ty with
  | Ctypes.Tvoid -> false
  | Ctypes.Tint (_sz, _sg, _a) ->
      false
      (* TODO ignoring the attributes for now. The volatile should be handled a layer up probably. Same for align? Either way going for the easy thing *)
      (* TODO deal with visibility modifier *)
  | Ctypes.Tarray (_ity, _num_ele, _attrs) -> true
  | Ctypes.Tstruct (_id, _attr) -> true
  | Ctypes.Tunion (_id, _attr) -> true
  | Ctypes.Tfloat (_sz, _a) -> false
  | Ctypes.Tlong (_sz, _a) -> false
  | Ctypes.Tpointer (_ty, _a) -> false
  (* function type*)
  | Ctypes.Tfunction (_tylist, _ty, _cc) -> true

let pretty_print_hashtbl tbl =
  Format.printf "UUID {@.";
  Hashtbl.iter
    (fun key value ->
      match value with
      | Some (s, _) -> Format.printf "UUID  %s -> Some %s@,\n" key s
      | None -> Format.printf "UUID  %s -> None @,\n" key)
    tbl;
  Format.printf "UUID}@."

let temp_name (id : AST.ident) =
  try "tmp_id_" ^ Hashtbl.find string_of_atom id
  with Not_found -> Printf.sprintf "tmp_id_%d" (P.to_int id)

let destination : string option ref = ref None
let linker : Linking.t ref = ref (Linking.create ())
let mod_name : string option ref = ref None
let proj_name : string option ref = ref None

let name_inttype_rust sz sg =
  match (sz, sg) with
  | I8, Signed -> "core::ffi::c_schar"
  | I8, Unsigned -> "core::ffi::c_uchar"
  | I16, Signed -> "core::ffi::c_short"
  | I16, Unsigned -> "core::ffi::c_ushort"
  | I32, Signed -> "core::ffi::c_int"
  | I32, Unsigned -> "core::ffi::c_uint"
  (* using bool here, libc doesn't have _Bool so use primitive instead*)
  | IBool, _ -> "bool"

let name_floattype_rust sz =
  match sz with F32 -> "core::ffi::c_float" | F64 -> "core::ffi::c_double"

let name_longtype_rust sz =
  match sz with
  | Signed -> "core::ffi::c_ssize_t"
  | Unsigned -> "core::ffi::c_size_t"

let rec map_tylist_to_list tylist =
  match tylist with
  | Tnil -> []
  | Tcons (ty, tyl) -> ty :: map_tylist_to_list tyl

let rec gen_ty_rust is_nested ty =
  match ty with
  | Ctypes.Tvoid -> if is_nested then "core::ffi::c_void" else "()"
  | Ctypes.Tint (sz, sg, a) ->
      (* TODO ignoring the attributes for now. The volatile should be handled a layer up probably. Same for align? Either way going for the easy thing *)
      (* TODO deal with visibility modifier *)
      name_inttype_rust sz sg
  | Ctypes.Tarray (ity, num_ele, attrs) ->
      let fmted_ity = gen_ty_rust true ity in
      sprintf "[ %s; %ld]" fmted_ity (camlint_of_coqint num_ele)
  | Ctypes.Tstruct (id, attr) -> extern_atom_r id
  | Ctypes.Tunion (id, attr) -> extern_atom_r id
  | Ctypes.Tfloat (sz, a) -> name_floattype_rust sz
  | Ctypes.Tlong (sz, a) -> name_longtype_rust sz
  (* raw pointer only right now *)
  (* TODO handle the attributes on a type *)
  | Ctypes.Tpointer (ty, _a) -> sprintf "*mut %s" (gen_ty_rust true ty)
  (* function pointers *)
  | Ctypes.Tfunction (tylist, ty, cc) ->
      let r_arglist =
        List.map (gen_ty_rust false) (map_tylist_to_list tylist)
        |> String.concat ","
      in
      (* TODO this makes for nicer code, but should we be mappign to c_void or unit everywhere? *)
      (* cvoid should only appear in function signatures by itself *)
      let rust_ret_ty = gen_ty_rust false ty in
      (* all C functions and C pointers look like this *)
      sprintf "(unsafe extern \"C\" fn(%s) -> %s)" r_arglist rust_ret_ty

let map_to_unsigned = function
  | Ctypes.Tarray (Ctypes.Tint (I8, _, attrs), num_ele, a) ->
      Ctypes.Tarray (Ctypes.Tint (I8, Unsigned, attrs), num_ele, a)
  | ty ->
      Format.printf "error! something besides expected type for %s\n"
        (gen_ty_rust false ty);
      ty

let gen_name_and_ty_rust name ty = name ^ " : " ^ gen_ty_rust false ty

let print_primitive_init fmt ty = function
  | Init_int8 n ->
      fprintf fmt "(%ld as core::ffi::c_char)" (camlint_of_coqint n)
  | Init_int16 n ->
      fprintf fmt "(%ld as core::ffi::c_short)" (camlint_of_coqint n)
  | Init_int32 n ->
      fprintf fmt "(%ld as core::ffi::c_int)" (camlint_of_coqint n)
  | Init_int64 n ->
      fprintf fmt "(%Ld as core::ffi::c_long)" (camlint64_of_coqint n)
  | Init_float32 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_float64 n -> fprintf fmt "%.15F" (camlfloat_of_coqfloat n)
  | Init_space n -> fprintf fmt "(0 as %s)" (gen_ty_rust false ty)
  (* this is hard because in the case of globals, the addr_of!  does not work. *)
  (* TODO *)
  (* - try with rust nightly and the new pointer type *)
  (* - copy c2rust *)
  | Init_addrof (symb, ofs) ->
      (* analogue to PrintCsyntax.ml:474 *)
      let ofs = camlint_of_coqint ofs in
      if ofs = 0l then
        fprintf fmt "std::ptr::addr_of_mut! { %s }" (extern_atom symb)
      else
        fprintf fmt "(std::ptr::addr_of_mut! { %s }).add(%ld)"
          (extern_atom symb) ofs

let re_string_literal = Str.regexp "__stringlit_[0-9]+"

let find_comp_defn (importer : Imports.t) id =
  Imports.get_ty_dfn importer ~name:id

let rec print_arr fmt (arr : init_data list) =
  match arr with
  | [] -> ()
  | e :: l ->
      let st =
        match e with
        | Init_int8 _ -> "int8"
        | Init_int16 _ -> "int16"
        | Init_int32 _ -> "int32"
        | Init_int64 _ -> "int64"
        | Init_float32 _ -> "flaot32"
        | Init_float64 _ -> "flaot64"
        | Init_space num ->
            "space" ^ (camlint_of_coqint num |> Int32.to_int |> string_of_int)
        | Init_addrof (_, _) -> "addrof"
      in
      fprintf fmt "%s," st;
      print_arr fmt l

let rec print_composite_init fmt (importer : Imports.t) arr ty =
  (*TODO both cases do the same thing. Make it more dry *)
  match ty with
  | Ctypes.Tstruct (id, _attrs) ->
      fprintf fmt "%s {" (extern_atom_r id);
      let (Composite (_, _, membs, _attrs)) = find_comp_defn importer id in
      let res =
        List.fold_left
          (fun acc memb ->
            match memb with
            | Member_plain (id_memb, ty_memb) ->
                fprintf fmt "%s: " (extern_atom_r id_memb);
                let arr_res = print_composite_init fmt importer acc ty_memb in
                fprintf fmt ",";
                arr_res
            | Member_bitfield _ -> raise (Panic "Don't support bitfields yet"))
          arr membs
      in
      fprintf fmt "}";
      res
  | Ctypes.Tunion (id, _attrs) ->
      fprintf fmt "%s {" (extern_atom_r id);
      let (Composite (_, _, membs, _attrs)) = find_comp_defn importer id in
      let res =
        List.fold_left
          (fun acc memb ->
            match memb with
            | Member_plain (id_memb, ty_memb) ->
                fprintf fmt "%s: " (extern_atom_r id_memb);
                let arr_res = print_composite_init fmt importer acc ty_memb in
                fprintf fmt ",";
                arr_res
            | Member_bitfield _ -> raise (Panic "Don't support bitfields yet"))
          arr membs
      in
      fprintf fmt "}";
      res
  | Ctypes.Tarray (ty_inner, num, _attrs) ->
      fprintf fmt "[";

      (* print_arr fmt arr; fprintf fmt "]"; *)
      let res =
        List.fold_left
          (fun acc _ ->
            let res = print_composite_init fmt importer acc ty_inner in
            fprintf fmt ", ";
            res)
          (arr
          |> List.filter (fun x ->
                 match x with Init_space _ -> false | _ -> true))
          (List.init (camlint_of_coqint num |> Int32.to_int) (fun x -> x))
      in
      fprintf fmt "]";

      res
  | _ -> (
      match arr with
      | ele :: l ->
          fprintf fmt "(";
          print_primitive_init fmt ty ele;
          fprintf fmt " as %s)" (gen_ty_rust false ty);
          l
      | nil ->
          fprintf fmt "(0 as %s)" (gen_ty_rust false ty);
          nil)

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

let string_of_init fmt id (expected_length : int option) =
  let b, extras =
    match expected_length with
    | Some l ->
        let differing_len = l - List.length id in
        fprintf fmt "/* \nLEN %d, expected_length %d, diff: %d */ \n"
          (List.length id) l differing_len;
        (Buffer.create l, differing_len)
    | None -> (Buffer.create (List.length id), 0)
  in
  let add_init = function
    | Init_int8 n ->
        let c = Int32.to_int (camlint_of_coqint n) in
        if c >= 32 && c <= 126 && c <> Char.code '\"' && c <> Char.code '\\'
        then Buffer.add_char b (Char.chr c)
        else if Char.code '\000' = c then Buffer.add_string b "\\0"
        else if Char.code '\n' = c then Buffer.add_string b "\\n"
        else if Char.code '\t' = c then Buffer.add_string b "\\t"
        else if Char.code '\"' = c then Buffer.add_string b "\\\""
        (* else if 11 = c then Buffer.add_string b "\\v" *)
        (* else if 12 = c then Buffer.add_string b "\\f" *)
        (* else if 13 = c then Buffer.add_string b "\\r" *)
          else Buffer.add_string b (Printf.sprintf "\\x%02x" c)
    | _ -> assert false
  in
  let rec add_extras l' =
    if l' <= 0 then ()
    else (
      Buffer.add_string b "\\0";
      add_extras (l' - 1))
  in
  List.iter add_init id;
  add_extras extras;
  Buffer.contents b

let print_globvar fmt (importer : Imports.t) id v =
  let name_bare = extern_atom_r id in
  let linkage = if C2C.atom_is_static id then "" else "pub " in
  (* NOTE: *)
  (* in rust, const a : u32 = 5; ensure (with the compiler) that a is not writable. Ever *)
  (* in c, const int a = 5; void f(){ *(&a) = 6; } works just fine*)
  (* This *IS* UB *)

  let name = linkage ^ "static mut " ^ name_bare in
  match v.gvar_init with
  (* in C this would be extern variablename; *)
  (* in Rust, we have a separate function that does imports *)
  (* so this is a noop *)
  | [] -> ()
  | [ Init_space _ ] ->
      fprintf fmt "%s = unsafe { std::mem::zeroed() }; @ @ "
        (gen_name_and_ty_rust name v.gvar_info)
  | _ ->
      (match (v.gvar_info, v.gvar_init) with
      | ( ( Ctypes.Tint _ | Ctypes.Tlong _ | Ctypes.Tfloat _ | Tpointer _
          | Tfunction _ ),
          [ i1 ] ) ->
          fprintf fmt "@[<hov 2>%s = unsafe {("
            (gen_name_and_ty_rust name v.gvar_info);
          print_primitive_init fmt v.gvar_info i1;
          fprintf fmt " as %s) }" (gen_ty_rust false v.gvar_info)
      | ty, il ->
          if
            Str.string_match re_string_literal (extern_atom_r id) 0
            && List.for_all (function Init_int8 _ -> true | _ -> false) il
          then (
            (* dereference here because string literals are pointers to byte arrays  *)
            (* transmute here because the literal isn't the expected type. In C it's signed and in rust it's unsigned *)
            (* We're black boxing the entire thing and just saying "this is what we expect it to be"  *)
            fprintf fmt "@[<hov 2>%s = unsafe { std::mem::transmute("
              (gen_name_and_ty_rust name v.gvar_info);
            fprintf fmt "*b\"%s\")}"
              (string_of_init fmt il (get_len_of_char_arr v.gvar_info)))
          else (
            fprintf fmt "@[<hov 2>%s = unsafe { "
              (gen_name_and_ty_rust name v.gvar_info);
            (* let maybe_struct_name = *)
            (* match g.var_info with *)
            (* | Ctypes.Tstruct(_, _) => *)
            (* | Ctypes.Tstruct(_, _) => *)
            (* in *)
            let _ = print_composite_init fmt importer il v.gvar_info in
            fprintf fmt " }"));
      fprintf fmt ";@]@ @ "

let rec print_expr fmt e =
  match e with
  (* | Eif_then_else(cond, if_branch, else_branch, _ty) ->( *)
  (*     fprintf fmt "@[<v 2>if %a {@ %a@;<0 -2>} else {@;%a@;<0 -2>}@]" *)
  (*       print_expr cond print_expr if_branch print_expr else_branch *)
  (*   ) *)
  | Econst_int (n, Ctypes.Tint (I32, Unsigned, _)) ->
      fprintf fmt "(%lu as core::ffi::c_uint)" (camlint_of_coqint n)
  | Econst_int (n, Ctypes.Tint (IBool, _, _)) ->
      fprintf fmt "%s"
        (match camlint_of_coqint n with
        | 0l -> "false"
        | 1l -> "true"
        | _ -> "ERROR bool is outside {0, 1}")
  | Econst_int (n, ty) ->
      fprintf fmt "(%ld as %s)" (camlint_of_coqint n) (gen_ty_rust false ty)
  | Econst_float (f, ty) ->
      let is32bit = match ty with Tfloat (F32, _) -> true | _ -> false in
      let camlf = camlfloat_of_coqfloat f in
      let num =
        if Float.is_infinite camlf then
          if is32bit then "core::f32::INFINITY" else "core::f64::INFINITY"
        else camlf |> Printf.sprintf "%.18g"
      in
      printf "\nGOT THIS FLOAT %f \n" camlf;
      fprintf fmt "(%s as %s)" num (gen_ty_rust false ty)
  | Econst_single (f, ty) ->
      let is32bit = match ty with Tfloat (F32, _) -> true | _ -> false in
      let camlf = camlfloat_of_coqfloat f in
      let num =
        if Float.is_infinite camlf then
          if is32bit then "core::f32::INFINITY" else "core::f64::INFINITY"
        else camlf |> Printf.sprintf "%.18g"
      in
      fprintf fmt "(%s as %s)" num (gen_ty_rust false ty)
  | Econst_long (n, Ctypes.Tlong (Unsigned, v)) ->
      fprintf fmt "(%Lu as %s)" (camlint64_of_coqint n)
        (gen_ty_rust false (Ctypes.Tlong (Unsigned, v)))
  | Econst_long (n, ty) ->
      fprintf fmt "(%Ld as %s)" (camlint64_of_coqint n) (gen_ty_rust false ty)
  | RustLight.Evar (id, _ty) ->
      fprintf fmt "%s" (extern_atom_r id) (* (_ty ==) *)
  | RustLight.Etempvar (id, _ty) -> fprintf fmt "%s" (temp_name id)
  | RustLight.Eunop (op_ty, exp, ty) -> (
      match (op_ty, ty) with
      | Cop.Oneg, Ctypes.Tint (Ctypes.I32, Ctypes.Unsigned, _) ->
          fprintf fmt "((%a).wrapping_neg() as %s)" print_expr exp
            (gen_ty_rust false ty)
      (* TODO this is cursed. Could be cleaned up *)
      | _ ->
          let op_name =
            match op_ty with
            (* conversion to bool *)
            | Cop.Onotbool -> "!"
            (* bitwise not is ! in rust *)
            | Cop.Onotint -> "!"
            | Cop.Oneg -> "-"
            | Cop.Oabsfloat -> "UNSUPPORTED OP"
          in
          fprintf fmt "((%s%a) as %s)" op_name print_expr exp
            (gen_ty_rust false ty))
  | RustLight.Ebinop (op_type, e1, e2, ty) -> (
      match (op_type, type_of_expr e1, type_of_expr e2) with
      | _, Ctypes.Tpointer (_, _), Ctypes.Tint (_, _, _) ->
          handle_ptr_arithmetic fmt op_type e1 e2
      | _, Ctypes.Tint (_, _, _), Ctypes.Tpointer (_, _) ->
          handle_ptr_arithmetic fmt op_type e2 e1
      | _, Ctypes.Tlong (_, _), Ctypes.Tpointer (_, _) ->
          handle_ptr_arithmetic fmt op_type e2 e1
      | _, Ctypes.Tpointer (_, _), Ctypes.Tlong (_, _) ->
          handle_ptr_arithmetic fmt op_type e1 e2
      (* TODO these only differ slightly. Shouldn't need so much repeated code *)
      | Cop.Osub, Ctypes.Tpointer (_, _), Ctypes.Tpointer (_, _) ->
          fprintf fmt "(%a).offset_from(%a)" print_expr e1 print_expr e2
      | Cop.Osub, Ctypes.Tint (_, Unsigned, _), Ctypes.Tint (_, Unsigned, _) ->
          fprintf fmt "(%a).wrapping_sub(%a)" print_expr e1 print_expr e2
      | Cop.Oadd, Ctypes.Tint (_, Unsigned, _), Ctypes.Tint (_, Unsigned, _) ->
          fprintf fmt "(%a).wrapping_add(%a)" print_expr e1 print_expr e2
      | Cop.Omul, Ctypes.Tint (_, Unsigned, _), Ctypes.Tint (_, Unsigned, _) ->
          fprintf fmt "(%a).wrapping_mul(%a)" print_expr e1 print_expr e2
      | Cop.Odiv, Ctypes.Tint (_, Unsigned, _), Ctypes.Tint (_, Unsigned, _) ->
          fprintf fmt "(%a).wrapping_div(%a)" print_expr e1 print_expr e2
      | Cop.Omod, Ctypes.Tint (_, Unsigned, _), Ctypes.Tint (_, Unsigned, _) ->
          fprintf fmt "(%a).wrapping_rem(%a)" print_expr e1 print_expr e2
      | Cop.Osub, Ctypes.Tlong (Unsigned, _), Ctypes.Tlong (Unsigned, _) ->
          fprintf fmt "(%a).wrapping_sub(%a)" print_expr e1 print_expr e2
      | Cop.Oadd, Ctypes.Tlong (Unsigned, _), Ctypes.Tlong (Unsigned, _) ->
          fprintf fmt "(%a).wrapping_add(%a)" print_expr e1 print_expr e2
      | Cop.Omul, Ctypes.Tlong (Unsigned, _), Ctypes.Tlong (Unsigned, _) ->
          fprintf fmt "(%a).wrapping_mul(%a)" print_expr e1 print_expr e2
      | Cop.Odiv, Ctypes.Tlong (Unsigned, _), Ctypes.Tlong (Unsigned, _) ->
          fprintf fmt "(%a).wrapping_div(%a)" print_expr e1 print_expr e2
      | Cop.Omod, Ctypes.Tlong (Unsigned, _), Ctypes.Tlong (Unsigned, _) ->
          fprintf fmt "(%a).wrapping_rem(%a)" print_expr e1 print_expr e2
      | _, _, _ ->
          let op_name =
            match op_type with
            | Cop.Oadd -> "+"
            | Cop.Osub -> "-"
            | Cop.Omul -> "*"
            | Cop.Odiv -> "/"
            | Cop.Omod -> "%"
            | Cop.Oand -> "&"
            | Cop.Oor -> "|"
            | Cop.Oxor -> "^"
            | Cop.Oshl -> "<<"
            | Cop.Oshr -> ">>"
            | Cop.Oeq -> "=="
            | Cop.One -> "!="
            | Cop.Olt -> "<"
            | Cop.Ogt -> ">"
            | Cop.Ole -> "<="
            | Cop.Oge -> ">="
          in
          fprintf fmt "(%a %s %a)" print_expr e1 op_name print_expr e2)
  | RustLight.Efield (exp, id, ty) ->
      fprintf fmt "%a.%s" print_expr exp (extern_atom_r id)
  | RustLight.Ederef (exp, _ty (* type we derefernce into *)) -> (
      (* type we were before dereferencing *)
      let exp_ty = type_of_expr exp in
      match exp_ty with
      (* edge case for this because now this is dependent on what ty is *)
      | Tpointer (_, _) -> fprintf fmt "(*%a)" print_expr exp
      (* TODO is this needed? *)
      | Tarray (_, _, _) -> fprintf fmt "(%a)[0]" print_expr exp
      | _ -> fprintf fmt "unimplemented deref for this type"
      (* get type of exp. If it's an array, use array dereference syntax.*))
  (* TODO broken for globals. Need to special case that. *)
  | RustLight.Eaddrof (exp, _) ->
      fprintf fmt "(std::ptr::addr_of_mut!(%a))" print_expr exp
  (* we know that we  *)
  | RustLight.Ecast (exp, ty) -> (
      let e_ty = type_of_expr exp in
      let e_ty_is_composite = is_composite e_ty in
      let to_ty_is_composite = is_composite ty in

      (* may only cast between scalar types  *)
      match (e_ty_is_composite, to_ty_is_composite) with
      | false, false ->
          fprintf fmt "(%a as %s)" print_expr exp (gen_ty_rust false ty)
      | b1, b2 -> (
          match (e_ty, ty) with
          | Ctypes.Tpointer (Tfunction (a, b, c), d), Ctypes.Tfunction (x, y, z)
            ->
              fprintf fmt "core::mem::transmute::<%s, %s>(%a)"
                (gen_ty_rust false e_ty) (gen_ty_rust false ty) print_expr exp
          (* TODO go back in rustlight and make sure it's not a wild cast... *)
          | Ctypes.Tarray (_ty_from, _, _), Ctypes.Tpointer (_ty_to, _)
          (* -> fprintf fmt "((%a).as_mut_ptr() as %s)" print_expr exp (gen_ty_rust false ty) *)
            ->
              fprintf fmt "(%a).as_mut_ptr() as %s" print_expr exp
                (gen_ty_rust false ty)
              (* (gen_ty_rust false _ty_from) (gen_ty_rust false _ty_to) *)
          | Ctypes.Tfunction (_, _, _), Ctypes.Tpointer (_, _) ->
              fprintf fmt "(%a as %s)" print_expr exp (gen_ty_rust false ty)
          | Ctypes.Tstruct (a, _), Ctypes.Tstruct (b, _) ->
              if a = b then fprintf fmt "%a" print_expr exp
              else
                let a', b' = (a |> P.to_int, b |> P.to_int) in
                printf "FOUND SOMETHING THAT ISNT RIGHT %b %b\n" b1 b2;
                fprintf fmt "casting (%s as %s %d %d %b)!!"
                  (gen_ty_rust false e_ty) (gen_ty_rust false ty) a' b' (a' = b');
                ()
          (* if this is the zero constant, we're going to print int -> pointer *)
          | _, _ ->
              printf "FOUND SOMETHING THAT ISNT RIGHT %b %b\n" b1 b2;
              fprintf fmt "(%a as %s)" print_expr exp (gen_ty_rust false ty))
      (* somewhat complicated because we might want to use *)
      (* `as` on pointers *)
      (* or https://doc.rust-lang.org/std/mem/fn.transmute.html *)
      (* fprintf fmt "TODO casts are unimplemented" *))
  | RustLight.Esizeof (ty, ty') ->
      fprintf fmt "(std::mem::size_of::<%s>() as %s)" (gen_ty_rust false ty)
        (gen_ty_rust false ty')
  | RustLight.Ealignof (ty, ty') ->
      fprintf fmt "(std::mem::align_of::<%s>() as %s)" (gen_ty_rust false ty)
        (gen_ty_rust false ty')
  | RustLight.Enull_check exp -> fprintf fmt "((%a).is_null())" print_expr exp

and handle_ptr_arithmetic fmt binop ptr_exp int_exp =
  let fn_name =
    match binop with Cop.Oadd -> "add" | Cop.Osub -> "sub" | _ -> "ERROR"
  in
  (* TODO should be reflected in semantics *)
  fprintf fmt "((%a).%s(%a as usize))" print_expr ptr_exp fn_name print_expr
    int_exp

let rec print_arglist fmt arglist =
  match arglist with
  | [ arg ] -> fprintf fmt "%a" print_expr arg
  | arg :: al ->
      fprintf fmt "%a, " print_expr arg;
      print_arglist fmt al
  | nil -> ()

let rec print_stmt fmt body =
  match body with
  | S_skip -> () (* fprintf fmt "/* skip stmt */@;"; *)
  | S_assign (e1, e2) ->
      fprintf fmt "@[<hv 2>%a =@ %a;@]" print_expr e1
        (* (gen_ty_rust (type_of_expr e1)) *)
        print_expr e2
  | S_set (id, e) ->
      fprintf fmt "@[<hv 2>%s =@ %a;@]" (temp_name id) print_expr e
  | S_return (Some (exp, ty)) -> fprintf fmt "return %a;" print_expr exp
  | S_return None -> fprintf fmt "return;"
  | S_sequence (RustLight.S_skip, s2) -> print_stmt fmt s2
  | S_sequence (s1, RustLight.S_skip) -> print_stmt fmt s1
  | S_sequence (e1, e2) -> fprintf fmt "%a@;%a" print_stmt e1 print_stmt e2
  | S_block (Some lbl, stmt) ->
      fprintf fmt "@[<v 2>'lbl_%ld: {@;%a@;<0 -2>}@]"
        (camlint_of_coqint lbl) print_stmt stmt
  | S_block (None, stmt) -> fprintf fmt "@[<v 2>{@;%a@;<0 -2>}@]" print_stmt stmt
  | S_continue None -> fprintf fmt "continue;"
  | S_continue (Some lbl) ->
      fprintf fmt "continue 'lbl_%ld;" (camlint_of_coqint lbl)
  | S_if_then_else (exp, s_true, S_skip) ->
      fprintf fmt "@[<v 2>if %a {@;%a@;<0 -2>}@]" print_expr exp print_stmt
        s_true
  | S_if_then_else (exp, S_skip, s_false) ->
      fprintf fmt "@[<v 2>if !(%a) {@;%a@;<0 -2>}@]" print_expr exp print_stmt
        s_false
  | S_if_then_else (exp, s_true, s_false) ->
      fprintf fmt "@[<v 2>if %a {@ %a@;<0 -2>} else {@;%a@;<0 -2>}@]" print_expr
        exp print_stmt s_true print_stmt s_false
  | S_break None -> fprintf fmt "break;"
  | S_break (Some lbl) -> fprintf fmt "break 'lbl_%ld;" (camlint_of_coqint lbl)
  | S_builtin (maybe_ident, external_fn, lty, lexp) ->
      fprintf fmt "unimplemented call stmt"
  | S_loop2 (Some outer, Some inner, s1, s2) ->
      fprintf fmt
        "@[<v 2>'lbl_%ld: loop {@;\
         @[<v 2>'lbl_%ld: loop {@;\
         %a@;\
         <0 -2>}@]%a@;\
         <0 -2>}@]"
        (camlint_of_coqint outer) (camlint_of_coqint inner) print_stmt s1
        print_stmt s2
  | S_loop2 (None, None, _, _) -> fprintf fmt "@[loop {}@]@;"
  | S_loop2 (Some outer, None, S_skip, s2) ->
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]"
        (camlint_of_coqint outer) print_stmt s2
  (* | S_loop2(Some(outer), None, s1, S_skip) -> ( *)
  (*     fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]" *)
  (*             (camlint_of_coqint outer) print_stmt s1 *)
  (*   ) *)
  | S_loop2 (_, _, _, _) ->
      let _ = Panic "Unexpected loop type" in
      ()
  | S_loop (None, stmt, S_skip) ->
      fprintf fmt "@[<v 2>loop {@;%a@;<0 -2>}@]@;" print_stmt stmt
  | S_loop (Some lbl, stmt, S_skip) ->
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;<0 -2>}@]"
        (camlint_of_coqint lbl) print_stmt stmt
  | S_loop (Some lbl, stmt, stmt2) ->
      fprintf fmt "@[<v 2>'lbl_%ld: loop {@;%a@;%a@;<0 -2>}@]"
        (camlint_of_coqint lbl) print_stmt stmt print_stmt stmt2
  | S_match_int (expr, stmts) ->
      fprintf fmt "@[<v 2>match %a {@;%a@;<0 -2>};@]" print_expr expr
        print_cases stmts
  (* the difference between these two cases is the assignment to a temporary var vs discard *)
  | S_call (Some id, name, arg_list) ->
      fprintf fmt "@[<hv 2>%s =@ %a(@[<hov 0>%a@]);@]" (temp_name id) print_expr
        name print_arglist arg_list
  | S_exit ecode ->
      fprintf fmt "@[<hv 2>::std::process::exit@,(@[<hov 0>%a@]);@]" print_expr
        ecode
  | S_call (None, name, arg_list) ->
      fprintf fmt "@[<hv 2>%a(@[<hov 0>%a@]);@]" print_expr name print_arglist
        arg_list
  | _ -> fprintf fmt "unimplemented?!"

and print_cases fmt cases =
  match cases with
  | LSnil body -> fprintf fmt "@[<v 2>_ => {@;%a@;<0 -2>}@]@;" print_stmt body
  | LScons (n, body, stmts) ->
      (match n with
      | Some n' ->
          fprintf fmt "@[<v 2>%ld => {@;%a@;<0 -2>}@]@;" (camlint_of_coqint n')
            print_stmt body
      | None -> fprintf fmt "@[<v 2>_ => {@;%a@;<0 -2>}@]@;" print_stmt body);
      print_cases fmt stmts

(* fn name(param: ty, ) -> { body  } *)
let print_function fmt id fn =
  let fn_name = extern_atom_r id in

  let fn_params = fn.fn_params in
  let fn_linkage = if C2C.atom_is_static id then "" else "pub" in
  let fn_args =
    fn_params
    |> List.map (fun (tid, tty) -> gen_name_and_ty_rust (extern_atom_r tid) tty)
    |> List.map (fun x -> "mut " ^ x)
    |> String.concat ", "
  in

  (* HACK this should be reflected in the semantics of rustlight *)
  (* But, we haven't gotten there yet. Rustlight is still generic over c types which isn't right. *)
  (* let rty = if fn_name = "main" then "!" else gen_ty_rust false fn.fn_return in *)
  let rty = gen_ty_rust false fn.fn_return in
  let needs_space = if String.length fn_linkage != 0 then " " else "" in

  (* let safety_qualifier = if fn.fn_is_safe then "" else "unsafe" in *)
  let externc = "extern \"C\"" in
  let ed = !Clflags.option_rust_edition in
  let nomangle =
    if C2C.atom_is_static id then ""
    else
      match ed with
      | Clflags.E2021 -> "#[no_mangle]"
      | Clflags.E2024 -> "#[unsafe(no_mangle)]"
  in

  printf "PRINTING FUNCTION %s" fn_name;
  fprintf fmt "%s@ @[<v 2>%s%s%s fn %s(%s) -> %s " nomangle fn_linkage
    needs_space externc fn_name fn_args rty;
  printf "PRINTed FUNCTION %s" fn_name;
  (* fprintf fmt "@ @[<v 2>{@ "; *)
  fprintf fmt "{@ @[<v 2>unsafe {@ ";
  (* In C we just reserve on the stack *)
  (* In Rust to avoid compilation errors we need the entire struct to be initialized before first use. *)
  (* We translate to that directly *)
  List.iter
    (fun (vid, vty) ->
      (* TODO can make this dryer *)
      (* initialized functions can only come from temporary variables *)
      (* so it's fine to not initialize them because they will be written to*)
      (* everything else will be initialized and valid *)
      let zero_initialize =
        match vty with
        | Ctypes.Tfunction (_, _, _) -> ""
        | _ -> " = std::mem::zeroed()"
      in
      fprintf fmt "let mut %s%s;@ "
        (gen_name_and_ty_rust (extern_atom_r vid) vty)
        zero_initialize)
    fn.fn_vars;
  List.iter
    (fun (vid, vty) ->
      let zero_initialize =
        match vty with
        | Ctypes.Tfunction (_, _, _) -> ""
        | _ -> " = std::mem::zeroed()"
      in
      fprintf fmt "let mut %s%s;@ "
        (gen_name_and_ty_rust (temp_name vid) vty)
        zero_initialize)
    fn.fn_temps;

  print_stmt fmt fn.fn_body;

  fprintf fmt "@;<0 -2>}@]@;<0 -2>}@]@ @."

let print_fundef fmt id fundef =
  match fundef with
  | Ctypes.Internal f -> print_function fmt id f
  | Ctypes.External (_, _, _, _) -> fprintf fmt ""

let print_globdef fmt (importer : Imports.t) (id, gd) =
  match gd with
  | Gfun fundef -> print_fundef fmt id fundef
  | Gvar v -> print_globvar fmt importer id v

let struct_or_union = function Struct -> "struct" | Union -> "union"

let print_member fmt = function
  | Member_plain (id, ty) ->
      fprintf fmt "@; pub %s," (gen_name_and_ty_rust (extern_atom_r id) ty)
  | _ -> ()

let define_composite fmt (Composite (id, su, m, a)) =
  (* let linkage = C2C.atom_is_static *)
  let maybe_aligned =
    match a.attr_alignas with
    | None -> ""
    | Some n -> sprintf ", align(%Ld)" (Int64.shift_left 1L (N.to_int n))
  in

  (* either I define this locally or I'm importing it. Even if this is a local-only thing, it's hidden behind the module so this is fine *)
  (* TODO while this does reflect C semantics, Copy is morally wrong here. *)
  (* It would be better to clone explicitly where needed. *)
  fprintf fmt "#[repr(C%s)]@;#[derive(Clone, Copy)]@;@[<v 2>pub %s %s {"
    maybe_aligned (struct_or_union su) (extern_atom_r id);
  List.iter (print_member fmt) m;
  fprintf fmt "@;<0 -2>}@]@; @;"

(* TODO ways to clean this up: *)
(* insertion is repeated code and there's probably a better way to do that *)
(* external_symbols key should be returned as something else. That's a hack *)
let get_fn_foreign_syms mapping (* global symbol -> module *)
    list_of_ids (* idents that might be global symbols *)
    cur_sym_map
      (* module name -> {imports from that module}  *)
      (* what we're filling out for the used symbols *) =
  (* printf "UID list of ids %d\n" (List.length list_of_ids); *)
  List.fold_left
    (fun acc id ->
      let name = extern_atom_r id in
      (* let _ = printf "USED NAME %s" name in *)
      let maybe_module = Hashtbl.find_opt mapping name in
      match maybe_module with
      (* we don't know what this symbol is. It's not defined in the project *)
      | None -> (
          if
            (* it's a libc symbol, so we can import from libc *)
            StringSet.mem name libc_symbol_set
          then (
            (* printf "UID couldn't find module for symbol %s in mapping. Assuming libc\n" name; *)
            let maybe_hs = Hashtbl.find_opt acc "libc" in
            match maybe_hs with
            | None ->
                let new_hs = StringSet.singleton name in
                Hashtbl.replace acc "libc" new_hs;
                acc
            | Some hs ->
                let new_hs = StringSet.add name hs in
                Hashtbl.replace acc "libc" new_hs;
                acc)
          (* it's not a libc symbol, so we have to extern "C" it and have the linker find i: *)
            else
            let maybe_hs = Hashtbl.find_opt acc "external_symbols" in
            match maybe_hs with
            | None ->
                let new_hs = StringSet.singleton name in
                Hashtbl.replace acc "external_symbols" new_hs;
                acc
            | Some hs ->
                let new_hs = StringSet.add name hs in
                Hashtbl.replace acc "external_symbols" new_hs;
                acc)
      | Some module_ -> (
          let maybe_hs = Hashtbl.find_opt acc module_ in
          match maybe_hs with
          | None ->
              let new_hs = StringSet.singleton name in
              Hashtbl.replace acc module_ new_hs;
              acc
          | Some hs ->
              let new_hs = StringSet.add name hs in
              Hashtbl.replace acc module_ new_hs;
              acc))
    cur_sym_map list_of_ids

(*get a list of composite types used by the c module *)
let[@warning "-42"] get_used_tys_in_prog
    (fn_defs :
      (AST.ident
      * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)
      list) =
  List.fold_left
    (fun acc
         (elt :
           AST.ident
           * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)
       ->
      match elt with
      (* TODO should probably pull in the types from this too but this requires rustlight changes*)
      | _id, Gvar v -> acc
      | id, Gfun (Internal rf) ->
          (* let fn_name = extern_atom_r id in *)
          let r_used_types = rf.fn_ty_imports in
          (* printf "\n\n function %s has %d imports \n\n" fn_name (List.length (PositiveSet.elements r_used_types)); *)
          PositiveSet.union acc r_used_types
      | _ -> acc)
    PositiveSet.empty fn_defs

let rec extract_tys_from_ty ty =
  match ty with
  | Tstruct (id, _) | Tunion (id, _) ->
      (* printf "extracted %s" (extern_atom_r id);  *)
      [ id ]
  | Tarray (ty, _, _) | Tpointer (ty, _) -> extract_tys_from_ty ty
  | Tfunction (tl, ty, _) -> extract_tys_from_ty ty @ extract_tys_from_tl tl
  | _ -> []

and extract_tys_from_tl tl =
  match tl with
  | Tnil -> []
  | Tcons (ty, tl') -> extract_tys_from_ty ty @ extract_tys_from_tl tl'

let get_contained_typ_idents (Ctypes.Composite (id, sou, members, _)) =
  List.fold_left
    (fun acc ele ->
      match ele with
      | Member_plain (_id, ty) ->
          (* printf "\n CONSIDERING MEMBER %s\n" (extern_atom_r _id);  *)
          extract_tys_from_ty ty @ acc
      | Member_bitfield (bid, _, _, _, _, _) ->
          unimplemented (extern_atom_r bid))
    [] members

(* args match gen_imports outputs *)
let rec recursively_gen_composite_defns_and_imports
    (composite_mapping :
      (string, (string * Ctypes.composite_definition) option) Hashtbl.t)
    (stack : ident list)
    (* (types found in a project local module, opaque types, types defined in module) *)
      ((seen_idents, glbl_imports, extern_typs, in_module_composite_defns) :
        StringSet.t
        * (string, StringSet.t) Hashtbl.t
        * StringSet.t
        * (ident, composite_definition) Hashtbl.t) :
    StringSet.t
    * (string, StringSet.t) Hashtbl.t
    * StringSet.t
    * (ident, composite_definition) Hashtbl.t =
  match stack with
  | [] -> (seen_idents, glbl_imports, extern_typs, in_module_composite_defns)
  | e :: stack' ->
      let name = extern_atom_r e in
      let seen_idents_updated = StringSet.add name seen_idents in
      let dflt_value =
        ( stack',
          ( seen_idents_updated,
            glbl_imports,
            extern_typs,
            in_module_composite_defns ) )
      in
      let stack'', acc =
        if StringSet.mem name seen_idents then dflt_value
        else (
          printf "\n CONSIDERING %s\n" name;
          match Hashtbl.find_opt composite_mapping name with
          | Some (Some (mod_name, (Ctypes.Composite (id, _, _, _) as cdef)))
            -> (
              printf "\n %s in GLBLS\n" name;
              if Hashtbl.mem in_module_composite_defns id then (
                let contained_typs = get_contained_typ_idents cdef in
                printf "\n %s in MODULE\n" name;
                ( stack' @ contained_typs,
                  ( seen_idents_updated,
                    glbl_imports,
                    extern_typs,
                    in_module_composite_defns ) ))
              else
                match Hashtbl.find_opt glbl_imports mod_name with
                | None ->
                    Hashtbl.add glbl_imports mod_name (StringSet.singleton name);
                    dflt_value
                | Some ss ->
                    Hashtbl.replace glbl_imports mod_name
                      (StringSet.add name ss);
                    dflt_value)
          (* multiple occurrences defined: do nothing because it's module local defined *)
          | Some None ->
              printf "\n ENCOUNTERED MULTI DEFNS for %s?! not good\n" name;
              dflt_value
          | None ->
              (* don't know about the symbol, not found in the globally defined symbols. *)
              if not (StringSet.mem name extern_typs) then
                match Hashtbl.find_opt in_module_composite_defns e with
                | Some cdef ->
                    if not (StringSet.mem name seen_idents) then
                      let contained_types : ident list =
                        get_contained_typ_idents cdef
                      in
                      ( stack' @ contained_types,
                        ( seen_idents_updated,
                          glbl_imports,
                          extern_typs,
                          in_module_composite_defns ) )
                    else dflt_value
                (* also not found in the locally defined symbols. *)
                | None ->
                    let extern_typs_new = StringSet.add name extern_typs in
                    ( stack',
                      ( seen_idents_updated,
                        glbl_imports,
                        extern_typs_new,
                        in_module_composite_defns ) )
                (* might be a locally defined struct or something but contains a lot of types *)
              else dflt_value)
      in
      recursively_gen_composite_defns_and_imports composite_mapping stack'' acc

(* (glbl_imports, extern_typs, in_module_composite_defns) *)

let[@warning "-42"] gen_imports
    (* mapping (across all modules) from global symbol (either function or variable) to the module it is defined in *)
      (sym_mapping : (string, string) Hashtbl.t)
    (* list of name * fundef in the program *)
    (* TODO rename from fn_defs to fundefs because that's confusing. They're not all functions *)
      (fn_defs :
        (AST.ident
        * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)
        list)
    (* mapping of known structs in the program (across all modules )*)
      (composite_mapping :
        (string, (string * Ctypes.composite_definition) option) Hashtbl.t)
    prog_types mod_name :
    (string, StringSet.t) Hashtbl.t
    * StringSet.t
    * _
    * (ident, ident * string) Hashtbl.t =
  (* this is the list of composite types that were used by functions *)
  let used_composites = get_used_tys_in_prog fn_defs |> PositiveSet.elements in
  (* printf "\n USED COMPOSITES LENGTH IS: %d FOR MODULE %s\n" (List.length used_composites) mod_name; *)

  (* this returns the list of variables and functions (but NOT types) that are not module local *)
  let imports_from_gbls_syms =
    List.fold_left
      (fun acc
           (elt :
             AST.ident
             * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)
         ->
        match elt with
        | id, Gvar v ->
            if List.length v.gvar_init == 0 then
              get_fn_foreign_syms sym_mapping [ id ] acc
            else acc
        | _id, Gfun f -> (
            match f with
            | Internal rf ->
                get_fn_foreign_syms sym_mapping
                  (PositiveSet.elements rf.fn_imports)
                  acc
            (* TODO we may need to handle this case? *)
            | External _ -> acc))
      (Hashtbl.create 7) fn_defs
  in
  (* note: do not have to be used to be defined. *)
  let defined_in_module =
    List.filter
      (fun dfn ->
        let r = match dfn with Composite (id, _, _, _) -> extern_atom_r id in
        match Hashtbl.find_opt composite_mapping r with
        (* This can happen if the struct is anonymous. *)
        (* | None -> printf "UUID: NOT FOUND STRUCT %s" r; false *)
        | None ->
            (* TODO this is wrong. Should mark as anonymous in hashtbl *)
            (* printf "ANON struct %s" r;  *)
            true
        (* might be external to module *)
        | Some (Some (mname, _)) ->
            (* printf "\nUUID: mod name %s, %s len modname: %d, nmame %d, eq %b\n" *)
            (*   mod_name mname *)
            (*   (String.length mod_name) *)
            (*   (String.length mname) *)
            (*   (mname = mod_name) ; *)
            mname = mod_name
        (* internal to module *)
        | Some None -> true)
      prog_types
  in
  let defined_in_module_idents =
    List.map (fun (Composite (id, _, _, _)) -> id) defined_in_module
  in
  let stack = used_composites @ defined_in_module_idents in
  let defined_in_module_ht =
    List.fold_left
      (fun acc (Composite (id, _, _, _) as c) ->
        Hashtbl.add acc id c;
        acc)
      (Hashtbl.create 7) defined_in_module
  in

  let _seen_idents, glbl_imports, extern_typs, in_module_composite_defns =
    recursively_gen_composite_defns_and_imports composite_mapping stack
      ( StringSet.empty,
        imports_from_gbls_syms,
        StringSet.empty,
        defined_in_module_ht )
  in
  let res_idents =
    check_mod_for_extra_types composite_mapping in_module_composite_defns
  in
  (glbl_imports, extern_typs, in_module_composite_defns, res_idents mod_name)

let convert_idents_to_mod (res_idents : (ident, ident * string) Hashtbl.t)
    (import_map : (string, StringSet.t) Hashtbl.t) :
    (string, StringSet.t) Hashtbl.t =
  Hashtbl.fold
    (fun m_from_name (m_to_name, m_to_module) acc ->
      match Hashtbl.find_opt acc m_to_module with
      | None ->
          Hashtbl.add acc m_to_module
            (extern_atom_r m_to_name |> StringSet.singleton);
          acc
      | Some (existing : StringSet.t) ->
          Hashtbl.replace acc m_to_module
            (StringSet.add (m_to_name |> extern_atom_r) existing);
          acc)
    res_idents import_map

let define_composite_type_alias fmt cur_mod_name project_name contains_main
    (in_mod_ident, (imported_ident, mod_name)) =
  (* TODO easier way to do repeated code*)
  if cur_mod_name <> mod_name then
    fprintf fmt "@;pub type %s = %s::%s::%s;@;"
      (extern_atom_r in_mod_ident)
      (if contains_main then project_name else "crate")
      mod_name
      (extern_atom_r imported_ident)
  else
    fprintf fmt "@;pub type %s = %s;@;"
      (extern_atom_r in_mod_ident)
      (extern_atom_r imported_ident)

(* TODO undo logic for crate use because contains_main is now always false *)
let print_imports fmt imports project_name contains_main =
  (* let import_map = convert_idents_to_mod res_idents import_map_unmerged in *)
  Hashtbl.iter
    (fun (module_name : string) (is : ImportSet.t) ->
      let crate = if contains_main then project_name ^ "::" else "crate::" in
      let import_names = ImportSet.elements is in
      let size = List.length import_names in
      if size == 1 then
        let ele = List.hd import_names in
        match ele with
        | Some a, id ->
            fprintf fmt "use %s%s::%s as %s;" crate
              (remove_c_extension module_name)
              (Linking.ident_to_string ~name:id)
              a
        | None, id ->
            fprintf fmt "use %s%s::%s;" crate
              (remove_c_extension module_name)
              (Linking.ident_to_string ~name:id)
      else (
        fprintf fmt "use %s%s::{" crate (remove_c_extension module_name);
        List.iter
          (fun x ->
            match x with
            | None, id -> fprintf fmt "%s, " (Linking.ident_to_string ~name:id)
            | Some x', id ->
                fprintf fmt "%s as %s, " (Linking.ident_to_string ~name:id) x')
          import_names;
        fprintf fmt "};"))
    imports;
  fprintf fmt "@;"

let print_extern_types fmt (is : IdentSet.t) =
  let ed = !Clflags.option_rust_edition in
  let extern_str =
    match ed with Clflags.E2021 -> "extern" | Clflags.E2024 -> "unsafe extern"
  in
  fprintf fmt "%s \"C\" {@ @[<v 2>@;" extern_str;
  IdentSet.iter
    (fun name -> fprintf fmt "pub type %s;@;" (Linking.ident_to_string ~name))
    is;
  fprintf fmt "@;<0 -2>}@]@;@;"
(* fun elt -> *)
(*       match Hashtbl.find_opt sigs elt with *)
(*       | Some(Gfun(External(ef, tl, rty, _))) -> ( *)
(*         match ef with *)
(*         | EF_external(name, s) *)
(*         | EF_builtin(name, s) *)
(*         | EF_runtime(name, s) -> *)
(*             fprintf fmt "fn %s(" (List.to_seq name |> String.of_seq); *)
(*             List.iter (fun ty -> *)
(*               fprintf fmt "_: %s," (gen_ty_rust false ty) *)
(*             ) (map_tylist_to_list tl); *)
(*             if s.sig_cc.cc_vararg <> None then fprintf fmt " _:..."; *)
(*             fprintf fmt ") -> %s;@;" (gen_ty_rust false rty) *)
(*         | _ -> printf "\nERROR unsupported external fn type \n" *)
(*       ) *)
(*       | Some(Gfun(Internal(_))) -> printf "\n ERROR: external linkage for internal function??\n" *)
(*       | Some(Gvar(gv)) -> *)
(*           fprintf fmt "static mut %s: %s;@;" elt (gen_ty_rust false gv.gvar_info) *)
(*       | None -> printf "\n ERROR: could not find function to link against in external function list for symbol %s?? Can't get signature, so bailing\n" elt *)

let print_externs fmt
    (syms :
      ( ident,
        (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef )
      Hashtbl.t) =
  let ed = !Clflags.option_rust_edition in
  let extern_str =
    match ed with Clflags.E2021 -> "extern" | Clflags.E2024 -> "unsafe extern"
  in
  fprintf fmt "%s \"C\" {@ @[<v 2>@;" extern_str;
  Hashtbl.iter
    (fun id fd ->
      let id_str = Linking.ident_to_string ~name:id in
      match fd with
      | Gfun (Ctypes.External (ef, tl, rty, _)) -> (
          match ef with
          | EF_external (name, s) | EF_builtin (name, s) | EF_runtime (name, s)
            ->
              fprintf fmt "fn %s(" (List.to_seq name |> String.of_seq);
              List.iter
                (fun ty -> fprintf fmt "_: %s," (gen_ty_rust false ty))
                (map_tylist_to_list tl);
              if s.sig_cc.cc_vararg <> None then fprintf fmt " _:...";
              fprintf fmt ") -> %s;@;" (gen_ty_rust false rty)
          | EF_malloc ->
              fprintf fmt
                "fn malloc(_: core::ffi::c_size_t) -> *mut core::ffi::c_void;@;"
          | EF_free -> fprintf fmt "fn free(_: *mut core::ffi::c_void);@;"
          | _ -> printf "\nERROR unsupported external fn type \n")
      | Gfun (Internal _) ->
          printf "\n ERROR: external linkage for internal function??\n"
      | Gvar gv ->
          fprintf fmt "static mut %s: %s;@;" id_str
            (gen_ty_rust false gv.gvar_info)
      (* | _ -> printf "\n ERROR: could not find function to link against in external function list for symbol %s?? Can't get signature, so bailing\n" id_str *))
    syms;
  fprintf fmt "@;<0 -2>}@]@;@;"

let make_syms_usable
    (syms :
      (AST.ident
      * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)
      list) =
  List.fold_left
    (fun acc
         (ele :
           AST.ident
           * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)
       ->
      match ele with
      | _id, (Gfun (External (ef, _, _, _)) as ext_fn) -> (
          match ef with
          | EF_external (name, _) | EF_builtin (name, _) | EF_runtime (name, _)
            ->
              Hashtbl.add acc (name |> List.to_seq |> String.of_seq) ext_fn;
              acc
          | _ -> acc)
      | id, (Gvar gv as glo) ->
          if List.length gv.gvar_init = 0 then
            Hashtbl.add acc (extern_atom_r id) glo;
          acc
      | _ -> acc)
    (Hashtbl.create 7) syms

let prog_contains_main (prog : RustLight.r_program) =
  match
    List.find_opt
      (fun (id, _dfn) ->
        let name = extern_atom_r id in
        name = "main" || name = "_main")
      prog.prog_defs
  with
  | Some _ -> true
  | None -> false

(* TODO this is a bit of a hack. Should probably be handled in the semantics of rustlight *)
let print_program f (importer : Imports.t) project_name =
  fprintf f "@[<v 0>";

  (* do printing  *)
  let imports : (string, ImportSet.t) Hashtbl.t =
    Imports.get_imports importer
  in

  print_imports f imports project_name false;

  print_externs f (Imports.get_extern_syms importer);
  print_extern_types f (Imports.get_extern_typs importer);

  let in_module_composite_defns : composite_definition list =
    Imports.get_in_module_composite_defns importer
  in

  List.iter (define_composite f) in_module_composite_defns;

  let in_module_prog_dfns = Imports.get_globvars importer in

  List.iter (print_globdef f importer) in_module_prog_dfns;
  fprintf f "@]@."

let change_directory dir_name =
  try Unix.chdir dir_name
  with
  (* Change the current working directory *)
  | Unix.Unix_error (err, _, _) ->
    Printf.printf "Error changing directory: %s\n" (Unix.error_message err)

let rec print_prog_types prog_types mod_name =
  match prog_types with
  | Composite (ty_ident, _, _, _) :: l' ->
      (* printf "\nTHIS TYPE IS ty: %s for mod %s \n" (extern_atom_r ty_ident) mod_name ; *)
      print_prog_types l' mod_name
  | nil -> ()

let print_main ((rfn, new_main_ident) : r_function * ident) =
  Printf.printf "PRINTING MAIN NOW!!!";
  match (!destination, !proj_name, !mod_name) with
  | Some f, Some project_name, Some mod_name ->
      "./" ^ project_name ^ "/src/" |> change_directory;
      let oc = open_out f in
      let fmt = formatter_of_out_channel oc in

      fprintf fmt
        "#![feature(extern_types)]@.#![feature(c_size_t)]@.#![no_main]@.@.";

      fprintf fmt "@.use %s::%s::%s;@.@." project_name mod_name "main_inner";

      print_function fmt new_main_ident rfn;
      close_out oc;

      change_directory "../.."
  | _ -> failwith "MISSING METADATA FOR main generation"

let print_if
    (* (clunky_mod_name: char list) *)
    (* (clunky_project_name: char list) *)
      (prog : r_program) =
  (* let mod_name = List.to_seq clunky_mod_name |> String.of_seq in *)
  (* let project_name = List.to_seq clunky_project_name |> String.of_seq in *)
  match (!destination, !proj_name, !mod_name) with
  | Some f, Some project_name, Some mod_name ->
      let imports = Imports.create ~r_prog:prog ~mod_name ~l:!linker in
      Imports.gen_metadata imports;

      (* printf "UUID hashtbl"; *)
      (* pretty_print_hashtbl composite_mapping; *)

      (* TODO uncomment*)
      "./" ^ project_name ^ "/src/" |> change_directory;
      let oc = open_out f in
      print_program (formatter_of_out_channel oc) imports project_name;
      close_out oc;
      change_directory "../.."
  | _ -> printf "METADATA IS MISSING, can't print."

let string_of_RustLight (prog : r_program) =
  let imports = Imports.create ~r_prog:prog ~mod_name:"my_mod" ~l:!linker in
  Imports.gen_metadata imports;

  let buffer = Buffer.create 1024 in
  let fmt = Format.formatter_of_buffer buffer in
  print_program fmt imports "myprog";
  Format.pp_print_flush fmt ();
  Buffer.contents buffer |> String.to_seq |> List.of_seq
