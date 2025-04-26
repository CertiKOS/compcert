[@@@ocaml.warning "-69"]
[@@@ocaml.warning "-32"]
[@@@ocaml.warning "-26"]
open AST
open Camlcoq (*for extern_atom*)
open! Ctypes
open RustLight

module StringSet = Set.Make(String)

let todo () : atom = failwith "\nTODO\n"

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

module IdentSet =
  Set.Make
  (struct
    type t = ident
    let compare = Stdlib.compare
  end)

type tyuid = (string * ident)

module TySet =
  Set.Make
  (struct
    type t = (string * ident)
    let compare = Stdlib.compare
  end)


(* strings -> module name *)
module Linking : sig
  type t

  val create: unit -> t


  (* resolves an ident to the string it represents *)
  val ident_to_string: t -> name : ident -> string

  (* TODO consider the case when we have two types with the same name or same identifier*)
  val is_anon_ident : t -> name : ident -> bool

  (* ident: we have a representative "compatible" type for each type. The rest of the types are type aliases to it. *)
  (* val get_rep_type: ty_id: ident -> ident option *)

  (* (ty_id, mod_name) -> defn *)
  val get_type_definition: t -> ty_id: tyuid -> composite_definition

  val get_rep_type_definition: t -> ty_id: tyuid -> (tyuid * composite_definition)

  val types_are_compat: t -> mod_1: string -> ty_1: composite_definition -> mod_2: string -> ty_2: composite_definition -> bool

  (* fills out r_ty_map s.t. there's only one "representative type" and the rest are de-duplicated *)
  val fill_out_rep_types: t -> unit

  val add_globdef: t -> name: ident -> mod_name: string -> defn: (Clight.coq_function Ctypes.fundef, Ctypes.coq_type) AST.globdef -> unit

  val add_ty_defn: t -> mod_name: string -> cd: composite_definition -> unit
end =
  struct
    type t = {
      (* type map: type ident -> (mod_name, composite_definition) *)
      (* *even* if the same name is. *)
      type_map : (tyuid, composite_definition) Hashtbl.t;

      globvars : (ident, (string * (Clight.coq_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)) Hashtbl.t;

      (* map of representative types *)
      r_ty_map: (tyuid, tyuid) Hashtbl.t;

      rep_types: (tyuid, TySet.t) Hashtbl.t;

      (* there's two phases: build up types and globals, then resolve the globals to generate imports and representative types *)
      mutable is_locked: bool
    }

    let create unit =
      {
      type_map  = Hashtbl.create 8;
      globvars  = Hashtbl.create 8;
      r_ty_map  = Hashtbl.create 8;
      rep_types = Hashtbl.create 8;
      is_locked = false;
    }


    let ident_to_string (state: t) ~name =
      let res = Hashtbl.find string_of_atom name in
      (* let _ = printf "NAMEVAR: %s\n" res in *)
      if res = "main" then "main_inner" else(
        if res = "_" then "_RENAMING_UNDERSCORE" else (
          if StringSet.mem res rust_keywords then "r#" ^ res else res)
      )

    let dump_rep_ty_table (state: t) unit =
      Printf.printf "Begininning dump r_ty_map: \n";
      Hashtbl.iter (fun (m_1, ty_1) (m_2, ty_2) -> Printf.printf "\t module %s, ty %s (%ld) -> module %s, ty %s (%ld)\n" (ident_to_string state ~name:ty_1) m_1 (ty_1 |> P.to_int32) m_2 (ident_to_string state ~name:ty_2) (ty_2 |> P.to_int32)) state.r_ty_map;
      Printf.printf "Ending dump r_ty_map: \n";
      flush stdout

    let dump_tylist (state: t) unit =
      Printf.printf "Begininning dump type_map: \n";
      Hashtbl.iter (fun (m, ty_uid) v -> Printf.printf "mod %s, ty %s (%ld)\n" m (ident_to_string state ~name:ty_uid) (ty_uid |> P.to_int32)) state.type_map;
      Printf.printf "Ending dump type_map: \n";
      flush stdout

    let print_rep_set (state: t) (s: TySet.t) =
      TySet.fold (fun (m, ty_uid) acc -> Printf.sprintf "%s (%s, %s (%ld))," acc m (ident_to_string state ~name:ty_uid) (ty_uid |> P.to_int32)) s ""

    let dump_rep_types (state: t) =
      Printf.printf "Begininning dump rep_types: \n";
      Hashtbl.iter (fun (m, ty_uid) s ->
        Printf.printf "\t (%s, %s (%ld)) -> {%s}\n" m (ident_to_string state ~name:ty_uid) (ty_uid |> P.to_int32) (print_rep_set state s)
    ) state.rep_types;
      Printf.printf "ending dump rep_types: \n";
      flush stdout

    let add_globdef (state: t) ~name ~mod_name ~defn = Hashtbl.replace state.globvars name (mod_name, defn)

    let add_ty_defn (state: t) ~mod_name ~cd =
      let Composite(id, _, _, _) = cd in
      Hashtbl.add state.type_map (mod_name, id) cd

    (* TODO this is a HACK. Really this information should be propagated through the parser *)
    let is_anon_ident (state: t) ~name =
      let name_string = ident_to_string state ~name in
      let len = String.length name_string in
      let rec check_digits i =
        if i = len then true
        else
          let c = String.get name_string i in
          if c >= '0' && c <= '9' then
            check_digits (i + 1)
          else
            false
      in
      len >= 2 && String.get name_string 0 = '_' && check_digits 1

    let rec rep_ty_equal (state: t) ~mod_1 ~cty_1 ~mod_2 ~cty_2 =
      match (cty_1, cty_2) with
      | (Tstruct(i', a'), Tstruct(j', b'))
      | (Tunion(i', a'), Tunion(j', b')) ->(
          if i' = j' then true
          else
            (* the struct should 100% exist in the module *)
            (* otherwise how will it know that struct exists?? *)
            match (Hashtbl.find_opt state.r_ty_map (mod_1, i'), Hashtbl.find_opt state.r_ty_map (mod_2, j')) with
            | (Some(i''), Some(j'')) -> i'' = j''
            | _ -> false)
      | (Tfunction(tl, rty, _cc), Tfunction(tl', rty', _cc')) ->
          rep_tylist_equal state ~mod_1 tl ~mod_2 tl' && rep_ty_equal state ~mod_1 ~cty_1:rty ~mod_2 ~cty_2:rty' && _cc = _cc'
      | (Tpointer(ty, _cc), Tpointer(ty', _cc')) ->
          rep_ty_equal state ~mod_1 ~cty_1:ty ~mod_2 ~cty_2:ty'
      | (Tarray(ty, num, _cc), Tarray(ty', num', _cc')) -> rep_ty_equal state ~mod_1 ~cty_1:ty ~mod_2 ~cty_2:ty' && num = num' && _cc = _cc'
      | _ -> cty_1 = cty_2
    and rep_tylist_equal (state: t) ~mod_1 tl1 ~mod_2 tl2 =
      match (tl1, tl2) with
      | (Tcons(ty1, tl1'), Tcons(ty2, tl2')) ->
          rep_ty_equal state ~mod_1 ~cty_1:ty1 ~mod_2 ~cty_2:ty2 && rep_tylist_equal state ~mod_1 tl1' ~mod_2 tl2'
      | (Tnil, Tnil) -> true
      | _ -> false

    (* module arguments are provided because ty_map needs those for lookup *)
    let types_are_compat (state: t) ~mod_1 ~ty_1 ~mod_2 ~ty_2 =
      match ty_1,ty_2 with
      | Ctypes.Composite (_, sou, mems, attrs), Ctypes.Composite(_, sou_, mems_, attrs_) -> (
          let sou_r =
            match (sou, sou_) with
            | (Ctypes.Union, Ctypes.Union) -> true
            | (Ctypes.Struct, Ctypes.Struct) -> true
            | _ -> false
          in
          let mem_eq_fn = fun mems_1 mems_2 -> (
              match (mems_1, mems_2) with
              | Ctypes.Member_plain(_, ty), Ctypes.Member_plain(_, ty') -> rep_ty_equal state ~cty_1:ty ~cty_2:ty' ~mod_1 ~mod_2
              | Ctypes.Member_bitfield(_, a, b, c, d, e), Ctypes.Member_bitfield(_, a', b', c', d', e') ->
                a = a' && b = b' && c = c' && d = d' && e = e'
              | _ -> false
            )
          in
          let mems_r =
            if (List.length mems) != (List.length mems_) then
              false
            else
              List.fold_left (fun acc (a, b) -> (mem_eq_fn a b) && acc)
                true
                (List.combine mems mems_)
          in
          let attrs_r = attrs = attrs_ in
          sou_r && mems_r && attrs_r
        )

    let get_type_definition (state: t) ~ty_id = Hashtbl.find state.type_map ty_id

    let get_rep_type_definition (state: t) ~ty_id =
      let rep_ty = Hashtbl.find state.r_ty_map ty_id in
      let cd = get_type_definition state ~ty_id:(rep_ty) in
      (rep_ty, cd)

    (* TODO the way to handle mutual recursion is a stack. But, we don't yet handle that *)
    (* need to make a test case then handle it. *)
    let rec internal_has_rep_type (state: t) (mod_1: string) (ty_1: composite_definition) (l: (string * composite_definition) list) =
      match l with
      | (mod_2, (Composite(id, _, _, _) as ty_2)) :: l' ->
          if types_are_compat state ~mod_1 ~ty_1 ~mod_2 ~ty_2 then
            Some(mod_2, id)
          else internal_has_rep_type state mod_1 ty_1 l'
      | nil -> None


    let has_rep_type (state: t) (mod_name: string) (cd: composite_definition) : tyuid option =
      let ty_list = Hashtbl.to_seq_keys state.rep_types |> List.of_seq |> List.map (fun x -> (fst x, Hashtbl.find state.type_map x))
      in internal_has_rep_type state mod_name cd ty_list

    (* we start out with the internal representation not filled out *)
    (* and we gradually fill it out. *)
    (* if it's contained: great, keep it contained *)
    (* if it's not contained: add as a representative type of itself *)
    let rec internal_fill_out_rep_types_initial (state: t) (l: (tyuid * composite_definition) list) =
      match l with
      | ((mod_name, id) as typ_uid, (Composite(_, sou, mems, attrs) as cd)) :: l' ->
          (match has_rep_type state mod_name cd with
          | None -> (
            Hashtbl.add state.rep_types typ_uid (TySet.singleton typ_uid);
            Hashtbl.add state.r_ty_map typ_uid typ_uid;
          )
          | Some(rep_id) -> (
            let old_set = Hashtbl.find state.rep_types rep_id in
            let new_set = TySet.add typ_uid old_set in
            Hashtbl.replace state.rep_types rep_id new_set;
            Hashtbl.replace state.r_ty_map typ_uid rep_id;
          ));
          internal_fill_out_rep_types_initial state l'
      | nil -> ()

    let rec internal_check_rep_types (state: t) (tid: tyuid) (l: tyuid list) =
      dump_rep_ty_table state ();
      dump_rep_types state;

      match l with
      | tid2 :: l' -> (
          let cd1 = Hashtbl.find state.type_map tid in
          let cd2 = Hashtbl.find state.type_map tid2 in
          if types_are_compat state ~mod_1:(fst tid) ~mod_2:(fst tid2) ~ty_1:cd1 ~ty_2:cd2 then(
            Hashtbl.replace state.r_ty_map tid tid2;

            let tid_rep_eles = Hashtbl.find state.rep_types tid in
            Printf.printf"before removal \n";
            dump_rep_types state;

            Hashtbl.remove state.rep_types tid;
            Printf.printf"after removal \n";
            dump_rep_types state;
            Printf.printf "TID1 %s %ld, TID2 is %s %ld \n" (ident_to_string state ~name:(snd tid)) (tid |> snd |> P.to_int32) (ident_to_string state ~name:(snd tid2)) (snd tid2 |> P.to_int32);

            flush stdout;

            let tid2_rep_eles = Hashtbl.find state.rep_types tid2 in
            Hashtbl.replace state.rep_types tid2 (TySet.union tid_rep_eles tid2_rep_eles);
            true
            (* type no longer exists so return out of here*)
          )
          else
            (* couldn't combine here, so move on and try the next type*)
            internal_check_rep_types state tid l'
      )
      | nil -> false


    let rec internal_fill_out_rep_types_rest (state: t) (made_changes: bool) (l: tyuid list) =
      match l with
      | tid :: l' ->
          let more_changes = internal_check_rep_types state tid l' in
          internal_fill_out_rep_types_rest state (made_changes || more_changes) l'
      | nil -> made_changes || false


    let rec get_fixed_point (state: t) =
      dump_tylist state ();
      dump_rep_ty_table state ();
      dump_rep_types state;
      Printf.printf "NEXT STEP\n"; flush stdout;
      let list_of_tys = state.rep_types |> Hashtbl.to_seq_keys |> List.of_seq in
      let made_changes = internal_fill_out_rep_types_rest state false list_of_tys in
      if made_changes then get_fixed_point state

    (* do repeated iteration until a fixed point is reached to iron out types that are actually equivalent *)
    let fill_out_rep_types (state: t) =
      if not state.is_locked then(
        state.is_locked <- true;
        let list_of_tys = state.type_map |> Hashtbl.to_seq |> List.of_seq in
        internal_fill_out_rep_types_initial state list_of_tys;
        get_fixed_point state)
      else ()

  end

module Imports : sig
  type t

  val create: l: Linking.t -> r_prog: RustLight.r_program -> name: string -> t

  (* val get_extern_typs: t -> string list *)

  (* module, name, definition *)
  (* note: only imports for types. Not for globals + functions. That is separate. *)
  (* val get_imports: t -> (string * string * composite_definition list) list *)
  (**)
  (* val get_in_module_composite_defns: t -> (string * composite_definition) list *)

  (* val generate_imports: t -> unit *)

  (* TODO need to deal with linking globals too, but that is much easier. *)

end = struct
  type t = {
    linking: Linking.t;
    r_prog: RustLight.r_program;
    imports: (string, IdentSet.t) Hashtbl.t;
    extern_typs: IdentSet.t;
    in_module_composite_dfns: IdentSet.t;
    name: string;
  }

  let create ~l ~r_prog ~name =
    {
      linking = l;
      r_prog;
      imports = Hashtbl.create 8;
      extern_typs = IdentSet.empty;
      in_module_composite_dfns = IdentSet.empty;
      name;
    }

  (* let get_extern_typs state = todo() *)
  (**)
  (* let get_imports state = todo() *)
  (**)
  (* let get_in_module_composite_defns state = todo() *)

  let identset_of_positivetree (tree: PositiveSet.t) =
    tree |> PositiveSet.elements |> IdentSet.of_list

  (* gather composite types from program *)
  let get_used_composite_tys_from_prog state =
    List.fold_left (
      fun acc (elt: AST.ident * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) ->
        match elt with
        (* TODO should probably pull in the types from this too but this requires rustlight changes*)
        | (_id, Gvar v) -> acc

        | (id, Gfun Internal rf) ->
            let r_used_types = rf.fn_ty_imports in
            IdentSet.union acc (r_used_types |> identset_of_positivetree)
        | _ -> acc
    ) IdentSet.empty state.r_prog.prog_defs


  (* let get_defined_in_module_tys_from_prog state = *)
  (*   List.filter (fun (Composite(id, _, _, _)) -> *)
  (*     let (mod_name, Composite(id', _, _, _)) = Linking.get_rep_type_definition state.linking ~ty_id:id in *)
  (*     if mod_name = state.name then *)
  (*       true *)
  (*     else *)
  (**)
  (*   ) *)
  (*   state.r_prog.prog_types *)


  (* gather composite types from globals *)
  (* let get_imports_from_gbls_syms state = *)
  (*   List.fold_left *)
  (*       (fun acc (elt: (AST.ident * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)) -> *)
  (*          match elt with *)
  (*          | id, Gvar v ->  if (List.length v.gvar_init == 0) then get_fn_foreign_syms sym_mapping [id] acc else acc *)
  (*          | _id, Gfun f -> ( *)
  (*              match f with *)
  (*              | Internal rf -> ( *)
  (*                get_fn_foreign_syms sym_mapping (PositiveSet.elements rf.fn_imports) acc *)
  (*              ) *)
  (*              (* TODO we may need to handle this case? *) *)
  (*              | External _ -> acc *)
  (*          ) *)
  (*       ) *)
  (*       (Hashtbl.create 7) state.r_prog.prog_defs *)


  (* let generate_imports state = *)
  (*   (* gather composite types from program *) *)
  (*   let used_composites = get_used_composite_tys_from_prog state in *)
  (*   todo() *)

    (* let defined_in_module_idents = get_defined_in_module_tys_from_prog state in *)


    (* gather composite types from globals *)
    (* let imports_from_gbls_syms = get_imports_from_gbls_syms state in *)

end

