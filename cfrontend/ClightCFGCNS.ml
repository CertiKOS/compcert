open AST
open BinNums
open BinPos
open ClightCFG
open Ctypes
open Errors

let pos_eq a b =
  match Pos.compare a b with
  | Eq -> true
  | _ -> false

let pos_lt a b =
  match Pos.compare a b with
  | Lt -> true
  | _ -> false

let rec map_switch_targets old_uid new_uid = function
  | SLnil b ->
      if pos_eq b old_uid then SLnil new_uid else SLnil b
  | SLcons (k, b, rest) ->
      let b' = if pos_eq b old_uid then new_uid else b in
      SLcons (k, b', map_switch_targets old_uid new_uid rest)

let rec map_switch_targets_with_self old_uid self_uid = function
  | SLnil b ->
      if pos_eq b old_uid then SLnil self_uid else SLnil b
  | SLcons (k, b, rest) ->
      let b' = if pos_eq b old_uid then self_uid else b in
      SLcons (k, b', map_switch_targets_with_self old_uid self_uid rest)

let replace_target_in_edge edge old_uid new_uid =
  match edge with
  | Coq_direct b ->
      if pos_eq b old_uid then Coq_direct new_uid else edge
  | Coq_conditional (c, bt, bf) ->
      let bt' = if pos_eq bt old_uid then new_uid else bt in
      let bf' = if pos_eq bf old_uid then new_uid else bf in
      Coq_conditional (c, bt', bf')
  | Coq_switch (c, sl) ->
      Coq_switch (c, map_switch_targets old_uid new_uid sl)
  | Coq_terminate _ | Coq_stub ->
      edge

let map_self_target_in_edge edge old_uid self_uid =
  match edge with
  | Coq_direct b ->
      if pos_eq b old_uid then Coq_direct self_uid else edge
  | Coq_conditional (c, bt, bf) ->
      let bt' = if pos_eq bt old_uid then self_uid else bt in
      let bf' = if pos_eq bf old_uid then self_uid else bf in
      Coq_conditional (c, bt', bf')
  | Coq_switch (c, sl) ->
      Coq_switch (c, map_switch_targets_with_self old_uid self_uid sl)
  | Coq_terminate _ | Coq_stub ->
      edge

let successors_of_edge = function
  | Coq_direct b -> [b]
  | Coq_conditional (_, bt, bf) -> [bt; bf]
  | Coq_switch (_, sl) ->
      let rec walk acc = function
        | SLnil b -> b :: acc
        | SLcons (_, b, rest) -> walk (b :: acc) rest
      in
      walk [] sl
  | Coq_terminate _ | Coq_stub -> []

let successors_of_node cfg uid =
  match BBMap.find uid cfg.map with
  | Some (Coq_bb (_, edge)) -> successors_of_edge edge
  | None -> []

let add_pred pred target pred_map =
  let old_preds =
    match BBMap.find target pred_map with
    | Some s -> s
    | None -> BBSet.empty
  in
  BBMap.add target (BBSet.add pred old_preds) pred_map

let compute_predecessors cfg =
  let nodes = BBSet.elements cfg.node_set in
  List.fold_left
    (fun pred_map n ->
      let succs = successors_of_node cfg n in
      List.fold_left (fun acc s -> add_pred n s acc) pred_map succs)
    BBMap.empty nodes

let max_uid cfg =
  let nodes = BBSet.elements cfg.node_set in
  List.fold_left
    (fun acc n -> if pos_lt acc n then n else acc)
    cfg.entry nodes

let dfs_postorder cfg start visited =
  let rec go node (seen, order) =
    if BBSet.mem node seen then
      (seen, order)
    else
      let seen' = BBSet.add node seen in
      let succs = successors_of_node cfg node in
      let seen'', order' =
        List.fold_left (fun st s -> go s st) (seen', order) succs
      in
      (seen'', node :: order')
  in
  go start (visited, [])

let reverse_adj cfg =
  let preds = compute_predecessors cfg in
  fun n ->
    match BBMap.find n preds with
    | Some s -> BBSet.elements s
    | None -> []

let find_sccs cfg =
  let nodes = BBSet.elements cfg.node_set in
  let _, finishing =
    List.fold_left
      (fun (seen, order) n ->
        if BBSet.mem n seen then
          (seen, order)
        else
          let seen', post = dfs_postorder cfg n seen in
          (seen', post @ order))
      (BBSet.empty, []) nodes
  in
  let rev_succ = reverse_adj cfg in
  let rec dfs_rev node seen acc =
    if BBSet.mem node seen then
      (seen, acc)
    else
      let seen' = BBSet.add node seen in
      let nexts = rev_succ node in
      List.fold_left
        (fun (s, a) n -> dfs_rev n s a)
        (seen', BBSet.add node acc) nexts
  in
  let _, sccs =
    List.fold_left
      (fun (seen, acc) n ->
        if BBSet.mem n seen then
          (seen, acc)
        else
          let seen', scc = dfs_rev n seen BBSet.empty in
          (seen', scc :: acc))
      (BBSet.empty, []) finishing
  in
  sccs

let instruction_count cfg uid =
  match BBMap.find uid cfg.map with
  | Some (Coq_bb (insts, _)) -> List.length insts
  | None -> 1

let pred_count pred_map uid =
  match BBMap.find uid pred_map with
  | Some s -> List.length (BBSet.elements s)
  | None -> 0

let select_split_candidate cfg =
  let pred_map = compute_predecessors cfg in
  let sccs = find_sccs cfg in
  let choose_better cfg pred_map best candidate =
    let score n =
      let q = max 1 (instruction_count cfg n) in
      let p = max 1 (pred_count pred_map n) in
      q * max 1 (p - 1)
    in
    match best with
    | None -> Some candidate
    | Some b ->
        if score candidate < score b then Some candidate else best
  in
  List.fold_left
    (fun best scc ->
      let scc_nodes = BBSet.elements scc in
      if List.length scc_nodes <= 1 then
        best
      else
        let entry_nodes =
          List.filter
            (fun n ->
              let preds =
                match BBMap.find n pred_map with
                | Some s -> BBSet.elements s
                | None -> []
              in
              List.exists (fun p -> not (BBSet.mem p scc)) preds)
            scc_nodes
        in
        if List.length entry_nodes <= 1 then
          best
        else
          List.fold_left
            (fun b n ->
              if pos_eq n cfg.entry then b
              else choose_better cfg pred_map b n)
            best entry_nodes)
    None sccs

let split_node cfg target_uid =
  let pred_map = compute_predecessors cfg in
  let preds =
    match BBMap.find target_uid pred_map with
    | Some s -> BBSet.elements s |> List.filter (fun p -> not (pos_eq p target_uid))
    | None -> []
  in
  if List.length preds <= 1 then
    cfg
  else
    match BBMap.find target_uid cfg.map with
    | None -> cfg
    | Some (Coq_bb (insts, edge)) ->
        let base = max_uid cfg in
        let rec alloc cur ps acc =
          match ps with
          | [] -> (List.rev acc, cur)
          | p :: rest ->
              let next = Pos.succ cur in
              alloc next rest ((p, next) :: acc)
        in
        let redirects, _ = alloc base preds [] in
        let new_map =
          List.fold_left
            (fun m (pred_uid, new_uid) ->
              let copied_edge = map_self_target_in_edge edge target_uid new_uid in
              let m1 = BBMap.add new_uid (Coq_bb (insts, copied_edge)) m in
              match BBMap.find pred_uid m1 with
              | Some (Coq_bb (pinsts, pedge)) ->
                  let pedge' = replace_target_in_edge pedge target_uid new_uid in
                  BBMap.add pred_uid (Coq_bb (pinsts, pedge')) m1
              | None -> m1)
            cfg.map redirects
        in
        let new_map = BBMap.remove target_uid new_map in
        let new_node_set =
          List.fold_left
            (fun s (_, u) -> BBSet.add u s)
            (BBSet.remove target_uid cfg.node_set) redirects
        in
        {cfg with map = new_map; node_set = new_node_set}

let make_cfg_reducible cfg =
  let rec loop cur fuel =
    if fuel <= 0 then
      cur
    else
      match select_split_candidate cur with
      | None -> cur
      | Some uid ->
          let next = split_node cur uid in
          if BBSet.equal cur.node_set next.node_set then cur
          else loop next (fuel - 1)
  in
  loop cfg 64

let transl_internal_function (f : coq_function) : coq_function =
  let cfg, extra = f.fn_body in
  let cfg' = make_cfg_reducible cfg in
  { fn_return = f.fn_return;
    fn_callconv = f.fn_callconv;
    fn_params = f.fn_params;
    fn_vars = f.fn_vars;
    fn_temps = f.fn_temps;
    fn_body = (cfg', extra) }

let transl_fundef (_id : ident) (fd : clightcfg_fundef) : clightcfg_fundef res =
  match fd with
  | Internal f -> OK (Internal (transl_internal_function f))
  | External (a, b, c, d) -> OK (External (a, b, c, d))

let transl_globvar (_id : ident) (ty : coq_type) : coq_type res = OK ty

let transl_program (p : clightcfg_program) : clightcfg_program res =
  match AST.transf_globdefs transl_fundef transl_globvar p.prog_defs with
  | Error msg -> Error msg
  | OK defs ->
      OK
        { prog_defs = defs;
          prog_public = p.prog_public;
          prog_main = p.prog_main;
          prog_types = p.prog_types;
          prog_comp_env = p.prog_comp_env }
