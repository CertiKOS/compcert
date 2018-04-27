Require Import Smallstep.
Require Import Machregs.
Require Import Asm.
Require Import Integers.
Require Import List.
Require Import ZArith.
Require Import Memtype.
Require Import Memory.
Require Import Archi.
Require Import Coqlib.
Require Import AST.
Require Import Globalenvs.
Require Import Events.
Require Import Values.
Require Import Conventions1.
Require Import AsmFacts.
Require Import RawAsm RealAsm.

Section WITHMEMORYMODEL.
  
  Context `{memory_model: Mem.MemoryModel }.
  Existing Instance inject_perm_upto_writable.

  Context `{external_calls_ops : !ExternalCallsOps mem }.
  Context `{!EnableBuiltins mem}.

  Existing Instance mem_accessors_default.
  Existing Instance symbols_inject_instance.
  Context `{external_calls_props : !ExternalCallsProps mem
                                    (memory_model_ops := memory_model_ops)
                                    }.

  Variable prog: Asm.program.
  Let ge := Genv.globalenv prog.
  Definition bstack := Genv.genv_next ge.
  Section PRESERVATION.

  Variable init_stk: stack.
  Definition init_sp: val := current_sp init_stk.
  Variable binit_sp: block.
  Hypothesis init_sp_ptr: init_sp = Vptr binit_sp Ptrofs.zero.


  Definition pc_at (s: state): option ((function * instruction) + external_function) :=
    let '(State rs m) := s in
    match rs PC with
    | Vptr b o =>
      match Genv.find_funct_ptr ge b with
      | Some (Internal f) =>
        match find_instr (Ptrofs.unsigned o) (fn_code f) with
        | Some i => Some (inl (f,i))
        | None => None
        end
      | Some (External ef) => Some (inr ef)
      | None => None
      end
    | _ => None
    end.

  Definition rs_state s :=
    let '(State rs _) := s in rs.

  Definition m_state s :=
    let '(State _ m) := s in m.

  Inductive is_alloc : instruction -> Prop :=
    is_alloc_intro f sz:
      is_alloc (Pallocframe f sz).

  Definition make_palloc f : instruction :=
    let sz := frame_size f in 
    (Pallocframe f (Ptrofs.sub (Ptrofs.repr (align sz 8)) (Ptrofs.repr (size_chunk Mptr)))).

  Lemma make_palloc_is_alloc:
    forall f,
      is_alloc (make_palloc f).
  Proof. constructor. Qed.
  
  Inductive is_free : instruction -> Prop :=
    is_free_intro sz ora:
      is_free (Pfreeframe sz ora).

  Inductive is_jmp: instruction -> Prop :=
  | is_jmp_s:
      forall symb b sg,
        Genv.find_symbol ge symb = Some b ->
        is_jmp (Pjmp_s symb sg)
  | is_jmp_r:
      forall (r: ireg) sg,
        is_jmp (Pjmp_r r sg).

  Inductive intermediate_instruction : instruction -> Prop :=
  | ii_alloc i: is_alloc i -> intermediate_instruction i
  | ii_jmp i: i = Pret \/ is_jmp i -> intermediate_instruction i.

  Inductive seq: state -> state -> Prop :=
  | seq_intro rs1 rs2 m (REQ: forall r, r <> RA -> rs1 r = rs2 r): seq (State rs1 m) (State rs2 m).
  
  Inductive match_states: state -> state -> Prop :=
  | match_states_call_alloc
      (rs1 rs2: regset) m1 m2
      (REQ: forall r : preg, r <> RSP -> r <> RA -> rs1 r = rs2 r)
      (RRSP: rs1 RSP = Val.offset_ptr (rs2 RSP) (Ptrofs.repr (size_chunk Mptr)))
      (MEQ: Mem.storev Mptr m1 (rs2 RSP) (rs1 RA) = Some m2)
      f ialloc
      (PC1: pc_at (State rs1 m1) = Some (inl (f,ialloc)))
      (ALLOC: is_alloc ialloc):
      match_states (State rs1 m1) (State rs2 m2)
  | match_states_call_external
      (rs1 rs2: regset) m1 m2
      (REQ: forall r : preg, r <> RSP -> r <> RA -> rs1 r = rs2 r)
      (RRSP: rs1 RSP = Val.offset_ptr (rs2 RSP) (Ptrofs.repr (size_chunk Mptr)))
      (MEQ: Mem.storev Mptr m1 (rs2 RSP) (rs1 RA) = Some m2)
      ef
      (PC1: pc_at (State rs1 m1) = Some (inr ef)):
      match_states (State rs1 m1) (State rs2 m2)
  | match_states_free_ret
      (rs1 rs2: regset) m
      (REQ: forall r : preg, r <> RSP -> r <> RA -> rs1 r = rs2 r)
      (RRSP: rs1 RSP = Val.offset_ptr (rs2 RSP) ((* Ptrofs.neg *) (Ptrofs.repr (size_chunk Mptr))))
      (LOADRA: Mem.loadv Mptr m (rs2 RSP) = Some (rs1 RA))
      f
      (PC1: pc_at (State rs1 m) = Some (inl (f,Pret))):
      match_states (State rs1 m) (State rs2 m)
  | match_states_free_jmp
      (rs1 rs2: regset) m
      (REQ: forall r: preg, r <> RSP -> r <> RA -> rs1 r = rs2 r)
      (RRSP: rs1 RSP = Val.offset_ptr (rs2 RSP) ((* Ptrofs.neg *) (Ptrofs.repr (size_chunk Mptr))))
      (MEQ: Mem.loadv Mptr m (rs2 RSP) = Some (rs1 RA))
      f ijmp
      (PC1: pc_at (State rs1 m) = Some (inl (f,ijmp)))
      (JMP: is_jmp ijmp):
      match_states (State rs1 m) (State rs2 m)
  (* | match_states_jmp_alloc *)
  (*     (rs1 rs2: regset) m *)
  (*     (REQ: forall r : preg, r <> RSP -> rs1 r = rs2 r) *)
  (*     (RRSP: rs1 RSP = Val.offset_ptr (rs2 RSP) (Ptrofs.repr (size_chunk Mptr))) *)
  (*     (MEQ: Mem.loadv Mptr m (rs2 RSP) = Some (rs1 RA)) *)
  (*     f ialloc *)
  (*     (PC1: pc_at (State rs1 m) = Some (inl (f,ialloc))) *)
  (*     (ALLOC: is_alloc ialloc): *)
  (*     match_states (State rs1 m) (State rs2 m) *)
  (* | match_states_jmp_external *)
  (*     (rs1 rs2: regset) m *)
  (*     (REQ: forall r : preg, r <> RSP -> rs1 r = rs2 r) *)
  (*     (RRSP: rs1 RSP = Val.offset_ptr (rs2 RSP) (Ptrofs.repr (size_chunk Mptr))) *)
  (*     (MEQ: Mem.loadv Mptr m (rs2 RSP) = Some (rs1 RA)) *)
  (*     ef *)
  (*     (PC1: pc_at (State rs1 m) = Some (inr ef)): *)
  (*     match_states (State rs1 m) (State rs2 m) *)
  | match_states_normal s1 s2
                        (SEQ: seq s1 s2)
                        (PC1: match pc_at s2 with
                              | Some (inl (f,i)) => ~ intermediate_instruction i
                              | Some (inr ef) => False
                              | None => True
                              end
                        ):
      match_states s1 s2.

  Lemma stack_limit_range':
    size_chunk Mptr <= Mem.stack_limit <= Ptrofs.max_unsigned.
  Proof.
    split.
    generalize Mem.stack_limit_aligned Mem.stack_limit_pos. intros (x & EQ) POS. rewrite EQ.
    transitivity 8.
    unfold Mptr. destr; simpl; omega.
    rewrite EQ in POS. cut (1 <= x). omega.
    change 0 with (0 * 8) in POS.
    rewrite <- Z.mul_lt_mono_pos_r in POS. omega. omega.
    apply Mem.stack_limit_range.
  Qed.


  Lemma nextinstr_nf_pc: forall rs sz, nextinstr_nf rs sz PC = Val.offset_ptr (rs PC) sz.
  Proof.
    unfold nextinstr_nf. simpl.
    intros. rewrite Asmgenproof0.nextinstr_pc. f_equal.
  Qed.

  Ltac simpl_regs_in H :=
    repeat first [ rewrite Pregmap.gso in H by congruence
                 | rewrite Pregmap.gss in H
                 | rewrite Asmgenproof0.nextinstr_pc in H
                 | rewrite nextinstr_nf_pc in H
                 | rewrite Asmgenproof0.nextinstr_inv in H by congruence
                 ].

  Ltac simpl_regs :=
    repeat first [ rewrite Pregmap.gso by congruence
                 | rewrite Pregmap.gss
                 | rewrite Asmgenproof0.nextinstr_pc
                 | rewrite nextinstr_nf_pc
                 | rewrite Asmgenproof0.nextinstr_inv by congruence
                 ].

  Fixpoint in_builtin_arg (b: builtin_arg preg) (r: preg) :=
    match b with
    | BA x => if preg_eq r x then True else False
    | BA_splitlong ba1 ba2 => in_builtin_arg ba1 r \/ in_builtin_arg ba2 r
    | _ => False
    end.

  Record wf_asm_function (f: function): Prop :=
    {
      wf_asm_call_target_exists:
        forall o symb sg,
          find_instr o (fn_code f) = Some (Pcall_s symb sg) ->
          exists bf f',
            Genv.symbol_address ge symb Ptrofs.zero = Vptr bf Ptrofs.zero /\
            Genv.find_funct_ptr ge bf = Some f';

      wf_asm_jmp_target_exists:
        forall o symb sg,
          find_instr o (fn_code f) = Some (Pjmp_s symb sg) ->
          exists bf f',
            Genv.symbol_address ge symb Ptrofs.zero = Vptr bf Ptrofs.zero /\
            Genv.find_funct_ptr ge bf = Some f';

      wf_asm_alloc_only_at_beginning:
        forall o fi ora,
          find_instr o (fn_code f) = Some (Pallocframe fi ora) ->
          o = 0;
      wf_asm_alloc_at_beginning:
        find_instr 0 (fn_code f) = Some (make_palloc (fn_frame f));

      wf_asm_after_freeframe:
        forall i o,
          find_instr (Ptrofs.unsigned o) (fn_code f) = Some i ->
          is_free i ->
          exists i' ,
            find_instr (Ptrofs.unsigned (Ptrofs.add o (Ptrofs.repr (instr_size i)))) (fn_code f) = Some i' /\
            (i' = Pret \/ is_jmp i' );

      wf_asm_ret_jmp_comes_after_freeframe:
        forall i o,
          find_instr (Ptrofs.unsigned o) (fn_code f) = Some i ->
          i = Pret \/ is_jmp i ->
          exists o' ifree,
            find_instr (Ptrofs.unsigned o') (fn_code f) = Some ifree /\
            is_free ifree /\
            Ptrofs.unsigned o' + instr_size ifree = Ptrofs.unsigned o;

      wf_asm_pc_repr:
        forall i o,
          find_instr (Ptrofs.unsigned o) (fn_code f) = Some i ->
          Ptrofs.unsigned (Ptrofs.add o (Ptrofs.repr (instr_size i))) = Ptrofs.unsigned o + instr_size i;

      wf_asm_code_bounded:
        0 <= code_size (fn_code f) <= Ptrofs.max_unsigned;

      wf_asm_builtin_not_PC:
        forall o ef args res,
          find_instr o (fn_code f) = Some (Pbuiltin ef args res) ->
          ~ in_builtin_res res PC
          /\ Forall (fun arg : builtin_arg preg => ~ in_builtin_arg arg RA) args;

      wf_asm_jmp_no_rsp:
        forall o (r: ireg) sg,
          find_instr o (fn_code f) = Some (Pjmp_r r sg) ->
          r <> RSP;

      wf_asm_free_spec:
        forall o sz ora,
          find_instr o (fn_code f) = Some (Pfreeframe sz ora) ->
          sz = frame_size (fn_frame f) /\ ora = Ptrofs.sub (Ptrofs.repr (align (Z.max 0 sz) 8)) (Ptrofs.repr (size_chunk Mptr));
      
    }.

  Lemma wf_asm_wf_allocframe:
    forall f (WF: wf_asm_function f) o fi ora
      (FI: find_instr o (fn_code f) = Some (Pallocframe fi ora)),
      make_palloc (fn_frame f) = Pallocframe fi ora.
  Proof.
    intros.
    exploit wf_asm_alloc_only_at_beginning; eauto. intro; subst.
    erewrite wf_asm_alloc_at_beginning in FI; eauto. inv FI; auto.
  Qed.
    
  Hypothesis wf_asm_prog:
    forall b f,
      Genv.find_funct_ptr ge b = Some (Internal f) ->
      wf_asm_function f.

  Ltac rewrite_hyps :=
    repeat
      match goal with
        H1 : ?a = _, H2: ?a = _ |- _ => rewrite H1 in H2; inv H2
      end.
 
  Hypothesis main_internal:
    exists bmain fmain,
      Genv.find_symbol ge (prog_main prog) = Some bmain /\
      Genv.find_funct_ptr ge bmain = Some (Internal fmain).
  
  Lemma initial_states_match rs:
    forall s1 s2,
      RawAsm.initial_state prog rs s1 ->
      initial_state prog rs s2 ->
      exists s1', RawAsm.initial_state prog rs s1' /\ match_states s1' s2.
  Proof.
    simpl; intros s1 s2 IS1 IS2.
    exists s1; split; auto. inv IS1; inv IS2.
    inv H0; inv H2.
    destruct main_internal as (bmain & fmain & symbmain & funmain).
    eapply match_states_call_alloc.
    - unfold rs0, rs1. intros. simpl_regs. rewrite (Pregmap.gso _ _ H0). rewrite (Pregmap.gso _ _ H2). auto.
    - unfold rs0, rs1. simpl_regs. simpl. f_equal. congruence.
      rewrite Ptrofs.add_assoc. rewrite (Ptrofs.add_commut (Ptrofs.neg _)), Ptrofs.add_neg_zero. rewrite Ptrofs.add_zero. auto.
    - unfold rs0, rs1; simpl_regs.
      simpl. rewrite <- Ptrofs.sub_add_opp.
      unfold Ptrofs.sub.
      rewrite (Ptrofs.unsigned_repr _ (Mem.stack_limit_range)).
      rewrite (Ptrofs.unsigned_repr (size_chunk Mptr)).
      2: vm_compute; intuition congruence.
      simpl in STORE_RETADDR. congruence.
    - simpl. unfold rs0. simpl_regs.
      replace ge0 with ge in * by reflexivity.
      replace ge1 with ge in * by reflexivity.
      unfold Genv.symbol_address. rewrite symbmain, funmain.
      erewrite wf_asm_alloc_at_beginning; eauto.
    - apply make_palloc_is_alloc.
  Qed.

  Lemma match_states_PC:
    forall s1 s2,
      match_states s1 s2 ->
      rs_state s1 PC = rs_state s2 PC.
  Proof.
    intros s1 s2 MS; inv MS; try rewrite REQ by congruence; try reflexivity.
    inv SEQ. simpl; auto. apply REQ. congruence.
  Qed.

  Inductive is_builtin: instruction -> Prop :=
  | is_builtin_intro ef args res: is_builtin (Pbuiltin ef args res).

  Lemma is_builtin_dec i: is_builtin i \/ ~ is_builtin i.
  Proof.
    destruct i; first [right; now inversion 1|now econstructor].
  Qed.

  Lemma step_internal:
    forall s t s'
      (STEP: RawAsm.step ge s t s')
      f i
      (PCAT: pc_at s = Some (inl (f,i)))
      (NB: ~ is_builtin i),
      RawAsm.exec_instr ge f i (rs_state s) (m_state s) = Next (rs_state s') (m_state s') /\ t = E0.
  Proof.
    unfold pc_at; intros s t s'  STEP; inv STEP.
    - rewrite H, H0, H1. inversion 1; subst. simpl. eauto.
    - rewrite H, H0, H1. intros f0 i A; inv A. intro NIB; exfalso; apply NIB. constructor.
    - rewrite H, H0. inversion 1.
  Qed.

  Lemma step_external_store:
    forall s t s'
      (STEP: RawAsm.step ge s t s')
      ef
      (PCAT: pc_at s = Some (inr ef)),
    exists m2,
      Mem.storev Mptr (m_state s) (Val.offset_ptr (rs_state s RSP) (Ptrofs.neg (Ptrofs.repr (size_chunk Mptr))))
                 (rs_state s RA) = Some m2.
  Proof.
    unfold pc_at; intros s t s'  STEP; inv STEP; rewrite H, H0; try now destr.
    inversion 1; simpl; eauto.
  Qed.

  Lemma internal_step:
    forall rs1 rs2 m1 m2 f i
      (PCAT: pc_at (State rs1 m1) = Some (inl (f,i)))
      (EI: RawAsm.exec_instr ge f i rs1 m1 = Next rs2 m2),
      RawAsm.step ge (State rs1 m1) E0 (State rs2 m2).
  Proof.
    intros.
    simpl in PCAT. repeat destr_in PCAT.
    eapply RawAsm.exec_step_internal; eauto.
  Qed.  

  Lemma offset_ptr_neg_sub a b ptr:
    (Val.offset_ptr (Val.offset_ptr ptr (Ptrofs.neg a)) (Ptrofs.sub a b)) = Val.offset_ptr ptr (Ptrofs.neg b).
  Proof.
    rewrite Val.offset_ptr_assoc. f_equal.
    rewrite Ptrofs.sub_add_opp. rewrite <- Ptrofs.add_assoc.
    rewrite (Ptrofs.add_commut (Ptrofs.neg _)). rewrite Ptrofs.add_neg_zero. apply Ptrofs.add_zero_l.
  Qed.

  Lemma offset_ptr_cancel:
    forall ptr a,
      (exists b o, ptr = Vptr b o) ->
      Val.offset_ptr (Val.offset_ptr ptr a) (Ptrofs.neg a) = ptr.
  Proof.
    intros ptr a (b & o & EQ); subst. simpl.
    rewrite <- Ptrofs.sub_add_opp.
    rewrite Ptrofs.add_commut.
    rewrite Ptrofs.sub_add_l.
    rewrite Ptrofs.sub_idem. rewrite Ptrofs.add_zero_l. auto.
  Qed.

  Lemma eval_addrmode64_seq:
    forall (rs rs' : regset) (REQ: forall r, r <> RA -> rs r = rs' r) a,
      eval_addrmode64 ge a rs = eval_addrmode64 ge a rs'.
  Proof.
    intros.
    unfold eval_addrmode64.
    destr. f_equal. destr. apply REQ. congruence.
    f_equal. destr. destr. rewrite REQ by congruence. auto.
  Qed.


  Lemma eval_addrmode32_seq:
    forall (rs rs' : regset) (REQ: forall r, r <> RA -> rs r = rs' r) a,
      eval_addrmode32 ge a rs = eval_addrmode32 ge a rs'.
  Proof.
    intros.
    unfold eval_addrmode32.
    destr. f_equal. destr. apply REQ. congruence.
    f_equal. destr. destr. rewrite REQ by congruence. auto.
  Qed.
  
  Lemma eval_addrmode_seq:
    forall (rs rs' : regset) (REQ: forall r, r <> RA -> rs r = rs' r) a,
      eval_addrmode ge a rs = eval_addrmode ge a rs'.
  Proof.
    unfold eval_addrmode. intros.
    destr; eauto using eval_addrmode32_seq, eval_addrmode64_seq.
  Qed.

  Lemma eval_testcond_seq:
    forall (rs rs' : regset) (REQ: forall r, r <> RA -> rs r = rs' r) t,
      eval_testcond t rs = eval_testcond t rs'.
  Proof.
    unfold eval_testcond. intros.
    repeat rewrite REQ by congruence. repeat destr.
  Qed.
  
  Lemma exec_load_seq:
    forall chunk m a r r' rd sz r0 m0,
      seq (State r m) (State r' m) ->
      exec_load ge chunk m a r rd sz = Next r0 m0 ->
      exists r1 m1,
        exec_load ge chunk m a r' rd sz = Next r1 m1.
  Proof.
    unfold exec_load; intros chunk m a r r' rd sz r0 m0 SEQ EL; repeat destr_in EL.
    erewrite eval_addrmode_seq in Heqo. rewrite Heqo. eauto. inv SEQ; auto.
  Qed.

  Lemma exec_store_seq:
    forall chunk m a r r' rd lrd sz r0 m0,
      seq (State r m) (State r' m) ->
      exec_store ge chunk m a r rd lrd sz = Next r0 m0 ->
      rd <> RA ->
      exists r1 m1,
        exec_store ge chunk m a r' rd lrd sz = Next r1 m1.
  Proof.
    unfold exec_store; intros chunk m a r r' rd lrd sz r0 m0 SEQ EL NRA; repeat destr_in EL.
    inv SEQ.
    erewrite eval_addrmode_seq in Heqo. rewrite <- REQ. rewrite Heqo. eauto. auto. auto.
  Qed.

  Lemma nextinstr_eq:
    forall rs rs' r,
      rs r = rs' r ->
      forall sz,
        nextinstr rs sz r = nextinstr rs' sz r.
  Proof.
    unfold nextinstr. intros.
    setoid_rewrite Pregmap.gsspec. destr.
  Qed.

  Lemma set_reg_eq:
    forall (rs rs': regset) r dst,
      (r <> dst -> rs r = rs' r) ->
      forall v v' (EQ: v = v'),
        (rs # dst <- v) r = (rs' # dst <- v') r.
  Proof.
    intros.
    setoid_rewrite Pregmap.gsspec. destr.
  Qed.

  Lemma undef_regs_eq:
    forall l (rs rs': regset) r,
      (~ In r l -> rs r = rs' r) ->
      undef_regs l rs r = undef_regs l rs' r.
  Proof.
    induction l; simpl; intros; eauto.
    apply IHl. intros; apply set_reg_eq. intros; apply H. intuition. auto.
  Qed.

  Lemma nextinstr_nf_eq:
    forall rs rs' r,
      rs r = rs' r ->
      forall sz,
        nextinstr_nf rs sz r = nextinstr_nf rs' sz r.
  Proof.
    unfold nextinstr_nf. intros.
    apply nextinstr_eq.
    intros; apply undef_regs_eq. auto.
  Qed.

  Lemma set_res_eq:
    forall res rs rs' r,
      rs r = rs' r ->
      forall vres,
        set_res res vres rs r = set_res res vres rs' r.
  Proof.
    induction res; simpl; intros; eauto.
    apply set_reg_eq; auto.
  Qed.

  Lemma set_pair_eq:
    forall res r rs rs',
      (~ In r (regs_of_rpair res) -> rs r = rs' r) ->
      forall vres,
        set_pair res vres rs r = set_pair res vres rs' r.
  Proof.
    destruct res; simpl; intros; eauto.
    apply set_reg_eq; auto.
    intros; eapply H. intros [A|A]; congruence.
    intros; apply set_reg_eq; auto.
    intros; apply set_reg_eq; auto.
    intros; apply H. intuition congruence.
  Qed.

  Lemma goto_label_seq:
    forall f l rs1 rs2 m rs' m'
      (GL : goto_label ge f l rs1 m = Next rs' m')
      (SEQ: rs1 PC = rs2 PC),
    exists (rs2' : regset) (m2' : mem), goto_label ge f l rs2 m = Next rs2' m2'.
  Proof.
    unfold goto_label. intros. destr. rewrite <- SEQ. destr. destr. eauto.
  Qed.

  Lemma is_call_dec:
    forall i,
      is_call i \/ ~ is_call i.
  Proof.
    destruct i; try now (right; intro A; inv A).
    - left; econstructor; eauto.
    - left; econstructor; eauto.
  Qed.
  
  Ltac force_rewrite_match H :=
    match goal with
      H: ?b = _ |- context [ match ?a with _ => _ end ] =>
      cut (b = a);[ let A := fresh in intro A; rewrite <- A, H | ]
    end.

  Lemma not_none_ex:
    forall {A: Type} (oa: option A),
      oa <> None ->
      exists a, oa = Some a.
  Proof.
    intros.
    destruct oa; try congruence; eauto.
  Qed.

  
  Lemma eval_builtin_arg_eq_rs:
    forall (rs1 rs2: regset) (REQ: forall r, r <> RA -> rs1 r = rs2 r) sp m args vargs
      (NIN: ~ in_builtin_arg args RA),
      eval_builtin_arg ge rs1 sp m args vargs ->
      eval_builtin_arg ge rs2 sp m args vargs.
  Proof.
    induction 3; rewrite ? REQ; try econstructor; eauto.
    intro; subst. now simpl in NIN.
    simpl in NIN. apply IHeval_builtin_arg1. intuition.
    simpl in NIN. apply IHeval_builtin_arg2. intuition.
  Qed.

  Lemma eval_builtin_args_eq_rs:
    forall (rs1 rs2: regset) (REQ: forall r, r <> RA -> rs1 r = rs2 r) sp m args vargs
      (NIN: Forall (fun arg => ~ in_builtin_arg arg RA) args),
      eval_builtin_args ge rs1 sp m args vargs ->
      eval_builtin_args ge rs2 sp m args vargs.
  Proof.
    induction 3; constructor; eauto.
    eapply eval_builtin_arg_eq_rs. 3: apply H. auto. inv NIN; auto.
    inv NIN. apply IHlist_forall2. auto.    
  Qed.

  Lemma preg_of_not_RA:
    forall r,
      preg_of r <> RA.
  Proof.
    unfold preg_of. intros.
    destr.
  Qed.
  
  Lemma extcall_arg_eq_rs:
    forall (rs1 rs2: regset)
      (REQ : forall r : preg, r <> RA -> rs1 r = rs2 r)
      m1 l arg
      (ARGS : extcall_arg rs1 m1 l arg),
      extcall_arg rs2 m1 l arg.
  Proof.
    intros rs1 rs2 REQ m1 l arg ARGS; inv ARGS.
    - rewrite REQ.
      econstructor. apply preg_of_not_RA.
    - econstructor; eauto. rewrite <- REQ; eauto. congruence.
  Qed.

  Lemma extcall_arg_pair_eq_rs:
    forall (rs1 rs2: regset)
      (REQ : forall r : preg, r <> RA -> rs1 r = rs2 r)
      m1 l arg
      (ARGS : extcall_arg_pair rs1 m1 l arg),
      extcall_arg_pair rs2 m1 l arg.
  Proof.
    intros; inv ARGS; econstructor; eauto using extcall_arg_eq_rs.
  Qed.

  Lemma extcall_arguments_eq_rs:
    forall (rs1 rs2: regset)
      (REQ : forall r : preg, r <> RA -> rs1 r = rs2 r)
      m1 sg args
      (ARGS : extcall_arguments rs1 m1 sg args),
      extcall_arguments rs2 m1 sg args.
  Proof.
    intros rs1 rs2 REQ m1. unfold extcall_arguments.
    induction 1; econstructor; eauto using extcall_arg_pair_eq_rs.
  Qed.

  Lemma extcall_progress:
    forall (rs1 rs2: regset)
      (REQ : forall r : preg, r <> RSP -> r <> RA -> rs1 r = rs2 r)
      (RRSP : rs1 RSP = Val.offset_ptr (rs2 RSP) (Ptrofs.repr (size_chunk Mptr)))
      m2
      b ef
      (FFP : Genv.find_funct_ptr ge b = Some (External ef))
      (PC1 : rs1 PC = Vptr b Ptrofs.zero)
      args res
      (ARGS : extcall_arguments rs1 m2 (ef_sig ef) args)
      ra (LOADRA: Mem.loadv Mptr m2 (rs2 RSP) = Some ra)
      (SP_TYPE : Val.has_type (rs1 RSP) Tptr)
      (SP_NOT_VUNDEF : rs1 RSP <> Vundef)
      (RA_NOT_VUNDEF : ra <> Vundef)
      m' t
      (EXTCALL : external_call ef ge args m2 t res m'),
    exists s2', step ge (State rs2 m2) t s2'.
  Proof.
    intros.
    eexists.
    eapply exec_step_external. rewrite <- REQ by congruence. eauto. eauto.
    eapply extcall_arguments_eq_rs. 2: eauto. intros. simpl_regs.
    setoid_rewrite Pregmap.gsspec. rewrite <- RRSP.
    destr. apply REQ. auto. auto.
    rewrite RRSP in SP_NOT_VUNDEF. unfold Val.offset_ptr in SP_NOT_VUNDEF. destr_in SP_NOT_VUNDEF. apply Val.Vptr_has_type.
    eauto.
    rewrite RRSP in SP_NOT_VUNDEF. unfold Val.offset_ptr in SP_NOT_VUNDEF. destr_in SP_NOT_VUNDEF.
    auto. eauto. eauto.
  Qed.

  Lemma real_asm_progress rs:
    forall s1 s2,
      match_states s1 s2 ->
      safe (RawAsm.semantics prog rs) s1 ->
      (exists r : int, final_state s2 r) \/ (exists (t : trace) (s2' : state), step (Genv.globalenv prog) s2 t s2').
  Proof.
    intros s1 s2 MS SAFE.
    destruct (SAFE _  (star_refl _ _ _)) as [(r & FS)|(t & s2' & STEP)].
    {
      simpl in FS. inv FS.
      assert (pc_at (State rs0 m) = None).
      - simpl. rewrite H. unfold Vnullptr. destruct ptr64; auto.
      - inv MS; try congruence. inv SEQ.
        left. eexists; constructor; rewrite <- REQ; eauto. congruence. congruence.
    } 
    simpl in *. fold ge in STEP |- *.
    inv MS.
    - exploit step_internal. apply STEP. eauto. intro IB; inv IB; inv ALLOC. intros (EI & T0).
      simpl in *. subst.
      inv ALLOC; simpl in EI. repeat destr_in EI.
      repeat destr_in PC1.
      exploit wf_asm_wf_allocframe; eauto. intro A; inv A.
      rewrite offset_ptr_neg_sub in Heqo.
      rewrite RRSP in Heqo.
      rewrite offset_ptr_cancel in Heqo.
      assert (m_state s2' = m2) by congruence. subst.
      right; do 2 eexists.
      eapply exec_step_internal.
      rewrite <- REQ by congruence. eauto. eauto. eauto.
      simpl. eauto.
      unfold Mem.storev in MEQ. destr_in MEQ.
      unfold Mem.loadv in Heqo2; destr_in Heqo2; eauto.
    - simpl in PC1. repeat destr_in PC1.
      inv STEP; rewrite_hyps.
      right. exists t.
      assert (m2 = m0).
      {
        rewrite RRSP in SZRA.
        rewrite offset_ptr_cancel in SZRA. congruence.
        unfold Mem.storev in MEQ. destr_in MEQ.
        unfold Mem.loadv in Heqo0; destr_in Heqo0; eauto.
      } subst.
      eapply extcall_progress; eauto.
      assert (exists b o, rs2 RSP = Vptr b o).
      {
        unfold Mem.storev, Mem.loadv in MEQ. destruct (rs2 RSP); simpl in *; try congruence. eauto.
      }
      unfold Mem.storev in SZRA. destr_in SZRA.
      rewrite RRSP in Heqo0. rewrite offset_ptr_cancel in Heqo0; eauto. destr_in SZRA.
      rewrite RRSP in SZRA. rewrite offset_ptr_cancel in SZRA; eauto.
      destruct H as (b & o & RSP2); rewrite RSP2 in *. simpl in *.
      erewrite Mem.load_store_same; eauto.
      change Mptr with (chunk_of_type Tptr).
      erewrite Val.load_result_same. auto. auto.
    - exploit step_internal. apply STEP. eauto. intro IB; inv IB. intros (EI & T0).
      simpl in EI. inv EI.
      simpl in *.
      repeat destr_in PC1.
      right; do 2 eexists.
      eapply exec_step_internal.
      rewrite <- REQ by congruence. eauto. eauto. eauto.
      simpl. rewrite LOADRA. eauto.
    - exploit step_internal. apply STEP. eauto. intro IB; inv IB; inv JMP. intros (EI & T0).
      simpl in *.
      repeat destr_in PC1.
      inv JMP.
      + right; do 2 eexists.
        eapply exec_step_internal.
        rewrite <- REQ by congruence. eauto. eauto. eauto.
        simpl in EI; simpl; inv EI. eauto.
      + right; do 2 eexists.
        eapply exec_step_internal.
        rewrite <- REQ by congruence. eauto. eauto. eauto.
        simpl in EI; repeat destr_in EI. simpl. rewrite <- REQ, Heqo1. eauto.
        eapply wf_asm_jmp_no_rsp in Heqo0; eauto. congruence.
        congruence.
    (* - exploit step_internal. apply STEP. eauto. intro IB; inv IB; inv ALLOC. intros (EI & T0). *)
    (*   simpl in *. subst. *)
    (*   inv ALLOC; simpl in EI. repeat destr_in EI. *)
    (*   repeat destr_in PC1. *)
    (*   exploit wf_asm_wf_allocframe; eauto. intro A; inv A. *)
    (*   rewrite offset_ptr_neg_sub in Heqo. *)
    (*   rewrite RRSP in Heqo. *)
    (*   rewrite offset_ptr_cancel in Heqo. *)
    (*   2: unfold Mem.storev in Heqo; destr_in Heqo; eauto. *)
    (*   right; do 2 eexists. *)
    (*   eapply exec_step_internal. *)
    (*   rewrite <- REQ by congruence. eauto. eauto. eauto. *)
    (*   simpl. eauto. *)
    (*   unfold Mem.loadv in MEQ; destr_in MEQ; eauto. *)
    - inversion SEQ; subst.
      simpl in *. rewrite <- REQ in PC1 by congruence.
      repeat destr_in PC1; subst.
      repeat destr_in Heqo.
      + inversion STEP; subst; rewrite_hyps.
        destruct (is_call_dec i1).
        {
          destruct (SAFE _ (star_one _ _ _ _ _ STEP)) as [(r & FS)|(t & s2' & STEP2)].
          - inv FS.
            inv H; simpl in H6. inv H6.
            simpl_regs_in H2. unfold Genv.symbol_address in H2. repeat destr_in H2.
            repeat destr_in H6.
            simpl_regs_in H2. rewrite H2 in Heqo.
            unfold Genv.find_funct in Heqo. destr_in Heqo. inv Heqv0.
          - assert (exists b f', Genv.find_funct_ptr ge b = Some f' /\
                            rs' PC = Vptr b Ptrofs.zero).
            {
              rename H6 into EI.
              inv H; simpl in EI; repeat destr_in EI.
              - eapply wf_asm_call_target_exists in Heqo1; eauto.
                destruct Heqo1 as (bf & f' & SA & FFP). simpl_regs.
                rewrite SA. exists bf. rewrite FFP. eauto.
              - simpl_regs. unfold Genv.find_funct in Heqo; repeat destr_in Heqo. eauto.
            }
            destruct H0 as (b & f' & FFP & PC').
            destruct f'.
            + inv H.
              * exploit step_internal. apply STEP2. simpl. rewrite PC'. rewrite FFP.
                erewrite wf_asm_alloc_at_beginning; eauto. inversion 1. intros (EI & T0). subst.
                simpl in EI. destr_in EI. inv EI.
                right; do 2 eexists. eapply exec_step_internal. rewrite <- REQ; eauto. congruence. eauto. eauto.
                simpl in H6. inv H6. simpl. force_rewrite_match Heqo. eauto.
                simpl_regs. rewrite <- ! REQ.
                f_equal.
                apply offset_ptr_neg_sub. congruence. congruence.
              * exploit step_internal. apply STEP2. simpl. rewrite PC'. rewrite FFP.
                erewrite wf_asm_alloc_at_beginning; eauto. inversion 1. intros (EI & T0). subst.
                simpl in EI. destr_in EI.
                right; do 2 eexists. eapply exec_step_internal. rewrite <- REQ; eauto. congruence. eauto. eauto.
                simpl in H6.  repeat destr_in H6. simpl. force_rewrite_match Heqo. eauto.
                simpl_regs. rewrite <- ! REQ.
                f_equal.
                apply offset_ptr_neg_sub. congruence. congruence.
            + generalize (step_external_store _ _ _ STEP2 e). simpl; rewrite PC' , FFP.
              intro STORE; trim STORE. auto. destruct STORE as (m2' & STORE).
              inv H.
              * simpl in H6. inv H6. revert STORE. simpl_regs. intros.
                right; do 2 eexists. eapply exec_step_internal. rewrite <- REQ; eauto. congruence. eauto. eauto.
                simpl. rewrite <- ! REQ. rewrite STORE. eauto. congruence. congruence.
              * simpl in H6. repeat destr_in H6. revert STORE. simpl_regs. intros.
                right; do 2 eexists. eapply exec_step_internal. rewrite <- REQ; eauto. congruence. eauto. eauto.
                simpl. rewrite <- ! REQ by congruence. rewrite STORE. eauto.
        }

        cut (exists rs2' m2', exec_instr ge f0 i1 rs2 m = Next rs2' m2').
        intros (rs2' & m2' & EI'). right; exists E0, (State rs2' m2').
        eapply exec_step_internal. rewrite <- REQ by congruence; eauto. eauto. eauto. eauto.
        destruct i1; simpl in H6; simpl; eauto using exec_load_seq, exec_store_seq.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        repeat rewrite <- REQ by congruence. repeat destr_in H6. eauto.
        repeat rewrite <- REQ by congruence. repeat destr_in H6. eauto.
        repeat rewrite <- REQ by congruence. repeat destr_in H6. eauto.
        repeat rewrite <- REQ by congruence. repeat destr_in H6. eauto.
        repeat destr; eauto.
        eapply goto_label_seq; eauto. apply REQ; congruence.
        rewrite <- REQ by congruence; repeat destr_in H6; eauto.
        erewrite <- eval_testcond_seq by eauto. repeat destr_in H6; eauto. eapply goto_label_seq; eauto. apply REQ; congruence.
        erewrite <- eval_testcond_seq by eauto. destr_in H6.
        erewrite <- eval_testcond_seq by eauto. repeat destr_in H6; eauto. eapply goto_label_seq; eauto. apply REQ; congruence.
        rewrite <- REQ by congruence. destr. destr. eapply goto_label_seq. eauto. simpl_regs. apply REQ; congruence.
        exfalso; apply H; econstructor.
        exfalso; apply H; econstructor.
        exfalso; apply PC1. constructor 2. auto.
        eapply exec_store_seq; eauto. congruence.
        eapply exec_store_seq; eauto. congruence.
        
        eapply eval_builtin_args_eq_rs in H4. rewrite REQ in H4.
        right; do 2 eexists. eapply exec_step_builtin. rewrite <- REQ; eauto. congruence. all: eauto. congruence.
        eapply wf_asm_builtin_not_PC; eauto.

      + inv STEP; repeat destr_in Heqo.
  Qed.

  Lemma ptrofs_cancel i f s:
    i =
    Ptrofs.add
      (Ptrofs.add (Ptrofs.add i s) (Ptrofs.neg f))
      (Ptrofs.sub f s).
  Proof.
    rewrite ! Ptrofs.add_assoc.
    transitivity (Ptrofs.add i Ptrofs.zero). rewrite Ptrofs.add_zero. auto.
    f_equal.
    rewrite Ptrofs.sub_add_opp.
    rewrite (Ptrofs.add_commut f). rewrite <- (Ptrofs.add_assoc _ (Ptrofs.neg s)).
    rewrite (Ptrofs.add_commut _ (Ptrofs.neg s)). rewrite (Ptrofs.add_assoc (Ptrofs.neg s)).
    rewrite <- (Ptrofs.add_assoc _ (Ptrofs.neg s)).
    rewrite Ptrofs.add_neg_zero. rewrite Ptrofs.add_zero_l.
    rewrite Ptrofs.add_commut.    rewrite Ptrofs.add_neg_zero. auto.
  Qed.
  Axiom instr_size_repr:
    forall i,
      0 <= instr_size i <= Ptrofs.max_unsigned.


  Lemma find_instr_pos_positive:
    forall l o i,
      find_instr o l = Some i -> 0 <= o.
  Proof.
    induction l; simpl; intros; eauto. congruence.
    destr_in H. omega. apply IHl in H.
    generalize (instr_size_positive a). omega.
  Qed.
  
  Lemma find_instr_no_overlap:
    forall l o1 o2 i1 i2,
      find_instr o1 l = Some i1 ->
      find_instr o2 l = Some i2 ->
      o1 <> o2 ->
      o1 + instr_size i1 <= o2 \/ o2 + instr_size i2 <= o1.
  Proof.
    induction l; simpl; intros; eauto. congruence.
    repeat destr_in H; repeat destr_in H0.
    - apply find_instr_pos_positive in H2. omega.
    - apply find_instr_pos_positive in H3. omega.
    - specialize (IHl _ _ _ _ H3 H2). trim IHl. omega. omega.
  Qed.

  Lemma find_instr_no_overlap':
    forall l o1 o2 i1 i2,
      find_instr o1 l = Some i1 ->
      find_instr o2 l = Some i2 ->
      i1 = i2 \/ o1 + instr_size i1 <= o2 \/ o2 + instr_size i2 <= o1.
  Proof.
    intros l o1 o2 i1 i2 FI1 FI2.
    destruct (zeq o1 o2). subst. rewrite FI1 in FI2; inv FI2; auto.
    right.
    eapply find_instr_no_overlap; eauto.
  Qed.

  Lemma offset_ptr_has_type:
    forall ptr o,
      Val.has_type (Val.offset_ptr ptr o) Tptr.
  Proof.
    intros. destruct ptr; now (simpl; auto).
  Qed.

  Lemma set_pair_no_rsp:
    forall p res rs,
      no_rsp_pair p ->
      set_pair p res rs RSP = rs RSP.
  Proof.
    destruct p; simpl; intros; rewrite ! Pregmap.gso; intuition. 
  Qed.

  Lemma rsp_not_destroyed_at_call:
    Asmgenproof0.preg_notin RSP destroyed_at_call.
  Proof.
    unfold destroyed_at_call. apply Asmgenproof0.preg_notin_charact.
    intros. intro EQ; symmetry in EQ.
    apply  preg_of_not_rsp in EQ. congruence.
  Qed.

  Lemma pc_not_destroyed_builtin ef:
    Asmgenproof0.preg_notin PC (destroyed_by_builtin ef).
  Proof.
    apply Asmgenproof0.preg_notin_charact.
    intros. unfold preg_of. destr.
  Qed.
  
  Lemma no_rsp_loc_external_result sg:
    no_rsp_pair (loc_external_result sg).
  Proof.
    unfold loc_external_result.
    generalize (loc_result sg).
    induction r; simpl; intros; try split; apply Asmgenproof0.preg_of_not_SP.
  Qed.

  Lemma is_free_dec:
    forall i,
      is_free i \/ ~ is_free i.
  Proof.
    destruct i; try now (right; intro A; inv A).
    left. econstructor; eauto.
  Qed.

  Lemma set_res_other:
    forall res vres rs r,
      ~ in_builtin_res res r ->
      set_res res vres rs r = rs r.
  Proof.
    induction res; simpl; intros; eauto.
    rewrite Pregmap.gso; auto.
    rewrite IHres2. apply IHres1. intuition. intuition.
  Qed.

  Ltac regs_eq :=
    repeat
      match goal with
      | |- nextinstr _ _ ?r = nextinstr _ _ ?r => apply nextinstr_eq
      | |- nextinstr_nf _ _ ?r = nextinstr_nf _ _ ?r => apply nextinstr_nf_eq
      | |- undef_regs _ _ ?r = undef_regs _ _ ?r => apply undef_regs_eq; [intros | eauto]
      | |- _ # ?r0 <- ?v ?r = _ # ?r0 <- ?v' ?r => apply set_reg_eq; [intros | eauto]
      | H: forall r: preg, r <> RA -> ?rs1 r = ?rs2 r |- ?rs1 _ = ?rs2 _ => apply H ; congruence
      | |- _ => unfold compare_ints, compare_longs, compare_floats, compare_floats32
      end.

  Lemma goto_label_match:
    forall f l rs2 m2 rs2' m2' rs1,
      (forall r: preg, r<>RA -> rs1 r = rs2 r) ->
      goto_label ge f l rs2 m2 = Next rs2' m2' ->
      exists rs1' m1', goto_label ge f l rs1 m2 = Next rs1' m1' /\ seq (State rs1' m1') (State rs2' m2').
  Proof.
    intros f l rs2 m2 rs2' m2' rs1 REQ GL2.
    edestruct goto_label_seq as (rs1' & m1' & GL). eauto. symmetry; apply REQ. congruence. rewrite GL.
    do 2 eexists; split; eauto.
    unfold goto_label in GL2, GL. destr_in GL. rewrite REQ in GL by congruence.
    repeat destr_in GL. inv GL2.
    constructor. intros. regs_eq.
  Qed.


  Lemma label_pos_rng:
    forall lbl c pos z,
      label_pos lbl pos c = Some z ->
      0 <= pos ->
      0 <= z - pos <= code_size c.
  Proof.
    induction c; simpl; intros; eauto. congruence. repeat destr_in H.
    generalize (code_size_non_neg c) (instr_size_positive a); omega.
    apply IHc in H2.
    generalize (instr_size_positive a); omega.
    generalize (instr_size_positive a); omega.
  Qed.

  Lemma label_pos_repr:
    forall lbl c pos z,
      code_size c + pos <= Ptrofs.max_unsigned ->
      0 <= pos ->
      label_pos lbl pos c = Some z ->
      Ptrofs.unsigned (Ptrofs.repr (z - pos)) = z - pos.
  Proof.
    intros.
    apply Ptrofs.unsigned_repr.
    generalize (label_pos_rng _ _ _ _ H1 H0). omega.
  Qed.

  Lemma find_instr_ofs_pos:
    forall c o i,
      find_instr o c = Some i ->
      0 <= o.
  Proof.
    induction c; simpl; intros; repeat destr_in H.
    omega. apply IHc in H1. generalize (instr_size_positive a); omega.
  Qed. 
  
  Lemma label_pos_spec:
    forall lbl c pos z,
      code_size c + pos <= Ptrofs.max_unsigned ->
      0 <= pos ->
      label_pos lbl pos c = Some z ->
      find_instr ((z - pos) - instr_size (Plabel lbl)) c = Some (Plabel lbl).
  Proof.
    induction c; simpl; intros; repeat destr_in H1. 
    destruct a; simpl in Heqb; try congruence. repeat destr_in Heqb.
    apply pred_dec_true. omega.
    eapply IHc in H3. 2: omega. 2: generalize (instr_size_positive a); omega.
    generalize (find_instr_ofs_pos _ _ _ H3). intro.
    rewrite pred_dec_false. 2: generalize (instr_size_positive a); omega.
    rewrite <- H3. f_equal. omega.                  
  Qed.
  
  Lemma goto_label_PC:
    forall f l r m r0 m0
      (GL: goto_label ge f l r m = Next r0 m0)
      b i
      (PCbef: r PC = Vptr b i)
      (FFP: Genv.find_funct_ptr ge b = Some (Internal f)) ,
      (forall f0 i2,
          pc_at (State r0 m0) = Some (inl (f0,i2)) ->
          ~ intermediate_instruction i2)
      /\ (forall ef,
            pc_at (State r0 m0) = Some (inr ef) ->
            False ).
  Proof.
    intros.
    simpl.
    unfold goto_label in GL.
    rewrite PCbef, FFP in GL. destr_in GL. inv GL. simpl_regs. rewrite FFP.
    destr. split. 2: inversion 1. intros f0 i2 EQ; inv EQ.
    assert (EQz: Ptrofs.unsigned (Ptrofs.repr z) = z).
    {
      replace z with (z-0) by omega.
      eapply label_pos_repr. rewrite Z.add_0_r. eapply wf_asm_code_bounded. eauto. omega. eauto.
    } rewrite EQz in *.
    generalize (label_pos_spec l (fn_code f0) 0 z). intro LPS; trim LPS.
    rewrite Z.add_0_r. apply wf_asm_code_bounded; eauto. trim LPS. omega. trim LPS; auto.
    generalize (find_instr_ofs_pos _ _ _ LPS).
    intros POS II; inv II.
    {
      inv H. exploit wf_asm_alloc_only_at_beginning. eauto. apply Heqo0.
      generalize (instr_size_positive (Plabel l)); omega.
    }
    {
      exploit wf_asm_ret_jmp_comes_after_freeframe. eauto. 2: apply H.
      rewrite EQz. eauto.
      intros (o' & ifree & FI & IFREE & RNG).
      generalize (find_instr_no_overlap' _ _ _ _ _ FI LPS).
      intros [EQ|NOOV]. subst; inv IFREE.
      rewrite EQz in *.
      generalize (instr_size_positive ifree) (instr_size_positive (Plabel l)). omega.
    }
  Qed.
  
  Lemma exec_instr_normal:
    forall rs1 rs2 m1 m2 b ofs f i rs2' m2',
      seq (State rs1 m1) (State rs2 m2) ->
      rs2 PC = Vptr b ofs ->
      Genv.find_funct_ptr ge b = Some (Internal f) ->
      find_instr (Ptrofs.unsigned ofs) (fn_code f) = Some i ->
      exec_instr ge f i rs2 m2 = Next rs2' m2' ->
      ~ intermediate_instruction i ->
      ~ is_call i ->
      ~ is_free i ->
      (exists rs1' m1',
        RawAsm.exec_instr ge f i rs1 m1 = Next rs1' m1' /\
        seq (State rs1' m1') (State rs2' m2')) /\
        match pc_at (State rs2' m2') with
        | Some (inl (_, i)) => ~ intermediate_instruction i
        | Some (inr ef) => False
        | None => True
        end.
  Proof.
    intros rs1 rs2 m1 m2 b ofs f i rs2' m2' SEQ PC2 FFP FI EI NII NIC NIF.
    simpl.
    inv SEQ.
    assert (RawAsm.exec_instr ge f i rs2 m2 = Next rs2' m2').
    {
      rewrite <- EI.
      destruct i; auto.
      contradict NIC; constructor.
      contradict NIC; constructor.
      contradict NII. constructor 2. auto.
      contradict NII. constructor. constructor.
      contradict NIF. constructor.
    } clear EI; rename H into EI.
    split.
    {
        destruct i; simpl in *; unfold exec_load, exec_store in *;
          erewrite ? eval_addrmode_seq by eauto;
          repeat erewrite ?  eval_testcond_seq by eauto;
          erewrite ? REQ by congruence;
          repeat destr_in EI;
          try (do 2 eexists; split; [eauto|constructor; intros; simpl; regs_eq;
                                           try eapply eval_addrmode32_seq ; now eauto
                                    ]; fail).
        do 2 eexists; split; [eauto|constructor; intros; simpl; regs_eq; repeat destr; simpl; regs_eq].
        do 2 eexists; split; [eauto|constructor; intros; simpl; regs_eq; repeat destr; simpl; regs_eq].
        eapply goto_label_match; eauto.
        eapply goto_label_match; eauto.
        erewrite eval_testcond_seq by eauto. rewrite Heqo0. eapply goto_label_match; eauto.
        erewrite eval_testcond_seq by eauto. rewrite Heqo0.
        do 2 eexists; split; [eauto|constructor; intros; simpl; regs_eq; repeat destr; simpl; regs_eq].
        erewrite eval_testcond_seq by eauto. rewrite Heqo0.
        do 2 eexists; split; [eauto|constructor; intros; simpl; regs_eq; repeat destr; simpl; regs_eq].
        eapply goto_label_match. 2: eauto. intros; regs_eq.
        contradict NII. constructor 2; auto.
        contradict NII. constructor. constructor.
    }
    destruct (Val.eq (rs2' PC) (Val.offset_ptr (rs2 PC) (Ptrofs.repr (instr_size i)))).
    {
      rewrite e, PC2. simpl. rewrite FFP.
      destr. repeat destr_in Heqo. rename Heqo0 into FI'.
      intro A.
      inv A.
      {
        inv H. exploit wf_asm_alloc_only_at_beginning. eauto. apply FI'.
        erewrite wf_asm_pc_repr; eauto.
        generalize (Ptrofs.unsigned_range ofs) (instr_size_positive i); omega.
      }
      {
        exploit wf_asm_ret_jmp_comes_after_freeframe; eauto.
        intros (o' & ifree & FI2 & IFREE & RNG).
        generalize (find_instr_no_overlap' _ _ _ _ _ FI FI2).
        erewrite wf_asm_pc_repr in RNG; eauto.
        rewrite RNG.
        intros [EQ|NOOV]. subst. congruence.
        generalize (instr_size_positive i) (instr_size_positive ifree). omega.
      }
    }
    
    destruct i; simpl in *; unfold exec_load, exec_store in EI; repeat destr_in EI;
      unfold compare_ints, compare_longs, compare_floats, compare_floats32 in n;
      repeat destr_in n;
      simpl_regs_in n; try congruence.
    generalize (goto_label_PC _ _ _ _ _ _ H0 _ _ PC2 FFP). simpl. intros (A & B); repeat destr; eauto.
    edestruct wf_asm_jmp_target_exists as (bf & fd & SA & FFP'); eauto. unfold Genv.symbol_address in SA; destr_in SA.
    contradict NII. econstructor 2. right. econstructor. eauto.
    contradict NII. econstructor 2. right. econstructor.
    generalize (goto_label_PC _ _ _ _ _ _ H0 _ _ PC2 FFP). simpl. intros (A & B); repeat destr; eauto.
    generalize (goto_label_PC _ _ _ _ _ _ H0 _ _ PC2 FFP). simpl. intros (A & B); repeat destr; eauto.
    generalize (goto_label_PC _ _ _ _ _ _ H0 _ _ PC2 FFP). simpl. intros (A & B); repeat destr; eauto.
    contradict NIC. constructor.
    contradict NIC. constructor.
    contradict NII. constructor 2. auto.
    rewrite PC2, FFP, FI. intro A. inv A. inv H. destruct H as [H|H]; inv H.
  Qed.
  
  Lemma real_asm_step rs:
    forall s2 t s2',
      step (Genv.globalenv prog) s2 t s2' ->
      forall s1 : state,
        match_states s1 s2 ->
        safe (RawAsm.semantics prog rs) s1 ->
        exists s1', RawAsm.step (Genv.globalenv prog) s1 t s1' /\ match_states s1' s2'.
  Proof.
    intros s2 t s2' STEP s1 MS SAFE.
    fold ge in STEP.
    inv MS.
    - simpl in PC1. repeat destr_in PC1.
      rewrite REQ in Heqv by congruence.
      inv STEP; rewrite_hyps. 2: inv ALLOC.
      inv ALLOC. simpl in H6. inv H6.
      eexists; split. eapply RawAsm.exec_step_internal. rewrite REQ by congruence; eauto.
      eauto. eauto.
      simpl. force_rewrite_match MEQ. eauto. f_equal.
      rewrite RRSP.
      eapply wf_asm_wf_allocframe in Heqo0; eauto. inv Heqo0.
      unfold Mem.storev, Mem.loadv in MEQ. destruct (rs2 RSP); simpl in *; try congruence.
      f_equal. apply ptrofs_cancel.
      eapply match_states_normal.
      constructor. intros. apply nextinstr_eq.
      intros; apply set_reg_eq. intros. apply set_reg_eq. eauto.
      auto.
      rewrite RRSP. rewrite Val.offset_ptr_assoc. f_equal.
      rewrite Ptrofs.sub_add_opp. rewrite Ptrofs.neg_add_distr. rewrite Ptrofs.add_commut.
      rewrite Ptrofs.neg_involutive. auto.
      simpl. simpl_regs. rewrite Heqv. simpl. rewrite Heqo.
      destr. destr_in Heqo1. inv Heqo1.
      intro A.
      inv A.
      {
        inv H. exploit wf_asm_alloc_only_at_beginning. eauto. apply Heqo0. intro I0.
        exploit wf_asm_alloc_only_at_beginning. eauto. apply Heqo2.
        rewrite Ptrofs.add_unsigned. rewrite I0.
        rewrite (Ptrofs.unsigned_repr (instr_size _)) by apply instr_size_repr.
        simpl.
        rewrite (Ptrofs.unsigned_repr (instr_size _)) by apply instr_size_repr.
        apply not_eq_sym. apply Z.lt_neq. apply instr_size_positive.
      }
      {
        exploit wf_asm_ret_jmp_comes_after_freeframe; eauto.
        intros (o' & ifree & FI & IFREE & RNG).
        exploit wf_asm_alloc_only_at_beginning; eauto.
        intro FALLOC.
        generalize (find_instr_no_overlap' _ _ _ _ _ FI Heqo0).
        erewrite wf_asm_pc_repr in RNG; eauto.
        rewrite RNG.
        intros [EQ|NOOV]. subst; inv IFREE.
        generalize (instr_size_positive (Pallocframe f sz)) (instr_size_positive ifree). omega.
      }
    - simpl in PC1. repeat destr_in PC1.
      rewrite REQ in Heqv by congruence.
      inv STEP; rewrite_hyps.
      assert (exists b o, rs2 RSP = Vptr b o).
      {
        unfold Mem.storev, Mem.loadv in MEQ. destruct (rs2 RSP); simpl in *; try congruence. eauto.
      }
      destruct H as (b & o & RSP2).
      assert (rs1 RA = ra /\ Val.has_type ra Tptr).
      {
        unfold Mem.storev in MEQ. destr_in MEQ.
        split. destr_in MEQ.
        rewrite RSP2 in *. simpl in *.
        erewrite Mem.load_store_same in LOADRA; eauto. inv LOADRA.
        change Mptr with (chunk_of_type Tptr).
        symmetry.  apply Val.load_result_same.
        revert RA_NOT_VUNDEF. unfold Val.load_result, Mptr, Tptr.
        destruct ptr64 eqn:PTR, (rs1 RA); simpl; try congruence. auto.
        rewrite RSP2 in *. eapply Mem.load_type in LOADRA. 
        change Tptr with (type_of_chunk Mptr). auto.
      } destruct H; subst.
      eexists; split. eapply RawAsm.exec_step_external. rewrite REQ by congruence; eauto.
      eauto. 
      rewrite RRSP. apply offset_ptr_has_type.
      auto.
      rewrite RRSP. rewrite RSP2; simpl; congruence.
      auto.
      rewrite <- MEQ. f_equal.
      rewrite RRSP. rewrite offset_ptr_cancel. eauto. eauto.
      eapply extcall_arguments_eq_rs. 2: apply H3.
      intros. setoid_rewrite Pregmap.gsspec. rewrite <- RRSP.
      destr. symmetry; apply REQ. auto. auto.
      eauto. eauto.
      eapply match_states_normal.
      constructor. intros.
      destruct (preg_eq r RSP). subst. simpl_regs.
      rewrite set_pair_no_rsp.
      rewrite Asmgenproof0.undef_regs_other.
      rewrite Asmgenproof0.undef_regs_other_2.
      auto.
      apply rsp_not_destroyed_at_call.
      simpl. intuition subst; congruence.
      apply no_rsp_loc_external_result.
      rewrite (Pregmap.gso _ _ n).
      intros; apply set_reg_eq.
      intros. apply set_reg_eq.
      intros. apply set_pair_eq.
      intros. apply undef_regs_eq.
      intros. apply undef_regs_eq.  intros; apply REQ. congruence.
      auto. auto. auto.
      simpl. simpl_regs.
      (* RA does not point to an intermediate instruction (alloc/ret/jmp) or an external function. *)
      admit.
    - simpl in PC1. repeat destr_in PC1.
      rewrite REQ in Heqv by congruence. inv STEP; rewrite_hyps.
      simpl in H6. destr_in H6. inv H6. inv LOADRA.
      eexists; split. eapply RawAsm.exec_step_internal. rewrite REQ by congruence; eauto. eauto. eauto.
      simpl. eauto.
      apply match_states_normal.
      + constructor. intros. apply set_reg_eq; auto.
        intros. apply set_reg_eq. intros.
        setoid_rewrite Pregmap.gsspec. destr. apply REQ. auto. auto. reflexivity.
      + simpl. simpl_regs.
        (* RA does not point to an intermediate instruction (alloc/ret/jmp) or an external function. *)
        admit.
    - simpl in PC1. repeat destr_in PC1.
      rewrite REQ in Heqv by congruence. inv STEP; rewrite_hyps. 2: now (inv JMP).
      inv JMP.
      + simpl in H6. inv H6.
        eexists; split. eapply RawAsm.exec_step_internal. rewrite REQ by congruence; eauto. eauto. eauto.
        simpl. eauto.
        edestruct wf_asm_jmp_target_exists as (bf & f'  & SA & FFP); eauto. assert (bf = b).
        unfold Genv.symbol_address in SA; rewrite H in SA. inv SA. auto. subst. fold ge. rewrite SA.
        destruct f'.
        * eapply match_states_call_alloc.
          intros. apply set_reg_eq; auto.
          simpl_regs. auto.
          simpl_regs.  unfold Mem.storev. rewrite MEQ. destr.
          simpl. rewrite FFP.
          erewrite wf_asm_alloc_at_beginning; eauto. constructor.
        * eapply match_states_call_external.
          intros. apply set_reg_eq; auto.
          simpl_regs. auto.
          simpl_regs.  unfold Mem.storev. rewrite MEQ. destr.
          simpl. rewrite FFP. eauto.
      + simpl in H6. destr_in H6. inv H6.
        eexists; split. eapply RawAsm.exec_step_internal. rewrite REQ by congruence; eauto. eauto. eauto.
        fold ge. simpl. rewrite REQ. rewrite Heqo1. eauto.
        eapply wf_asm_jmp_no_rsp in Heqo0; eauto. congruence. congruence.
        unfold Genv.find_funct in Heqo1. repeat destr_in Heqo1.
        destruct f.
        * eapply match_states_call_alloc.
          intros. apply set_reg_eq; auto.
          simpl_regs. auto.
          simpl_regs.  unfold Mem.storev. rewrite MEQ. destr.
          simpl. simpl_regs. rewrite H0.
          erewrite wf_asm_alloc_at_beginning; eauto. constructor.
        * eapply match_states_call_external.
          intros. apply set_reg_eq; auto.
          simpl_regs. auto.
          simpl_regs.  unfold Mem.storev. rewrite MEQ. destr.
          simpl. rewrite H0. eauto.
    - inv STEP; simpl in *; rewrite H, H0, ? H1 in PC1.
      + destruct (is_call_dec i).
        {
          inv H3.
          * simpl in H2. destr_in H2. inv H2.
            inv SEQ.
            eexists; split.
            eapply RawAsm.exec_step_internal.
            rewrite REQ; eauto. congruence. eauto. eauto.
            simpl. eauto.
            edestruct wf_asm_call_target_exists as (bf & fd & SA & FFP); eauto.
            fold ge. rewrite SA.
            destruct fd.
            eapply match_states_call_alloc.
            intros. rewrite (Pregmap.gso _ _ H2). apply set_reg_eq; auto. intros; apply set_reg_eq. auto.
            rewrite REQ; auto. congruence.
            simpl_regs. rewrite REQ by congruence.
            etransitivity. symmetry; apply offset_ptr_cancel.
            unfold Mem.storev, Mem.loadv in Heqo. destruct (rs0 RSP); simpl in *; try congruence; eauto.
            f_equal. apply Ptrofs.neg_involutive.
            simpl_regs.  rewrite REQ by congruence. auto.
            simpl. rewrite FFP.
            erewrite wf_asm_alloc_at_beginning; eauto. constructor.
            eapply match_states_call_external.
            intros. rewrite (Pregmap.gso _ _ H2). apply set_reg_eq; auto. intros; apply set_reg_eq. auto.
            rewrite REQ; auto. congruence.
            simpl_regs. rewrite REQ by congruence.
            etransitivity. symmetry; apply offset_ptr_cancel.
            unfold Mem.storev, Mem.loadv in Heqo. destruct (rs0 RSP); simpl in *; try congruence; eauto.
            f_equal. apply Ptrofs.neg_involutive.
            simpl_regs.  rewrite REQ by congruence; auto.
            simpl. rewrite FFP. eauto.
          * simpl in H2.
            destruct (SAFE _ (star_refl _ _ _)) as [(rr & FS)|(t & s' & STEP)].
            simpl in FS. inv FS. contradict H3. inv SEQ. rewrite REQ by congruence. rewrite H. inversion 1.
            simpl in STEP. fold ge in STEP.
            assert (t = E0).
            {
              inv SEQ. rewrite <- REQ in H by congruence.
              inv STEP; rewrite_hyps; auto.
            } subst.
            eexists; split. eauto.
            edestruct step_internal; eauto. inv SEQ. simpl. rewrite REQ, H, H0, H1. eauto. congruence. inversion 1.
            simpl in H3. destr_in H3. inv H3.
            unfold Genv.find_funct in Heqo. repeat destr_in Heqo.
            inv SEQ. simpl in *. subst. destruct s'. simpl in *. subst.
            destr_in H2. inv H2.
            destruct f0.
            eapply match_states_call_alloc.
            intros. rewrite (Pregmap.gso _ _ H2). apply set_reg_eq; auto. intros; apply set_reg_eq. auto.
            rewrite REQ by congruence; auto. rewrite <- REQ by congruence; auto.
            simpl_regs. rewrite REQ by congruence.
            etransitivity. symmetry; apply offset_ptr_cancel.
            unfold Mem.storev, Mem.loadv in Heqo. destruct (rs0 RSP); simpl in *; try congruence; eauto.
            f_equal. apply Ptrofs.neg_involutive.
            simpl_regs.  rewrite REQ by congruence; auto.
            simpl. rewrite H5.
            erewrite wf_asm_alloc_at_beginning; eauto. constructor.
            eapply match_states_call_external.
            intros. rewrite (Pregmap.gso _ _ H2). apply set_reg_eq; auto. intros; apply set_reg_eq. auto.
            rewrite REQ by congruence; auto. rewrite <- REQ by congruence; auto.
            simpl_regs. rewrite REQ by congruence.
            etransitivity. symmetry; apply offset_ptr_cancel.
            unfold Mem.storev, Mem.loadv in Heqo. destruct (rs0 RSP); simpl in *; try congruence; eauto.
            f_equal. apply Ptrofs.neg_involutive.
            simpl_regs. rewrite REQ by congruence; auto.
            simpl. rewrite H5. eauto.
        }
        destruct (is_free_dec i).
        {
          inv H4.
          simpl in H2.
          destruct (SAFE _ (star_refl _ _ _)) as [(rr & FS)|(t & s' & STEP)].
          simpl in FS. inv FS. contradict H4. inv SEQ. rewrite REQ by congruence. rewrite H. inversion 1.
          simpl in STEP. fold ge in STEP.
          assert (t = E0).
          {
            inv SEQ. rewrite <- REQ in H by congruence.
            inv STEP; rewrite_hyps; auto.
          } subst.
          eexists; split. eauto.
          edestruct step_internal; eauto. inv SEQ. simpl. rewrite REQ, H, H0, H1 by congruence. eauto. inversion 1.
          simpl in H4. destr_in H4. inv H4.
          inv SEQ. simpl in *. subst. destruct s'. simpl in *. subst.
          inv H2.
          edestruct wf_asm_after_freeframe as (i' & FI & RJ); eauto. constructor.
          destruct RJ as [RET|JMP].
          - eapply match_states_free_ret.
            intros.
            apply nextinstr_eq.
            rewrite (Pregmap.gso _ _ H4). simpl_regs. auto. 
            rewrite REQ by congruence; auto. 
            simpl_regs.
            rewrite Val.offset_ptr_assoc. f_equal.
            generalize (Ptrofs.repr (align (Z.max 0 sz) 8)).
            generalize (Ptrofs.repr (size_chunk Mptr)).
            intros. rewrite <- Ptrofs.sub_add_l.
            rewrite Ptrofs.sub_add_opp.
            rewrite Ptrofs.add_assoc. rewrite Ptrofs.add_neg_zero. rewrite Ptrofs.add_zero; auto.
            simpl_regs.
            rewrite <- Heqo. f_equal.
            rewrite <- REQ by congruence; auto.
            eapply wf_asm_free_spec in H1; eauto. f_equal. destruct H1 as (SZ & ORA); subst. auto.
            simpl. simpl_regs. rewrite REQ, H by congruence. simpl. rewrite H0. rewrite FI. subst; eauto.
          - eapply match_states_free_jmp.
            intros.
            apply nextinstr_eq.
            rewrite (Pregmap.gso _ _ H4). simpl_regs. auto. 
            rewrite REQ by congruence; auto. 
            simpl_regs.
            rewrite Val.offset_ptr_assoc. f_equal.
            generalize (Ptrofs.repr (align (Z.max 0 sz) 8)).
            generalize (Ptrofs.repr (size_chunk Mptr)).
            intros. rewrite <- Ptrofs.sub_add_l.
            rewrite Ptrofs.sub_add_opp.
            rewrite Ptrofs.add_assoc. rewrite Ptrofs.add_neg_zero. rewrite Ptrofs.add_zero; auto.
            simpl_regs.
            rewrite <- Heqo. f_equal.
            rewrite <- REQ by congruence; auto.
            eapply wf_asm_free_spec in H1; eauto. f_equal. destruct H1 as (SZ & ORA); subst. auto.
            simpl. simpl_regs. rewrite REQ, H by congruence. simpl. rewrite H0. rewrite FI. subst; eauto.
            auto.
        }


        destruct s1. simpl in *. fold ge.
        edestruct exec_instr_normal as ((rs1' & m1' & EI & SEQ') & NEXT); eauto.
        eexists; split.
        inv SEQ. 
        eapply RawAsm.exec_step_internal; eauto.
        rewrite REQ by congruence; eauto.
        apply match_states_normal. auto. auto.
      + inv SEQ. eexists; split. eapply RawAsm.exec_step_builtin; eauto.
        rewrite REQ by congruence; eauto.
        eapply eval_builtin_args_eq_rs. 3: rewrite REQ by congruence; apply H2. intros; symmetry; apply REQ; auto.
        eapply wf_asm_builtin_not_PC; eauto.
        apply match_states_normal.
        constructor. intros. apply nextinstr_nf_eq.
        apply set_res_eq. apply undef_regs_eq. intros; auto.
        simpl. simpl_regs. rewrite set_res_other.
        rewrite Asmgenproof0.undef_regs_other_2. rewrite H; simpl. rewrite H0.
        2: apply pc_not_destroyed_builtin.
        2: eapply wf_asm_builtin_not_PC; eauto.
        destr. destr_in Heqo. inv Heqo.
        intro II; inv II.
        {
          inv H4. exploit wf_asm_alloc_only_at_beginning. eauto. apply Heqo0.
          erewrite wf_asm_pc_repr; eauto.
          apply not_eq_sym. apply Z.lt_neq.
          generalize (Ptrofs.unsigned_range ofs) (instr_size_positive (Pbuiltin ef args res)). omega.
        }
        {
          exploit wf_asm_ret_jmp_comes_after_freeframe; eauto.
          intros (o' & ifree & FI & IFREE & RNG).
          erewrite wf_asm_pc_repr in RNG; eauto.
          erewrite wf_asm_pc_repr in Heqo0; eauto.
          generalize (find_instr_no_overlap' _ _ _ _ _ FI H1).
          rewrite RNG.
          intros [EQ|NOOV]. subst; inv IFREE.
          generalize (instr_size_positive (Pbuiltin ef args res)) (instr_size_positive ifree). omega.
        }
      + easy.
  Admitted.

  Theorem real_asm_correct rs:
    backward_simulation (RawAsm.semantics prog rs) (RealAsm.semantics prog rs).
  Proof.
    eapply backward_simulation_plus with (match_states := match_states).
    - reflexivity.
    - simpl; intros s1 IS1. inv IS1. inv H0.
      edestruct (Mem.valid_access_store m3 Mptr bstack0 (Mem.stack_limit - size_chunk Mptr) Vnullptr).
      split;[|split].
      red; intros. repeat rewrite_perms. rewrite peq_true. split.
      cut (size_chunk Mptr <=  Mem.stack_limit). omega. apply stack_limit_range'.
      constructor.
      apply Z.divide_sub_r. apply Mem.stack_limit_aligned. apply align_size_chunk_divides.
      intros.
      red. rewrite_stack_blocks. intro. left. unfold is_stack_top. simpl. auto.
      eexists; econstructor. eauto. econstructor; eauto.
      unfold Mem.storev.
      simpl. erewrite Mem.load_unchanged_on. rewrite pred_dec_false. rewrite Ptrofs.unsigned_repr. eauto. 
      generalize stack_limit_range'. generalize (size_chunk_pos Mptr). omega.
      Focus 2. eapply Mem.strong_unchanged_on_weak, Mem.record_stack_block_unchanged_on. eauto.
      Focus 3. erewrite Mem.load_drop. 2: eauto.
      eapply Mem.load_alloc_same'. eauto. apply Ptrofs.unsigned_range.
      rewrite Ptrofs.unsigned_repr. omega.
      generalize stack_limit_range'. generalize (size_chunk_pos Mptr); omega.
      rewrite Ptrofs.unsigned_repr. apply Z.divide_sub_r. apply Mem.stack_limit_aligned. apply align_size_chunk_divides.
      generalize stack_limit_range'. generalize (size_chunk_pos Mptr); omega.
      right. right. right. constructor.
      inversion 1.
      instantiate (1 := fun _ _ => True). simpl; auto.
    - eapply initial_states_match.
    - simpl; intros s1 s2 r MS FS; inv FS.
      assert (pc_at s1 = None).
      {
        generalize (match_states_PC _ _ MS). intros PCeq.
        unfold pc_at. destr.  simpl in *. rewrite PCeq.
        rewrite H. unfold Vnullptr. destruct ptr64; simpl; auto.
      }
      inv MS; try congruence.
      inv SEQ. simpl in *.
      constructor. rewrite REQ by congruence. auto. rewrite REQ; auto. congruence.
    - simpl.
      eapply real_asm_progress.
    - simpl.
      intros.
      edestruct real_asm_step as (s1' & STEP & MS); eauto.
      exists s1'; split; eauto. apply plus_one; auto.
  Qed.

End WITHMEMORYMODEL.