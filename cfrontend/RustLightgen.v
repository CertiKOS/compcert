Require Import ClightCFG.
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

(* -------------------- END haskell attempt. Will return to this later -----*)

Local Open Scope gensym_monad_scope_2.
Local Open Scope error_monad_scope.

Definition transl_cfg_to_rustlight_aux (
  cfg: ClightCFG) (cur_node: bb_uid)
  (* TODO more metadata will probably go here *)
  : SimplExpr.mon rstatement :=
  SimplExpr.error (msg "unimplemented").

Definition transl_cfg_to_rustlight (cfg: ClightCFG) : SimplExpr.mon rstatement :=
  transl_cfg_to_rustlight_aux cfg cfg.(entry).

Definition gen_r_cc (cc: calling_convention) : res (r_calling_convention) :=
  match cc.(AST.cc_vararg) with
  | Some _n => Error(msg "Variadics are currently unsupported when converting to rust")
  | None => OK(mkcallconv (AST.cc_structret cc))
  end.

Definition transl_internal_function_to_rustlight (c_fn: ClightCFG.function) (glob_syms: list ident) : Errors.res r_function :=
  let generator := reconstruct_generator c_fn.(ClightCFG.fn_temps) in
  match transl_cfg_to_rustlight (fst c_fn.(ClightCFG.fn_body)) generator with
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

      Errors.OK(
      let cc := ClightCFG.fn_callconv c_fn in
      {|
        fn_return := c_fn.(ClightCFG.fn_return);
        (* TODO this should be easy but need to make a function*)
        fn_callconv := rcc;
        fn_params := c_fn.(ClightCFG.fn_params);
        fn_vars := c_fn.(ClightCFG.fn_vars);
        fn_temps := c_fn.(ClightCFG.fn_temps);
        fn_body := r_body;
        fn_imports := (walk_r_body_for_symbols in_scope_symbols_tree r_body);
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

Definition get_glob_syms (cfg: clightcfg_program) : list ident :=
  (* symbols that we know to be in scope already *)
    map fst (filter (fun (prog_symbols: (_ * globdef (Ctypes.fundef ClightCFG.function) type)) =>
       match (snd prog_symbols) with
       | Gfun (Ctypes.Internal _) => true
       | Gvar v => true
       | _ => false
       end)
     cfg.(Ctypes.prog_defs)).

Definition transl_program (cfg: clightcfg_program) : res (r_program)
  :=
  let global_symbols := get_glob_syms cfg in
  do translated_fns <-
    AST.transf_globdefs
      (transl_fundef_r global_symbols)
      transl_globvar
      cfg.(prog_defs);

  (* TODO the main renaming should be a separte function or separate pass or something *)
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
