Require Import ClightCFG.
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

Inductive DominatorSet : Type
  :=
  | entry_node: bb_uid -> DominatorSet
  (* immediate domiantor *)
  (* immediate dominator -> nodes domianting the immediate dominator
     -> dominator set *)
  | immediate_dominator: bb_uid -> DominatorSet -> DominatorSet.

Print ClightCFG.

Inductive Tree (T : Type) : Type :=
  (* element -> children -> Tree *)
  | tree_node (ele: T) (children: list (Tree T)).

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
  tree_node bb_uid cfg.(entry) nil.

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
  let seen_nodes := BBSet.empty in
  let pot := nil in
  let cur_node := cfg.(entry) in

  do (seen_set, pot) <- postorder_traversal_gen_aux num_nodes cfg seen_nodes pot cur_node;

  let rpot := rev pot in

  ret (rpot, gen_bb_map rpot (BBMap.empty positive) 1).


(* NOTE: to translate clight expression: Clight.transl_syntax_expr *)

Print msg.

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


  (* prepend Fail to fixpoint then ltac:(fail "TODO").*)
(* Fixpoint transl_clightcfg_to_rustlight
  (cfg: ClightCFGWithMetadata)
  : mon rstatement
  := ret S_skip
with doTree
. *)
