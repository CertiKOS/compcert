Require Import ZArith.
Require Import Coq.Strings.String.
Require Import Ctypes.
Require Clight.
Require Import AST.

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



Inductive Instruction :=
  | i_skip : Instruction
  | i_assign : Clight.expr -> Clight.expr -> Instruction
  | i_set : ident -> Clight.expr -> Instruction
  | i_call : option ident -> Clight.expr -> list Clight.expr -> Instruction
  | i_builtin: option ident -> external_function -> typelist -> list Clight.expr -> Instruction
.

  (* | Sifthenelse : expr  -> statement -> statement -> statement (**r conditional *) *)
  (* | Sloop: statement -> statement -> statement (**r infinite loop *) *)
  (* | Sbreak : statement                      (**r [break] statement *) *)
  (* | Scontinue : statement                   (**r [continue] statement *) *)
  (* | Sreturn : option expr -> statement      (**r [return] statement *) *)
  (* | Sswitch : expr -> labeled_statements -> statement  (**r [switch] statement *) *)
  (* | Slabel : label -> statement -> statement *)
  (* | Sgoto : label -> statement *)

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
  fn_body: ClightCFG;
}.

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
  | None => error(Errors.msg "BB missing from node")
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
  do target_bb <-
  (match BBMap.find target_bb_uid (map cfg) with
  | Some ele => ret ele
  | None => error(Errors.msg "BB missing from node")
  end);

  (* match on node to get instructions *)
  match target_bb with
  | bb insts old_edge => (

    (* create new node with additional instruction *)
    let new_bb := bb insts edge in
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


(* TODO be careful! What if cur_bb_uid is in next_nodes ?
   aka we get two assignments or something*)
Definition fixup_graph (cfg: ClightCFG) (cur_bb_uid: bb_uid)
                       (* TODO think a bit more about the return type here *)
                       (next_nodes: list (bb_uid * BasicBlock)) : mon (ClightCFG)
  := ret cfg.

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
  | None => error(Errors.msg "BB missing from node")
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
  | Clight.LScons v stmt lstmts' => (
    do (new_uid, cfg1) <- create_new_bb cfg;
    do (l, cfg2) <- create_new_bbs_for_switch cfg1 lstmts';
    ret (new_uid :: l, cfg2)
  )
  end
  .

(* we have a bunch of bbs with `goto` statements that never *)
(* got finished. So, we finish them up. *)
Definition finish_lbled_nodes (cfg: ClightCFG)
  (* basicblock bb_uid should goto label lbl*)
  (unfinished_goto_nodes: list (Clight.label * bb_uid))
  : mon ClightCFG
  :=
  match unfinished_goto_nodes with
  | nil => ret cfg
  | (lbl, unfinished_node_uid) :: l' => (
    (* get node from cfg *)
    (* do unfinished_node <- *)
    (*   match BBMap.find unfinished_node_uid (map cfg) with *)
    (*   | Some unfinished_node => ret unfinished_node *)
    (*   | None => error(Errors.msg "BB in unfinished goto node missing from cfg") *)
    (*   end; *)

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

    ret cfg
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
  (* TODO this needs to change to include unfinished_goto_nodes *)
  : mon (ClightCFG * list bb_uid * (list (Clight.label * bb_uid)))
:=
  match c_stmt with
  | Clight.Sbuiltin x ef tyargs bl =>
      let new_inst := i_builtin x ef tyargs bl in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, [cur_bb_uid], unfinished_goto_nodes)
  | Clight.Scall x name al =>
      let new_inst := i_call x name al in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, [cur_bb_uid], unfinished_goto_nodes)
  | Clight.Sskip =>
      let new_inst := i_skip in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, [cur_bb_uid], unfinished_goto_nodes)
  | Clight.Sassign lval rval =>
      let new_inst := i_assign lval rval in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, [cur_bb_uid], unfinished_goto_nodes)
  | Clight.Sset x exp =>
      let new_inst := i_set x exp in
      do updated_cfg <- add_inst_to_bb cfg cur_bb_uid new_inst;
      ret (updated_cfg, [cur_bb_uid], unfinished_goto_nodes)
  | Clight.Sreturn maybe_expr =>
      let new_edge := terminate maybe_expr in
      do updated_cfg <- set_edge_in_bb cfg cur_bb_uid new_edge;
      ret (updated_cfg, nil, unfinished_goto_nodes)
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
         <- process_statement_to_cfg cfg4 b2_uid s2 maybe_break_uid maybe_break_uid
                                    ugn1;

      let all_unfinished_edges := b1_unfinished_edges ++ b2_unfinished_edges in

      (* note: could just compare to nil *)
      if Nat.ltb 0 (List.length all_unfinished_edges) then

        do (b_join, cfg6) <- create_new_bb cfg5;

        let finishing_edge := direct b_join in
        do cfg7 <- apply_edge_to_all_bbs cfg6 finishing_edge all_unfinished_edges;
        ret (cfg7, [b_join], ugn2)
      else
        ret (cfg5, nil, ugn2)
  | Clight.Sloop ns1 ns2 => (
    (* TODO there is optimization needed here; should NOT always create a new basic block. *)
    (* do can_use_cur_bb <- bb_is_empty cfg cur_bb_uid; *)

    (* if can_use_cur_bb then *)

    (* else ( *)
      (* create the loop header bb *)
      do (bb_ns1, cfg1) <- create_new_bb cfg;

      let cur_bb_edge := direct bb_ns1 in

      (* close up the curent bb *)
      do cfg2 <- set_edge_in_bb cfg1 cur_bb_uid cur_bb_edge;

      (* create the exit bb *)
      do (bb_exit, cfg3) <- create_new_bb cfg2;

      (* create the s2 bb *)
      do (bb_ns2, cfg4) <- create_new_bb cfg3;

      do (cfg5, unfinished_bbs_ns1, ugn1)
         <- process_statement_to_cfg cfg3 bb_ns1 ns1 (Some bb_ns2) (Some bb_exit)
                                    unfinished_goto_nodes;

      (* ns1 -> ns2 *)
      let s1_edge := direct bb_ns2 in

      do cfg6 <- apply_edge_to_all_bbs cfg5 s1_edge unfinished_bbs_ns1;


      do (cfg7, unfinished_bbs_ns2, ugn2)
         <- process_statement_to_cfg cfg6 bb_ns2 ns2 (Some bb_ns1) (Some bb_exit)
                                    ugn1;

      let s2_edge := direct bb_ns1 in

      do cfg8 <- apply_edge_to_all_bbs cfg7 s2_edge unfinished_bbs_ns2;

      (* exit is the "next bb" so to speak*)
      ret (cfg8, [bb_exit], ugn2)
    (* ) *)
  )
  | Clight.Sbreak =>
      match maybe_break_uid with
      | Some break_uid => (
        let break_edge := direct break_uid in
        do cfg1 <- set_edge_in_bb cfg cur_bb_uid break_edge;
        ret (cfg1, nil, unfinished_goto_nodes)
      )
      | None => error(Errors.msg "Break missing target")
      end
  | Clight.Scontinue =>
      (* ret (cfg, nil) *)
      match maybe_continue_uid with
      | Some continue_uid => (
        let continue_edge := direct continue_uid in
        do cfg1 <- set_edge_in_bb cfg cur_bb_uid continue_edge;
        ret (cfg1, nil, unfinished_goto_nodes)
      )
      | None => error(Errors.msg "Break missing target")
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

      ret (cfg4, [next_bb], ugn1)

  | Clight.Ssequence s1 s2 =>
      do (cfg2, unfinished_nodes, ugn1)
         <- process_statement_to_cfg cfg cur_bb_uid s1
                                    maybe_continue_uid maybe_break_uid unfinished_goto_nodes;
      match unfinished_nodes with
      | nil => (
        (* if this is empty, that's ok. We probably returned. But, still need a new node. *)
        do (new_bb, cfg3) <- create_new_bb cfg2;
        (* note: we are *not* making a new bb here. If the control flow ends here, that's okay. *)
        process_statement_to_cfg cfg3 new_bb s2 maybe_continue_uid maybe_break_uid
                                 ugn1
      )
      | unfinished_bb_uid :: nil => (
        do (new_bb, cfg3) <- create_new_bb cfg2;

        let end_edge := direct new_bb in

        do cfg4 <- set_edge_in_bb cfg3 unfinished_bb_uid end_edge;

        process_statement_to_cfg cfg3 new_bb s2 maybe_continue_uid maybe_break_uid
                                 ugn1
      )
      | _ => error (Errors.msg "multiple unfinished nodes (impossible)" )
      end
  | Clight.Sgoto lbl =>
    (* The basic block ends. We add to the unfinished nodes and fix it up later *)
    let ugn1 := (lbl, cur_bb_uid) :: unfinished_goto_nodes in
    ret (cfg, nil, ugn1)
  | Clight.Slabel lbl s => (
    (* check if we need to make a new uid *)
    (* if we do, make it*)
    do dont_need_new_bb_uid <- bb_is_empty cfg cur_bb_uid;
    do (cfg1, lbl_uid) <-
    match dont_need_new_bb_uid with
    | true => (
      do (goto_bb_uid, cfg1) <- create_new_bb cfg;
      let finished_edge := direct goto_bb_uid in
      do cfg2 <- set_edge_in_bb cfg1 cur_bb_uid finished_edge;
      ret (cfg2, goto_bb_uid)
    )
    | false => ret (cfg, cur_bb_uid)
    end;

    (* insert label into label map. If I did this more than once I would
       separate out into auxilary function *)
    let updated_lbl_map := LBLMap.add lbl lbl_uid (lbl_map cfg) in
    let cfg2 := {|
      (* TODO nuke this field *)
      node_set := cfg.(node_set);
      entry := cfg.(entry);
      map := cfg.(map);
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
      | [unfinished_bb] => (
        let ending_edge := direct end_uid in
        do cfg2 <- set_edge_in_bb cfg1 unfinished_bb ending_edge;
        ret (sl, cfg2, ugn1)
      )
      | _ => ret (sl, cfg1, ugn1)
      end
    )
    | _ => error (Errors.msg "missing uid (not possible)" )
    end
  )

  | Clight.LScons v stmt ((Clight.LScons v' stmt' stmts'') as the_rest) => (
    match l' with
    | case_uid :: case_uid_next :: l'' => (
      do (cfg1, maybe_unfinished_bb, ugn1) <-
           process_statement_to_cfg cfg case_uid stmt maybe_continue_uid maybe_break_uid
                                    unfinished_goto_nodes;

      do (sl, cfg2, ugn2) <-
           handle_switch_aux cfg1 end_uid maybe_continue_uid maybe_break_uid the_rest l''
                             ugn1;

      let sl' := SLcons v case_uid sl in
      match maybe_unfinished_bb with
      | [unfinished_bb] => (
        let ending_edge := direct case_uid_next in
        do cfg3 <- set_edge_in_bb cfg2 unfinished_bb ending_edge;
        ret (sl', cfg3, ugn2)
      )
      | _ => ret (sl', cfg2, ugn2)
      end
    )
    | _ => error (Errors.msg "missing uid (not possible)" )
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


Definition transl_statement_to_cfg (c_stmt: Clight.statement) : mon ClightCFG :=
  do entry_node_uid <- gen_bb_uid;

  let init_map := BBMap.add entry_node_uid (bb nil stub) (BBMap.empty BasicBlock) in

  let initial_cfg :=
    {|
      node_set := BBSet.add entry_node_uid BBSet.empty;
      entry := entry_node_uid;
      map := init_map;
      lbl_map := LBLMap.empty bb_uid;
    |} in

  do (cfg, unfinished_nodes, unfinished_goto_nodes)
     <- process_statement_to_cfg initial_cfg entry_node_uid c_stmt None None nil;

  (* finish up last edge *)
  do cfg1 <-
    match unfinished_nodes with
    | nil => ret cfg
    | unfinished_node_uid :: nil =>
        set_edge_in_bb cfg unfinished_node_uid (terminate None)
    | _ => error(Errors.msg "BB missing from cfg")
    end;

  finish_lbled_nodes cfg1 unfinished_goto_nodes.


Print Clight.function.
Print Errors.Error.

Definition transl_function_to_cfg (c_fn: Clight.function) : Errors.res function :=
  let state := (initial_bb_generator tt) in
  match transl_statement_to_cfg c_fn.(Clight.fn_body) state with
    | OK cfg gen proof  => Errors.OK(
      {|
        fn_return := c_fn.(Clight.fn_return);
        fn_callconv := c_fn.(Clight.fn_callconv);
        fn_params := c_fn.(Clight.fn_params);
        fn_vars := c_fn.(Clight.fn_vars);
        fn_temps := c_fn.(Clight.fn_temps);
        fn_body := cfg;
      |})
    | ERR(msg) => Errors.Error(msg)
  end.



(* Definition transl_prog_to_cfg () *)
