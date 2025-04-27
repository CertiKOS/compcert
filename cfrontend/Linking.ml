[@@@ocaml.warning "-69"]
[@@@ocaml.warning "-32"]
[@@@ocaml.warning "-26"]
open AST
open Camlcoq (*for extern_atom*)
open! Ctypes
open RustLight

(* TODO pull in janestreet stdlib *)
let (>>=) o f =
  match o with
  | None   -> None
  | Some x -> f x

let flip f x y = f y x

let unimplemented s = failwith (Printf.sprintf "Not yet implemented %s" s)

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

module ImportSet =
  Set.Make
  (struct
    type t = (string option * ident)
    let compare = Stdlib.compare
  end)


(* strings -> module name *)
module Linking : sig
  type t

  val create: unit -> t


  (* resolves an ident to the string it represents *)
  val ident_to_string: name : ident -> string

  (* TODO consider the case when we have two types with the same name or same identifier*)
  val is_anon_ident : t -> name : ident -> bool

  (* ident: we have a representative "compatible" type for each type. The rest of the types are type aliases to it. *)
  (* val get_rep_type: ty_id: ident -> ident option *)

  (* (ty_id, mod_name) -> defn *)
  val get_type_definition: t -> ty_id: tyuid -> composite_definition

  val get_rep_type_definition: t -> ty_id: tyuid -> (tyuid * composite_definition)

  val get_rep_type_opt: t -> ty_id: tyuid -> tyuid option

  val get_globdef: t -> name: ident -> (string * (Clight.coq_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) option
  val has_internal_sym: t -> mod_name: string -> name: ident -> bool

  val types_are_compat: t -> mod_1: string -> ty_1: composite_definition -> mod_2: string -> ty_2: composite_definition -> bool

  (* fills out r_ty_map s.t. there's only one "representative type" and the rest are de-duplicated *)
  val fill_out_rep_types: t -> unit

  val get_globvars: t -> (ident, (string * (Clight.coq_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)) Hashtbl.t

  val add_globdef: t -> name: ident -> mod_name: string -> defn: (Clight.coq_function Ctypes.fundef, Ctypes.coq_type) AST.globdef -> unit

  val add_ty_defn: t -> mod_name: string -> cd: composite_definition -> unit

  val get_main_module: t -> string option
end =
  struct
    type t = {
      (* type map: type ident -> (mod_name, composite_definition) *)
      (* *even* if the same name is. *)
      type_map : (tyuid, composite_definition) Hashtbl.t;


      (* map of representative types *)
      r_ty_map: (tyuid, tyuid) Hashtbl.t;

      rep_types: (tyuid, TySet.t) Hashtbl.t;

      (* global definitions *)
      globvars : (ident, (string * (Clight.coq_function Ctypes.fundef, Ctypes.coq_type) AST.globdef)) Hashtbl.t;

      (* module local definitions *)
      internal_symbols: (string, IdentSet.t) Hashtbl.t;

      mutable main_module: string option;

      (* there's two phases: build up types and globals, then resolve the globals to generate imports and representative types *)
      mutable is_locked: bool
    }

    let create unit =
      {
      type_map  = Hashtbl.create 8;
      globvars  = Hashtbl.create 8;
      r_ty_map  = Hashtbl.create 8;
      rep_types = Hashtbl.create 8;
      internal_symbols = Hashtbl.create 8;
      main_module = None;
      is_locked = false;
    }

    let get_globvars state = state.globvars

    let ident_to_string ~name =
      let res = Hashtbl.find string_of_atom name in
      (* let _ = printf "NAMEVAR: %s\n" res in *)
      if res = "main" then "main_inner" else(
        if res = "_" then "_RENAMING_UNDERSCORE" else (
          if StringSet.mem res rust_keywords then "r#" ^ res else res)
      )

    let set_main_module state =
      Hashtbl.iter (fun id (m, _) -> if "main_inner" = (ident_to_string ~name:id) then state.main_module <- Some(m)) state.globvars;
      match state.main_module with
      | None ->
        Printf.printf "No MAIN MODULE found"
      | Some(mm) ->
        Printf.printf "MAIN MODULE FOUND AND IS: %s" mm

    let get_main_module state =
      set_main_module state;
      state.main_module

    let dump_rep_ty_table (state: t) unit =
      Printf.printf "Begininning dump r_ty_map: \n";
      Hashtbl.iter (fun (m_1, ty_1) (m_2, ty_2) -> Printf.printf "\t module %s, ty %s (%ld) -> module %s, ty %s (%ld)\n" (ident_to_string ~name:ty_1) m_1 (ty_1 |> P.to_int32) m_2 (ident_to_string ~name:ty_2) (ty_2 |> P.to_int32)) state.r_ty_map;
      Printf.printf "Ending dump r_ty_map: \n";
      flush stdout

    let dump_tylist (state: t) unit =
      Printf.printf "Begininning dump type_map: \n";
      Hashtbl.iter (fun (m, ty_uid) v -> Printf.printf "mod %s, ty %s (%ld)\n" m (ident_to_string ~name:ty_uid) (ty_uid |> P.to_int32)) state.type_map;
      Printf.printf "Ending dump type_map: \n";
      flush stdout

    let print_rep_set (state: t) (s: TySet.t) =
      TySet.fold (fun (m, ty_uid) acc -> Printf.sprintf "%s (%s, %s (%ld))," acc m (ident_to_string ~name:ty_uid) (ty_uid |> P.to_int32)) s ""

    let dump_rep_types (state: t) =
      Printf.printf "Begininning dump rep_types: \n";
      Hashtbl.iter (fun (m, ty_uid) s ->
        Printf.printf "\t (%s, %s (%ld)) -> {%s}\n" m (ident_to_string ~name:ty_uid) (ty_uid |> P.to_int32) (print_rep_set state s)
    ) state.rep_types;
      Printf.printf "ending dump rep_types: \n";
      flush stdout

    let add_globdef (state: t) ~name ~mod_name ~defn =
      let linkage_is_static = C2C.atom_is_static name in
      if linkage_is_static then
        (* these are not globals. I think this information is lost by the time we get to clight.
           Important to record here *)
        Hashtbl.replace state.internal_symbols mod_name
          (match Hashtbl.find_opt state.internal_symbols mod_name with
           | Some set -> IdentSet.add name set
           | None     -> IdentSet.singleton name)
        (* Printf.printf "\nLINKAGE IS STATIC FOR %s (%ld)\n" (ident_to_string ~name:name) (name |> P.to_int32) *)
      else(
        Hashtbl.replace state.globvars name (mod_name, defn);
        (* Printf.printf "\nCONSIDERING LINKAGE FOR %s (%ld)\n" (ident_to_string ~name:name) (name |> P.to_int32); *)
        (* (* these are globals. We only want to record the ones that are defined symbols. *) *)
        (* if C2C.atom_is_extern name |> not then ( *)
        (*   Printf.printf "\nLINKAGE IS NOT EXTERN FOR %s (%ld)\n" (ident_to_string ~name:name) (name |> P.to_int32)) *)
        (* else *)
        (*   (* there's a lot of these *) *)
        (*   Printf.printf "\nLINKAGE IS EXTERN FOR %s (%ld)\n" (ident_to_string ~name:name) (name |> P.to_int32) *)
      )

    let get_globdef (state: t) ~name = Hashtbl.find_opt state.globvars name

    let has_internal_sym (state: t) ~mod_name ~name =
      let maybe_opt = Hashtbl.find_opt state.internal_symbols mod_name in
      match maybe_opt with
      | Some(tbl) -> IdentSet.mem name tbl
      | None -> false


    let add_ty_defn (state: t) ~mod_name ~cd =
      let Composite(id, _, _, _) = cd in
      Hashtbl.add state.type_map (mod_name, id) cd

    (* TODO this is a HACK. Really this information should be propagated through the parser *)
    let is_anon_ident (state: t) ~name =
      let name_string = ident_to_string ~name in
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
              | Ctypes.Member_plain(id_1, ty), Ctypes.Member_plain(id_2, ty') ->
                  ((is_anon_ident state ~name:id_1 && is_anon_ident state ~name:id_2) || id_1 = id_2) &&
                    rep_ty_equal state ~cty_1:ty ~cty_2:ty' ~mod_1 ~mod_2
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

    let get_rep_type_opt (state: t) ~ty_id =
      Hashtbl.find_opt state.r_ty_map ty_id

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

            TySet.iter (fun ele -> Hashtbl.replace state.r_ty_map ele tid2) tid_rep_eles;

            Printf.printf"before removal \n";
            dump_rep_types state;

            Hashtbl.remove state.rep_types tid;
            Printf.printf"after removal \n";
            dump_rep_types state;
            Printf.printf "TID1 %s %ld, TID2 is %s %ld \n" (ident_to_string ~name:(snd tid)) (tid |> snd |> P.to_int32) (ident_to_string ~name:(snd tid2)) (snd tid2 |> P.to_int32);

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

  val create: l: Linking.t -> r_prog: RustLight.r_program -> mod_name: string -> t

  val gen_metadata: t -> unit

  val get_extern_typs: t -> IdentSet.t

  val get_extern_syms: t -> (ident, (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) Hashtbl.t

  val get_globvars: t -> (ident * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) list

  (* module, name, definition *)
  (* note: only imports for types. Not for globals + functions. That is separate. *)
  val get_imports: t -> (string, ImportSet.t) Hashtbl.t
  val get_in_module_composite_defns: t -> composite_definition list

  (* val generate_imports: t -> unit *)

  (* TODO need to deal with linking globals too, but that is much easier. *)

  val get_ty_dfn: t -> name: ident -> composite_definition

end = struct
  type t = {
    linking: Linking.t;
    r_prog: RustLight.r_program;
    (* module name -> (identifier, name to import as) set*)
    imports: (string, ImportSet.t) Hashtbl.t;
    mutable extern_typs: IdentSet.t;
    (* global symbols that must be improted*)
    mutable extern_syms: (ident, (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) Hashtbl.t;
    mutable in_module_composite_dfns: IdentSet.t;
    mod_name: string;
  }

  let create ~l ~r_prog ~mod_name =
    {
      linking = l;
      r_prog;
      imports = Hashtbl.create 8;
      extern_typs = IdentSet.empty;
      extern_syms = Hashtbl.create 8;
      in_module_composite_dfns = IdentSet.empty;
      mod_name;
    }

  let dump_identset (label: string) (set: IdentSet.t) =
    Printf.printf "Beginning dump %s:\n" label;
    IdentSet.iter
      (fun id ->
        let id_str = Linking.ident_to_string ~name:id in
        let id_num = P.to_int32 id in
        Printf.printf "\t%s (%ld)\n" id_str id_num
      )
      set;
    Printf.printf "Ending dump %s.\n" label;
    flush stdout

  let get_extern_typs state = state.extern_typs

  let get_extern_syms state = state.extern_syms

  let get_imports state = state.imports

  let get_ty_dfn state ~name =
    Linking.get_type_definition state.linking ~ty_id:(state.mod_name, name)

  let get_globvars state =
    let gvs = Linking.get_globvars state.linking in
    List.filter_map (fun (id, dfn) ->
      match dfn with
      (* in simplexpr we add internal global variables when statically linked *)
      | AST.Gvar v -> if List.length v.gvar_init > 0 then Some(id, dfn) else None
      | _ ->
          if Hashtbl.mem gvs id || Linking.has_internal_sym state.linking ~mod_name:state.mod_name ~name:id then Some(id, dfn) else None
    ) state.r_prog.prog_defs

    (* Hashtbl.to_seq (Linking.get_globvars state.linking) |> List.of_seq |> List.filter_map (fun (id, (mod_name, dfn)) -> if mod_name = state.mod_name then Some(id, dfn) else None) *)

  let get_in_module_composite_defns state =
    IdentSet.elements state.in_module_composite_dfns  |>
    List.map (fun id -> (List.find (fun cd -> match cd with Composite(id', _, _, _) -> id = id') state.r_prog.prog_types))
  (**)
  (* let get_in_module_composite_defns state = todo() *)

  let identset_of_positivetree (tree: PositiveSet.t) =
    tree |> PositiveSet.elements |> IdentSet.of_list

  (* gather composite types in use from program *)
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

  (* TODO same as function above. Rewrite to just use one of them*)
  let get_used_idents_from_prog state =
    List.fold_left (fun acc (elt: AST.ident * (RustLight.r_function Ctypes.fundef, Ctypes.coq_type) AST.globdef) ->
      match elt with
      | (_id, Gvar v) -> acc
      | (id, Gfun Internal rf) ->
          let r_used_types = rf.fn_imports in
          let types_used = r_used_types |> identset_of_positivetree in
          dump_identset (Printf.sprintf "used idents from %s" (Linking.ident_to_string ~name:id)) types_used;

          IdentSet.union acc (r_used_types |> identset_of_positivetree)
      | _ -> acc
    ) IdentSet.empty state.r_prog.prog_defs

  (* iterate through all types in prog_types *)
  (* if type is a representative type from different module *)
  (*   add to in_module_composite_definitions *)
  (* if not repr type: link against that type by adding to imports *)
  let get_in_module_composite_typs (state: t) =
    List.iter (fun (Composite(id, _, _, _) as cd: composite_definition) ->
      let ty_id = (state.mod_name, id) in

      match Linking.get_rep_type_opt state.linking ~ty_id with
      | None -> (Printf.printf "ERROR: can't find %s eg %ld in mod %s\n" (Linking.ident_to_string ~name:(snd ty_id)) (P.to_int32 (snd ty_id)) state.mod_name)
      | Some(rep_tyuid) ->
        (* if the representative type is in this module: this is fine *)
        if rep_tyuid = ty_id then
          state.in_module_composite_dfns <- IdentSet.add (snd ty_id) state.in_module_composite_dfns
        else
          let (rep_mod, rep_uid) = rep_tyuid in
          let rep_name = Linking.ident_to_string ~name:rep_uid in
          let ty_name = Linking.ident_to_string ~name:id in
          let maybe_name = if rep_name = ty_name then None else Some(ty_name) in
          let ele = (maybe_name, rep_uid) in
          match Hashtbl.find_opt state.imports rep_mod with
          | Some(old_hs) ->
              let new_hs = ImportSet.add ele old_hs in
              Hashtbl.replace state.imports rep_mod new_hs
          | None -> Hashtbl.replace state.imports rep_mod (ImportSet.singleton ele)
      ) state.r_prog.prog_types


  let rec extract_tys_from_ty ty =
    match ty with
    | Tstruct(id, _)
    | Tunion(id, _) ->
        (* printf "extracted %s" (extern_atom_r id);  *)
        [id]
    | Tarray(ty, _, _)
    | Tpointer(ty, _) -> extract_tys_from_ty ty
    | Tfunction(tl, ty, _) ->
        extract_tys_from_ty ty @ extract_tys_from_tl tl
    | _ -> []
  and extract_tys_from_tl tl =
    match tl with
    | Tnil -> []
    | Tcons(ty, tl') -> (extract_tys_from_ty ty) @ (extract_tys_from_tl tl')

  let dump_in_module_composite_dfns (state: t) =
    Printf.printf "Begininning dump in_module_composite_dfns:\n";
    IdentSet.iter
      (fun id ->
        let id_str = Linking.ident_to_string ~name:id in
        let id_num = id |> P.to_int32 in
        Printf.printf "\t%s (%ld)\n" id_str id_num
      )
      state.in_module_composite_dfns;
    Printf.printf "Ending dump in_module_composite_dfns.\n";
    flush stdout


  let get_contained_typ_idents (Ctypes.Composite(id, sou, members, _))
  =
    List.fold_left (
      fun acc ele ->
        match ele with
        | Member_plain(_id, ty) ->
            (* printf "\n CONSIDERING MEMBER %s\n" (extern_atom_r _id);  *)
            extract_tys_from_ty ty @ acc
        | Member_bitfield(bid, _, _, _, _, _) ->
            unimplemented(Linking.ident_to_string ~name:bid)
    ) [] members |> IdentSet.of_list

  let ident_already_exists (state: t) (id: ident) =
    let ident_name = Linking.ident_to_string ~name:id in
    (* TODO this can be optimized incredibly easy. Very slow as is. *)
    let is_imported =
      (* short circuit is necessary because we just wanna flip through them all if it's true *)
      Hashtbl.fold (fun _ is acc ->
        acc ||
        (ImportSet.fold (fun (name, id') acc ->
          acc || match name with None -> (Linking.ident_to_string ~name:id') = ident_name | Some(name) -> name = ident_name
        ) is false)
      ) state.imports false in
    let is_defined = IdentSet.mem id state.in_module_composite_dfns in
    (* Printf.printf "\n%s (%ld) is defined in module %s: %b\n" ident_name (id |> P.to_int32) state.mod_name is_defined; *)
    (* dump_in_module_composite_dfns state; *)
    is_imported || is_defined


  (* returns type idents in the struct that are used but also not in imports or in_module_composite_dfns *)
  let get_used_tys (state: t) (cd: composite_definition) =
    get_contained_typ_idents cd |> IdentSet.filter (fun id -> not (ident_already_exists state id))


  let set_extern_typs_from_in_module_composite_defns (state: t) =
    IdentSet.iter (fun ty_id ->
      let cd = Linking.get_type_definition state.linking ~ty_id:(state.mod_name, ty_id) in
      let used_typs = get_used_tys state cd in

      (* these have to be extern. They aren't defined types in the module. *)
      state.extern_typs <- IdentSet.union state.extern_typs used_typs

    ) state.in_module_composite_dfns

  let set_extern_typs_from_used_types (state: t) (ids: IdentSet.t) =
    IdentSet.iter (fun ele ->
      if not (ident_already_exists state ele) then
        state.extern_typs <- IdentSet.add ele state.extern_typs
  ) ids

  let all_used_typs_in_module (state: t) =
    let used_tys_in_fns = get_used_composite_tys_from_prog state in
    set_extern_typs_from_used_types state used_tys_in_fns;
    set_extern_typs_from_in_module_composite_defns state;
    ()


  let dump_imports (state: t) =
    Printf.printf "Begininning dump imports:\n";
    Hashtbl.iter
      (fun m import_set ->
        Printf.printf "\tModule %s imports:\n" m;
        ImportSet.iter
          (fun (alias_opt, id) ->
            let id_str = Linking.ident_to_string ~name:id in
            match alias_opt with
            | Some alias ->
              Printf.printf "\t\t%s as %s\n" id_str alias
            | None ->
              Printf.printf "\t\t%s\n" id_str
          )
          import_set
      )
      state.imports;
    Printf.printf "Ending dump imports.\n";
    flush stdout

  let dump_externs (state: t) =
    Printf.printf "Begininning dump extern_typs:\n";
    IdentSet.iter
      (fun id ->
        let id_str = Linking.ident_to_string ~name:id in
        let id_num = id |> P.to_int32 in
        Printf.printf "\t%s (%ld)\n" id_str id_num
      )
      state.extern_typs;
    Printf.printf "Ending dump extern_typs.\n";
    flush stdout

  let get_extern_defn (state: t) (name: ident) =
    let defns = state.r_prog.prog_defs in
    List.find (fun defn -> name = fst defn) defns

  (* fill out imports with the needed globdefs*)
  let fill_out_globdef_imports (state: t) =
    (* TODO think about global variables *)
    let used_idents = get_used_idents_from_prog state in
    dump_identset "IDENT USED\n" used_idents;
    IdentSet.iter (fun id ->
      let id_str = Linking.ident_to_string ~name:id in
      (* Printf.printf "\t%s (%ld)\n" id_str (id |> P.to_int32); *)
      (* if the global definition exists: import it from its respective module*)
      match Linking.get_globdef state.linking ~name:id with
      | Some(m, defn) ->(
          if m = state.mod_name |> not then (
            let ele = (None, id) in
            match Hashtbl.find_opt state.imports m with
            | Some(old_hs) ->
                let new_hs = ImportSet.add ele old_hs in
                Hashtbl.replace state.imports m new_hs
            | None -> Hashtbl.replace state.imports m (ImportSet.singleton ele)))
      | None -> (
        Printf.printf "PROCCESSING %s %ld" (Linking.ident_to_string ~name:id) (id |> P.to_int32);
        (* if the symbol doesn't exist, check if it's statically linked in the file. If it is: do nothing. *)

        if Linking.has_internal_sym state.linking ~name:(id) ~mod_name:(state.mod_name) then
          ()
        else
          (* if the symbol doesn't exist and is not statically linked: look up the signature and extern import it. *)
          let defn = get_extern_defn state id in
          Hashtbl.replace state.extern_syms id (snd defn)
      )
    ) used_idents

  let check_if_type_is_elsewhere (state: t) (inner_ident: ident) (id_fn: ident) =
    Printf.printf "\nUID Considering %s from module %s for function %s\n" (Linking.ident_to_string ~name:inner_ident) state.mod_name (Linking.ident_to_string ~name:id_fn);
    match Linking.get_globdef state.linking ~name:id_fn with
    | None -> (
      Printf.printf "\t couldn't find\n"
    )
    | Some(mod_name, _) -> (
      Printf.printf "\t found in module %s\n" mod_name;
      match Linking.get_rep_type_opt state.linking ~ty_id:(mod_name, inner_ident) with
      | None -> (
        Printf.printf "\t couldn't find rep type\n";
      )
      | Some(rep_mod_name, rep_ty) ->
          Printf.printf "\t found rep type\n";
          let rename = if (Linking.ident_to_string ~name:inner_ident) = (Linking.ident_to_string ~name:rep_ty) then None else Some(Linking.ident_to_string ~name:inner_ident) in
          (match Hashtbl.find_opt state.imports rep_mod_name with
          | Some(is) ->
              Hashtbl.replace state.imports rep_mod_name (ImportSet.add (rename, rep_ty) is)
          | None -> (
              Hashtbl.replace state.imports rep_mod_name (ImportSet.singleton (rename, rep_ty))

          ));

          Printf.printf "\t removing %s from extern_typs\n" (Linking.ident_to_string ~name:rep_ty);

          state.extern_typs <- IdentSet.remove inner_ident state.extern_typs;

          dump_externs state
    )

    (* figure out which module has the fn in it, call that mod_name*)
    (* try to get_rep_type of (mod_name, inner_ident) *)
    (* if that works, remove from extern_typs *)
    (* insert into import list from corresponding module*)

  let rec check_typ (state: t) (ty: Ctypes.coq_type) (id_fn: ident) =
    match ty with
    | Tstruct (id, _)
    | Tunion (id, _) ->
        if IdentSet.mem id state.extern_typs then
          check_if_type_is_elsewhere state id id_fn

    | Tpointer(ty', _)
    | Tarray (ty', _, _) -> check_typ state ty' id_fn
    | Tfunction (_, _, _) -> ()
    | _ -> ()


      (* if IdentSet.mem ty state.extern_typs then *)
      (*   check_typ rty *)
    (* if id = ty then *)
    (*   () *)

  let rec fixup_fn (state: t) (prog_def : (AST.ident * ('f Ctypes.fundef, Ctypes.coq_type) AST.globdef)) =
    match prog_def with
    | (id, Gfun(External(ef, tl, rty, _))) ->
        fixup_tylist state tl id
    | (_, _) -> ()

  and fixup_tylist (state: t) (tl: typelist) (id: ident) =
      match tl with
      | Tnil -> ()
      | Tcons(ty, tl') ->
          check_typ state ty id;
          fixup_tylist state tl' id



  (* sometimes we break if the type is a forward declaration, but can be inferred by the argument of a function. *)
  let fwd_decl_fixup (state: t) =
    List.iter (fixup_fn state) state.r_prog.prog_defs

  let dump_extern_syms (state: t) =
    Printf.printf "Beginning dump extern_syms:\n";
    Hashtbl.iter
      (fun id globdef ->
        (* turn the key-ident into a string *)
        let id_str       = Linking.ident_to_string ~name:id in
        (* extract the resolved name out of your globdef record: *)
        Printf.printf "\t%s, %ld\n" id_str (id |> P.to_int32)
      )
      state.extern_syms;
    Printf.printf "Ending dump extern_syms.\n";
    flush stdout


  let dump_metadata (state: t) =
    Printf.printf "\nmetadata for %s\n" state.mod_name;
    dump_imports state;
    dump_externs state;
    dump_in_module_composite_dfns state;
    dump_extern_syms state


  let gen_metadata (state: t) =
    get_in_module_composite_typs state;
    fill_out_globdef_imports state;
    all_used_typs_in_module state;
    fwd_decl_fixup state;
    dump_metadata state

end
