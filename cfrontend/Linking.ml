open AST
open Camlcoq
open Ctypes

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

(* strings -> module name *)
module Linking : sig
  (* type map: type ident -> (mod_name, composite_definition) *)
  val type_map : (ident, string * composite_definition) Hashtbl.t

  val globvars : (ident, (string * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)) Hashtbl.t

  val ident_to_string: ident -> string

  (* val is_anon_ident : name: ident -> bool *)
  (* val resolve_name: id: ident -> string *)
  (**)
  (* (* ident: we have a representative "compatible" type for each type. The rest of the types are type aliases to it. *) *)
  (* val get_representative_type: ty_id: ident -> ident *)
  (**)
  (* val add_global: name: ident -> mod_name: string -> defn: (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef -> unit *)
  (**)
  (* val add_type: id: ident -> mod_name: string -> defn: composite_definition -> unit *)
  (**)
  (* (* val normalize_fn: unit *) *)
  (**)
  (* val find_globvar: id: ident -> mod_name: string -> (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef *)
  (**)
  (* val find_type: ident -> string *)
  (**)
  (* (* val gen_mapping: hashtbl ident -> ident *) *)
  (**)
  (* val recursively_calculate_imports: mod_name: string -> r_prog: RustLight.r_program -> unit *)
end =
  struct
    let type_map = Hashtbl.create 8
    let globvars = Hashtbl.create 8

    let is_anon_ident id = true

    let ident_to_string id =
      let res = Hashtbl.find string_of_atom id in
      (* let _ = printf "NAMEVAR: %s\n" res in *)
      if res = "main" then "main_inner" else(
        if res = "_" then "_RENAMING_UNDERSCORE" else (
          if StringSet.mem res rust_keywords then "r#" ^ res else res)
      )


  end
(* Example usage: *)
(*
let open Linking in
let t1 = create_anon_type () in
add_type t1 { definition = Struct ["x", Named "int"; "y", Named "float"]; complete = true };
add_function { name="foo"; return_type=Named "void"; param_types=[t1]; is_variadic=false };
match find_function "foo" with
| Some info -> (* … *)
| None -> (* not found *)
*)

(* let todo () = failwith "\nTODO\n" *)
