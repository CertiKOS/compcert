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

Section WITHMEMORYMODEL.

  Existing Instance mem_accessors_default.
  Context `{memory_model_ops: Mem.MemoryModelOps}.
  Context `{external_calls_ops : !ExternalCallsOps mem}.
  Context `{enable_builtins: !EnableBuiltins mem}.

Section WITHGE.
  Variable ge : Genv.t Asm.fundef unit.

  Definition exec_instr f i' rs (m: mem) :=
    match i' with
    | (i,isz) =>
    match i with
    | Pallocframe fi ofs_ra =>
      let sp := Val.offset_ptr (rs RSP) (Ptrofs.neg (Ptrofs.repr (align (frame_size fi) 8))) in
      match Mem.storev Mptr m (Val.offset_ptr sp ofs_ra) rs#RA with
      | None => Stuck
      | Some m2 =>
        Next (nextinstr (rs #RAX <- (rs#RSP) #RSP <- sp) (Ptrofs.repr (si_size isz))) m2
      end
    | Pfreeframe sz ofs_ra =>
      match Mem.loadv Mptr m (Val.offset_ptr rs#RSP ofs_ra) with
      | None => Stuck
      | Some ra =>
        let sp := Val.offset_ptr (rs RSP) (Ptrofs.repr (align (Z.max 0 sz) 8)) in
        Next (nextinstr (rs#RSP <- sp #RA <- ra) (Ptrofs.repr (si_size isz))) m
      end
    | Pload_parent_pointer rd z =>
      let sp := Val.offset_ptr (rs RSP) (Ptrofs.repr (align (Z.max 0 z) 8)) in
      Next (nextinstr (rs#rd <- sp) (Ptrofs.repr (si_size isz))) m
    | Pcall_s id sg =>
      Next (rs#RA <- (Val.offset_ptr rs#PC (Ptrofs.repr (si_size isz))) #PC <- (Genv.symbol_address ge id Ptrofs.zero)) m
    | Pcall_r r sg =>
      Next (rs#RA <- (Val.offset_ptr rs#PC (Ptrofs.repr (si_size isz))) #PC <- (rs r)) m
    | Pret => Next (rs#PC <- (rs#RA) #RA <- Vundef) m
    | _ => Asm.exec_instr nil ge f i' rs m
    end
    end.
  
  Inductive step  : state -> trace -> state -> Prop :=
  | exec_step_internal:
      forall b ofs f i rs m rs' m',
        rs PC = Vptr b ofs ->
        Genv.find_funct_ptr ge b = Some (Internal f) ->
        find_instr (Ptrofs.unsigned ofs) (fn_code f) = Some i ->
        exec_instr f i rs m = Next rs' m' ->
        step (State rs m) E0 (State rs' m')
  | exec_step_builtin:
      forall b ofs f ef args res rs m vargs t vres rs' m' sz,
        rs PC = Vptr b ofs ->
        Genv.find_funct_ptr ge b = Some (Internal f) ->
        find_instr (Ptrofs.unsigned ofs) f.(fn_code) = Some (Pbuiltin ef args res,sz) ->
        eval_builtin_args ge rs (rs RSP) m args vargs ->
        external_call ef ge vargs m t vres m' ->
        forall BUILTIN_ENABLED: builtin_enabled ef,
          rs' = nextinstr_nf
                  (set_res res vres
                           (undef_regs (map preg_of (destroyed_by_builtin ef)) rs))
                  (Ptrofs.repr (si_size sz)) ->
          step (State rs m) t (State rs' m')
  | exec_step_external:
      forall b ef args res rs m t rs' m',
        rs PC = Vptr b Ptrofs.zero ->
        Genv.find_funct_ptr ge b = Some (External ef) ->
        extcall_arguments rs m (ef_sig ef) args ->
        forall (SP_TYPE: Val.has_type (rs RSP) Tptr)
          (RA_TYPE: Val.has_type (rs RA) Tptr)
          (SP_NOT_VUNDEF: rs RSP <> Vundef)
          (RA_NOT_VUNDEF: rs RA <> Vundef), 
          external_call ef ge args m t res m' ->
          rs' = (set_pair (loc_external_result (ef_sig ef)) res (undef_regs (CR ZF :: CR CF :: CR PF :: CR SF :: CR OF :: nil) (undef_regs (map preg_of destroyed_at_call) rs))) #PC <- (rs RA) #RA <- Vundef ->
          step (State rs m) t (State rs' m').

End WITHGE.

  Definition frame_info_mono: frame_info :=
    {|
      frame_size := Mem.stack_limit;
      frame_perm := fun o => Public;
      frame_size_pos := proj1 Mem.stack_limit_range;
    |}.

  
  Inductive initial_state_gen (prog: Asm.program) (rs: regset) m: state -> Prop :=
  | initial_state_gen_intro:
      forall m1 bstack m2 m3
        (MALLOC: Mem.alloc m 0 (Mem.stack_limit) = (m1,bstack))
        (MDROP: Mem.drop_perm m1 bstack 0 (Mem.stack_limit) Writable = Some m2)
        (MRSB: Mem.record_stack_blocks (Mem.push_new_stage m2) (make_singleton_frame_adt' bstack frame_info_mono 0) = Some m3),
        let ge := Genv.globalenv prog in
        let rs0 :=
            rs # PC <- (Genv.symbol_address ge prog.(prog_main) Ptrofs.zero)
               #RA <- Vnullptr
               #RSP <- (Vptr bstack (Ptrofs.repr Mem.stack_limit)) in
        initial_state_gen prog rs m (State rs0 m3).

  Inductive initial_state (prog: Asm.program) (rs: regset) (s: state): Prop :=
  | initial_state_intro: forall m,
      Genv.init_mem prog = Some m ->
      initial_state_gen prog rs m s ->
      initial_state prog rs s.

  Definition semantics_gen prog rs m :=
    Semantics step (initial_state_gen prog rs m) final_state (Genv.globalenv prog).

  Definition semantics prog rs :=
    Semantics step (initial_state prog rs) final_state (Genv.globalenv prog).

End WITHMEMORYMODEL.

Section WITHMEMORYMODEL2.

  Existing Instance mem_accessors_default.
  Context `{external_calls_prf : ExternalCalls }.

  Lemma semantics_gen_determinate:
    forall p m rs,
      determinate (semantics_gen p rs m).
  Proof.
    Ltac Equalities :=
      match goal with
      | [ H1: ?a = ?b, H2: ?a = ?c |- _ ] =>
        rewrite H1 in H2; inv H2; Equalities
      | _ => idtac
      end.
    intros; constructor; simpl; intros.
    - (* determ *)
      inv H; inv H0; Equalities.
      + split. constructor. auto.
      + discriminate.
      + discriminate.
      + assert (vargs0 = vargs) by (eapply Events.eval_builtin_args_determ; eauto). subst vargs0.
        exploit Events.external_call_determ. eexact H5. eexact H11. intros [A B].
        split. auto. intros. destruct B; auto. subst. auto.
      + assert (args0 = args) by (eapply Asm.extcall_arguments_determ; eauto). subst args0.
        exploit Events.external_call_determ. eexact H4. eexact H9. intros [A B].
        split. auto. intros. destruct B; auto. subst. auto.
    - (* trace length *)
      red; intros; inv H; simpl.
      omega.
      eapply Events.external_call_trace_length; eauto.
      eapply Events.external_call_trace_length; eauto.
    - (* initial states *)
      inv H; inv H0.
      assert (m1 = m0 /\ bstack = bstack0) by intuition congruence. destruct H; subst.
      assert (m2 = m4) by congruence. subst.
      f_equal. congruence.
    - (* final no step *)
      assert (NOTNULL: forall b ofs, Values.Vnullptr <> Values.Vptr b ofs).
      { intros; unfold Values.Vnullptr; destruct Archi.ptr64; congruence. }
      inv H. red; intros; red; intros. inv H; rewrite H0 in *; eelim NOTNULL; eauto.
    - (* final states *)
      inv H; inv H0. congruence.
  Qed.


  Lemma semantics_determinate:
    forall p rs,
      determinate (semantics p rs).
  Proof.
    intros; constructor; simpl; intros.
    - (* determ *)
      inv H; inv H0; Equalities.
      + split. constructor. auto.
      + discriminate.
      + discriminate.
      + assert (vargs0 = vargs) by (eapply Events.eval_builtin_args_determ; eauto). subst vargs0.
        exploit Events.external_call_determ. eexact H5. eexact H11. intros [A B].
        split. auto. intros. destruct B; auto. subst. auto.
      + assert (args0 = args) by (eapply Asm.extcall_arguments_determ; eauto). subst args0.
        exploit Events.external_call_determ. eexact H4. eexact H9. intros [A B].
        split. auto. intros. destruct B; auto. subst. auto.
    - (* trace length *)
      red; intros; inv H; simpl.
      omega.
      eapply Events.external_call_trace_length; eauto.
      eapply Events.external_call_trace_length; eauto.
    - (* initial states *)
      inv H; inv H0. assert (m = m0) by congruence. subst. inv H2; inv H3.
      assert (m1 = m4 /\ bstack = bstack0) by intuition congruence. destruct H0; subst.
      assert (m2 = m5) by congruence. subst.
      f_equal. congruence.
    - (* final no step *)
      assert (NOTNULL: forall b ofs, Values.Vnullptr <> Values.Vptr b ofs).
      { intros; unfold Values.Vnullptr; destruct Archi.ptr64; congruence. }
      inv H. red; intros; red; intros. inv H; rewrite H0 in *; eelim NOTNULL; eauto.
    - (* final states *)
      inv H; inv H0. congruence.
  Qed.

  
End WITHMEMORYMODEL2.
