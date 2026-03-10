Require Import ClightCFG.
Require Import Integers.
Require Import AST.
Require Import Ctypes.
Require Import ZArith.
Require Import RustLight.
Require Import SimplExpr.
Require Import Errors.
Require Import ZArith.
Require Import Coq.Strings.String.
Require Import List.
Import List.ListNotations.

Notation "'TODO'" := (ltac:(fail "TODO: implement this")) (at level 0).

Open Scope gensym_monad_scope.
Open Scope gensym_monad_scope_2.

Inductive DominatorSet : Type
  :=
  | entry_node: bb_uid -> DominatorSet
  (* immediate dominator *)
  (* immediate dominator -> nodes domianting the immediate dominator
     -> dominator set *)
  | immediate_dominator: bb_uid -> DominatorSet -> DominatorSet.

Print ClightCFG.

Inductive Tree (T : Type) : Type :=
  (* element -> children -> Tree *)
  | tree_node (ele: T) (children: list (Tree T)).

Arguments tree_node {T}.

Definition tree_root {T : Type} (tree: Tree T) : T :=
  match tree with
  | tree_node ele _ => ele
  end.

Definition tree_children {T : Type} (tree: Tree T) : list (Tree T) :=
  match tree with
  | tree_node _ children => children
  end.

Require Import Coq.FSets.FMapList.
Locate OrderedTypeEx.
Require Import Coq.Structures.OrderedTypeEx.  (* For positive_as_OT *)
Module PTOMap := Coq.FSets.FMapList.Make(Positive_as_OT).

Record ClightCFGWithMetadata: Type
  := mkClightCFGWithDominators {
    (* underlying CFG *)
    clight_cfg: ClightCFG;
    (* root of dominator tree *)
    clight_dominator_tree: Tree bb_uid;
    (* postorder traversal list (TODO if this is unused, nuke it )*)
    rpto: list bb_uid;

    (* this is useful b/c constant time lookup *)
    rpto_map: PTOMap.t positive;
  }.

(* TODO will need to make this a fixpoint eventually *)
Definition build_dominator_tree (cfg: ClightCFG) : Tree bb_uid :=
  tree_node cfg.(entry) nil.

Print BBSet.add.
Print list.

(* run dfs on the cfg *)
(* return nodes in the order they were *last* seen *)
(* we run on the invariant that we'll never "run out of fuel"
   just as long as the fuel is >= the number of nodes in the cfg *)
(* we will never go beyond that since given we're doing DFS we will not be
   encountering any cycles *)
Fixpoint postorder_traversal_gen_aux
  (* NOTE: I could define my own measure but this is easier *)
  (fuel: nat)
  (cfg: ClightCFG)
  (seen_nodes: BBSet.t)
  (pot: list bb_uid)
  (cur_node: bb_uid)
  {struct fuel}
  : mon (BBSet.t * list bb_uid)
  :=
  match fuel with
  | 0 => error(Errors.msg "Out of fuel")
  | S fuel' =>
    if BBSet.mem cur_node seen_nodes
    then ret (seen_nodes, pot)
    else
      (* add to visitor set*)
      let new_seen_nodes := BBSet.add cur_node seen_nodes in

      (* obtain children *)
      do (sn, pot) <-
        recurse_on_children fuel' cfg new_seen_nodes pot cur_node;

      (* add to postorder traversal *)
      let final_postorder := cons cur_node pot in
      ret (sn, final_postorder)
  end
with
  recurse_on_children
  (fuel: nat)
  (cfg: ClightCFG)
  (seen_nodes: BBSet.t)
  (postorder_traversal: list bb_uid)
  (cur_node: bb_uid)
  {struct fuel}
  : mon (BBSet.t * list bb_uid)
  :=
  match fuel with
  | 0 => error(Errors.msg "Out of fuel")
  | S fuel' =>
    match BBMap.find cur_node cfg.(ClightCFG.map) with
    | Some (bb _ edge) =>
        match edge with
        | direct nextbb =>
            postorder_traversal_gen_aux
              fuel' cfg seen_nodes postorder_traversal nextbb
        | conditional _ b_true b_false =>
            do (sn', pot') <- postorder_traversal_gen_aux fuel'
              cfg seen_nodes postorder_traversal b_true;
            postorder_traversal_gen_aux fuel' cfg sn' pot' b_false
        | switch _ sl =>
            recurse_on_switch_list fuel' cfg seen_nodes postorder_traversal sl
        | stub => error(Errors.msg "stub edge encountered")
        | terminate _ => ret (seen_nodes, postorder_traversal)
        end
    | None => error(Errors.msg "Edge referred to by but not in CFG")
    end
  end
with recurse_on_switch_list
  (fuel: nat)
  (cfg: ClightCFG)
  (seen_nodes: BBSet.t)
  (postorder_traversal: list bb_uid)
  (sl: switch_list)
  {struct fuel}
  : mon (BBSet.t * list bb_uid)
  :=
  match fuel with
  | 0 => error(Errors.msg "Out of fuel")
  | S fuel' =>
    match sl with
    | SLnil b =>
        postorder_traversal_gen_aux fuel' cfg seen_nodes postorder_traversal b
    | SLcons _ b sl' =>
        do (sn, pot) <- postorder_traversal_gen_aux fuel' cfg seen_nodes postorder_traversal b;
        recurse_on_switch_list fuel' cfg sn pot sl'
    end
  end.

Print BBSet.cardinal.

Fixpoint gen_bb_map (pot: list bb_uid) (cur_map : BBMap.t positive) (num: positive)
  : BBMap.t positive
  :=
  match pot with
  | nil => cur_map
  | hd :: tl => gen_bb_map tl (BBMap.add hd num cur_map) (Pos.succ num)
  end.

Definition reverse_postorder_traversal_gen
  (cfg: ClightCFG) : mon (list bb_uid * BBMap.t positive)
  :=
  let num_nodes := BBSet.cardinal cfg.(node_set) in
  (* The DFS helper consumes fuel at multiple recursive layers per visited node
     (node visit + edge traversal + switch-list traversal). A quadratic budget
     avoids spurious "Out of fuel" failures on normal CFGs. *)
  let fuel := S (Nat.mul (S num_nodes) (S num_nodes)) in
  let seen_nodes := BBSet.empty in
  let pot := nil in
  let cur_node := cfg.(entry) in

  do (seen_set, pot) <- postorder_traversal_gen_aux fuel cfg seen_nodes pot cur_node;

  let rpot := pot in

  ret (rpot, gen_bb_map rpot (BBMap.empty positive) 1).

Definition edge_successors (edge: BBEdge) : list bb_uid :=
  match edge with
  | direct nextbb => [nextbb]
  | conditional _ b_true b_false => [b_true; b_false]
  | switch _ sl =>
      let fix sl_successors (sl': switch_list) : list bb_uid :=
        match sl' with
        | SLnil b => [b]
        | SLcons _ b sl'' => b :: sl_successors sl''
        end
      in sl_successors sl
  | terminate _ => []
  | stub => []
  end.

Definition add_predecessor
  (pred succ: bb_uid)
  (pred_map: BBMap.t BBSet.t)
  : BBMap.t BBSet.t
  :=
  let preds :=
    match BBMap.find succ pred_map with
    | Some s => s
    | None => BBSet.empty
    end
  in
  BBMap.add succ (BBSet.add pred preds) pred_map.

Fixpoint add_predecessors_for_successors
  (pred: bb_uid)
  (succs: list bb_uid)
  (pred_map: BBMap.t BBSet.t)
  : BBMap.t BBSet.t
  :=
  match succs with
  | [] => pred_map
  | succ :: rest =>
      add_predecessors_for_successors pred rest (add_predecessor pred succ pred_map)
  end.

Definition compute_predecessor_map (cfg: ClightCFG) : BBMap.t BBSet.t :=
  fold_left
    (fun (pred_map: BBMap.t BBSet.t) (source: bb_uid) =>
      match BBMap.find source cfg.(ClightCFG.map) with
      | Some (bb _ edge) =>
          add_predecessors_for_successors source (edge_successors edge) pred_map
      | None => pred_map
      end)
    (BBSet.elements cfg.(ClightCFG.node_set))
    (BBMap.empty BBSet.t).

Definition get_rpo_num (rpo_map: BBMap.t positive) (n: bb_uid) : option positive :=
  BBMap.find n rpo_map.

Definition is_backward_edge
  (rpo_map: BBMap.t positive)
  (source target: bb_uid)
  : bool
  :=
  match get_rpo_num rpo_map source, get_rpo_num rpo_map target with
  | Some src_num, Some tgt_num => Pos.leb tgt_num src_num
  | _, _ => false
  end.

Fixpoint count_forward_predecessors
  (rpo_map: BBMap.t positive)
  (node: bb_uid)
  (preds: list bb_uid)
  : nat
  :=
  match preds with
  | [] => O
  | pred :: rest =>
      let rest_count := count_forward_predecessors rpo_map node rest in
      if is_backward_edge rpo_map pred node
      then rest_count
      else S rest_count
  end.

Definition is_merge_node
  (pred_map: BBMap.t BBSet.t)
  (rpo_map: BBMap.t positive)
  (node: bb_uid)
  : bool
  :=
  match BBMap.find node pred_map with
  | Some preds =>
      let forward_count := count_forward_predecessors rpo_map node (BBSet.elements preds) in
      Nat.leb 2 forward_count
  | None => false
  end.

Definition compute_merge_nodes
  (cfg: ClightCFG)
  (pred_map: BBMap.t BBSet.t)
  (rpo_map: BBMap.t positive)
  : BBSet.t
  :=
  fold_left
    (fun (merges: BBSet.t) (node: bb_uid) =>
      if is_merge_node pred_map rpo_map node
      then BBSet.add node merges
      else merges)
    (BBSet.elements cfg.(ClightCFG.node_set))
    BBSet.empty.

Definition compute_loop_headers
  (cfg: ClightCFG)
  (rpo_map: BBMap.t positive)
  : BBSet.t
  :=
  fold_left
    (fun (headers: BBSet.t) (source: bb_uid) =>
      match BBMap.find source cfg.(ClightCFG.map) with
      | Some (bb _ edge) =>
          fold_left
            (fun (acc: BBSet.t) (target: bb_uid) =>
              if is_backward_edge rpo_map source target
              then BBSet.add target acc
              else acc)
            (edge_successors edge)
            headers
      | None => headers
      end)
    (BBSet.elements cfg.(ClightCFG.node_set))
    BBSet.empty.

Record StructuredMetadata : Type :=
  mkStructuredMetadata {
    sm_rpo_list: list bb_uid;
    sm_rpo_map: BBMap.t positive;
    sm_predecessors: BBMap.t BBSet.t;
    sm_merge_nodes: BBSet.t;
    sm_loop_headers: BBSet.t;
    sm_idom_map: BBMap.t bb_uid;
    sm_dom_tree: Tree bb_uid;
  }.

Definition initial_idom_map (cfg: ClightCFG) : BBMap.t bb_uid :=
  BBMap.add cfg.(entry) cfg.(entry) (BBMap.empty bb_uid).

Definition idom_defined (idom_map: BBMap.t bb_uid) (node: bb_uid) : bool :=
  match BBMap.find node idom_map with
  | Some _ => true
  | None => false
  end.

Fixpoint intersect_idoms
  (fuel: nat)
  (rpo_map: BBMap.t positive)
  (idom_map: BBMap.t bb_uid)
  (finger1 finger2: bb_uid)
  : option bb_uid
  :=
  match fuel with
  | O => None
  | S fuel' =>
      if Pos.eqb finger1 finger2 then
        Some finger1
      else
        match get_rpo_num rpo_map finger1, get_rpo_num rpo_map finger2 with
        | Some n1, Some n2 =>
            if Pos.ltb n1 n2 then
              match BBMap.find finger2 idom_map with
              | Some next2 => intersect_idoms fuel' rpo_map idom_map finger1 next2
              | None => None
              end
            else if Pos.ltb n2 n1 then
              match BBMap.find finger1 idom_map with
              | Some next1 => intersect_idoms fuel' rpo_map idom_map next1 finger2
              | None => None
              end
            else None
        | _, _ => None
        end
  end.

Fixpoint fold_idom_preds
  (fuel: nat)
  (rpo_map: BBMap.t positive)
  (idom_map: BBMap.t bb_uid)
  (preds: list bb_uid)
  (acc: option bb_uid)
  : option bb_uid
  :=
  match preds with
  | [] => acc
  | pred :: rest =>
      if idom_defined idom_map pred then
        match acc with
        | None => fold_idom_preds fuel rpo_map idom_map rest (Some pred)
        | Some cur =>
            match intersect_idoms fuel rpo_map idom_map pred cur with
            | Some merged => fold_idom_preds fuel rpo_map idom_map rest (Some merged)
            | None => fold_idom_preds fuel rpo_map idom_map rest acc
            end
        end
      else
        fold_idom_preds fuel rpo_map idom_map rest acc
  end.

Definition update_idom_for_node
  (fuel: nat)
  (entry: bb_uid)
  (pred_map: BBMap.t BBSet.t)
  (rpo_map: BBMap.t positive)
  (idom_map: BBMap.t bb_uid)
  (node: bb_uid)
  : (BBMap.t bb_uid * bool)
  :=
  if Pos.eqb node entry then
    (idom_map, false)
  else
    let preds :=
      match BBMap.find node pred_map with
      | Some ps => BBSet.elements ps
      | None => []
      end
    in
    match fold_idom_preds fuel rpo_map idom_map preds None with
    | None => (idom_map, false)
    | Some new_idom =>
        match BBMap.find node idom_map with
        | Some old_idom =>
            if Pos.eqb old_idom new_idom then
              (idom_map, false)
            else
              (BBMap.add node new_idom idom_map, true)
        | None =>
            (BBMap.add node new_idom idom_map, true)
        end
    end.

Fixpoint update_idom_over_nodes
  (fuel: nat)
  (entry: bb_uid)
  (pred_map: BBMap.t BBSet.t)
  (rpo_map: BBMap.t positive)
  (nodes: list bb_uid)
  (idom_map: BBMap.t bb_uid)
  : (BBMap.t bb_uid * bool)
  :=
  match nodes with
  | [] => (idom_map, false)
  | node :: rest =>
      let '(updated_map, changed_here) :=
        update_idom_for_node fuel entry pred_map rpo_map idom_map node in
      let '(final_map, changed_rest) :=
        update_idom_over_nodes fuel entry pred_map rpo_map rest updated_map in
      (final_map, orb changed_here changed_rest)
  end.

Fixpoint compute_idom_map_fuel
  (fuel: nat)
  (entry: bb_uid)
  (pred_map: BBMap.t BBSet.t)
  (rpo_map: BBMap.t positive)
  (nodes: list bb_uid)
  (idom_map: BBMap.t bb_uid)
  : BBMap.t bb_uid
  :=
  match fuel with
  | O => idom_map
  | S fuel' =>
      let '(next_map, changed) :=
        update_idom_over_nodes fuel entry pred_map rpo_map nodes idom_map in
      if changed then
        compute_idom_map_fuel fuel' entry pred_map rpo_map nodes next_map
      else
        next_map
  end.

Definition compute_idom_map
  (cfg: ClightCFG)
  (rpo_list: list bb_uid)
  (rpo_map: BBMap.t positive)
  (pred_map: BBMap.t BBSet.t)
  : BBMap.t bb_uid
  :=
  let fuel := S (Nat.mul (length rpo_list) (length rpo_list)) in
  compute_idom_map_fuel fuel cfg.(entry) pred_map rpo_map rpo_list (initial_idom_map cfg).

Fixpoint children_of
  (parent: bb_uid)
  (ordered_nodes: list bb_uid)
  (idom_map: BBMap.t bb_uid)
  : list bb_uid
  :=
  match ordered_nodes with
  | [] => []
  | node :: rest =>
      let rest_children := children_of parent rest idom_map in
      if Pos.eqb node parent then
        rest_children
      else
        match BBMap.find node idom_map with
        | Some idom =>
            if Pos.eqb idom parent then node :: rest_children else rest_children
        | None => rest_children
        end
  end.

Fixpoint build_dom_tree_aux
  (fuel: nat)
  (ordered_nodes: list bb_uid)
  (idom_map: BBMap.t bb_uid)
  (root: bb_uid)
  : mon (Tree bb_uid)
  :=
  match fuel with
  | O => error (Errors.msg "Out of fuel while building dominator tree")
  | S fuel' =>
      let child_labels := children_of root ordered_nodes idom_map in
      do child_trees <- build_dom_forest_aux fuel' ordered_nodes idom_map child_labels;
      ret (tree_node root child_trees)
  end
with build_dom_forest_aux
  (fuel: nat)
  (ordered_nodes: list bb_uid)
  (idom_map: BBMap.t bb_uid)
  (roots: list bb_uid)
  : mon (list (Tree bb_uid))
  :=
  match fuel with
  | O => error (Errors.msg "Out of fuel while building dominator forest")
  | S fuel' =>
      match roots with
      | [] => ret []
      | root :: rest =>
          do tree <- build_dom_tree_aux fuel' ordered_nodes idom_map root;
          do forest <- build_dom_forest_aux fuel' ordered_nodes idom_map rest;
          ret (tree :: forest)
      end
  end.

Fixpoint find_subtree_fuel
  (fuel: nat)
  (target: bb_uid)
  (tree: Tree bb_uid)
  : option (Tree bb_uid)
  :=
  match fuel with
  | O => None
  | S fuel' =>
      if Pos.eqb target (tree_root tree) then
        Some tree
      else
        find_subtree_in_forest_fuel fuel' target (tree_children tree)
  end
with find_subtree_in_forest_fuel
  (fuel: nat)
  (target: bb_uid)
  (forest: list (Tree bb_uid))
  : option (Tree bb_uid)
  :=
  match fuel with
  | O => None
  | S fuel' =>
      match forest with
      | [] => None
      | tree :: rest =>
          match find_subtree_fuel fuel' target tree with
          | Some subtree => Some subtree
          | None => find_subtree_in_forest_fuel fuel' target rest
          end
      end
  end.

Definition find_subtree
  (fuel: nat)
  (target: bb_uid)
  (tree: Tree bb_uid)
  : option (Tree bb_uid)
  :=
  find_subtree_fuel fuel target tree.

Definition build_structured_metadata (cfg: ClightCFG) : mon StructuredMetadata :=
  gdo (rpo_list, rpo_map) <- reverse_postorder_traversal_gen cfg;
  let predecessors := compute_predecessor_map cfg in
  let merge_nodes := compute_merge_nodes cfg predecessors rpo_map in
  let loop_headers := compute_loop_headers cfg rpo_map in
  let idom_map := compute_idom_map cfg rpo_list rpo_map predecessors in
  let dom_fuel := S (Nat.mul (length rpo_list) (length rpo_list)) in
  gdo dom_tree <- build_dom_tree_aux dom_fuel rpo_list idom_map cfg.(entry);
  ret
    {|
      sm_rpo_list := rpo_list;
      sm_rpo_map := rpo_map;
      sm_predecessors := predecessors;
      sm_merge_nodes := merge_nodes;
      sm_loop_headers := loop_headers;
      sm_idom_map := idom_map;
      sm_dom_tree := dom_tree;
    |}.


(* NOTE: to translate clight expression: Clight.transl_syntax_expr *)

Print msg.

Fixpoint transl_syntax_expr (a: Clight.expr) {struct a}
  : SimplExpr.mon (rexpr) :=
  match a with
  | Clight.Econst_int n ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret (Econst_int n ty)
  | Clight.Econst_float n ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Econst_float n ty)
  | Clight.Econst_single n ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Econst_single n ty)
  | Clight.Econst_long n ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Econst_long n ty)
  | Clight.Evar id ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Evar id ty)
  | Clight.Etempvar id ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Etempvar id ty)
  | Clight.Ederef b ty =>
      (*do unused <- check_ty ty;*)
      do tb <- transl_syntax_expr b;
      SimplExpr.ret(Ederef tb ty)
  | Clight.Eaddrof b ty =>
      (*do unused <- check_ty ty;*)
      do tb <- transl_syntax_expr b;
      SimplExpr.ret(Eaddrof tb ty)
  | Clight.Eunop op exp ty =>
      (*do unused <- check_ty ty;*)
      do translated_exp <- transl_syntax_expr exp;
      SimplExpr.ret(Eunop op translated_exp ty)
  | Clight.Ebinop op exp1 exp2 ty =>
      (*do unused <- check_ty ty;*)
      do rexp1 <- transl_syntax_expr exp1;
      do rexp2 <- transl_syntax_expr exp2;
      SimplExpr.ret(Ebinop op rexp1 rexp2 ty)
  | Clight.Ecast exp ty =>
      (*do unused <- check_ty ty;*)
      do rexp <- transl_syntax_expr exp;
      SimplExpr.ret(Ecast rexp ty)
  | Clight.Efield exp ident ty =>
      (*do unused <- check_ty ty;*)
      do rexp <- transl_syntax_expr exp;
      SimplExpr.ret(Efield rexp ident ty)
  | Clight.Esizeof ty' ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Esizeof ty' ty)
  | Clight.Ealignof ty' ty =>
      (*do unused <- check_ty ty;*)
      SimplExpr.ret(Ealignof ty' ty)
  end.

Fixpoint transl_syntax_arglist
  (al: list Clight.expr)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      do arg <- transl_syntax_expr a1 ;
      do args <- transl_syntax_arglist a2 ;
      SimplExpr.ret(arg :: args)
  end.

Fixpoint transl_syntax_arglist_with_ty_info
  (al: list Clight.expr)
  (tyl: typelist)
  {struct al}:
  SimplExpr.mon (list rexpr) :=
  match al with
  | nil => SimplExpr.ret(nil)
  | a1 :: a2 =>
      match tyl with
      | Tnil =>
        (
          do arg <- transl_syntax_expr a1 ;
          do args <- transl_syntax_arglist_with_ty_info a2 Tnil ;
          SimplExpr.ret(arg :: args)
        )
      | Tcons ty tyl' =>
      (
          do arg <- transl_syntax_expr a1 ;
          (* TODO laso don't need this *)
          (* gdo casted_arg <- i2etc (r_typeof arg) ty arg ; *)
          do args <- transl_syntax_arglist_with_ty_info a2 tyl';
          SimplExpr.ret(arg :: args)
      )
      end
  end.

(* for now essentially copying transl_syntax_statement *)
(* TODO process_expr will happen later *)
Definition transl_clightcfg_instruction (inst: Instruction)
  : mon rstatement :=
  match inst with
  | i_skip => SimplExpr.ret S_skip
  | i_assign lval rval =>
      do rust_lval <- transl_syntax_expr lval;
      do rust_rval <- transl_syntax_expr rval;
      ret (S_assign rust_lval rust_rval)
  | i_set lvar rval =>
      do rust_rval <- transl_syntax_expr rval;
      ret (S_set lvar rust_rval)
  | i_call x fn_name al =>
      do fn_name_rust <- transl_syntax_expr fn_name ;
      match r_typeof fn_name_rust with
      | Tfunction tyl t cc =>
        (
          (* TODO move this fn to this file *)
          do al' <- transl_syntax_arglist_with_ty_info al tyl;
          ret (S_call x fn_name_rust al')
        )
      | _ =>
        (
          do al' <- transl_syntax_arglist al ;
          ret (S_call x fn_name_rust al')
        )
      end
  | i_builtin maybe_ident extfun tl args =>
      error(Errors.msg "INVALID BUILTIN")
  end.

Fixpoint transl_clightcfg_instructions (insts: list Instruction) :
  mon rstatement :=
  match insts with
  | i :: rest =>
      (* TODO make tail recursive *)
      (* by passing around fn to construction the function given a hole *)
      do translated_inst <- transl_clightcfg_instruction i;
      do translated_insts <- transl_clightcfg_instructions rest;
      ret (S_sequence translated_inst translated_insts)
  | nil => ret S_skip
  end.

Definition get_bb (cfg: ClightCFG) (block_uid: bb_uid): mon BasicBlock :=
  match BBMap.find block_uid (cfg.(ClightCFG.map)) with
  | Some block => ret block
  | None => error(Errors.msg "BB missing from ndoe when viewing edge")
  end.

Inductive ContainingSyntax :=
  | IfThenElse: ContainingSyntax
  | LoopHeadedBy: bb_uid -> ContainingSyntax
  | BlockFollowedBy: bb_uid -> ContainingSyntax.

Record TranslContext :=
  mkTranslContext {
      enclosing: list ContainingSyntax;
      fallthrough: option bb_uid;
  }.

Definition empty_context : TranslContext :=
  {|
    enclosing := nil;
    fallthrough := None;
  |}.

Definition inside_context
  (frame: ContainingSyntax)
  (context: TranslContext)
  : TranslContext :=
  {|
    enclosing := frame :: context.(enclosing);
    fallthrough := context.(fallthrough);
  |}.

Definition with_fallthrough
  (target: bb_uid)
  (context: TranslContext)
  : TranslContext :=
  {|
    enclosing := context.(enclosing);
    fallthrough := Some target;
  |}.

Fixpoint label_in_context_frames
  (target: bb_uid)
  (frames: list ContainingSyntax)
  : bool
  :=
  match frames with
  | [] => false
  | IfThenElse :: rest => label_in_context_frames target rest
  | LoopHeadedBy l :: rest =>
      if Pos.eqb l target then true else label_in_context_frames target rest
  | BlockFollowedBy l :: rest =>
      if Pos.eqb l target then true else label_in_context_frames target rest
  end.

Definition label_in_context (target: bb_uid) (context: TranslContext) : bool :=
  label_in_context_frames target context.(enclosing).

Definition is_fallthrough_target (target: bb_uid) (context: TranslContext) : bool :=
  match context.(fallthrough) with
  | Some lbl => Pos.eqb lbl target
  | None => false
  end.

(* Keep control labels and block labels disjoint in emitted Rust:
   control labels are even, block labels are odd. *)
Definition encode_control_label (uid: positive) : Z :=
  Z.mul (Z.pos uid) 2.

Definition encode_block_label (uid: bb_uid) : Z :=
  Z.succ (encode_control_label uid).

(* Helper used by upcoming structured translation:
   - backward edge => continue to loop header
   - forward edge to merge label => break to block
   - otherwise inline by caller (None) *)
Definition structured_jump_for_branch
  (meta: StructuredMetadata)
  (source target: bb_uid)
  (context: TranslContext)
  : option rstatement
  :=
  if is_fallthrough_target target context
  then Some S_skip
  else if is_backward_edge meta.(sm_rpo_map) source target
       then Some (S_continue (Some (encode_block_label target)))
       else if BBSet.mem target meta.(sm_merge_nodes)
            then Some (S_break (Some (encode_block_label target)))
            else None.

Definition mk_loop_for_header (header: bb_uid) (body: rstatement) : rstatement :=
  S_loop (Some (encode_block_label header)) body S_skip.

Definition mk_block_followed_by (label: bb_uid) (body: rstatement) : rstatement :=
  S_block (Some (encode_block_label label)) body.

Definition choose_structured_branch
  (meta: StructuredMetadata)
  (source target: bb_uid)
  (context: TranslContext)
  (inline_target: option rstatement)
  : rstatement
  :=
  match structured_jump_for_branch meta source target context with
  | Some jump_stmt => jump_stmt
  | None =>
      match inline_target with
      | Some stmt => stmt
      | None => S_skip
      end
  end.

Fixpoint filter_merge_children
  (meta: StructuredMetadata)
  (children: list (Tree bb_uid))
  : list (Tree bb_uid)
  :=
  match children with
  | [] => []
  | child :: rest =>
      let filtered_rest := filter_merge_children meta rest in
      if BBSet.mem (tree_root child) meta.(sm_merge_nodes)
      then child :: filtered_rest
      else filtered_rest
  end.

Definition merge_children_in_nesting_order
  (meta: StructuredMetadata)
  (children: list (Tree bb_uid))
  : list (Tree bb_uid)
  :=
  rev (filter_merge_children meta children).

Definition lookup_subtree
  (fuel: nat)
  (meta: StructuredMetadata)
  (target: bb_uid)
  : mon (Tree bb_uid)
  :=
  match find_subtree fuel target meta.(sm_dom_tree) with
  | Some subtree => ret subtree
  | None => error (Errors.msg "Missing dominator subtree for branch target")
  end.

Definition structured_translation_fuel (meta: StructuredMetadata) : nat :=
  let n := S (length meta.(sm_rpo_list)) in
  S (Nat.mul (Nat.mul n n) n).

Fixpoint doTree_nodisp
  (fuel: nat)
  (meta: StructuredMetadata)
  (cfg: ClightCFG)
  (r_ty: type)
  (subtree: Tree bb_uid)
  (context: TranslContext)
  : SimplExpr.mon rstatement
  :=
  match fuel with
  | O => SimplExpr.error (Errors.msg "Out of fuel in structured tree translation")
  | S fuel' =>
      let x := tree_root subtree in
      let children := tree_children subtree in
      let merge_children := merge_children_in_nesting_order meta children in
      if BBSet.mem x meta.(sm_loop_headers)
      then
        let loop_context :=
          with_fallthrough x (inside_context (LoopHeadedBy x) context)
        in
        gdo code_for_x <- nodeWithin_nodisp fuel' meta cfg r_ty x merge_children loop_context;
        ret (mk_loop_for_header x code_for_x)
      else
        nodeWithin_nodisp fuel' meta cfg r_ty x merge_children context
  end
with nodeWithin_nodisp
  (fuel: nat)
  (meta: StructuredMetadata)
  (cfg: ClightCFG)
  (r_ty: type)
  (x: bb_uid)
  (merge_children: list (Tree bb_uid))
  (context: TranslContext)
  : SimplExpr.mon rstatement
  :=
  match fuel with
  | O => SimplExpr.error (Errors.msg "Out of fuel in structured node placement")
  | S fuel' =>
      match merge_children with
      | [] =>
          transl_cfg_node_nodisp fuel' meta cfg r_ty x context
      | y_n :: ys =>
          let ylabel := tree_root y_n in
          let inner_context :=
            with_fallthrough ylabel (inside_context (BlockFollowedBy ylabel) context)
          in
          gdo inner <- nodeWithin_nodisp fuel' meta cfg r_ty x ys inner_context;
          gdo y_stmt <- doTree_nodisp fuel' meta cfg r_ty y_n context;
          ret (S_sequence (mk_block_followed_by ylabel inner) y_stmt)
      end
  end
with doBranch_nodisp
  (fuel: nat)
  (meta: StructuredMetadata)
  (cfg: ClightCFG)
  (r_ty: type)
  (source target: bb_uid)
  (context: TranslContext)
  : SimplExpr.mon rstatement
  :=
  match fuel with
  | O => SimplExpr.error (Errors.msg "Out of fuel in structured branch translation")
  | S fuel' =>
      if is_fallthrough_target target context then
        ret S_skip
      else if andb (is_backward_edge meta.(sm_rpo_map) source target)
                    (BBSet.mem target meta.(sm_loop_headers))
      then
        if label_in_context target context then
          ret (S_continue (Some (encode_block_label target)))
        else
          SimplExpr.error (Errors.msg "Backward edge target missing from context")
      else if BBSet.mem target meta.(sm_merge_nodes) then
        if label_in_context target context then
          ret (S_break (Some (encode_block_label target)))
        else
          SimplExpr.error (Errors.msg "Merge target missing from context")
      else
        gdo target_tree <- lookup_subtree fuel' meta target;
        doTree_nodisp fuel' meta cfg r_ty target_tree context
  end
with transl_cfg_to_rustlight_sl_nodisp
  (fuel: nat)
  (meta: StructuredMetadata)
  (cfg: ClightCFG)
  (r_ty: type)
  (source: bb_uid)
  (context: TranslContext)
  (maybe_dflt: option rstatement)
  (sl: switch_list)
  : SimplExpr.mon labeled_rstatements
  :=
  match fuel with
  | O => SimplExpr.error (Errors.msg "Out of fuel in structured switch translation")
  | S fuel' =>
      match sl with
      | SLnil s' =>
          gdo final_stmt <-
            match maybe_dflt with
            | Some dflt_stmt => ret dflt_stmt
            | None => doBranch_nodisp fuel' meta cfg r_ty source s' context
            end;
          ret (LSnil final_stmt)
      | SLcons maybe_int b sl' =>
          match maybe_int with
          | None =>
              gdo final_stmt <- doBranch_nodisp fuel' meta cfg r_ty source b context;
              transl_cfg_to_rustlight_sl_nodisp fuel' meta cfg r_ty source context (Some final_stmt) sl'
          | Some i =>
              gdo branch_stmt <- doBranch_nodisp fuel' meta cfg r_ty source b context;
              gdo rest <- transl_cfg_to_rustlight_sl_nodisp fuel' meta cfg r_ty source context maybe_dflt sl';
              ret (LScons (Some i) branch_stmt rest)
          end
      end
  end
with transl_cfg_node_nodisp
  (fuel: nat)
  (meta: StructuredMetadata)
  (cfg: ClightCFG)
  (r_ty: type)
  (cur_node: bb_uid)
  (context: TranslContext)
  : SimplExpr.mon rstatement
  :=
  match fuel with
  | O => SimplExpr.error (Errors.msg "Out of fuel in structured node translation")
  | S fuel' =>
      gdo block <- get_bb cfg cur_node;
      match block with
      | bb insts edge =>
          gdo transl_insts <- transl_clightcfg_instructions insts;
          gdo transl_edge <-
            match edge with
            | direct target =>
                doBranch_nodisp fuel' meta cfg r_ty cur_node target context
            | conditional cexp b_true b_false =>
                gdo r_cexp <- transl_syntax_expr cexp;
                let branch_context := inside_context IfThenElse context in
                gdo true_branch <- doBranch_nodisp fuel' meta cfg r_ty cur_node b_true branch_context;
                gdo false_branch <- doBranch_nodisp fuel' meta cfg r_ty cur_node b_false branch_context;
                ret (S_if_then_else r_cexp true_branch false_branch)
            | terminate maybe_exp =>
                match maybe_exp with
                | Some exp =>
                    gdo e <- transl_syntax_expr exp;
                    ret (S_return (Some (e, r_typeof e)))
                | None =>
                    ret
                      (match r_ty with
                       | Tvoid => S_return None
                       | _ => S_skip
                       end)
                end
            | switch cexp sl =>
                gdo tr_exp <- transl_syntax_expr cexp;
                gdo lrs <- transl_cfg_to_rustlight_sl_nodisp fuel' meta cfg r_ty cur_node context None sl;
                ret (S_match_int tr_exp lrs)
            | stub =>
                SimplExpr.error (Errors.msg "stub edge encountered")
            end;
          ret (S_sequence transl_insts transl_edge)
      end
  end.

(* -------------------- END haskell attempt. Will return to this later -----*)

Local Open Scope gensym_monad_scope_2.
Local Open Scope error_monad_scope.

Definition bbuid_ty : type := Ctypes.Tint I32 Unsigned noattr.

Definition bb_to_rexpr (block_id: bb_uid): rexpr :=
  Econst_int (Int.repr (Z.pos block_id)) bbuid_ty.

Definition gen_goto_next_bb
  (cf_lbl_ident: bb_uid) (goto_id: bb_uid) : rstatement :=
  let set_stmt := S_set cf_lbl_ident (bb_to_rexpr goto_id) in
  (* NOTE probably unnecessary in most cases. I could remove it. *)
  let continue_stmt := S_continue (Some (encode_control_label cf_lbl_ident)) in
  S_sequence set_stmt continue_stmt.

Fixpoint bb_uid_in_list (target: bb_uid) (labels: list bb_uid) : bool :=
  match labels with
  | [] => false
  | lbl :: rest => if Pos.eqb lbl target then true else bb_uid_in_list target rest
  end.

Fixpoint next_in_order (target: bb_uid) (ordered_nodes: list bb_uid) : option bb_uid :=
  match ordered_nodes with
  | [] => None
  | [n] => None
  | n1 :: (n2 :: rest as tl) =>
      if Pos.eqb n1 target
      then Some n2
      else next_in_order target tl
  end.

Definition doBranch
  (cf_lbl_ident source target: bb_uid)
  (next_node: option bb_uid)
  (context_labels: list bb_uid)
  : rstatement :=
  if
    match next_node with
    | Some nextbb => Pos.eqb nextbb target
    | None => false
    end
  then S_skip
  else if bb_uid_in_list target context_labels
       then S_break (Some (encode_block_label target))
       else gen_goto_next_bb cf_lbl_ident target.

Fixpoint selector_cases (entry_uid: bb_uid) (nodes: list bb_uid) : labeled_rstatements :=
  match nodes with
  | [] => LSnil S_skip
  | node :: rest =>
      let stmt :=
        if Pos.eqb node entry_uid
        then S_skip
        else S_break (Some (encode_block_label node))
      in
      LScons (Some (Z.pos node)) stmt (selector_cases entry_uid rest)
  end.

Fixpoint transl_cfg_to_rustlight_sl_structured
  (branch_for: bb_uid -> rstatement)
  (maybe_dflt: option rstatement)
  (sl: switch_list)
  : labeled_rstatements :=
  match sl with
  | SLnil s' =>
      LSnil
        (match maybe_dflt with
         | Some dflt_stmt => dflt_stmt
         | None => branch_for s'
         end)
  | SLcons maybe_int b sl' =>
      match maybe_int with
      | None =>
          transl_cfg_to_rustlight_sl_structured branch_for (Some (branch_for b)) sl'
      | Some i =>
          LScons
            (Some i)
            (branch_for b)
            (transl_cfg_to_rustlight_sl_structured branch_for maybe_dflt sl')
      end
  end.

Definition transl_cfg_node_structured
  (cfg: ClightCFG)
  (cf_lbl_ident: bb_uid)
  (cur_node: bb_uid)
  (next_node: option bb_uid)
  (context_labels: list bb_uid)
  (r_ty: type)
  : SimplExpr.mon rstatement :=
  gdo block <- get_bb cfg cur_node;
  match block with
  | bb insts edge =>
      gdo transl_insts <- transl_clightcfg_instructions insts;
      let branch_for := fun target => doBranch cf_lbl_ident cur_node target next_node context_labels in
      gdo transl_edge <-
      match edge with
      | direct target =>
          ret (branch_for target)
      | conditional cexp b_true b_false =>
          gdo r_cexp <- transl_syntax_expr cexp;
          ret (S_if_then_else r_cexp (branch_for b_true) (branch_for b_false))
      | terminate maybe_exp =>
          match maybe_exp with
          | Some exp =>
              gdo e <- transl_syntax_expr exp;
              ret (S_return (Some (e, r_typeof e)))
          | None =>
              ret
                (match r_ty with
                 | Tvoid => S_return None
                 | _ => S_skip
                 end)
          end
      | switch cexp sl =>
          gdo tr_exp <- transl_syntax_expr cexp;
          let lrs := transl_cfg_to_rustlight_sl_structured branch_for None sl in
          ret (S_match_int tr_exp lrs)
      | stub => SimplExpr.error (Errors.msg "stub edge encountered")
      end;
      ret (S_sequence transl_insts transl_edge)
  end.

Fixpoint nodeWithin
  (cfg: ClightCFG)
  (cf_lbl_ident: bb_uid)
  (r_ty: type)
  (ordered_nodes: list bb_uid)
  (entry_uid: bb_uid)
  (follows_desc: list bb_uid)
  (context_labels: list bb_uid)
  : SimplExpr.mon rstatement :=
  match follows_desc with
  | [] =>
      gdo base_stmt <-
        transl_cfg_node_structured
          cfg
          cf_lbl_ident
          entry_uid
          (next_in_order entry_uid ordered_nodes)
          context_labels
          r_ty;
      let selector :=
        S_match_int
          (Etempvar cf_lbl_ident bbuid_ty)
          (selector_cases entry_uid ordered_nodes)
      in
      ret (S_sequence selector base_stmt)
  | y_n :: ys =>
      gdo inner <- nodeWithin cfg cf_lbl_ident r_ty ordered_nodes entry_uid ys (y_n :: context_labels);
      gdo y_stmt <-
        transl_cfg_node_structured
          cfg
          cf_lbl_ident
          y_n
          (next_in_order y_n ordered_nodes)
          context_labels
          r_ty;
      ret (S_sequence (S_block (Some (encode_block_label y_n)) inner) y_stmt)
  end.

Definition doTree
  (cfg: ClightCFG)
  (cf_lbl_ident: bb_uid)
  (r_ty: type)
  (ordered_nodes: list bb_uid)
  : SimplExpr.mon rstatement :=
  let entry_uid := cfg.(entry) in
  let rest_nodes :=
    filter
      (fun n => negb (Pos.eqb n entry_uid))
      ordered_nodes
  in
  let follows_desc := rev rest_nodes in
  nodeWithin cfg cf_lbl_ident r_ty (entry_uid :: rest_nodes) entry_uid follows_desc [].

Fixpoint transl_cfg_to_rustlight_sl
  (cfg: ClightCFG) (cf_lbl_ident: bb_uid) (maybe_dflt: option rstatement) (sl: switch_list)
  : SimplExpr.mon labeled_rstatements :=
  match sl with
  | SLnil s' =>
      ret
      (match maybe_dflt with
      | None =>
          let final_stmt := LSnil (gen_goto_next_bb cf_lbl_ident s') in
          final_stmt
      | Some dflt_stmt =>
          LSnil dflt_stmt
      end)
  | SLcons maybe_int b sl' =>
      match maybe_int with
      | None =>
          let final_stmt := gen_goto_next_bb cf_lbl_ident b in
          transl_cfg_to_rustlight_sl cfg cf_lbl_ident (Some final_stmt) sl'
      | Some _ =>
        gdo tr_sl' <- transl_cfg_to_rustlight_sl cfg cf_lbl_ident maybe_dflt sl';
        ret (LScons maybe_int (gen_goto_next_bb cf_lbl_ident b) tr_sl')
      end
  end.


Definition transl_cfg_to_rustlight_aux
  (cfg: ClightCFG) (cf_lbl_ident: bb_uid) (cur_node: bb_uid) (r_ty: type)
  : SimplExpr.mon rstatement :=
  gdo block <- get_bb cfg cur_node;
  match block with
  | bb insts edge => (
      gdo transl_insts <- transl_clightcfg_instructions insts;
      gdo transl_edge <-
      match edge with
      | direct nextbb =>
          let rs := gen_goto_next_bb cf_lbl_ident nextbb in
          ret rs
      | conditional cexp b_true b_false =>
          let r_b_true := gen_goto_next_bb cf_lbl_ident b_true in
          let r_b_false := gen_goto_next_bb cf_lbl_ident b_false in
          gdo r_cexp <- transl_syntax_expr cexp;
          let rs := S_if_then_else r_cexp r_b_true r_b_false in
          ret rs
      | terminate maybe_exp =>
          (* There's three options *)
          (* - return something*)
          (* - artificially inserted return by cfg translation that returns nothing (needs to be turned into a skip)*)
          (* - actually returning nothing *)
          match maybe_exp with
          | Some exp =>
              gdo e <- transl_syntax_expr exp;
              ret (S_return (Some(e, r_typeof e)))
          | None => (
              (* TODO will also need to pass main type in because section 5.1.2.2.3 *)
              ret (
                match r_ty with
                | Tvoid => S_return None
                | _ => S_skip
                end
              ))
          end
      | switch cexp sl =>
        gdo lrstmts <- transl_cfg_to_rustlight_sl cfg cf_lbl_ident None sl;
        gdo tr_exp <- transl_syntax_expr cexp;
        ret (S_match_int tr_exp lrstmts)
      | stub => SimplExpr.error(Errors.msg "stub edge encountered")
      end;
      ret (S_sequence transl_insts transl_edge)
  )
  end.

Fixpoint transl_cfg_nodes_to_rustlight (cfg: ClightCFG) (cf_lbl_ident: bb_uid) (nodes : list bb_uid) (r_ty: type): SimplExpr.mon labeled_rstatements :=
  match nodes with
  | n :: nodes' => (
      gdo r_block <- transl_cfg_to_rustlight_aux cfg cf_lbl_ident n r_ty;
      gdo rest <- transl_cfg_nodes_to_rustlight cfg cf_lbl_ident nodes' r_ty;
      ret (LScons (Some (Z.pos n)) r_block rest)
  )
  | nil =>
      (* NOTE it would be nice to panic here, but I guess an infinite loop will do *)
      (* shouldn't be possible to end up in an unknown block anyway *)
      ret (LSnil S_skip)
  end.

Definition transl_cfg_to_rustlight_dispatcher (cfg: ClightCFG) (r_ty: type) : SimplExpr.mon rstatement :=
  gdo cf_lbl_ident <- SimplExpr.gensym bbuid_ty;
  let entry_uid := cfg.(entry) in
  let s_stmt := S_set cf_lbl_ident (bb_to_rexpr entry_uid) in
  let nodes := cfg.(ClightCFG.node_set) in
  (* map transl_cfg_to_rustlight_aux over cfg nodes *)
  (* each node becomes a switch *)
  (*transl_cfg_to_rustlight_aux cfg cfg.(entry) entry_uid.*)
  gdo r_list <- transl_cfg_nodes_to_rustlight cfg cf_lbl_ident (BBSet.elements nodes) r_ty;
  let m_stmt := S_match_int (Etempvar cf_lbl_ident bbuid_ty) r_list in
  let l_stmt := S_loop (Some (encode_control_label cf_lbl_ident)) m_stmt S_skip in
  let seq_stmt := S_sequence s_stmt l_stmt in
  ret seq_stmt.

Definition transl_cfg_to_rustlight (cfg: ClightCFG) (r_ty: type) : SimplExpr.mon rstatement :=
  gdo meta <- build_structured_metadata cfg;
  let fuel := structured_translation_fuel meta in
  doTree_nodisp fuel meta cfg r_ty meta.(sm_dom_tree) empty_context.

Print calling_convention.
Print r_calling_convention.

Definition gen_r_cc (cc: calling_convention) : res (r_calling_convention) :=
  match cc.(AST.cc_vararg) with
  | Some _n => Error(msg "Variadics are currently unsupported when converting to rust")
  | None => OK(mkcallconv (AST.cc_structret cc))
  end.

Definition transl_internal_function_to_rustlight (c_fn: ClightCFG.function) (glob_syms: list ident) : Errors.res r_function :=
  let generator := reconstruct_generator c_fn.(ClightCFG.fn_temps) in
  match transl_cfg_to_rustlight (fst c_fn.(ClightCFG.fn_body)) c_fn.(ClightCFG.fn_return) generator with
    | SimplExpr.Res r_body r_g i  =>
      do rcc <- gen_r_cc c_fn.(ClightCFG.fn_callconv);

      let tmp_vars := r_g.(SimplExpr.gen_trail) in
      let in_scope_symbols := (map fst c_fn.(ClightCFG.fn_vars)) ++ (map fst c_fn.(ClightCFG.fn_params)) ++ (map fst tmp_vars) ++ glob_syms in

      (* TODO this does NOT handle global symbols. I need to worry about those by (1) propagating their type and (2) including them here. .*)
      (* name is not sufficient*)
      let in_scope_symbols_tree :=
        fold_left (fun
          (acc : PositiveSet.t) (elt: ident) => PositiveSet.add elt acc)
          in_scope_symbols (PositiveSet.empty) in

      let fn_temps := r_g.(SimplExpr.gen_trail) in
      let fn_vars := c_fn.(ClightCFG.fn_vars) in
      let fn_return := c_fn.(ClightCFG.fn_return) in
      let fn_params := c_fn.(ClightCFG.fn_params) in

      let import_types := walk_r_fn_for_composite_types fn_return fn_params fn_vars fn_temps r_body in

      Errors.OK(
      {|
        fn_return := fn_return;
        (* TODO this should be easy but need to make a function*)
        fn_callconv := rcc;
        fn_params := fn_params;
        fn_vars := c_fn.(ClightCFG.fn_vars);
        fn_temps := fn_temps;
        fn_body := r_body;
        (* TODO should be doing this in a separate step *)
        (* NOTE: it doesn't matter when we do this because we only add local variables*)
        fn_imports := (walk_r_body_for_symbols in_scope_symbols_tree r_body);
        fn_ty_imports := import_types;
        fn_is_safe := false;
      |})
    | SimplExpr.Err msg  => Errors.Error(msg)
  end.

Definition transl_fundef_r
  (glob_syms: list ident)
  (id: ident)
  (fn : clightcfg_fundef) : Errors.res r_fundef :=
  match fn with
    | Ctypes.Internal f =>
        do r_f <- transl_internal_function_to_rustlight f glob_syms;
        OK(Ctypes.Internal r_f)
    | Ctypes.External a b c d => OK(Ctypes.External a b c d)
  end.

Definition transl_globvar (id: ident) (ty: type) := OK ty.

Locate globdef.

Definition get_glob_syms (cfg: clightcfg_program) : list ident :=
  (* symbols that we know to be in scope already *)
    map fst (filter (fun (prog_symbols: (_ * globdef (Ctypes.fundef ClightCFG.function) type)) =>
       match (snd prog_symbols) with
       | Gfun (Ctypes.Internal _) => true
       | Gvar v =>
           match AST.gvar_init v with
           | nil => false
           | _ => true
           end
       | _ => false
       end)
     cfg.(Ctypes.prog_defs)).
Print r_function.

Definition transl_program (cfg: clightcfg_program) : res (r_program)
  :=
  (* TODO have to do this at the end (final pass or sth) and not here *)
  let global_symbols := get_glob_syms cfg in
  do translated_fns <-
    AST.transf_globdefs
      (transl_fundef_r global_symbols)
      transl_globvar
      cfg.(prog_defs);

  (* TODO the main renaming should be a separate function or separate pass or something *)
  let r_prog : r_program :=
    {|
      (* PUBLIC only fns *)
      Ctypes.prog_defs := translated_fns;
      Ctypes.prog_public := cfg.(prog_public);
      Ctypes.prog_main := cfg.(prog_main);
      Ctypes.prog_types := cfg.(prog_types);
      Ctypes.prog_comp_env := cfg.(prog_comp_env);
      Ctypes.prog_comp_env_eq := cfg.(prog_comp_env_eq);
    |} in
  OK(r_prog).

(* ============================================================================= *)
(* CNS IMPLEMENTATION - Controlled Node Splitting Algorithm                     *)
(* Implementation of algorithm from Janssen & Corporaal (1997)                  *)
(* "Making Graphs Reducible with Controlled Node Splitting"                    *)
(* ============================================================================= *)

(* NOTE: The basic graph analysis functions (get_successors, compute_predecessors, *)
(* compute_dominators, find_sccs) are now in ClightCFG.v and can be imported.     *)

(* ============================================================================= *)
(* Phase 1 Complete - Basic graph analysis available from ClightCFG.v:          *)
(*   - get_edge_successors, get_successors                                       *)
(*   - compute_predecessors, get_predecessors                                    *)
(*   - compute_dominators, immediate_dominator, dominates                        *)
(*   - TarjanState, find_sccs, nodes_in_same_loop                               *)
(* ============================================================================= *)
