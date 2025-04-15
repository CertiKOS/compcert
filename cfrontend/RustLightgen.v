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

Definition bbuid_ty : type := Ctypes.Tint I32 Unsigned noattr.

Definition bb_to_rexpr (block_id: bb_uid): rexpr :=
  Econst_int (Int.repr (Z.pos block_id)) bbuid_ty.

Definition get_bb (cfg: ClightCFG) (block_uid: bb_uid): mon BasicBlock :=
  match BBMap.find block_uid (cfg.(ClightCFG.map)) with
  | Some block => ret block
  | None => error(Errors.msg "BB missing from ndoe when viewing edge")
  end.

Definition gen_goto_next_bb
  (cf_lbl_ident: bb_uid) (goto_id: bb_uid) : rstatement :=
  let set_stmt := S_set cf_lbl_ident (bb_to_rexpr goto_id) in
  (* NOTE probably unnecessary in most cases. I could remove it. *)
  let continue_stmt := S_continue None in
  S_sequence set_stmt continue_stmt.

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

Definition transl_cfg_to_rustlight (cfg: ClightCFG) (r_ty: type) : SimplExpr.mon rstatement :=
  gdo cf_lbl_ident <- SimplExpr.gensym bbuid_ty;
  let entry_uid := cfg.(entry) in
  let s_stmt := S_set cf_lbl_ident (bb_to_rexpr entry_uid) in
  let nodes := cfg.(ClightCFG.node_set) in
  (* map transl_cfg_to_rustlight_aux over cfg nodes *)
  (* each node becomes a switch *)
  (*transl_cfg_to_rustlight_aux cfg cfg.(entry) entry_uid.*)
  gdo r_list <- transl_cfg_nodes_to_rustlight cfg cf_lbl_ident (BBSet.elements nodes) r_ty;
  let m_stmt := S_match_int (Etempvar cf_lbl_ident bbuid_ty) r_list in
  let l_stmt := S_loop None m_stmt S_skip in
  let seq_stmt := S_sequence s_stmt l_stmt in
  ret seq_stmt.

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

Definition get_glob_syms (cfg: clightcfg_program) : list ident :=
  (* symbols that we know to be in scope already *)
    map fst (filter (fun (prog_symbols: (_ * globdef (Ctypes.fundef ClightCFG.function) type)) =>
       match (snd prog_symbols) with
       | Gfun (Ctypes.Internal _) => true
       | Gvar v => true
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
