Require Import RelationClasses.

From Paco Require Import paco.
From sflib Require Import sflib.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import DataStructure.
From PromisingLib Require Import Language.
From PromisingLib Require Import Loc.
Require Import Time.
Require Import Event.
Require Import View.
Require Import Cell.
Require Import Memory.
Require Import MemoryFacts.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.
Require Import Progress.
Require Import Behavior.
Require Import Cover.
Require Import Pred.
Require Import Trace.

Require Import PromiseConsistent.
Require Import PFConsistent.
Require Import MemoryProps.
Require Import Single.

Set Implicit Arguments.



Section LOCALPF.

  Variable L: Loc.t -> bool.

  Definition pf_event (e: ThreadEvent.t): Prop :=
    forall loc from to msg kind (PROMISE: e = ThreadEvent.promise loc from to msg kind) (LOC: L loc),
      msg = Message.reserve.

  Definition pf_consistent lang (th: Thread.t lang): Prop :=
    exists tr_cert,
      (<<CONSISTENT: Trace.consistent th tr_cert>>) /\
      (<<PFCERT: List.Forall (compose pf_event snd) tr_cert>>).

  Lemma pf_consistent_consistent lang (th: Thread.t lang)
        (CONSISTENT: pf_consistent th)
    :
      Thread.consistent th.
  Proof.
    ii. unfold pf_consistent in *. des.
    exploit CONSISTENT0; eauto. i. des.
    { eapply Trace.silent_steps_tau_steps in STEPS; eauto.
      left. unfold Thread.steps_failure. esplits; eauto. }
    { eapply Trace.silent_steps_tau_steps in STEPS; eauto. }
  Qed.


  (* a single thread steps per one configuration step *)
  Inductive pf_step:
    forall (e:ThreadEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop :=
  | pf_step_intro
      e tid c1 lang st1 lc1 e2 e3 st4 lc4 sc4 memory4
      (TID: IdentMap.find tid c1.(Configuration.threads) = Some (existT _ lang st1, lc1))
      (CANCELS: rtc (@Thread.cancel_step _) (Thread.mk _ st1 lc1 c1.(Configuration.sc) c1.(Configuration.memory)) e2)
      (STEP: Thread.opt_step e e2 e3)
      (RESERVES: rtc (@Thread.reserve_step _) e3 (Thread.mk _ st4 lc4 sc4 memory4))
      (CONSISTENT: e <> ThreadEvent.failure -> pf_consistent (Thread.mk _ st4 lc4 sc4 memory4))
      (PF: pf_event e)
    :
      pf_step e tid c1 (Configuration.mk (IdentMap.add tid (existT _ _ st4, lc4) c1.(Configuration.threads)) sc4 memory4)
  .
  Hint Constructors pf_step.

  Inductive pf_machine_step: forall (e:MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop :=
  | pf_machine_step_intro
      e tid c1 c2
      (STEP: pf_step e tid c1 c2)
    :
      pf_machine_step (ThreadEvent.get_machine_event e) tid c1 c2
  .
  Hint Constructors pf_machine_step.

  Inductive opt_pf_machine_step:
    forall (e: MachineEvent.t) (tid: Ident.t) (c1 c2: Configuration.t), Prop :=
  | opt_pf_machine_step_none
      tid c:
      opt_pf_machine_step MachineEvent.silent tid c c
  | opt_pf_machine_step_some
      e tid c1 c2
      (STEP: pf_machine_step e tid c1 c2):
      opt_pf_machine_step e tid c1 c2
  .
  Hint Constructors opt_pf_machine_step.

  Definition tau_pf_machine_step := union (pf_machine_step MachineEvent.silent).

  Inductive pf_all_step (c1 c2: Configuration.t): Prop :=
  | pf_all_step_intro
      e tid
      (STEP: pf_step e tid c1 c2)
  .
  Hint Constructors pf_all_step.

  Inductive pf_steps:
    forall (es: list ThreadEvent.t) (tid: Ident.t) (c1 c2:Configuration.t), Prop :=
  | pf_steps_nil
      tid c1
    :
      pf_steps [] tid c1 c1
  | pf_steps_cons
      ehd etl tid c1 c2 c3
      (STEP: pf_step ehd tid c1 c2)
      (STEPS: pf_steps etl tid c2 c3)
    :
      pf_steps (ehd :: etl) tid c1 c3
  .
  Hint Constructors pf_steps.

  Lemma pf_steps_rtc_pf_all_step es tid c1 c2
        (STEPS: pf_steps es tid c1 c2)
    :
      rtc pf_all_step c1 c2.
  Proof.
    induction STEPS; eauto.
  Qed.

  Lemma pf_steps_split es0 es1 tid c0 c2
        (STEPS: pf_steps (es0 ++ es1) tid c0 c2)
    :
      exists c1,
        (<<STEPS0: pf_steps es0 tid c0 c1>>) /\
        (<<STEPS1: pf_steps es1 tid c1 c2>>).
  Proof.
    ginduction es0; eauto. i. ss. inv STEPS.
    exploit IHes0; eauto. i. des.
    esplits; eauto.
  Qed.

  Lemma silent_pf_steps_tau_pf_machine_steps es tid c1 c2
        (STEPS: pf_steps es tid c1 c2)
        (SILENT: List.Forall (fun e => ThreadEvent.get_machine_event e = MachineEvent.silent) es)
    :
      rtc (pf_machine_step MachineEvent.silent tid) c1 c2.
  Proof.
    ginduction es; i.
    { inv STEPS. eauto. }
    { inv STEPS. inv SILENT. exploit IHes; eauto.
      i. econs 2; eauto. rewrite <- H1. econs; eauto. }
  Qed.

  Inductive reading_event (loc: Loc.t) (ts: Time.t):
    forall (e: ThreadEvent.t), Prop :=
  | reading_event_read
      valr releasedr ordr
    :
      reading_event loc ts (ThreadEvent.read loc ts valr releasedr ordr)
  | reading_event_update
      to valr valw releasedr releasedw ordr ordw
    :
      reading_event loc ts (ThreadEvent.update loc ts to valr valw releasedr releasedw ordr ordw)
  .

  Inductive writing_event (loc: Loc.t) (ts: Time.t):
    forall (e: ThreadEvent.t), Prop :=
  | writing_event_write
      from valw releasedw ordw
      (ORD: Ordering.le ordw Ordering.relaxed)
    :
      writing_event loc ts (ThreadEvent.write loc from ts valw releasedw ordw)
  | writing_event_update
      from valr valw releasedr releasedw ordr ordw
      (ORD: Ordering.le ordw Ordering.relaxed)
    :
      writing_event loc ts (ThreadEvent.update loc from ts valr valw releasedr releasedw ordr ordw)
  .

  Definition pf_racefree_imm (c0: Configuration.t): Prop :=
    forall tid0 c1 tid1 c2 c3
           loc ts te0 te1 e0 e1
           (LOC: L loc)
           (TID: tid0 <> tid1)
           (CSTEP0: pf_step e0 tid0 c0 c1)
           (WRITE: writing_event loc ts te0)
           (STEPS: rtc (pf_machine_step MachineEvent.silent tid1) c1 c2)
           (CSTEP1: pf_step e1 tid1 c2 c3)
           (READ: reading_event loc ts te1),
      False.

  Definition pf_racefree (c0: Configuration.t): Prop :=
    forall c1
           (CSTEPS: rtc pf_all_step c0 c1),
      pf_racefree_imm c1.

  Lemma step_pf_racefree c0 c1 e tid
        (RACEFREE: pf_racefree c0)
        (STEP: pf_step e tid c0 c1)
    :
      pf_racefree c1.
  Proof.
    unfold pf_racefree in *. i.
    eapply RACEFREE. econs 2; eauto.
  Qed.

  Lemma rtc_tau_machine_step_pf_racefree c0 c1
        (RACEFREE: pf_racefree c0)
        (STEP: rtc tau_pf_machine_step c0 c1)
    :
      pf_racefree c1.
  Proof.
    ginduction STEP; eauto.
    i. eapply IHSTEP. inv H. inv USTEP.
    eapply step_pf_racefree; eauto.
  Qed.

  Lemma steps_pf_racefree es tid c0 c1
        (RACEFREE: pf_racefree c0)
        (STEPS: pf_steps es tid c0 c1)
    :
      pf_racefree c1.
  Proof.
    ginduction STEPS; eauto.
    i. eapply IHSTEPS.
    eapply step_pf_racefree; eauto.
  Qed.

  Definition pf_promises (prom: Memory.t): Prop :=
    forall loc to from msg
           (LOC: L loc)
           (GET: Memory.get loc to prom = Some (from, msg)),
      msg = Message.reserve.

  Lemma pf_promises_promise prom0 mem0 loc from to msg prom1 mem1 kind
        (PROMISE: Memory.promise prom0 mem0 loc from to msg prom1 mem1 kind)
        (PF: L loc -> msg = Message.reserve)
        (PROMISES: pf_promises prom0)
    :
      pf_promises prom1.
  Proof.
    inv PROMISE.
    - ii. erewrite Memory.add_o in GET; eauto. des_ifs.
      + ss. des; clarify. auto.
      + eapply PROMISES; eauto.
    - ii. erewrite Memory.split_o in GET; eauto. des_ifs.
      + ss. des; clarify. auto.
      + ss. des; clarify. exploit PF; ss.
      + eapply PROMISES; eauto.
    - ii. erewrite Memory.lower_o in GET; eauto. des_ifs.
      + ss. des; clarify. auto.
      + eapply PROMISES; eauto.
    - ii. erewrite Memory.remove_o in GET; eauto. des_ifs.
      eapply PROMISES; eauto.
  Qed.

  Lemma pf_promises_write prom0 mem0 loc from to val released prom1 mem1 kind
        (WRITE: Memory.write prom0 mem0 loc from to val released prom1 mem1 kind)
        (PROMISES: pf_promises prom0)
    :
      pf_promises prom1.
  Proof.
    inv WRITE. ii. erewrite Memory.remove_o in GET; eauto. des_ifs.
    inv PROMISE.
    - ii. erewrite Memory.add_o in GET; eauto. des_ifs.
      + ss. des; clarify.
      + eapply PROMISES; eauto.
    - ii. erewrite Memory.split_o in GET; eauto. des_ifs.
      + ss. des; clarify.
      + ss. des; clarify.
        eapply Memory.split_get0 in PROMISES0. des.
        eapply PROMISES in GET0; eauto.
      + eapply PROMISES; eauto.
    - ii. erewrite Memory.lower_o in GET; eauto. des_ifs.
      + ss. des; clarify.
      + eapply PROMISES; eauto.
    - ii. erewrite Memory.remove_o in GET; eauto. des_ifs.
  Qed.

  Lemma pf_promises_step lang (th0 th1: Thread.t lang) pf e
        (STEP: Thread.step pf e th0 th1)
        (PF: pf_event e)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      pf_promises th1.(Thread.local).(Local.promises).
  Proof.
    inv STEP.
    - inv STEP0; ss. inv LOCAL.
      eapply pf_promises_promise; eauto.
    - inv STEP0. inv LOCAL; ss.
      + inv LOCAL0; ss.
      + inv LOCAL0; ss.
        eapply pf_promises_write; eauto.
      + inv LOCAL1. inv LOCAL2; ss.
        eapply pf_promises_write; eauto.
      + inv LOCAL0; ss.
      + inv LOCAL0; ss.
  Qed.

  Lemma pf_promises_opt_step lang (th0 th1: Thread.t lang) e
        (STEP: Thread.opt_step e th0 th1)
        (PF: pf_event e)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      pf_promises th1.(Thread.local).(Local.promises).
  Proof.
    inv STEP; auto.
    eapply pf_promises_step; eauto.
  Qed.

  Lemma pf_promises_reserve_steps lang (th0 th1: Thread.t lang)
        (STEPS: rtc (@Thread.reserve_step _) th0 th1)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      pf_promises th1.(Thread.local).(Local.promises).
  Proof.
    ginduction STEPS; eauto. i. eapply IHSTEPS.
    inv H. eapply pf_promises_step; eauto. ii. clarify.
  Qed.

  Lemma pf_promises_cancel_steps lang (th0 th1: Thread.t lang)
        (STEPS: rtc (@Thread.cancel_step _) th0 th1)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      pf_promises th1.(Thread.local).(Local.promises).
  Proof.
    ginduction STEPS; eauto. i. eapply IHSTEPS.
    inv H. eapply pf_promises_step; eauto. ii. clarify.
  Qed.

  Definition pf_configuration (c: Configuration.t) :=
    forall tid lang st lc
           (TID: IdentMap.find tid c.(Configuration.threads) = Some (existT _ lang st, lc)),
      pf_promises lc.(Local.promises).

  Lemma configuration_init_pf syn: pf_configuration (Configuration.init syn).
  Proof.
    ii. ss. unfold Threads.init in *.
    erewrite IdentMap.Facts.map_o in TID.
    unfold option_map in *. des_ifs. dep_clarify.
    erewrite Memory.bot_get in GET. ss.
  Qed.

  Lemma pf_configuration_step tid c1 c2 e
        (STEP: pf_step e tid c1 c2)
        (PF: pf_configuration c1)
    :
      pf_configuration c2.
  Proof.
    inv STEP. unfold pf_configuration in *. i. ss.
    erewrite IdentMap.gsspec in TID0. des_ifs; eauto.
    dep_clarify. eapply PF in TID.
    eapply pf_promises_cancel_steps in CANCELS; eauto.
    eapply pf_promises_opt_step in STEP0; eauto.
    eapply pf_promises_reserve_steps in RESERVES; eauto.
  Qed.

  Lemma pf_promises_pf_step_pf_event lang (th0 th1: Thread.t lang) e
        (STEP: Thread.step true e th0 th1)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      pf_event e.
  Proof.
    ii. subst. inv STEP; inv STEP0; inv LOCAL. ss.
    inv PROMISE; ss. des. subst.
    eapply Memory.lower_get0 in PROMISES0. des.
    eapply PROMISES in GET; eauto. clarify.
  Qed.

  Lemma pf_promises_pf_steps_pf_trace lang (th0 th1: Thread.t lang)
        (STEPS: rtc (tau (Thread.step true)) th0 th1)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      exists tr,
        (<<STEPS: Trace.steps tr th0 th1>>) /\
        (<<PF: List.Forall (compose pf_event snd) tr>>) /\
        (<<SILENT: List.Forall (fun lce => ThreadEvent.get_machine_event (snd lce) = MachineEvent.silent) tr>>).
  Proof.
    ginduction STEPS; eauto; i.
    { exists []. splits; eauto. }
    i. inv H. hexploit pf_promises_pf_step_pf_event; eauto. intros PF.
    hexploit pf_promises_step; eauto. intros PROMISES0.
    exploit IHSTEPS; eauto. i. des. esplits; eauto.
  Qed.

  Lemma pf_promises_consistent_pf_consistent lang (th: Thread.t lang)
        (CONSISTENT: Thread.consistent th)
        (WF: Local.wf th.(Thread.local) th.(Thread.memory))
        (MEM: Memory.closed th.(Thread.memory))
        (PROMISES: pf_promises th.(Thread.local).(Local.promises))
    :
      pf_consistent th.
  Proof.
    eapply consistent_pf_consistent in CONSISTENT; eauto.
    exploit Memory.cap_exists; eauto. i. des.
    exploit Memory.max_concrete_timemap_exists.
    { eapply Memory.cap_closed; eauto. } i. des.
    exploit CONSISTENT; eauto. i. des.
    { eapply pf_promises_pf_steps_pf_trace in STEPS; eauto. des.
      exists tr. splits; auto. ii.
      exploit (@Memory.cap_inj th.(Thread.memory) mem2 mem1); eauto. i. subst.
      exploit (@Memory.max_concrete_timemap_inj mem1 tm sc1); eauto. i. subst.
      esplits; eauto.
    }
    { eapply pf_promises_pf_steps_pf_trace in STEPS; eauto. des.
      exists tr. splits; auto. ii.
      exploit (@Memory.cap_inj th.(Thread.memory) mem2 mem1); eauto. i. subst.
      exploit (@Memory.max_concrete_timemap_inj mem1 tm sc1); eauto. i. subst.
      esplits; eauto.
    }
  Qed.

  Lemma pf_event_configuration_step_pf_step c1 c2 e tid
        (STEP: SConfiguration.step e tid c1 c2)
        (WF: Configuration.wf c1)
        (PF: pf_configuration c1)
        (EVENT: pf_event e)
    :
      pf_step e tid c1 c2.
  Proof.
    inv STEP. econs; eauto. i.
    exploit Thread.rtc_cancel_step_future; eauto; try eapply WF; eauto. ss. i. des.
    exploit Thread.opt_step_future; eauto. ss. i. des.
    exploit Thread.rtc_reserve_step_future; eauto; try eapply WF; eauto. ss. i. des.
    hexploit pf_promises_cancel_steps; eauto. i. ss.
    hexploit pf_promises_opt_step; eauto. i. ss.
    hexploit pf_promises_reserve_steps; eauto. i. ss.
    eapply pf_promises_consistent_pf_consistent; eauto.
  Qed.

  Lemma reservation_only_step_pf_step tid c1 c2
        (STEP: SConfiguration.reservation_only_step tid c1 c2)
        (WF: Configuration.wf c1)
        (PF: pf_configuration c1)
    :
      pf_step ThreadEvent.silent tid c1 c2.
  Proof.
    eapply SConfiguration.reservation_only_step_step in STEP.
    eapply pf_event_configuration_step_pf_step; eauto. ss.
  Qed.

  Lemma pf_step_pf_event_configuration_step c1 c2 e tid
        (STEP: pf_step e tid c1 c2)
        (WF: Configuration.wf c1)
    :
      (<<STEP: SConfiguration.step e tid c1 c2>>) /\
      (<<EVENT: pf_event e>>)
  .
  Proof.
    inv STEP. splits; auto. econs; eauto.
    i. eapply pf_consistent_consistent; eauto.
  Qed.

  Lemma pf_step_future
        e tid c1 c2
        (STEP: pf_step e tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    exploit pf_step_pf_event_configuration_step; eauto. i. des.
    exploit SConfiguration.step_future; eauto. i. des.
    splits; auto. eapply pf_configuration_step; eauto.
  Qed.

  Lemma pf_machine_step_future
        e tid c1 c2
        (STEP: pf_machine_step e tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    inv STEP. eapply pf_step_future; eauto.
  Qed.

  Lemma opt_pf_machine_step_future
        e tid c1 c2
        (STEP: opt_pf_machine_step e tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    inv STEP; eauto.
    - splits; eauto. refl.
    - eapply pf_machine_step_future; eauto.
  Qed.

  Lemma pf_all_step_future
        c1 c2
        (STEP: pf_all_step c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    inv STEP. eapply pf_step_future; eauto.
  Qed.

  Lemma tau_pf_machine_step_future
        c1 c2
        (STEP: tau_pf_machine_step c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    inv STEP. eapply pf_machine_step_future; eauto.
  Qed.

  Lemma rtc_tau_pf_machine_step_future
        c1 c2
        (STEPS: rtc tau_pf_machine_step c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    ginduction STEPS; eauto.
    - i. splits; eauto. refl.
    - i. exploit tau_pf_machine_step_future; eauto. i. des.
      exploit IHSTEPS; eauto. i. des. esplits; eauto. etrans; eauto.
  Qed.

  Lemma rtc_pf_all_step_future
        c1 c2
        (STEPS: rtc pf_all_step c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>).
  Proof.
    ginduction STEPS; eauto.
    - i. splits; eauto. refl.
    - i. exploit pf_all_step_future; eauto. i. des.
      exploit IHSTEPS; eauto. i. des. esplits; eauto. etrans; eauto.
  Qed.

  Lemma pf_steps_future
        es tid c1 c2
        (STEPS: pf_steps es tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    ginduction STEPS; eauto.
    - i. splits; eauto. refl.
    - i. exploit pf_step_future; eauto. i. des.
      exploit IHSTEPS; eauto. i. des. esplits; eauto. etrans; eauto.
  Qed.




  (* multiple thread steps per one configuration step *)
  Inductive pf_step_trace: forall (tr: Trace.t) (e:MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop :=
  | pf_step_trace_intro
      lang tr e tr' pf tid c1 st1 lc1 e2 st3 lc3 sc3 memory3
      (TID: IdentMap.find tid c1.(Configuration.threads) = Some (existT _ lang st1, lc1))
      (STEPS: Trace.steps tr' (Thread.mk _ st1 lc1 c1.(Configuration.sc) c1.(Configuration.memory)) e2)
      (SILENT: List.Forall (fun the => ThreadEvent.get_machine_event (snd the) = MachineEvent.silent) tr')
      (STEP: Thread.step pf e e2 (Thread.mk _ st3 lc3 sc3 memory3))
      (TR: tr = tr'++[(e2.(Thread.local), e)])
      (CONSISTENT: forall (EVENT: e <> ThreadEvent.failure),
          pf_consistent (Thread.mk _ st3 lc3 sc3 memory3))
      (PF: List.Forall (compose pf_event snd) tr)
    :
      pf_step_trace tr (ThreadEvent.get_machine_event e) tid c1 (Configuration.mk (IdentMap.add tid (existT _ _ st3, lc3) c1.(Configuration.threads)) sc3 memory3)
  .

  Lemma pf_promises_trace_steps lang (th0 th1: Thread.t lang) tr
        (STEPS: Trace.steps tr th0 th1)
        (PF: List.Forall (compose pf_event snd) tr)
        (PROMISES: pf_promises th0.(Thread.local).(Local.promises))
    :
      pf_promises th1.(Thread.local).(Local.promises).
  Proof.
    ginduction STEPS; eauto. i. subst.
    inv PF. eapply IHSTEPS; eauto.
    eapply pf_promises_step; eauto.
  Qed.

  Lemma pf_trace_step_pf_step_trace c1 c2 tr e tid
        (STEP: Trace.configuration_step tr e tid c1 c2)
        (WF: Configuration.wf c1)
        (PF: pf_configuration c1)
        (TRACE: List.Forall (compose pf_event snd) tr)
    :
      pf_step_trace tr e tid c1 c2.
  Proof.
    inv STEP. econs; eauto. i.
    eapply Forall_app_inv in TRACE. des. inv FORALL2.
    exploit Trace.steps_future; eauto; try eapply WF; eauto. ss. i. des.
    exploit Thread.step_future; eauto. ss. i. des.
    hexploit pf_promises_trace_steps; eauto. i. ss.
    hexploit pf_promises_step; eauto. i. ss.
    eapply pf_promises_consistent_pf_consistent; eauto.
  Qed.

  Lemma pf_step_trace_pf_trace_step c1 c2 tr e tid
        (STEP: pf_step_trace tr e tid c1 c2)
        (WF: Configuration.wf c1)
    :
      (<<STEP: Trace.configuration_step tr e tid c1 c2>>) /\
      (<<TRACE: List.Forall (compose pf_event snd) tr>>).
  Proof.
    inv STEP. splits; auto. econs; eauto. i.
    eapply pf_consistent_consistent; eauto.
  Qed.

  Inductive pf_opt_step_trace: forall (tr: Trace.t) (e:MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop :=
  | pf_opt_step_trace_some
      tr e tid c1 c2
      (STEP: pf_step_trace tr e tid c1 c2)
    :
      pf_opt_step_trace tr e tid c1 c2
  | pf_opt_step_trace_none
      tid c1
    :
      pf_opt_step_trace [] MachineEvent.silent tid c1 c1
  .

  Lemma pf_step_trace_step tr e tid c1 c2
        (STEP: pf_step_trace tr e tid c1 c2)
    :
      Configuration.step e tid c1 c2.
  Proof.
    inv STEP. destruct (classic (e0 = ThreadEvent.failure)).
    { subst. econs 1; try apply STEP0; eauto.
      eapply Trace.silent_steps_tau_steps; eauto. }
    { econs 2; try apply STEP0; eauto.
      { eapply Trace.silent_steps_tau_steps; eauto. }
      { exploit CONSISTENT; eauto. i. unfold pf_consistent in *. des.
        eapply Trace.consistent_thread_consistent; eauto. }
    }
  Qed.

  Inductive pf_steps_trace:
    forall (c0 c1: Configuration.t) (tr: Trace.t), Prop :=
  | pf_steps_trace_nil
      c0
    :
      pf_steps_trace c0 c0 []
  | pf_steps_trace_cons
      c0 c1 c2 trs tr e tid
      (STEPS: pf_steps_trace c1 c2 trs)
      (STEP: pf_step_trace tr e tid c0 c1)
    :
      pf_steps_trace c0 c2 (tr ++ trs)
  .

  Lemma pf_step_trace_pf_steps tr e tid c1 c3
        (STEP: pf_step_trace tr e tid c1 c3)
        (WF: Configuration.wf c1)
        (PF: pf_configuration c1)
    :
      ((<<STEPS: pf_steps (List.filter ThreadEvent.is_normal_dec (List.map snd tr)) tid c1 c3>>) /\
       (<<NIL: List.filter ThreadEvent.is_normal_dec (List.map snd tr) <> []>>)) \/
      ((<<STEP: SConfiguration.reservation_only_step tid c1 c3>>) /\
       (<<NIL: List.filter ThreadEvent.is_normal_dec (List.map snd tr) = []>>)).
  Proof.
    eapply pf_step_trace_pf_trace_step in STEP; eauto. des.
    eapply SConfiguration.trace_step_machine_step in STEP0; eauto. des; eauto.
    left. splits; auto. clear e.
    remember (List.filter (fun e => ThreadEvent.is_normal_dec e) (List.map snd tr)).
    assert (EVENTS: List.Forall pf_event l).
    { subst. clear - TRACE. induction tr; ss. inv TRACE. des_ifs; eauto. }
    clear tr Heql NIL TRACE. ginduction STEPS; eauto.
    i. inv EVENTS.
    eapply pf_event_configuration_step_pf_step in STEP; eauto.
    exploit pf_step_future; eauto. i. des.
    hexploit pf_configuration_step; eauto.
  Qed.

  Lemma pf_step_trace_future
        (tr: Trace.t) e tid c1 c2
        (STEP: pf_step_trace tr e tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    eapply pf_step_trace_pf_steps in STEP; eauto. des.
    { eapply pf_steps_future; eauto. }
    { eapply reservation_only_step_pf_step in STEP0; eauto.
      eapply pf_step_future; eauto. }
  Qed.

  Lemma pf_opt_step_trace_future
        (tr: Trace.t) e tid c1 c2
        (STEP: pf_opt_step_trace tr e tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    inv STEP.
    { eapply pf_step_trace_future; eauto. }
    { splits; auto. refl. }
  Qed.

  Lemma pf_steps_trace_future
        c1 c2 tr
        (STEPS: pf_steps_trace c1 c2 tr)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    revert WF1. induction STEPS; i.
    - splits; ss; refl.
    - exploit pf_step_trace_future; eauto. i. des.
      exploit IHSTEPS; eauto. i. des.
      splits; ss; etrans; eauto.
  Qed.

  Lemma pf_steps_trace_n1 c0 c1 c2 tr trs e tid
        (STEPS: pf_steps_trace c0 c1 trs)
        (STEP: pf_step_trace tr e tid c1 c2)
    :
      pf_steps_trace c0 c2 (trs ++ tr).
  Proof.
    ginduction STEPS.
    { i. exploit pf_steps_trace_cons.
      { econs 1. }
      { eapply STEP. }
      { i. ss. erewrite List.app_nil_r in *. auto. }
    }
    { i. exploit IHSTEPS; eauto. i. erewrite <- List.app_assoc. econs; eauto. }
  Qed.

  Lemma pf_steps_trace_trans c0 c1 c2 trs0 trs1
        (STEPS0: pf_steps_trace c0 c1 trs0)
        (STEPS1: pf_steps_trace c1 c2 trs1)
    :
      pf_steps_trace c0 c2 (trs0 ++ trs1).
  Proof.
    ginduction STEPS0.
    { i. erewrite List.app_nil_l. eauto. }
    { i. exploit IHSTEPS0; eauto. i. erewrite <- List.app_assoc. econs; eauto. }
  Qed.

  Lemma pf_step_trace_pf_steps_trace tr e tid c1 c2
        (STEP: pf_step_trace tr e tid c1 c2)
    :
      pf_steps_trace c1 c2 tr.
  Proof.
    exploit pf_steps_trace_cons.
    { econs 1. }
    { eauto. }
    i. rewrite List.app_nil_r in x0. auto.
  Qed.

  Lemma pf_opt_step_trace_pf_steps_trace tr e tid c1 c2
        (STEP: pf_opt_step_trace tr e tid c1 c2)
    :
      pf_steps_trace c1 c2 tr.
  Proof.
    inv STEP.
    { eapply pf_step_trace_pf_steps_trace; eauto. }
    { econs 1. }
  Qed.

  Inductive silent_pf_steps_trace:
    forall (c0 c1: Configuration.t) (tr: Trace.t), Prop :=
  | silent_pf_steps_trace_nil
      c0
    :
      silent_pf_steps_trace c0 c0 []
  | silent_pf_steps_trace_cons
      c0 c1 c2 trs tr tid
      (STEPS: silent_pf_steps_trace c1 c2 trs)
      (STEP: pf_step_trace tr MachineEvent.silent tid c0 c1)
    :
      silent_pf_steps_trace c0 c2 (tr ++ trs)
  .

  Lemma silent_pf_steps_trace_pf_steps_trace
    :
      silent_pf_steps_trace <3= pf_steps_trace.
  Proof.
    intros. induction PR.
    { econs. }
    { econs; eauto. }
  Qed.

  Inductive pf_steps_trace_rev: forall (c1 c2: Configuration.t) (tr: Trace.t), Prop :=
  | pf_steps_trace_rev_nil
      c:
      pf_steps_trace_rev c c []
  | pf_steps_trace_rev_cons
      c1 c2 c3 tr1 tr2 e tid
      (STEPS: pf_steps_trace_rev c1 c2 tr1)
      (STEP: pf_step_trace tr2 e tid c2 c3):
      pf_steps_trace_rev c1 c3 (tr1 ++ tr2)
  .
  Hint Constructors pf_steps_trace_rev.

  Lemma pf_steps_trace_rev_1n
        c1 c2 c3 tr1 tr2 e tid
        (STEP: pf_step_trace tr1 e tid c1 c2)
        (STEPS: pf_steps_trace_rev c2 c3 tr2):
    pf_steps_trace_rev c1 c3 (tr1 ++ tr2).
  Proof.
    revert tr1 e tid c1 STEP. induction STEPS; i.
    - replace (tr1 ++ []) with ([] ++ tr1) by (rewrite List.app_nil_r; ss).
      econs 2; [econs 1|]. eauto.
    - exploit IHSTEPS; eauto. i.
      rewrite List.app_assoc.
      econs 2; eauto.
  Qed.

  Lemma pf_steps_trace_equiv c1 c2 tr:
    pf_steps_trace c1 c2 tr <-> pf_steps_trace_rev c1 c2 tr.
  Proof.
    split; i.
    - induction H; eauto.
      eapply pf_steps_trace_rev_1n; eauto.
    - induction H; [econs 1|].
      eapply pf_steps_trace_n1; eauto.
  Qed.

  Lemma pf_steps_trace_inv
        c1 c2 tr lc e
        (STEPS: pf_steps_trace c1 c2 tr)
        (WF: Configuration.wf c1)
        (PF: pf_configuration c1)
        (TRACE: List.In (lc, e) tr):
    exists c tr1 tid lang st1 lc1,
      (<<STEPS: pf_steps_trace c1 c tr1>>) /\
      (<<FIND: IdentMap.find tid c.(Configuration.threads) = Some (existT _ lang st1, lc1)>>) /\
      exists tr2 pf e2 e3,
        (<<THREAD_STEPS: Trace.steps tr2 (Thread.mk _ st1 lc1 c.(Configuration.sc) c.(Configuration.memory)) e2>>) /\
        (<<SILENT: List.Forall (fun the => ThreadEvent.get_machine_event (snd the) = MachineEvent.silent) tr2>>) /\
        (<<PF: List.Forall (compose pf_event snd) tr2>>) /\
        (<<LC: e2.(Thread.local) = lc>>) /\
        (<<THREAD_STEP: Thread.step pf e e2 e3>>) /\
        (<<CONS: Local.promise_consistent e3.(Thread.local)>>).
  Proof.
    rewrite pf_steps_trace_equiv in STEPS.
    induction STEPS; ss.
    apply List.in_app_or in TRACE. des; eauto.
    clear IHSTEPS. inv STEP.
    exists c2, tr1, tid, lang, st1, lc1.
    rewrite <- pf_steps_trace_equiv in STEPS.
    splits; ss.
    apply List.in_app_or in TRACE. des; cycle 1.
    { inv TRACE; ss. inv H. esplits; eauto.
      - apply Forall_app_inv in PF0. des. ss.
      - destruct (classic (e = ThreadEvent.failure)).
        + subst. inv STEP0; inv STEP. inv LOCAL. inv LOCAL0. ss.
        + exploit CONSISTENT; eauto. i. inv x. des.
          exploit pf_steps_trace_future; eauto. i. des.
          inv WF2. inv WF0. exploit THREADS; eauto. i.
          exploit Trace.steps_future; try exact STEPS0; eauto. s. i. des.
          exploit Thread.step_future; try exact STEP0; eauto. s. i. des.
          hexploit consistent_promise_consistent;
            try eapply Trace.consistent_thread_consistent; try exact CONSISTENT0; eauto.
    }
    exploit pf_steps_trace_future; eauto. i. des.
    inv WF2. inv WF0. exploit THREADS; eauto. i. clear DISJOINT THREADS.
    exploit Trace.steps_inv; try exact STEPS0; eauto.
    { destruct (classic (e1 = ThreadEvent.failure)).
      - subst. inv STEP0; inv STEP. inv LOCAL. inv LOCAL0. ss.
      - exploit CONSISTENT; ss. i. inv x0. des.
        exploit Trace.steps_future; eauto. s. i. des.
        exploit Thread.step_future; eauto. s. i. des.
        eapply step_promise_consistent; eauto.
        eapply consistent_promise_consistent; eauto.
        eapply Trace.consistent_thread_consistent; eauto.
    }
    i. des. esplits; eauto; subst.
    - apply Forall_app_inv in SILENT. des. ss.
    - apply Forall_app_inv in PF0. des.
      apply Forall_app_inv in FORALL1. des. ss.
  Qed.

  Inductive pf_multi_step (e:MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t): Prop :=
  | pf_multi_step_intro
      tr
      (STEP: pf_step_trace tr e tid c1 c2)
  .

  Lemma pf_multi_step_machine_step e tid c1 c3
        (STEP: pf_multi_step e tid c1 c3)
        (WF: Configuration.wf c1)
        (PF: pf_configuration c1)
    :
      exists c2,
        (<<STEPS: rtc tau_pf_machine_step c1 c2>>) /\
        (<<STEP: opt_pf_machine_step e tid c2 c3>>).
  Proof.
    inv STEP. exploit pf_step_trace_pf_steps; eauto. i. des.
    { inv STEP0.
      rewrite List.map_app in *.
      rewrite list_filter_app in *. ss.
      eapply pf_steps_split in STEPS. des. exists c0. splits.
      { eapply rtc_implies with (R1:=(pf_machine_step MachineEvent.silent tid)).
        { clear. i. econs; eauto. }
        eapply silent_pf_steps_tau_pf_machine_steps; eauto.
        eapply list_filter_forall with (Q:=fun e => ThreadEvent.get_machine_event e = MachineEvent.silent); eauto.
        eapply list_map_forall; eauto.
      }
      unfold proj_sumbool in *. des_ifs.
      { inv STEPS2. inv STEPS.
        econs 2. econs; eauto. }
      { inv STEPS2.
        replace (ThreadEvent.get_machine_event e0) with MachineEvent.silent; eauto.
        apply NNPP in n.
        unfold ThreadEvent.is_reservation_event, ThreadEvent.is_reserve, ThreadEvent.is_cancel in n.
        des; des_ifs.
      }
    }
    { eapply SConfiguration.reservation_only_step_step in STEP.
      eapply pf_event_configuration_step_pf_step in STEP; eauto; ss.
      exists c1. esplits; eauto.
      replace e with (ThreadEvent.get_machine_event ThreadEvent.silent); eauto.
      ss. inv STEP0.
      rewrite List.map_app in NIL.
      rewrite list_filter_app in NIL.
      eapply List.app_eq_nil in NIL.
      ss. unfold proj_sumbool in NIL. des. des_ifs.
      apply NNPP in n.
      unfold ThreadEvent.is_reservation_event, ThreadEvent.is_reserve, ThreadEvent.is_cancel in n.
      des; des_ifs.
    }
  Qed.

  Lemma pf_multi_step_future
        e tid c1 c2
        (STEP: pf_multi_step e tid c1 c2)
        (WF1: Configuration.wf c1)
        (PF: pf_configuration c1):
    (<<WF2: Configuration.wf c2>>) /\
    (<<SC_FUTURE: TimeMap.le c1.(Configuration.sc) c2.(Configuration.sc)>>) /\
    (<<MEM_FUTURE: Memory.future c1.(Configuration.memory) c2.(Configuration.memory)>>) /\
    (<<PF: pf_configuration c2>>).
  Proof.
    inv STEP. eapply pf_step_trace_future; eauto.
  Qed.

  Lemma silent_pf_multi_steps_trace_behaviors c0 c1 tr
        (STEP: silent_pf_steps_trace c0 c1 tr)
    :
      behaviors pf_multi_step c1 <1= behaviors pf_multi_step c0.
  Proof.
    ginduction STEP; auto.
    i. eapply IHSTEP in PR. econs 4; eauto.
    econs. esplits; eauto.
  Qed.

  Definition pf_multi_racefree_imm (c0: Configuration.t): Prop :=
    forall tid0 c1 trs0 tid1 c2 trs1
           loc ts lc1 te0 te1 e0 e1
           (LOC: L loc)
           (TID: tid0 <> tid1)
           (CSTEP0: pf_step_trace trs0 e0 tid0 c0 c1)
           (WRITE: writing_event loc ts te0)
           (TRACE0: final_event_trace te0 trs0)
           (CSTEP1: pf_step_trace trs1 e1 tid1 c1 c2)
           (READ: reading_event loc ts te1)
           (TRACE1: List.In (lc1, te1) trs1),
      False.

  Definition pf_multi_racefree (c0: Configuration.t): Prop :=
    forall c1 trs
           (CSTEPS: pf_steps_trace c0 c1 trs),
      pf_multi_racefree_imm c1.

  Lemma multi_step_pf_multi_racefree c0 c1 tr e tid
        (RACEFREE: pf_multi_racefree c0)
        (STEP: pf_step_trace tr e tid c0 c1)
    :
      pf_multi_racefree c1.
  Proof.
    unfold pf_multi_racefree in *. i.
    eapply RACEFREE. econs 2; eauto.
  Qed.

  Lemma multi_steps_pf_multi_racefree c0 c1 trs
        (RACEFREE: pf_multi_racefree c0)
        (STEPS: pf_steps_trace c0 c1 trs)
    :
      pf_multi_racefree c1.
  Proof.
    induction STEPS; auto. eapply IHSTEPS.
    eapply multi_step_pf_multi_racefree; eauto.
  Qed.

  Lemma reserving_trace_filter tr
        (TRACE: reserving_trace tr)
    :
      List.filter ThreadEvent.is_normal_dec (List.map snd tr) = [].
  Proof.
    induction TRACE; eauto. ss. rewrite IHTRACE; eauto.
    unfold ThreadEvent.is_normal, proj_sumbool in *. des_ifs.
  Qed.

  Lemma final_event_trace_filter tr e
        (FINAL: final_event_trace e tr)
        (NORMAL: ThreadEvent.is_normal e)
    :
      exists tr_hd,
        (<<FILTER: List.filter ThreadEvent.is_normal_dec (List.map snd tr) = tr_hd ++ [e]>>).
  Proof.
    induction FINAL; eauto; i.
    { exists []. ss. rewrite reserving_trace_filter; eauto.
      unfold proj_sumbool. des_ifs. }
    { des. ss. rewrite FILTER. des_ifs; eauto.
      eexists. erewrite List.app_comm_cons. eauto.
    }
  Qed.

  Lemma pf_racefree_multi_racefree_imm c
        (RACEFREE: pf_racefree c)
        (WF: Configuration.wf c)
        (PF: pf_configuration c)
    :
      pf_multi_racefree_imm c.
  Proof.
    ii. exploit pf_step_trace_future; try apply CSTEP0; eauto.  i. des.
    exploit final_event_trace_filter; eauto.
    { unfold ThreadEvent.is_normal, ThreadEvent.is_reservation_event.
      inv WRITE; ss; ii; des; ss. } i. des.
    eapply pf_step_trace_pf_steps in CSTEP0; eauto.
    rewrite FILTER in *. des; cycle 1.
    { eapply List.app_eq_nil in NIL. des; ss. }
    eapply pf_steps_split in STEPS. des. inv STEPS1. inv STEPS.
    eapply List.in_split in TRACE1. des; subst.
    dup CSTEP1. eapply pf_step_trace_pf_steps in CSTEP1; eauto.
    rewrite List.map_app in *.
    rewrite list_filter_app in *. ss. unfold proj_sumbool in *.
    des_ifs; cycle 1.
    { clear - READ n. apply NNPP in n.
      unfold ThreadEvent.is_normal, ThreadEvent.is_reservation_event in *.
      inv READ; ss; ii; des; ss. }
    des; cycle 1.
    { eapply List.app_eq_nil in NIL0. des; ss. }
    eapply pf_steps_split in STEPS. des. inv STEPS2.
    eapply RACEFREE; try eassumption.
    { eapply pf_steps_rtc_pf_all_step; eauto. }
    { eapply silent_pf_steps_tau_pf_machine_steps; eauto.
      clear - CSTEP0. inv CSTEP0.
      destruct (list_match_rev l2); des; subst.
      { eapply List.app_inj_tail in TR. des; clarify.
        eapply List.Forall_forall. ii.
        eapply List.filter_In in H. des.
        eapply List.in_map_iff in H. des; subst.
        eapply List.Forall_forall in SILENT; eauto. }
      { rewrite List.app_comm_cons in TR.
        rewrite List.app_assoc in TR.
        eapply List.app_inj_tail in TR. des; clarify.
        eapply Forall_app_inv in SILENT. des.
        eapply List.Forall_forall. ii.
        eapply List.filter_In in H. des.
        eapply List.in_map_iff in H. des; subst.
        eapply List.Forall_forall in FORALL1; eauto. }
    }
  Qed.

  Lemma pf_racefree_multi_racefree c
        (RACEFREE: pf_racefree c)
        (WF: Configuration.wf c)
        (PF: pf_configuration c)
    :
      pf_multi_racefree c.
  Proof.
    unfold pf_multi_racefree. i.
    ginduction CSTEPS; eauto.
    { i. eapply pf_racefree_multi_racefree_imm; eauto. }
    { i. exploit pf_step_trace_future; eauto.
      i. des. eapply IHCSTEPS; eauto.
      eapply pf_step_trace_pf_steps in STEP; eauto. des.
      { eapply steps_pf_racefree; eauto. }
      { eapply reservation_only_step_pf_step in STEP0; eauto.
        eapply step_pf_racefree; eauto. }
    }
  Qed.

  Lemma pf_multi_step_behavior c
        (WF: Configuration.wf c)
        (PF: pf_configuration c)
    :
      behaviors pf_multi_step c <1= behaviors pf_machine_step c.
  Proof.
    i. induction PR.
    - econs 1; eauto.
    - exploit pf_multi_step_future; eauto. i. des.
      eapply pf_multi_step_machine_step in STEP; eauto. des.
      eapply rtc_tau_step_behavior; eauto.
      inv STEP0; eauto. econs 2; eauto.
    - exploit pf_multi_step_future; eauto. i. des.
      eapply pf_multi_step_machine_step in STEP; eauto. des.
      eapply rtc_tau_step_behavior; eauto.
      inv STEP0; eauto. econs 3; eauto.
    - exploit pf_multi_step_future; eauto. i. des.
      eapply pf_multi_step_machine_step in STEP; eauto. des.
      eapply rtc_tau_step_behavior; eauto.
      inv STEP0; eauto. econs 4; eauto.
  Qed.

  Inductive racy_read (loc: Loc.t) (ts: Time.t):
    forall (lc: Local.t) (e: ThreadEvent.t), Prop :=
  | racy_read_read
      lc
      valr releasedr ordr
      (VIEW:
         Time.lt (if Ordering.le Ordering.relaxed ordr
                  then (lc.(Local.tview).(TView.cur).(View.rlx) loc)
                  else (lc.(Local.tview).(TView.cur).(View.pln) loc)) ts)
    :
      racy_read loc ts lc (ThreadEvent.read loc ts valr releasedr ordr)
  | racy_read_update
      lc
      to valr valw releasedr releasedw ordr ordw
      (VIEW:
         Time.lt (if Ordering.le Ordering.relaxed ordr
                  then (lc.(Local.tview).(TView.cur).(View.rlx) loc)
                  else (lc.(Local.tview).(TView.cur).(View.pln) loc)) ts)
    :
      racy_read loc ts lc (ThreadEvent.update loc ts to valr valw releasedr releasedw ordr ordw)
  .

  Inductive racy_write (loc: Loc.t) (ts: Time.t):
    forall (lc: Local.t) (e: ThreadEvent.t), Prop :=
  | racy_write_write
      lc
      from valw releasedw ordw
      (ORD: Ordering.le ordw Ordering.relaxed)
    :
      racy_write loc ts lc (ThreadEvent.write loc from ts valw releasedw ordw)
  | racy_write_update
      lc
      from valr valw releasedr releasedw ordr ordw
      (ORD: Ordering.le ordw Ordering.relaxed)
    :
      racy_write loc ts lc (ThreadEvent.update loc from ts valr valw releasedr releasedw ordr ordw)
  .

  Definition pf_racefree_view (c0: Configuration.t): Prop :=
    forall c1 trs1 c2 trs2
      loc ts lc0 lc1 e0 e1
      (CSTEPS1: pf_steps_trace c0 c1 trs1)
      (LOC: L loc)
      (TRACE1: List.In (lc0, e0) trs1)
      (WRITE: racy_write loc ts lc0 e0)
      (CSTEPS2: pf_steps_trace c1 c2 trs2)
      (TRACE2: List.In (lc1, e1) trs2)
      (READ: racy_read loc ts lc1 e1),
      False.

  Lemma step_pf_racefree_view c0 c1 tr e tid
        (RACEFREE: pf_racefree_view c0)
        (STEP: pf_step_trace tr e tid c0 c1)
    :
      pf_racefree_view c1.
  Proof.
    ii. eapply RACEFREE.
    { econs 2.
      { eapply CSTEPS1. }
      { eauto. }
    }
    { eauto. }
    { eapply List.in_or_app. right. eapply TRACE1. }
    { eauto. }
    { eauto. }
    { eauto. }
    { eauto. }
  Qed.

  Lemma steps_pf_racefree_view c0 c1 trs
        (RACEFREE: pf_racefree_view c0)
        (STEPS: pf_steps_trace c0 c1 trs)
    :
      pf_racefree_view c1.
  Proof.
    induction STEPS; auto. eapply IHSTEPS.
    eapply step_pf_racefree_view; eauto.
  Qed.

End LOCALPF.