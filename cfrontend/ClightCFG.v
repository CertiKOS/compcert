Require Import ZArith.
Require Import Coq.Strings.String.
Require Import Ctypes.
Require Clight.
Require Import AST.

Notation "'TODO'" := (ltac:(fail "TODO: implement this")) (at level 0).

(* Open Scope list_scope. *)
Import List.ListNotations.
Print list.
Locate eqb_eq.

(* Require Import Ctypes. *)
(* Require Import Floats. *)
(* Require Import Maps. *)
(* Require Import Axioms Coqlib. *)
(* Require Import Values. *)
(* Require Import Integers. *)
(* Require Import AST. *)
(* brings in do notation on errors *)
(* Require Import Errors. *)
(* Require Import Cop. *)
(* Require Import Memory. *)
(* Require Import Globalenvs. *)
(* Require Import Memory. *)
(* Require SimplExpr. *)
(* Require Clight. *)
Require Import FSets.   (* Efficient functional sets *)

(* TODO I'm not sure if it's worth it to operate on a monad *)
(*      could add the state to the cfg, and handle errors using Errors.res *)

(* for the CFG, this marks the next node *)
Definition bb_uid := positive.
Print positive.

Locate ident.

Require Import Axioms Coqlib Integers ZArith Values.
Locate FSets.FSetInterface.S.

Require Import Coq.FSets.FMapList.
Locate OrderedTypeEx.
Require Import Coq.Structures.OrderedTypeEx.  (* For positive_as_OT *)
(* https://coq.inria.fr/doc/v8.9/stdlib/Coq.Structures.OrderedTypeEx.html *)
Module BBMap := Coq.FSets.FMapList.Make(Positive_as_OT).
Locate FSetInterface.S.

Print Clight.label.
Print ident.

Module LBLMap := Coq.FSets.FMapList.Make(Positive_as_OT).

(* set of bb_uids *)
Module BBSet <: FSets.FSetInterface.S := FSets.FSetPositive.PositiveSet.

(* Helper function to get successors of a node from its edge *)
Definition get_edge_successors (edge: BBEdge) : list bb_uid :=
  match edge with
  | direct uid => [uid]
  | conditional _ uid1 uid2 => [uid1; uid2]
  | switch _ sl =>
      let fix get_switch_targets (s: switch_list) : list bb_uid :=
        match s with
        | SLnil uid => [uid]
        | SLcons _ uid rest => uid :: get_switch_targets rest
        end
      in get_switch_targets sl
  | terminate _ => []
  | stub => []
  end.

(* Get all successors of a basic block *)
Definition get_successors (cfg: ClightCFG) (uid: bb_uid) : list bb_uid :=
  match BBMap.find uid (map cfg) with
  | None => []
  | Some (bb _ edge) => get_edge_successors edge
  end.

(* Build predecessor map: for each node, list of nodes that point to it *)
Definition compute_predecessors (cfg: ClightCFG) : BBMap.t (list bb_uid) :=
  BBSet.fold
    (fun node acc =>
      let succs := get_successors cfg node in
      List.fold_left
        (fun acc' succ =>
          let existing := match BBMap.find succ acc' with
                         | None => []
                         | Some preds => preds
                         end in
          BBMap.add succ (node :: existing) acc')
        succs
        acc)
    (node_set cfg)
    (BBMap.empty (list bb_uid)).

(* Get predecessors of a node *)
Definition get_predecessors (pred_map: BBMap.t (list bb_uid)) (uid: bb_uid) : list bb_uid :=
  match BBMap.find uid pred_map with
  | None => []
  | Some preds => preds
  end.

(* Check if a node is in a set *)
Definition uid_in_set (uid: bb_uid) (s: BBSet.t) : bool :=
  BBSet.mem uid s.

(* Compute dominator sets using iterative dataflow *)
(* Dom(n) = {n} ∪ (∩ Dom(p) for all predecessors p of n) *)
(* For entry node: Dom(entry) = {entry} *)
Fixpoint compute_dominators_fixpoint
  (cfg: ClightCFG)
  (pred_map: BBMap.t (list bb_uid))
  (dom_map: BBMap.t BBSet.t)  (* Current dominator sets *)
  (fuel: nat)
  : BBMap.t BBSet.t :=
  match fuel with
  | O => dom_map  (* Ran out of fuel, return current state *)
  | S fuel' =>
      let (new_dom_map, changed) :=
        BBSet.fold
          (fun node (acc_pair: BBMap.t BBSet.t * bool) =>
            let (acc, has_changed) := acc_pair in
            if Pos.eqb node (entry cfg) then
              (* Entry node dominates only itself *)
              (acc, has_changed)
            else
              let preds := get_predecessors pred_map node in
              let new_dom :=
                match preds with
                | [] => BBSet.singleton node  (* No predecessors, only self *)
                | p :: rest =>
                    (* Start with dominators of first predecessor *)
                    let init_dom := match BBMap.find p acc with
                                   | None => BBSet.empty
                                   | Some d => d
                                   end in
                    (* Intersect with dominators of remaining predecessors *)
                    let dom_inter := List.fold_left
                      (fun d_acc pred =>
                        match BBMap.find pred acc with
                        | None => BBSet.empty
                        | Some pred_dom => BBSet.inter d_acc pred_dom
                        end)
                      rest
                      init_dom in
                    (* Add node itself *)
                    BBSet.add node dom_inter
                end in
              let old_dom := match BBMap.find node acc with
                            | None => BBSet.empty
                            | Some d => d
                            end in
              (* Check if changed *)
              if BBSet.equal new_dom old_dom then
                (acc, has_changed)
              else
                (BBMap.add node new_dom acc, true))
          (node_set cfg)
          (dom_map, false) in
      if changed then
        compute_dominators_fixpoint cfg pred_map new_dom_map fuel'
      else
        new_dom_map
  end.

(* Initialize dominator map: entry dominates only itself, others dominate all *)
Definition init_dominator_map (cfg: ClightCFG) : BBMap.t BBSet.t :=
  let all_nodes := node_set cfg in
  BBSet.fold
    (fun node acc =>
      if Pos.eqb node (entry cfg) then
        BBMap.add node (BBSet.singleton node) acc
      else
        BBMap.add node all_nodes acc)
    all_nodes
    (BBMap.empty BBSet.t).

(* Main entry point for computing dominators *)
Definition compute_dominators (cfg: ClightCFG) : BBMap.t BBSet.t :=
  let pred_map := compute_predecessors cfg in
  let init_dom := init_dominator_map cfg in
  compute_dominators_fixpoint cfg pred_map init_dom 100.

(* Get immediate dominator of a node *)
(* ID(n) = the dominator of n that is dominated by all other dominators of n *)
Definition immediate_dominator
  (dom_map: BBMap.t BBSet.t)
  (entry: bb_uid)
  (n: bb_uid)
  : option bb_uid :=
  match BBMap.find n dom_map with
  | None => None
  | Some doms =>
      (* Remove n itself from its dominators *)
      let doms_without_n := BBSet.remove n doms in
      (* Entry has no immediate dominator *)
      if Pos.eqb n entry then None
      else if BBSet.is_empty doms_without_n then None
      else
        (* Find the dominator that is dominated by no other dominator of n *)
        (* This is the one closest to n in the dominator tree *)
        let candidates := BBSet.elements doms_without_n in
        let rec find_idom (cands: list bb_uid) : option bb_uid :=
          match cands with
          | [] => None
          | [single] => Some single
          | c :: rest =>
              (* Check if c is dominated by any other dominator *)
              let is_idom := List.forallb
                (fun other =>
                  if Pos.eqb c other then true
                  else
                    (* c is idom if other doesn't dominate c, or c dominates other *)
                    match BBMap.find c dom_map with
                    | None => true
                    | Some c_doms => negb (BBSet.mem other c_doms)
                    end)
                rest in
              if is_idom then Some c
              else find_idom rest
          end in
        find_idom candidates
  end.

(* Check if node u dominates node v *)
Definition dominates (dom_map: BBMap.t BBSet.t) (u v: bb_uid) : bool :=
  match BBMap.find v dom_map with
  | None => false
  | Some doms => BBSet.mem u doms
  end.

(* ============================================================================= *)
(* SCC Detection - Tarjan's Algorithm (Phase 1.3)                               *)
(* ============================================================================= *)

(* State for Tarjan's SCC algorithm *)
Record TarjanState : Type := mkTarjanState {
  (* Index counter *)
  t_index: nat;
  (* Stack of nodes *)
  t_stack: list bb_uid;
  (* Nodes currently on stack *)
  t_on_stack: BBSet.t;
  (* Index of each node (when first visited) *)
  t_indices: BBMap.t nat;
  (* Lowlink value of each node *)
  t_lowlinks: BBMap.t nat;
  (* Discovered SCCs *)
  t_sccs: list BBSet.t;
}.

Definition init_tarjan_state : TarjanState :=
  mkTarjanState 0 [] BBSet.empty (BBMap.empty nat) (BBMap.empty nat) [].

(* Helper: get index of node, returns None if not yet visited *)
Definition get_index (state: TarjanState) (n: bb_uid) : option nat :=
  BBMap.find n (t_indices state).

(* Helper: get lowlink of node *)
Definition get_lowlink (state: TarjanState) (n: bb_uid) : option nat :=
  BBMap.find n (t_lowlinks state).

(* Helper: set index and lowlink for node *)
Definition set_index_lowlink (state: TarjanState) (n: bb_uid) (idx: nat) : TarjanState :=
  mkTarjanState
    (S idx)
    (n :: t_stack state)
    (BBSet.add n (t_on_stack state))
    (BBMap.add n idx (t_indices state))
    (BBMap.add n idx (t_lowlinks state))
    (t_sccs state).

(* Helper: update lowlink *)
Definition update_lowlink (state: TarjanState) (n: bb_uid) (new_low: nat) : TarjanState :=
  mkTarjanState
    (t_index state)
    (t_stack state)
    (t_on_stack state)
    (t_indices state)
    (BBMap.add n new_low (t_lowlinks state))
    (t_sccs state).

(* Helper: pop SCC from stack *)
Fixpoint pop_scc_from_stack
  (stack: list bb_uid)
  (on_stack: BBSet.t)
  (root: bb_uid)
  (acc: BBSet.t)
  : (BBSet.t * list bb_uid * BBSet.t) :=
  match stack with
  | [] => (acc, [], on_stack)
  | w :: rest =>
      let new_acc := BBSet.add w acc in
      let new_on_stack := BBSet.remove w on_stack in
      if Pos.eqb w root then
        (new_acc, rest, new_on_stack)
      else
        pop_scc_from_stack rest new_on_stack root new_acc
  end.

(* Tarjan's strongconnect procedure *)
Fixpoint tarjan_strongconnect
  (cfg: ClightCFG)
  (v: bb_uid)
  (state: TarjanState)
  (fuel: nat)
  : TarjanState :=
  match fuel with
  | O => state
  | S fuel' =>
      (* Set index and lowlink for v *)
      let state1 := set_index_lowlink state v (t_index state) in

      (* Process all successors *)
      let succs := get_successors cfg v in
      let state2 := List.fold_left
        (fun st w =>
          match get_index st w with
          | None =>
              (* Successor w has not been visited; recurse *)
              let st' := tarjan_strongconnect cfg w st fuel' in
              (* Update v's lowlink *)
              match get_lowlink st' v, get_lowlink st' w with
              | Some v_low, Some w_low =>
                  if Nat.ltb w_low v_low then
                    update_lowlink st' v w_low
                  else
                    st'
              | _, _ => st'
              end
          | Some _ =>
              (* Successor w has been visited *)
              if BBSet.mem w (t_on_stack st) then
                (* w is on stack, part of current SCC *)
                match get_lowlink st v, get_index st w with
                | Some v_low, Some w_idx =>
                    if Nat.ltb w_idx v_low then
                      update_lowlink st v w_idx
                    else
                      st
                | _, _ => st
                end
              else
                st
          end)
        succs
        state1 in

      (* If v is a root node, pop the stack and create SCC *)
      match get_lowlink state2 v, get_index state2 v with
      | Some v_low, Some v_idx =>
          if Nat.eqb v_low v_idx then
            (* v is root of SCC *)
            let (scc, new_stack, new_on_stack) :=
              pop_scc_from_stack (t_stack state2) (t_on_stack state2) v BBSet.empty in
            mkTarjanState
              (t_index state2)
              new_stack
              new_on_stack
              (t_indices state2)
              (t_lowlinks state2)
              (scc :: t_sccs state2)
          else
            state2
      | _, _ => state2
      end
  end.

(* Main SCC finder *)
Definition find_sccs (cfg: ClightCFG) : list BBSet.t :=
  let nodes := BBSet.elements (node_set cfg) in
  let final_state := List.fold_left
    (fun state v =>
      match get_index state v with
      | None => tarjan_strongconnect cfg v state 100
      | Some _ => state
      end)
    nodes
    init_tarjan_state in
  t_sccs final_state.

(* Check if two nodes are in the same SCC (loop) *)
Definition nodes_in_same_loop (sccs: list BBSet.t) (u v: bb_uid) : bool :=
  List.existsb
    (fun scc =>
      andb (BBSet.mem u scc) (BBSet.mem v scc))
    sccs.



Inductive Instruction :=
  | i_skip : Instruction
  | i_assign : Clight.expr -> Clight.expr -> Instruction
  | i_set : ident -> Clight.expr -> Instruction
  | i_call : option ident -> Clight.expr -> list Clight.expr -> Instruction
  | i_builtin: option ident -> external_function -> typelist -> list Clight.expr -> Instruction
.

Inductive BBEdge :=
  | direct: bb_uid -> BBEdge
  (* cond -> true -> false -> out *)
  | conditional: Clight.expr -> bb_uid -> bb_uid -> BBEdge
  | switch: Clight.expr -> switch_list -> BBEdge
  | terminate: option Clight.expr ->  BBEdge
  (* temporary. Used only during translation*)
  | stub: BBEdge
  with switch_list : Type :=
    (* base case: point to the next block*)
    | SLnil : bb_uid -> switch_list
    | SLcons : option Z -> bb_uid -> switch_list -> switch_list.

Print option.

Inductive BasicBlock :=
  | bb : list Instruction -> BBEdge -> BasicBlock.

Record ClightCFG : Type
  := mkCFG {
         (* set of bb_uids of nodes in the graph *)
         node_set: BBSet.t;
         (* the entry node bb_uid *)
         entry: bb_uid;
         (* bb_uid -> BasicBlock map *)
         map: BBMap.t BasicBlock;
         (* label -> bb_uid that it resolves to *)
         lbl_map: LBLMap.t bb_uid;
}.

(* need two things: list of (lbl, bbuid), map lbl -> uid*)

(* Record LblMapping { *)
(*   (* label -> unfinished nodes that need the label to be finished *) *)
(*   lbls: BBMap.t *)

(* } *)

Print BBMap.
Print option.

Record function : Type := mkfunction {
  fn_return: type;
  fn_callconv: calling_convention;
  fn_params: list (ident * type);
  fn_vars: list (ident * type);
  fn_temps: list (ident * type);
  fn_body: (ClightCFG * list (bb_uid * bb_uid));
}.

Definition clightcfg_program := Ctypes.program function.
Definition clightcfg_fundef := Ctypes.fundef function.

Record bb_generator : Type := mkgenerator {
  next_bb_uid: bb_uid;
}.

Locate Ple.

Inductive result (A: Type) (g: bb_generator): Type :=
  | ERR: Errors.errmsg -> result A g
  | OK: A -> forall (g': bb_generator), Coqlib.Ple (next_bb_uid g) (next_bb_uid g') -> result A g.

Arguments OK [A g].
Arguments ERR [A g].

Definition mon (A: Type) := forall (g: bb_generator), result A g.

Definition ret {A: Type} (x: A) : mon A :=
  fun g => OK x g (Coqlib.Ple_refl (next_bb_uid g)).

Definition error {A: Type} (msg: Errors.errmsg) : mon A :=
  fun g => ERR msg.

Definition bind {A B: Type} (x: mon A) (f: A -> mon B) : mon B :=
  fun g =>
    match x g with
      | ERR msg => ERR msg
      | OK a g' i =>
          match f a g' with
          | ERR msg => ERR msg
          | OK b g'' i' => OK b g'' (Coqlib.Ple_trans _ _ _ i i')
      end
    end.

Definition bind2 {A B C: Type} (x: mon (A * B)) (f: A -> B -> mon C) : mon C :=
  bind x (fun p => f (fst p) (snd p)).

(* Definition bind3 {A B C D: Type} (x: mon (A * B * C)) (f: A -> B -> C -> mon D) : mon D := *)
(*   bind x (fun p => f (fst (fst p)) (snd (fst p)) (snd p)). *)
Definition bind3 {A B C D: Type} (x: mon (A * B * C)) (f: A -> B -> C -> mon D) : mon D :=
  bind x (fun '(a, b, c) => f a b c).

Declare Scope cfg_monad_scope.
Notation "'do' X <- A ; B" := (bind A (fun X => B))
   (at level 200, X ident, A at level 100, B at level 200)
   : cfg_monad_scope.
Notation "'do' ( X , Y ) <- A ; B" := (bind2 A (fun X Y => B))
   (at level 200, X ident, Y ident, A at level 100, B at level 200)
   : cfg_monad_scope.

Notation "'do' ( X , Y , Z ) <- A ; B" := (bind3 A (fun X Y Z => B))
   (at level 200, X ident, Y ident, Z ident, A at level 100, B at level 200)
   : cfg_monad_scope.

Local Open Scope cfg_monad_scope.

Parameter first_unused_bb_uid: unit -> bb_uid.

Definition initial_bb_generator (x: unit) : bb_generator :=
  mkgenerator (first_unused_bb_uid x).

Definition gen_bb_uid: mon bb_uid :=
  fun (g: bb_generator) =>
    OK (next_bb_uid g)
        (mkgenerator
          (Pos.succ (next_bb_uid g)))
        (Coqlib.Ple_succ (next_bb_uid g)).

(* need to operate under monad that can: *)
(* - produce error *)
(* - produce block id *)

Print BBMap.

(* Definition finish_bb (cfg: ClightCFG) (cur_bb_uid: bb_uid) (cur_bb: BasicBlock) : mon ClightCFG := *)
(*   let new_lbls := BBSet.add cur_bb_uid (cfg.(ClightCFG.lbls)) in *)
(*   let new_map := BBMap.add cur_bb_uid cur_bb (cfg.(ClightCFG.map)) in *)
(*   ret *)
(*     {| *)
(*       lbls := new_lbls; *)
(*       entry := cfg.(entry); *)
(*       map := new_map; *)
(*     |}. *)

Definition add_inst_to_bb (cfg: ClightCFG) (target_bb_uid: bb_uid) (inst: Instruction)
  : mon ClightCFG
  :=
  (* get node out of cfg *)
  do target_bb <-
  (match BBMap.find target_bb_uid (map cfg) with
  | Some ele => ret ele
  | None => error(Errors.msg "BB missing from node when setting inst in bb")
  end);

  (* match on node to get instructions *)
  match target_bb with
  | bb insts edge => (

    (* create new node with additional instruction *)
    let new_bb := bb (inst :: insts) edge in
    let new_map := BBMap.add target_bb_uid new_bb (map cfg) in
    ret
    {|
      node_set := cfg.(node_set);
      entry := (entry cfg);
      map := new_map;
      lbl_map := cfg.(lbl_map)
    |}
  )
  end
.

(* TODO probably an easy way to merge with add_inst_to_bb *)
Definition set_edge_in_bb (cfg: ClightCFG) (target_bb_uid: bb_uid) (edge: BBEdge)
  : mon ClightCFG
  :=
  (* get node out of cfg *)
  do (target_bb, new_map) <-
  (match BBMap.find target_bb_uid (map cfg) with
  | Some ele =>
      let new_map := BBMap.remove target_bb_uid cfg.(map) in
      ret (ele, new_map)
  | None => error(Errors.msg "BB missing from node when setting edge")
  end);

  (* match on node to get instructions *)
  match target_bb with
  | bb insts old_edge => (

    (* create new node with additional instruction *)
    let new_bb := bb (List.rev insts) edge in
    let new_new_map := BBMap.add target_bb_uid new_bb new_map in
    ret
    {|
      node_set := cfg.(node_set);
      entry := (entry cfg);
      map := new_new_map;
      lbl_map := cfg.(lbl_map)
    |}
  )
  end
.

(* note I could probably do this with a fold but working in the monad is somewhat annoying *)
Fixpoint apply_edge_to_all_bbs
  (cfg: ClightCFG)
  (edge: BBEdge)
  (bbs: list bb_uid)
  : mon ClightCFG
  :=

  match bbs with
  | nil => ret cfg
  | cur_bb_uid :: rest =>
      do new_cfg <- set_edge_in_bb cfg cur_bb_uid edge;
      apply_edge_to_all_bbs new_cfg edge rest
  end
  .



  (* reinsert into cfg *)
  (* return cfg *)


Definition create_new_bb (cfg: ClightCFG) : mon (bb_uid * ClightCFG) :=
  do new_bb_id <- gen_bb_uid;
  let new_bb := bb nil stub in
  let new_map := BBMap.add new_bb_id new_bb (map cfg) in
  let new_node_set := BBSet.add new_bb_id cfg.(node_set) in
  ret(new_bb_id, {|
    node_set := new_node_set;
    entry := (entry cfg);
    map := new_map;
    lbl_map := cfg.(lbl_map)
  |}).


Print BBSet.

Definition bb_is_empty
  (cfg: ClightCFG)
  (target_bb_uid: bb_uid)
  : mon bool
:=
  (* get node out of cfg *)
  do target_bb <-
  (match BBMap.find target_bb_uid (map cfg) with
  | Some ele => ret ele
  | None => error(Errors.msg "BB missing from node UID in ClightCFG")
  end);
  match target_bb with
  | bb insts edge => (
    ret (negb (Nat.ltb 0 (List.length insts)))
  )
  end.

(* converts labeled_statmtents to list *)
(* additionally creates adds in new nodes *)
Fixpoint create_new_bbs_for_switch
  (cfg: ClightCFG)
  (lstmts : Clight.labeled_statements)
  : mon (list bb_uid * ClightCFG) :=
  match lstmts with
  | Clight.LSnil => ret (nil, cfg)
  | Clight.LScons _lbl _stmt lstmts' => (
    do (new_uid, cfg1) <- create_new_bb cfg;
    do (l, cfg2) <- create_new_bbs_for_switch cfg1 lstmts';
    ret (new_uid :: l, cfg2)
  )
  end
  .

(* we have a bunch of bbs with `goto` statements that never *)
(* got finished. So, we finish them up. *)
Fixpoint finish_lbled_nodes (cfg: ClightCFG)
  (* basicblock bb_uid should goto label lbl*)
  (unfinished_goto_nodes: list (Clight.label * bb_uid))
  : mon ClightCFG
  :=
  match unfinished_goto_nodes with
  | nil => ret cfg
  | (lbl, unfinished_node_uid) :: l' => (
    (* get uid unfinished_node should go to from lbl map in cfg *)

    do target_uid <-
      match LBLMap.find lbl (lbl_map cfg) with
      | Some target_uid => ret target_uid
      | None => error(Errors.msg "undefined label in goto statement")
      end;

    (* create edge *)
    let edge := direct target_uid in

    (* insert node with fixed up edge into cfg *)
    do cfg1 <- set_edge_in_bb cfg unfinished_node_uid edge;

    finish_lbled_nodes cfg1 l'
  )
  end.

(* invariants:
  - we greedily fill in edges into the graph
  - bbs that have their edges stubbed out are returned to be resolved by parent.
  - any one call of process_statement_to_cfg can return at MOST one stubbed out bb
  - TODO should enforce this by returning option unfinished
*)

Fixpoint process_statement_to_cfg
  (cfg: ClightCFG)
  (cur_bb_uid: bb_uid)
  (c_stmt: Clight.statement)
  (maybe_continue_uid: option bb_uid)
  (maybe_break_uid: option bb_uid)
  (* bbs that are basically goto lbl.
     - the label denotes which label to goto
     - the bb_uid denotes which bb is unfinished
   *)
  (unfinished_goto_nodes: list (Clight.label * bb_uid))
  {struct c_stmt}
  : mon (ClightCFG * option bb_uid * (list (Clight.label * bb_uid)))
:=
  match c_stmt with
  | Clight.Sbuiltin x ef tyargs bl =>
      let new_inst := i_builtin x ef tyargs bl in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, Some cur_bb_uid, unfinished_goto_nodes)
  | Clight.Scall x name al =>
      let new_inst := i_call x name al in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, Some cur_bb_uid, unfinished_goto_nodes)
  | Clight.Sskip =>
      let new_inst := i_skip in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, Some cur_bb_uid, unfinished_goto_nodes)
  | Clight.Sassign lval rval =>
      let new_inst := i_assign lval rval in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, Some cur_bb_uid, unfinished_goto_nodes)
  | Clight.Sset x exp =>
      let new_inst := i_set x exp in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, Some cur_bb_uid, unfinished_goto_nodes)
  | Clight.Sreturn maybe_expr =>
      let new_edge := terminate maybe_expr in
      do updated_cfg <- set_edge_in_bb cfg cur_bb_uid new_edge;
      ret (updated_cfg, None, unfinished_goto_nodes)
  | Clight.Sifthenelse exp s1 s2 =>
      (* create two branch bbs*)
      do (b1_uid, cfg1) <- create_new_bb cfg;
      do (b2_uid, cfg2) <- create_new_bb cfg1;

      (* finish up current edge *)
      let cur_bb_edge := conditional exp b1_uid b2_uid in
      do cfg3 <- set_edge_in_bb cfg2 cur_bb_uid cur_bb_edge;

      (* process and get back the edges that are "in progress" *)
      do (cfg4, b1_unfinished_edges, ugn1)
         <- process_statement_to_cfg cfg3 b1_uid s1 maybe_continue_uid maybe_break_uid
                                    unfinished_goto_nodes;
      do (cfg5, b2_unfinished_edges, ugn2)
         <- process_statement_to_cfg cfg4 b2_uid s2 maybe_continue_uid maybe_break_uid
                                    ugn1;

      let all_unfinished_edges :=
        match b1_unfinished_edges, b2_unfinished_edges with
        | None, None => nil
        | Some x, None => [x]
        | None, Some y => [y]
        | Some x, Some y => [x ; y]
        end in

      (* note: could just compare to nil *)
      if Nat.ltb 0 (List.length all_unfinished_edges) then

        do (b_join, cfg6) <- create_new_bb cfg5;

        let finishing_edge := direct b_join in
        do cfg7 <- apply_edge_to_all_bbs cfg6 finishing_edge all_unfinished_edges;
        ret (cfg7, Some b_join, ugn2)
      else
        ret (cfg5, None, ugn2)
  | Clight.Sloop ns1 ns2 => (
    (* TODO there is optimization needed here; should NOT always create a new basic block.We can reuse if the previous bb is empty. *)

      do (bb_ns1, cfg1) <-
        (
         do dont_need_new_bb_uid <- bb_is_empty cfg cur_bb_uid;
           match dont_need_new_bb_uid with
           | false =>
             do (loop_header_uid, cfg1) <- create_new_bb cfg;
             let finished_edge := direct loop_header_uid in
             do cfg2 <- set_edge_in_bb cfg1 cur_bb_uid finished_edge;
             ret (loop_header_uid, cfg2)
           | true =>
             ret (cur_bb_uid, cfg)
           end
        );

      (* create the exit bb *)
      do (bb_exit, cfg3) <- create_new_bb cfg1;

      (* create the s2 bb *)
      do (bb_ns2, cfg4) <- create_new_bb cfg3;

      do (cfg5, unfinished_bbs_ns1, ugn1)
         <- process_statement_to_cfg cfg4 bb_ns1 ns1 (Some bb_ns2) (Some bb_exit)
                                    unfinished_goto_nodes;

      let unfinished_bbs_ns1_list :=
        match unfinished_bbs_ns1 with
        | None => []
        | Some x => [x]
        end in

      (* ns1 -> ns2 *)
      let s1_edge := direct bb_ns2 in

      do cfg6 <- apply_edge_to_all_bbs cfg5 s1_edge unfinished_bbs_ns1_list;


      do (cfg7, unfinished_bbs_ns2, ugn2)
         <- process_statement_to_cfg cfg6 bb_ns2 ns2 (Some bb_ns1) (Some bb_exit)
                                    ugn1;

      let s2_edge := direct bb_ns1 in

      let unfinished_bbs_ns2_list :=
        match unfinished_bbs_ns2 with
        | None => []
        | Some x => [x]
        end in


      do cfg8 <- apply_edge_to_all_bbs cfg7 s2_edge unfinished_bbs_ns2_list;

      (* exit is the "next bb" so to speak*)
      ret (cfg8, Some bb_exit, ugn2)
    (* ) *)
  )
  | Clight.Sbreak =>
      match maybe_break_uid with
      | Some break_uid => (
        let break_edge := direct break_uid in
        do cfg1 <- set_edge_in_bb cfg cur_bb_uid break_edge;
        ret (cfg1, None, unfinished_goto_nodes)
      )
      | None => error(Errors.msg "Break missing target")
      end
  | Clight.Scontinue =>
      (* ret (cfg, nil) *)
      match maybe_continue_uid with
      | Some continue_uid => (
        let continue_edge := direct continue_uid in
        do cfg1 <- set_edge_in_bb cfg cur_bb_uid continue_edge;
        ret (cfg1, None, unfinished_goto_nodes)
      )
      | None => error(Errors.msg "Continue missing target")
      end
  (* | Clight.Sswitch exp Clight.LSnil => *)
  (*     (* we rely on the fact that exp does not contain side effects *) *)
  (*     (* because if it did it would have been separate out into separate tempvar *) *)
  (*     ret (cfg, [cur_bb_uid]) *)
  (* NOTE: will have to special case this in the rust case statement generation to include a _ => ()*)


  | Clight.Sswitch exp stmts =>

      (* create the new bbs *)
      do (l, cfg1) <- create_new_bbs_for_switch cfg stmts;

      (* where to go after the switch *)
      do (next_bb, cfg2) <- create_new_bb cfg1;


      (* iterate through remaining nodes one by one *)
      (* process them, direct to next node *)

      do (lbls, cfg3, ugn1) <-
           handle_switch_aux cfg2 next_bb maybe_continue_uid (Some next_bb) stmts l
                             unfinished_goto_nodes;

      (* wrap up the current bb *)
      let new_edge := switch exp lbls in

      do cfg4 <- set_edge_in_bb cfg3 cur_bb_uid new_edge;

      ret (cfg4, Some next_bb, ugn1)

  | Clight.Ssequence s1 s2 =>
      do (cfg2, unfinished_nodes, ugn1)
         <- process_statement_to_cfg cfg cur_bb_uid s1
                                    maybe_continue_uid maybe_break_uid unfinished_goto_nodes;
      match unfinished_nodes with
      | None => (
        (* if this is empty, that's ok. We probably returned. But, still need a new node. *)
        do (new_bb, cfg3) <- create_new_bb cfg2;
        (* note: we are *not* making a new bb here. If the control flow ends here, that's okay. *)
        process_statement_to_cfg cfg3 new_bb s2 maybe_continue_uid maybe_break_uid
                                 ugn1
      )
      | Some unfinished_bb_uid => (
        (*if Pos.eqb unfinished_bb_uid cur_bb_uid then*)
        (*  process_statement_to_cfg cfg2 unfinished_bb_uid s2 maybe_continue_uid maybe_break_uid ugn1*)
        (*else*)
        (*do (new_bb, cfg3) <- create_new_bb cfg2;*)

        (*let end_edge := direct new_bb in*)

        (*do cfg4 <- set_edge_in_bb cfg3 unfinished_bb_uid end_edge;*)

        process_statement_to_cfg cfg2 unfinished_bb_uid s2 maybe_continue_uid maybe_break_uid ugn1
      )
      (*| _ => error (Errors.msg "multiple unfinished nodes (impossible)" )*)
      end
  | Clight.Sgoto lbl =>
    (* The basic block ends. We add to the unfinished nodes and fix it up later *)
    let ugn1 := (lbl, cur_bb_uid) :: unfinished_goto_nodes in
    ret (cfg, None, ugn1)
  | Clight.Slabel lbl s => (
    (* check if we need to make a new uid *)
    (* if we do, make it*)
    do dont_need_new_bb_uid <- bb_is_empty cfg cur_bb_uid;
    do (cfg1, lbl_uid) <-
    match dont_need_new_bb_uid with
    | true =>
        ret (cfg, cur_bb_uid)
    | false =>
      do (goto_bb_uid, cfg1) <- create_new_bb cfg;
      let finished_edge := direct goto_bb_uid in
      do cfg2 <- set_edge_in_bb cfg1 cur_bb_uid finished_edge;
      ret (cfg2, goto_bb_uid)
    end;

    (* insert label into label map. If I did this more than once I would
       separate out into auxilary function *)
    let updated_lbl_map := LBLMap.add lbl lbl_uid (lbl_map cfg1) in
    let cfg2 := {|
      (* TODO nuke this field *)
      node_set := cfg1.(node_set);
      entry := cfg1.(entry);
      map := cfg1.(map);
      lbl_map := updated_lbl_map;
    |} in

    do (cfg3, unfinished_nodes, ugn1) <-
         process_statement_to_cfg cfg2 lbl_uid s maybe_continue_uid maybe_break_uid
                                  unfinished_goto_nodes;

    ret (cfg3, unfinished_nodes, ugn1)
  )
  end

(* this does two things: *)
(* - enforce the control flow that we expect (aka fall through behavior) *)
(* - construct a switch list (that we need for the edge)  *)
with handle_switch_aux
  (cfg: ClightCFG)
  (end_uid: bb_uid)
  (maybe_continue_uid: option bb_uid)
  (maybe_break_uid: option bb_uid)
  (l : Clight.labeled_statements)
  (l': list bb_uid)
  (unfinished_goto_nodes: list (Clight.label * bb_uid))
  {struct l}
  : mon (switch_list * ClightCFG * (list (Clight.label * bb_uid)))
  :=
  match l with
  | Clight.LSnil => (
    ret (SLnil end_uid, cfg, unfinished_goto_nodes)
  )
  | Clight.LScons v stmt (Clight.LSnil) => (
    match l' with
    | case_uid :: l'' => (
      do (cfg1, maybe_unfinished_bb, ugn1) <-
           process_statement_to_cfg cfg case_uid stmt maybe_continue_uid maybe_break_uid
                                    unfinished_goto_nodes;
      let sl := SLcons v case_uid (SLnil end_uid) in
      match maybe_unfinished_bb with
      | Some unfinished_bb => (
        let ending_edge := direct end_uid in
        do cfg2 <- set_edge_in_bb cfg1 unfinished_bb ending_edge;
        ret (sl, cfg2, ugn1)
      )
      | None => ret (sl, cfg1, ugn1)
      end
    )
    | nil => error (Errors.msg "ran out of uids (not possible)" )
    end
  )

  | Clight.LScons v stmt ((Clight.LScons v' stmt' stmts'') as the_rest) => (
    match l' with
    | case_uid :: ((case_uid_next :: l'') as the_rest') => (
      do (cfg1, maybe_unfinished_bb, ugn1) <-
           process_statement_to_cfg cfg case_uid stmt maybe_continue_uid maybe_break_uid
                                    unfinished_goto_nodes;

      do (sl, cfg2, ugn2) <-
           handle_switch_aux cfg1 end_uid maybe_continue_uid maybe_break_uid the_rest the_rest'
                             ugn1;

      let sl' := SLcons v case_uid sl in
      match maybe_unfinished_bb with
      | Some unfinished_bb => (
        let ending_edge := direct case_uid_next in
        do cfg3 <- set_edge_in_bb cfg2 unfinished_bb ending_edge;
        ret (sl', cfg3, ugn2)
      )
      | _ => ret (sl', cfg2, ugn2)
      end
    )
    | a :: _b => error (Errors.msg "missing one uid" )
    | nil => error (Errors.msg "missing 2 or more uids" )
    end
  )
  (* | nil => ( *)
  (*   error (Errors.msg "empty switch statement somehow exists" ) *)
  (* ) *)
  (* | (_, case_uid, stmt) :: nil => ( *)
  (*   let ending_edge := direct end_uid in *)
  (*   (* TODO statement needs to be handled *) *)
  (*   do cfg1 <- set_edge_in_bb cfg case_uid ending_edge; *)
  (*   ret cfg1 *)
  (* ) *)
  (* | (case_uid, stmt) :: (case_uid_next, stmt_nxt)  :: l'' => ( *)

  (* | (_, case_uid, stmt) :: (((_, case_uid_next, _)  :: _) as l') => ( *)
  (*   let ending_edge := direct case_uid_next in *)

  (*   (* fallthrough behavior *) *)
  (*   do cfg1 <- set_edge_in_bb cfg case_uid ending_edge; *)

  (*   do (cfg2, unfinished_uid) <- *)
  (*        process_statement_to_cfg cfg1 case_uid stmt maybe_continue_uid maybe_break_uid; *)

  (*   handle_switch_aux cfg1 end_uid maybe_continue_uid maybe_break_uid l' *)
  (* ) *)
  (* | _ => (ret (cfg)) *)
  end.


Print option.


(* TODO need to pass in bool to indicate if this function is main (5.1.2.2.3), because that can implicitly return *)
Definition transl_statement_to_cfg (c_stmt: Clight.statement) (r_type: type) : mon ClightCFG :=
  do entry_node_uid <- gen_bb_uid;

  let init_map := BBMap.add entry_node_uid (bb nil stub) (BBMap.empty BasicBlock) in

  let initial_cfg :=
    {|
      node_set := BBSet.add entry_node_uid BBSet.empty;
      entry := entry_node_uid;
      map := init_map;
      lbl_map := LBLMap.empty bb_uid;
    |} in

  do (cfg, maybe_unfinished_node, unfinished_goto_nodes)
     <- process_statement_to_cfg initial_cfg entry_node_uid c_stmt None None nil;


  (* finish up last edge *)
  do cfg1 <-
    match maybe_unfinished_node with
    | None => ret cfg
    | Some unfinished_node_uid =>
        set_edge_in_bb cfg unfinished_node_uid (terminate None)
    end;

  finish_lbled_nodes cfg1 unfinished_goto_nodes.


Print Clight.function.
Print Errors.Error.

Definition transl_internal_function_to_cfg (c_fn: Clight.function) : Errors.res function :=
  let state := (initial_bb_generator tt) in
  match transl_statement_to_cfg c_fn.(Clight.fn_body) c_fn.(Clight.fn_return) state with
    | OK cfg gen proof  => Errors.OK(
      {|
        fn_return := c_fn.(Clight.fn_return);
        fn_callconv := c_fn.(Clight.fn_callconv);
        fn_params := c_fn.(Clight.fn_params);
        fn_vars := c_fn.(Clight.fn_vars);
        fn_temps := c_fn.(Clight.fn_temps);
        fn_body := (cfg, nil);
      |})
    | ERR(msg) => Errors.Error(msg)
  end.
Close Scope cfg_monad_scope.

Require Import Errors.
Local Open Scope error_monad_scope.

Definition transl_fundef
  (_: ident)
  (fn : Clight.fundef) : Errors.res clightcfg_fundef :=
  match fn with
    | Ctypes.Internal f =>
      do r_f <- transl_internal_function_to_cfg f;
        OK(Ctypes.Internal r_f)
    | Ctypes.External a b c d => OK(Ctypes.External a b c d)
  end.

Definition transl_globvar (id: ident) (ty: type) := OK ty.

Definition transl_program (c_prog: Clight.program) : Errors.res clightcfg_program :=
  do translated_fns <- AST.transf_globdefs
        (transl_fundef)
        transl_globvar
        c_prog.(prog_defs);
  OK {|
    Ctypes.prog_defs := translated_fns;
    Ctypes.prog_public := c_prog.(prog_public);
    Ctypes.prog_main := c_prog.(prog_main);
    Ctypes.prog_types := c_prog.(prog_types);
    Ctypes.prog_comp_env := c_prog.(prog_comp_env);
    Ctypes.prog_comp_env_eq := c_prog.(prog_comp_env_eq);
  |}.
