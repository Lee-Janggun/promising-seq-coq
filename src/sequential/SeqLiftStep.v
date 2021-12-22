Require Import RelationClasses.

From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import Loc.
From PromisingLib Require Import DenseOrder.
From PromisingLib Require Import Language.

Require Import Event.
Require Import Time.
Require Import View.
Require Import Cell.
Require Import Memory.
Require Import MemoryFacts.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.

Require Import Cover.
Require Import MemorySplit.
Require Import MemoryMerge.
Require Import FulfillStep.
Require Import MemoryProps.

Require Import gSimAux.
Require Import LowerMemory.
Require Import JoinedView.

Require Import MaxView.
Require Import Delayed.

Require Import Lia.

Require Import JoinedView.
Require Import SeqLift.
Require Import gSimulation.
Require Import Simple.


Record sim_tview
       (f: Mapping.ts)
       (flag_src: Loc.t -> option Time.t)
       (rel_vers: Loc.t -> version)
       (tvw_src: TView.t) (tvw_tgt: TView.t)
  :
    Prop :=
  sim_tview_intro {
      sim_tview_rel: forall loc,
        sim_view (fun loc0 => loc0 <> loc) f (rel_vers loc) (tvw_src.(TView.rel) loc) (tvw_tgt.(TView.rel) loc);
      sim_tview_cur: sim_view (fun loc => flag_src loc = None) f (Mapping.vers f) tvw_src.(TView.cur) tvw_tgt.(TView.cur);
      sim_tview_acq: sim_view (fun loc => flag_src loc = None) f (Mapping.vers f) tvw_src.(TView.acq) tvw_tgt.(TView.acq);
      rel_vers_wf: forall loc, version_wf f (rel_vers loc);
    }.

Lemma sim_tview_mon_latest f0 f1 flag_src rel_vers tvw_src tvw_tgt
      (SIM: sim_tview f0 flag_src rel_vers tvw_src tvw_tgt)
      (LE: Mapping.les f0 f1)
      (WF0: Mapping.wfs f0)
      (WF1: Mapping.wfs f1)
  :
    sim_tview f1 flag_src rel_vers tvw_src tvw_tgt.
Proof.
  econs.
  { i. erewrite <- sim_view_mon_mapping; [eapply SIM|..]; eauto. eapply SIM. }
  { eapply sim_view_mon_latest; eauto. eapply SIM. }
  { eapply sim_view_mon_latest; eauto. eapply SIM. }
  { i. eapply version_wf_mapping_mon; eauto. eapply SIM. }
Qed.

Lemma sim_tview_tgt_mon f flag_src rel_vers tvw_src tvw_tgt0 tvw_tgt1
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt0)
      (TVIEW: TView.le tvw_tgt0 tvw_tgt1)
  :
    sim_tview f flag_src rel_vers tvw_src tvw_tgt1.
Proof.
  econs.
  { i. eapply sim_view_mon_tgt.
    { eapply SIM. }
    { eapply TVIEW. }
  }
  { eapply sim_view_mon_tgt.
    { eapply SIM. }
    { eapply TVIEW. }
  }
  { eapply sim_view_mon_tgt.
    { eapply SIM. }
    { eapply TVIEW. }
  }
  { eapply SIM. }
Qed.

Variant wf_release_vers (vers: versions) (prom_tgt: Memory.t) (rel_vers: Loc.t -> version): Prop :=
| wf_release_vers_intro
    (PROM: forall loc from to val released
                  (GET: Memory.get loc to prom_tgt = Some (from, Message.concrete val (Some released))),
        exists v,
          (<<VER: vers loc to = Some v>>) /\
          (<<REL: rel_vers loc = v>>))
.

Variant sim_local
        (f: Mapping.ts) (vers: versions)
        (flag_src: Loc.t -> option Time.t)
        (flag_tgt: Loc.t -> option Time.t)
  :
    Local.t -> Local.t -> Prop :=
| sim_local_intro
    tvw_src tvw_tgt prom_src prom_tgt rel_vers
    (TVIEW: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
    (PROMISES: sim_promises flag_src flag_tgt f vers prom_src prom_tgt)
    (RELVERS: wf_release_vers vers prom_tgt rel_vers)
    (FLAGTGT: forall loc ts (FLAG: flag_tgt loc = Some ts),
        tvw_src.(TView.cur).(View.rlx) loc = ts)
    (FLAGSRC: forall loc ts (FLAG: flag_src loc = Some ts),
        tvw_src.(TView.cur).(View.rlx) loc = ts)
  :
    sim_local
      f vers flag_src flag_tgt
      (Local.mk tvw_src prom_src)
      (Local.mk tvw_tgt prom_tgt)
.

Lemma sim_local_tgt_mon f vers flag_src flag_tgt lc_src lc_tgt0 lc_tgt1
      (SIM: sim_local f vers flag_src flag_tgt lc_src lc_tgt0)
      (PROM: lc_tgt0.(Local.promises) = lc_tgt1.(Local.promises))
      (TVIEW: TView.le lc_tgt0.(Local.tview) lc_tgt1.(Local.tview))
  :
    sim_local f vers flag_src flag_tgt lc_src lc_tgt1.
Proof.
  inv SIM. destruct lc_tgt1. ss. clarify. econs; eauto.
  eapply sim_tview_tgt_mon; eauto.
Qed.

Lemma sim_local_consistent f vers flag_src flag_tgt lc_src lc_tgt
      (CONSISTENT: Local.promise_consistent lc_tgt)
      (SIM: sim_local f vers flag_src flag_tgt lc_src lc_tgt)
      (WF: Mapping.wfs f)
  :
    Local.promise_consistent lc_src.
Proof.
  inv SIM. ii. ss.
  hexploit sim_promises_get_if; eauto. i. des.
  { eapply sim_timestamp_lt.
    { eapply sim_view_rlx.
      { eapply sim_tview_cur. eauto. }
      { ss. destruct (flag_src loc) eqn:FLAG; auto.
        erewrite sim_promises_none in PROMISE; eauto. ss.
      }
    }
    { eauto. }
    { eapply CONSISTENT; eauto. inv MSG0; ss. }
    { eauto. }
    { eapply mapping_latest_wf_loc. }
  }
  { eapply FLAGTGT in FLAG. subst. auto. }
Qed.

Lemma sim_local_racy f vers flag_src flag_tgt lc_src lc_tgt mem_src mem_tgt loc
      (CONSISTENT: Local.promise_consistent lc_tgt)
      (MEM: sim_memory flag_src f vers mem_src mem_tgt)
      (SIM: sim_local f vers flag_src flag_tgt lc_src lc_tgt)
      (WF: Mapping.wfs f)
      (RACY: Local.is_racy lc_tgt mem_tgt loc Ordering.na)
      (FLAGSRC: flag_src loc = None)
      (FLAGTGT: flag_tgt loc = None)
  :
    Local.is_racy lc_src mem_src loc Ordering.na.
Proof.
  inv RACY. hexploit sim_memory_get; eauto. i. des. econs; eauto.
  { inv SIM. ss.
    destruct (Memory.get loc to_src prom_src) eqn:EQ; ss.
    destruct p. hexploit sim_promises_get_if; eauto. i. des; ss; clarify.
    eapply sim_timestamp_exact_unique in TO; eauto; clarify.
  }
  { unfold TView.racy_view in *. eapply sim_timestamp_lt; eauto.
    { inv SIM. ss. eapply TVIEW. auto. }
    { eapply mapping_latest_wf_loc. }
  }
  { inv MSG; ss. }
  { i. hexploit MSG2; auto. i. inv MSG; ss. }
Qed.

Variant max_value_src (loc: Loc.t) (v: option Const.t)
        (mem: Memory.t)
  :
    forall (lc: Local.t), Prop :=
| max_value_src_intro
    tvw prom
    (MAX: forall v0 (VAL: v = Some v0),
        exists released,
          (<<MAX: max_readable
                    mem
                    prom
                    loc
                    (tvw.(TView.cur).(View.pln) loc)
                    v0 released>>))
    (NONMAX: forall (VAL: v = None),
        forall val released,
          ~ max_readable mem prom loc (tvw.(TView.cur).(View.pln) loc) val released)
  :
    max_value_src loc v mem (Local.mk tvw prom)
.

Definition max_values_src (vs: Loc.t -> option Const.t)
           (mem: Memory.t) (lc: Local.t): Prop :=
  forall loc, max_value_src loc (vs loc) mem lc.

Variant max_value_tgt (loc: Loc.t) (v: option Const.t)
        (mem: Memory.t)
  :
    forall (lc: Local.t), Prop :=
| max_value_tgt_intro
    tvw prom
    (MAX: forall v1 (VAL: v = Some v1),
        exists released v0,
          (<<MAX: max_readable
                    mem
                    prom
                    loc
                    (tvw.(TView.cur).(View.pln) loc)
                    v0 released>>) /\
          (<<VAL: Const.le v0 v1>>))
  :
    max_value_tgt loc v mem (Local.mk tvw prom)
.

Definition max_values_tgt (vs: Loc.t -> option Const.t)
           (mem: Memory.t) (lc: Local.t): Prop :=
  forall loc, max_value_tgt loc (vs loc) mem lc.

Lemma max_value_tgt_mon loc v mem lc0 lc1
      (MAXTGT: max_value_tgt loc v mem lc0)
      (PROM: lc0.(Local.promises) = lc1.(Local.promises))
      (TVIEW: TView.le lc0.(Local.tview) lc1.(Local.tview))
      (LOCAL: Local.wf lc1 mem)
      (CONSISTENT: Local.promise_consistent lc1)
  :
    max_value_tgt loc v mem lc1.
Proof.
  inv MAXTGT. ss. subst. destruct lc1. econs. i.
  hexploit MAX; eauto. i. des. ss.
  hexploit max_readable_view_mon; eauto.
Qed.

Lemma max_values_tgt_mon vs mem lc0 lc1
      (MAXTGT: max_values_tgt vs mem lc0)
      (PROM: lc0.(Local.promises) = lc1.(Local.promises))
      (TVIEW: TView.le lc0.(Local.tview) lc1.(Local.tview))
      (LOCAL: Local.wf lc1 mem)
      (CONSISTENT: Local.promise_consistent lc1)
  :
    max_values_tgt vs mem lc1.
Proof.
  ii. eapply max_value_tgt_mon; eauto.
Qed.

Variant sim_thread
        (f: Mapping.ts) (vers: versions)
        (flag_src: Loc.t -> option Time.t)
        (flag_tgt: Loc.t -> option Time.t)
        (vs_src: Loc.t -> option Const.t)
        (vs_tgt: Loc.t -> option Const.t)
        mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt: Prop :=
| sim_thread_intro
    (SC: sim_timemap (fun _ => True) f (Mapping.vers f) sc_src sc_tgt)
    (MEM: sim_memory flag_src f vers mem_src mem_tgt)
    (LOCAL: sim_local f vers flag_src flag_tgt lc_src lc_tgt)
    (MAXSRC: max_values_src vs_src mem_src lc_src)
    (MAXTGT: max_values_tgt vs_tgt mem_tgt lc_tgt)
    (PERM: forall loc, option_rel (fun _ _ => True) (vs_src loc) (vs_tgt loc))
.

Lemma max_value_src_exists loc mem lc
  :
    exists v,
      (<<MAX: max_value_src loc v mem lc>>).
Proof.
  destruct (classic (exists val released, max_readable mem lc.(Local.promises) loc (View.pln (TView.cur lc.(Local.tview)) loc) val released)).
  { des. exists (Some val). splits. destruct lc. econs; ss.
    i. clarify. esplits; eauto.
  }
  { exists None. splits. destruct lc. econs; ss.
    ii. eapply H. eauto.
  }
Qed.

Lemma race_non_max_readable mem prom tvw loc
      (MAX: Local.is_racy (Local.mk tvw prom) mem loc Ordering.na)
  :
    forall val released, ~ max_readable mem prom loc (tvw.(TView.cur).(View.pln) loc) val released.
Proof.
  ii. inv H. inv MAX.
  eapply MAX0 in RACE; eauto. ss. clarify.
Qed.

Lemma no_flag_max_value_same f vers flag_src flag_tgt lc_src lc_tgt mem_src mem_tgt loc v
      (MEM: sim_memory flag_src f vers mem_src mem_tgt)
      (LOCAL: sim_local f vers flag_src flag_tgt lc_src lc_tgt)
      (FLAGSRC: flag_src loc = None)
      (FLAGTGT: flag_tgt loc = None)
      (MAX: max_value_src loc (Some v) mem_src lc_src)
      (LOCALWF: Local.wf lc_tgt mem_tgt)
      (CONSISTENT: Local.promise_consistent lc_tgt)
      (WF: Mapping.wfs f)
  :
    max_value_tgt loc (Some v) mem_tgt lc_tgt.
Proof.
  inv MAX. destruct lc_tgt. econs. i. clarify.
  hexploit MAX0; eauto. i. des.
  assert (exists val released, max_readable mem_tgt promises loc (View.pln (TView.cur tview) loc) val released).
  { apply NNPP. ii. hexploit non_max_readable_race.
    { ii. eapply H; eauto. }
    { eauto. }
    { eauto. }
    { i. eapply sim_local_racy in H0; eauto.
      eapply race_non_max_readable in H0; eauto. }
  }
  des. esplits; eauto. inv H.
  hexploit sim_memory_get; eauto; ss. i. des.
  hexploit sim_timestamp_le.
  2:{ eapply TO. }
  2:{ refl. }
  { inv LOCAL. eapply TVIEW; ss. }
  { eauto. }
  { eapply mapping_latest_wf_loc. }
  i. inv MAX. inv H.
  { hexploit MAX2; eauto.
    { inv MSG; ss. }
    i. hexploit sim_promises_get_if; eauto.
    { inv LOCAL. eauto. }
    i. des.
    2:{ rewrite FLAGTGT in *; ss. }
    eapply sim_timestamp_exact_unique in TO; eauto.
    2:{ eapply mapping_latest_wf_loc. }
    subst. clarify.
  }
  { inv H0. clarify. inv MSG; auto. }
Qed.

Lemma sim_thread_tgt_read_na
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt0 sc_src sc_tgt
      loc to_tgt val_tgt vw_tgt lc_tgt1
      (READ: Local.read_step lc_tgt0 mem_tgt loc to_tgt val_tgt vw_tgt Ordering.na lc_tgt1)
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt0 sc_src sc_tgt)
      (CONSISTENT: Local.promise_consistent lc_tgt1)
      (LOCAL: Local.wf lc_tgt0 mem_tgt)
      (MEM: Memory.closed mem_tgt)
  :
    (<<SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt1 sc_src sc_tgt>>) /\
    (<<VAL: forall val (VALS: vs_tgt loc = Some val), Const.le val_tgt val>>).
Proof.
  hexploit Local.read_step_future; eauto.
  i. des. splits.
  { inv SIM. econs; eauto.
    { eapply sim_local_tgt_mon; eauto.
      { inv READ; ss. }
    }
    { eapply max_values_tgt_mon; eauto.
      { inv READ; ss. }
    }
  }
  { i. inv SIM. specialize (MAXTGT loc). inv MAXTGT.
    hexploit MAX; eauto. i. des.
    hexploit max_readable_read_only; eauto.
    i. des; auto. etrans; eauto.
  }
Qed.

Lemma sim_thread_tgt_read_na_racy
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt0 sc_src sc_tgt
      loc val_tgt ord
      (READ: Local.racy_read_step lc_tgt0 mem_tgt loc val_tgt ord)
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt0 sc_src sc_tgt)
      (LOCAL: Local.wf lc_tgt0 mem_tgt)
  :
    vs_tgt loc = None.
Proof.
  destruct (vs_tgt loc) eqn:VAL; auto.
  inv SIM. specialize (MAXTGT loc). inv MAXTGT. hexploit MAX; eauto. i. des.
  exfalso. eapply max_readable_not_read_race; eauto.
  Unshelve.
Qed.

Lemma sim_thread_src_read_na
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt
      loc val_src val
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt)
      (VALS: vs_src loc = Some val)
      (VAL: Const.le val_src val)
      (LOCAL: Local.wf lc_src mem_src)
  :
    exists to vw,
      Local.read_step lc_src mem_src loc to val_src vw Ordering.na lc_src.
Proof.
  inv SIM. specialize (MAXSRC loc). inv MAXSRC. hexploit MAX; eauto. i. des.
  hexploit max_readable_read.
  { eauto. }
  { eauto. }
  { eauto. }
  { instantiate (1:=val_src). auto. }
  i. des. esplits; eauto.
Qed.

Lemma sim_thread_src_read_na_racy
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt
      loc val_src
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt)
      (CONSISTENT: Local.promise_consistent lc_tgt)
      (LOCAL: Local.wf lc_src mem_src)
      (VALS: vs_src loc = None)
      (WF: Mapping.wfs f)
  :
    Local.racy_read_step lc_src mem_src loc val_src Ordering.na.
Proof.
  inv SIM. specialize (MAXSRC loc). inv MAXSRC.
  hexploit non_max_readable_read; eauto.
  eapply sim_local_consistent; eauto.
Qed.

Lemma sim_thread_tgt_write_na_racy
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt0 sc_src sc_tgt
      loc
      (WRITE: Local.racy_write_step lc_tgt0 mem_tgt loc Ordering.na)
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt0 sc_src sc_tgt)
      (LOCAL: Local.wf lc_tgt0 mem_tgt)
  :
    vs_tgt loc = None.
Proof.
  destruct (vs_tgt loc) eqn:VAL; auto.
  inv SIM. specialize (MAXTGT loc). inv MAXTGT. hexploit MAX; eauto. i. des.
  exfalso. eapply max_readable_not_write_race; eauto.
Qed.

Lemma sim_thread_src_write_na_racy
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt
      loc
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt)
      (CONSISTENT: Local.promise_consistent lc_tgt)
      (LOCAL: Local.wf lc_src mem_src)
      (VALS: vs_src loc = None)
      (WF: Mapping.wfs f)
  :
    Local.racy_write_step lc_src mem_src loc Ordering.na.
Proof.
  inv SIM. specialize (MAXSRC loc). inv MAXSRC.
  hexploit non_max_readable_write; eauto.
  eapply sim_local_consistent; eauto.
Qed.

Lemma local_write_step_write_na_step
      lc0 sc0 mem0 loc from to val releasedm released lc1 sc1 mem1 kind
      (WRITE: Local.write_step lc0 sc0 mem0 loc from to val releasedm released Ordering.na lc1 sc1 mem1 kind)
  :
    Local.write_na_step lc0 sc0 mem0 loc from to val Ordering.na lc1 sc1 mem1 [] [] kind.
Proof.
  inv WRITE. econs; eauto. econs.
  { eapply WRITABLE. }
  exact WRITE0.
Qed.

Lemma sim_thread_tgt_flag_up
      f vers flag_src flag_tgt vs_src vs_tgt mem_src0 mem_tgt lc_src0 lc_tgt sc_src sc_tgt loc
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src0 mem_tgt lc_src0 lc_tgt sc_src sc_tgt)
      (CONSISTENT: Local.promise_consistent lc_tgt)
      (LOCAL: Local.wf lc_src0 mem_src0)
      (MEM: Memory.closed mem_src0)
      (WF: Mapping.wfs f)
      lang st
  :
    exists mem_src1 lc_src1,
      (<<STEPS: rtc (@Thread.tau_step _)
                    (Thread.mk lang st lc_src0 sc_src mem_src0)
                    (Thread.mk _ st lc_src1 sc_src mem_src1)>>) /\
      (<<SIM: sim_thread
                f vers flag_src (fun loc0 => if Loc.eq_dec loc0 loc
                                             then Some (lc_src1.(Local.tview).(TView.cur).(View.rlx) loc)
                                             else flag_tgt loc0)
                vs_src vs_tgt
                mem_src1 mem_tgt lc_src1 lc_tgt sc_src sc_tgt>>).
Proof.
  destruct (flag_tgt loc) eqn:FLAG.
  { esplits; [refl|].
    match goal with
    | |- _ ?flag_tgt' _ _ _ _ _ _ _ _ => replace flag_tgt' with flag_tgt; auto
    end.
    extensionality loc0. des_ifs.
    inv SIM. inv LOCAL0.
    hexploit FLAGTGT; eauto. i. clarify.
  }
  inv SIM. dup LOCAL0. inv LOCAL0.
  hexploit tgt_flag_up_sim_promises.
  { eauto. }
  { eauto. }
  { eapply sim_local_consistent in CONSISTENT; eauto.
    i. eapply CONSISTENT; eauto.
  }
  { eauto. }
  { eapply LOCAL. }
  { eapply MEM. }
  i. des. esplits; [eapply STEPS|..]. econs; eauto.
  { econs; eauto. i. des_ifs. auto. }
  { ii. hexploit (MAXSRC loc0). i. inv H. econs.
    { i. hexploit MAX; eauto. i. des. esplits. eapply VALS; eauto. }
    { i. hexploit NONMAX; eauto. ii. eapply H. eapply VALS; eauto. }
  }
Qed.

Lemma lower_write_memory_le prom0 mem0 loc from to msg prom1 mem1 kind
      (WRITE: Memory.write prom0 mem0 loc from to msg prom1 mem1 kind)
      (KIND: Memory.op_kind_is_lower kind)
  :
    Memory.le prom1 prom0.
Proof.
  destruct kind; ss. inv WRITE. inv PROMISE. ii.
  erewrite Memory.remove_o in LHS; eauto.
  erewrite Memory.lower_o in LHS; eauto. des_ifs.
Qed.

Lemma na_write_max_readable
      mem0 lc0 loc ts val_old released ord
      lc1 mem1 msgs kinds kind sc0 sc1 from to val_new
      (MAX: max_readable mem0 lc0.(Local.promises) loc ts val_old released)
      (TS: lc0.(Local.tview).(TView.cur).(View.pln) loc = ts)
      (WRITE: Local.write_na_step lc0 sc0 mem0 loc from to val_new ord lc1 sc1 mem1
                                  msgs kinds kind)
      (LOWER: mem1 = mem0)
      (CONS: Local.promise_consistent lc0)
  (* (WF: Local.wf lc0 mem0) *)
  :
    max_readable mem1 lc1.(Local.promises) loc (lc1.(Local.tview).(TView.cur).(View.pln) loc) val_new None.
Proof.
  destruct lc0. unfold Local.promise_consistent in CONS. ss. subst.
  hexploit write_na_step_lower_memory_lower; eauto. i. des.
  inv WRITE. ss.
  revert MAX KINDS KIND CONS. induction WRITE0.
  { i. admit. }
  { i. inv KINDS. destruct kind'; ss. inv WRITE_EX. inv PROMISE.
    eapply IHWRITE0; auto.
    2:{ i. erewrite Memory.remove_o in PROMISE; eauto.
        erewrite Memory.lower_o in PROMISE; eauto. des_ifs.
        eapply CONS; eauto.
    }
    inv MAX. econs; eauto.
    { erewrite Memory.remove_o; eauto.
      erewrite Memory.lower_o; eauto. des_ifs.
    }
    { i. erewrite Memory.remove_o; eauto.
      erewrite Memory.lower_o; eauto. des_ifs.
      { ss. des; clarify. exfalso. exploit CONS.
        { eapply Memory.lower_get0 in PROMISES. des; eauto. }
        { inv MSG_EX; des; ss. }
        i. ts < to'

exfalso.
        eapply MAX0 in TS0.
        {


admit. }
      { eapply MAX0; eauto. }
    }

    }

eauto.


eapply max_readable_not_racy; eauto.
Qed.


Lemma na_write_max_readable mem0 prom0 loc ts from to val1
      (WF: Memory.le prom0 mem0)
      (WRITE: Memory.na_write

      (BOT: Memory.bot_none prom0)
      (RESERVE: forall to' from' msg'
                       (GET: Memory.get loc to' prom0 = Some (from', msg')),
          (<<RESERVE: msg' <> Message.reserve>>) /\
          (<<TS: Time.lt ts to'>>))
      (CLOSED: __guard__ (exists from' msg',
                             (<<GET: Memory.get loc ts mem0 = Some (from', msg')>>) /\ (<<RESERVE: msg' <> Message.reserve>>)))
      (FROM: Time.le (Memory.max_ts loc mem0) from)
      (TO: Time.lt from to)
  :

Lemma max_readable_na_write mem0 prom0 loc ts from to val1
      (WF: Memory.le prom0 mem0)
      (BOT: Memory.bot_none prom0)
      (RESERVE: forall to' from' msg'
                       (GET: Memory.get loc to' prom0 = Some (from', msg')),
          (<<RESERVE: msg' <> Message.reserve>>) /\
          (<<TS: Time.lt ts to'>>))
      (CLOSED: __guard__ (exists from' msg',
                             (<<GET: Memory.get loc ts mem0 = Some (from', msg')>>) /\ (<<RESERVE: msg' <> Message.reserve>>)))
      (FROM: Time.le (Memory.max_ts loc mem0) from)
      (TO: Time.lt from to)
  :
    exists mem1 prom1 mem2 msgs ks,
      (<<MEM: fulfilled_memory loc mem0 mem1>>) /\
      (<<ADD: Memory.add mem1 loc from to (Message.concrete val1 None) mem2>>) /\
      (<<PROMISES: forall loc' ts',
          Memory.get loc' ts' prom1 =
          if Loc.eq_dec loc' loc
          then None
          else Memory.get loc' ts' prom0>>) /\
      (<<WRITE: Memory.write_na ts prom0 mem0 loc from to val1 prom1 mem2 msgs ks Memory.op_kind_add>>) /\
      (<<NONE: Memory.get loc to prom1 = None>>) /\
      (<<MAX: Memory.max_ts loc mem2 = to>>)
.


Lemma sim_thread_tgt_write_na
      f vers flag_src flag_tgt vs_src vs_tgt
      mem_src mem_tgt0 lc_src lc_tgt0 sc_src sc_tgt0
      loc from to val_old val_new lc_tgt1 sc_tgt1 mem_tgt1 ord msgs kinds kind ts
      (WRITE: Local.write_na_step lc_tgt0 sc_tgt0 mem_tgt0 loc from to val_new ord lc_tgt1 sc_tgt1 mem_tgt1 msgs kinds kind)
      (LOWER: mem_tgt1 = mem_tgt0)
      (SIM: sim_thread
              f vers flag_src flag_tgt vs_src vs_tgt
              mem_src mem_tgt0 lc_src lc_tgt0 sc_src sc_tgt0)
      (VAL: vs_tgt loc = Some val_old)
      (FLAG: flag_tgt loc = Some ts)
      (CONSISTENT: Local.promise_consistent lc_tgt1)
      (LOCAL: Local.wf lc_tgt0 mem_tgt0)
      (MEM: Memory.closed mem_tgt0)
      (WF: Mapping.wfs f)
  :
    (<<SIM: sim_thread
              f vers flag_src flag_tgt vs_src (fun loc0 => if Loc.eq_dec loc0 loc then Some val_new else vs_tgt loc0)
              mem_src mem_tgt1 lc_src lc_tgt1 sc_src sc_tgt1>>) /\
    (<<ORD: ord = Ordering.na>>) /\
    (<<SC: sc_tgt1 = sc_tgt0>>)
.
Proof.
  subst. hexploit write_na_step_lower_memory_lower; eauto. i. des.
  assert ((<<MLE: Memory.le lc_tgt1.(Local.promises) lc_tgt0.(Local.promises)>>) /\
          (<<OTHERS: forall loc0 (NEQ: loc0 <> loc) to,
              Memory.get loc0 to lc_tgt1.(Local.promises)
              =
              Memory.get loc0 to lc_tgt0.(Local.promises)>>)).
  { inv WRITE. ss.
    revert KINDS KIND. clear CONSISTENT. induction WRITE0; i.
    { splits.
      { eapply lower_write_memory_le; eauto. destruct kind; ss. }
      { i. inv WRITE. destruct kind; ss. inv PROMISE.
        erewrite (@Memory.remove_o promises2); eauto.
        erewrite (@Memory.lower_o promises0); eauto.
        des_ifs. des; clarify.
      }
    }
    { inv KINDS. splits.
      { transitivity promises'.
        { eapply IHWRITE0; eauto. }
        { eapply lower_write_memory_le; eauto. destruct kind'; ss. }
      }
      { i. inv WRITE_EX. destruct kind'; ss. inv PROMISE.
        transitivity (Memory.get loc0 to0 promises').
        { eapply IHWRITE0; eauto. }
        { erewrite (@Memory.remove_o promises'); eauto.
          erewrite (@Memory.lower_o promises0); eauto.
          des_ifs. des; clarify.
        }
      }
    }
  }
  hexploit sim_local_consistent.
  { eapply PromiseConsistent.write_na_step_promise_consistent; eauto. }
  { inv SIM. eauto. }
  { auto. }
  intros CONSSRC. des. splits.
  2:{ inv WRITE. destruct ord; ss. }
  2:{ inv WRITE. auto. }
  inv SIM. econs; auto.
  { inv WRITE. auto. }
  { inv WRITE. inv LOCAL0. econs; ss; auto.
    { eapply sim_tview_tgt_mon; eauto.
      eapply TViewFacts.write_tview_incr. eapply LOCAL.
    }
    { econs.
      { i. eapply MLE in GET. hexploit sim_promises_get; eauto.
        i. des. esplits; eauto.
      }
      { i. destruct (Loc.eq_dec loc0 loc).
        { subst. right. esplits; eauto. eapply FLAGTGT in FLAG. subst.
          i. eapply CONSSRC; eauto.
        }
        { hexploit sim_promises_get_if; eauto. i. des.
          { left. esplits; eauto. rewrite OTHERS; eauto. }
          { right. esplits; eauto. }
        }
      }
      { i. eapply sim_promises_none; eauto. }
    }
    { inv RELVERS. econs. i. eapply MLE in GET. eauto. }
  }
  { ii. des_ifs.
    { inv WRITE. econs; ss. i.
      clear CONSISTENT. clarify.

admit. }
    { hexploit (MAXTGT loc0). i.
      inv H. inv WRITE. econs; ss.
      i. hexploit MAX; eauto. i. des. esplits; eauto.
      match goal with
      | |- _ ?vw _ _ => replace vw with (tvw.(TView.cur).(View.pln) loc0)
      end.
      { inv MAX0. econs; eauto.
        { rewrite OTHERS; eauto. }
        { i. rewrite OTHERS; eauto. }
      }
      { symmetry. eapply TimeFacts.le_join_l. unfold TimeMap.singleton.
        setoid_rewrite LocFun.add_spec_neq; auto. eapply Time.bot_spec.
      }
    }
  }
  { i. des_ifs. specialize (PERM loc).
    rewrite VAL in PERM. unfold option_rel in *. des_ifs.
  }
Qed.

rewrite <- VAL.


Time.join unfold TimeMap.join, TimeMap.singleton.


      inv MAX0. econs; eauto.


clarify.


econs.


      eapply PROM.

      h


admit. }
  {




destruct ord; ss. }

induction WRITE. inv WRITE.

  inv

     Proof.
  hexploit Local.read_step_future; eauto.
  i. des. splits.
  { inv SIM. econs; eauto.
    { eapply sim_local_tgt_mon; eauto.
      { inv READ; ss. }
    }
    { eapply max_values_tgt_mon; eauto.
      { inv READ; ss. }
    }
  }
  { i. inv SIM. specialize (MAXTGT loc). inv MAXTGT.
    hexploit MAX; eauto. i. des.
    hexploit max_readable_read_only; eauto.
    i. des; auto. etrans; eauto.
  }
Qed.

Local.write_step

Lemma cap_max_readable mem cap prom loc ts val released
      (CAP: Memory.cap mem cap)
      (MLE: Memory.le prom mem)
      (MEM: Memory.closed mem)
  :
    max_readable mem prom loc ts val released
    <->
    max_readable cap prom loc ts val released.
Proof.
  split.
  { i. inv H. econs; eauto.
    { eapply Memory.cap_le; [..|eauto]; eauto. refl. }
    { i. eapply Memory.cap_inv in GET0; eauto. des; clarify.
      eapply MAX in GET0; eauto.
    }
  }
  { i. inv H. eapply Memory.cap_inv in GET; eauto. des; clarify.
    econs; eauto. i. eapply MAX; eauto.
    eapply Memory.cap_le; [..|eauto]; eauto. refl.
  }
Qed.

Lemma cap_max_values_src vs mem cap lc
      (MAX: max_values_src vs mem lc)
      (CAP: Memory.cap mem cap)
      (LOCAL: Local.wf lc mem)
      (MEM: Memory.closed mem)
  :
    max_values_src vs cap lc.
Proof.
  ii. specialize (MAX loc). inv MAX. econs.
  { i. hexploit MAX0; eauto. i. des. esplits; eauto.
    erewrite <- cap_max_readable; eauto. eapply LOCAL.
  }
  { i. hexploit NONMAX; eauto. ii. eapply H.
    erewrite cap_max_readable; eauto. eapply LOCAL.
  }
Qed.

Lemma cap_max_values_tgt vs mem cap lc
      (MAX: max_values_tgt vs mem lc)
      (CAP: Memory.cap mem cap)
      (LOCAL: Local.wf lc mem)
      (MEM: Memory.closed mem)
  :
    max_values_tgt vs cap lc.
Proof.
  ii. specialize (MAX loc). inv MAX. econs.
  i. hexploit MAX0; eauto. i. des. esplits; eauto.
  erewrite <- cap_max_readable; eauto. eapply LOCAL.
Qed.

Lemma sim_promises_preserve
      prom_src prom_tgt flag_src flag_tgt f0 f1 vers mem
      (SIM: sim_promises flag_src flag_tgt f0 vers prom_src prom_tgt)
      (MAPLE: Mapping.les f0 f1)
      (PRESERVE: forall loc to from msg
                        (GET: Memory.get loc to mem = Some (from, msg))
                        ts fts
                        (TS: Time.le ts to)
                        (MAP: sim_timestamp_exact (f0 loc) (f0 loc).(Mapping.ver) fts ts),
          sim_timestamp_exact (f1 loc) (f1 loc).(Mapping.ver) fts ts)
      (MLE: Memory.le prom_tgt mem)
      (WF: Mapping.wfs f0)
      (VERS: versions_wf f0 vers)
  :
    sim_promises flag_src flag_tgt f1 vers prom_src prom_tgt.
Proof.
  econs.
  { i. hexploit sim_promises_get; eauto. i. des. esplits.
    { eapply PRESERVE; eauto. eapply memory_get_ts_le; eauto. }
    { eapply PRESERVE; eauto. refl. }
    { eauto. }
    { erewrite <- sim_message_max_mon_mapping; eauto. }
  }
  { i. hexploit sim_promises_get_if; eauto. i. des.
    { left. esplits.
      { eapply PRESERVE; eauto. refl. }
      { eauto. }
    }
    { right. esplits; eauto. }
  }
  { i. eapply sim_promises_none; eauto. }
Qed.

Lemma sim_thread_cap
      f0 vers flag_tgt vs_src vs_tgt
      mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt
      cap_src cap_tgt
      (SIM: sim_thread
              f0 vers (fun _ => None) flag_tgt vs_src vs_tgt
              mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt)
      (CAPSRC: Memory.cap mem_src cap_src)
      (CAPTGT: Memory.cap mem_tgt cap_tgt)
      (WF: Mapping.wfs f0)
      (VERS: versions_wf f0 vers)
      (MEMSRC: Memory.closed mem_src)
      (MEMTGT: Memory.closed mem_tgt)
      (LOCALSRC: Local.wf lc_src mem_src)
      (LOCALTGT: Local.wf lc_tgt mem_tgt)
  :
    exists f1,
      (<<MAPLE: Mapping.les f0 f1>>) /\
      (<<MAPWF: Mapping.wfs f1>>) /\
      (<<SIM: sim_thread
                f1 vers (fun _ => None) flag_tgt vs_src vs_tgt
                cap_src cap_tgt lc_src lc_tgt sc_src sc_tgt>>) /\
      (<<VERS: versions_wf f1 vers>>)
.
Proof.
  inv SIM. hexploit cap_sim_memory; eauto. i. des. esplits; eauto.
  2:{ eapply versions_wf_mapping_mon; eauto. }
  econs; eauto.
  { eapply sim_timemap_mon_latest; eauto. }
  { inv LOCAL. econs; eauto.
    { eapply sim_tview_mon_latest; eauto. }
    { eapply sim_promises_preserve; eauto. eapply LOCALTGT. }
  }
  { eapply cap_max_values_src; eauto. }
  { eapply cap_max_values_tgt; eauto. }
Qed.

Lemma sim_readable L f vw_src vw_tgt loc to_src to_tgt released_src released_tgt ord
      (READABLE: TView.readable vw_tgt loc to_tgt released_tgt ord)
      (SIM: sim_view L f (Mapping.vers f) vw_src vw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (WF: Mapping.wfs f)
      (LOC: L loc)
  :
    TView.readable vw_src loc to_src released_src ord.
Proof.
  inv READABLE. econs.
  { eapply sim_timestamp_le.
    { eapply SIM. auto. }
    { eauto. }
    { eauto. }
    { eauto. }
    { eapply mapping_latest_wf_loc. }
  }
  { i. eapply sim_timestamp_le.
    { eapply SIM. auto. }
    { eauto. }
    { eauto. }
    { eauto. }
    { eapply mapping_latest_wf_loc. }
  }
Qed.

Lemma sim_writable L f vw_src vw_tgt loc to_src to_tgt sc_src sc_tgt ord
      (WRITABLE: TView.writable vw_tgt sc_tgt loc to_tgt ord)
      (SIM: sim_view L f (Mapping.vers f) vw_src vw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (WF: Mapping.wfs f)
      (LOC: L loc)
  :
    TView.writable vw_src sc_src loc to_src ord.
Proof.
  inv WRITABLE. econs.
  eapply sim_timestamp_lt.
  { eapply SIM. auto. }
  { eauto. }
  { eauto. }
  { eauto. }
  { eapply mapping_latest_wf_loc. }
Qed.

Lemma semi_sim_timemap_join loc f v to_src to_tgt tm_src tm_tgt
      (SIM: sim_timemap (fun loc0 => loc0 <> loc) f v tm_src tm_tgt)
      (TS: sim_timestamp (f loc) (v loc) to_src to_tgt)
      (LESRC: time_le_timemap loc to_src tm_src)
      (LETGT: time_le_timemap loc to_tgt tm_tgt)
      (WF: Mapping.wfs f)
      (VER: version_wf f v)
  :
    sim_timemap (fun _ => True) f v (TimeMap.join (TimeMap.singleton loc to_src) tm_src) (TimeMap.join (TimeMap.singleton loc to_tgt) tm_tgt).
Proof.
  ii. destruct (Loc.eq_dec l loc).
  { subst. unfold TimeMap.join.
    repeat rewrite TimeFacts.le_join_l.
    { eapply sim_timemap_singleton; ss. }
    { unfold TimeMap.singleton. setoid_rewrite LocFun.add_spec_eq.
      eapply LETGT. }
    { unfold TimeMap.singleton. setoid_rewrite LocFun.add_spec_eq.
      eapply LESRC. }
  }
  { eapply sim_timestamp_join; eauto.
    unfold TimeMap.singleton. setoid_rewrite LocFun.add_spec_neq; eauto.
    eapply sim_timestamp_bot; eauto.
  }
Qed.

Lemma semi_sim_view_join loc f v to_src to_tgt vw_src vw_tgt
      (SIM: sim_view (fun loc0 => loc0 <> loc) f v vw_src vw_tgt)
      (TS: sim_timestamp (f loc) (v loc) to_src to_tgt)
      (LESRC: time_le_view loc to_src vw_src)
      (LETGT: time_le_view loc to_tgt vw_tgt)
      (WF: Mapping.wfs f)
      (VER: version_wf f v)
  :
    sim_view (fun _ => True) f v (View.join (View.singleton_ur loc to_src) vw_src) (View.join (View.singleton_ur loc to_tgt) vw_tgt).
Proof.
  econs.
  { eapply semi_sim_timemap_join; eauto.
    { eapply SIM. }
    { eapply LESRC. }
    { eapply LETGT. }
  }
  { eapply semi_sim_timemap_join; eauto.
    { eapply SIM. }
    { eapply LESRC. }
    { eapply LETGT. }
  }
Qed.

Lemma semi_sim_opt_view_join loc f v to_src to_tgt released_src released_tgt
      (SIM: sim_opt_view (fun loc0 => loc0 <> loc) f (Some v) released_src released_tgt)
      (TS: sim_timestamp (f loc) (v loc) to_src to_tgt)
      (LESRC: time_le_opt_view loc to_src released_src)
      (LETGT: time_le_opt_view loc to_tgt released_tgt)
      (WF: Mapping.wfs f)
      (VER: version_wf f v)
  :
    sim_view (fun _ => True) f v (View.join (View.singleton_ur loc to_src) (View.unwrap released_src)) (View.join (View.singleton_ur loc to_tgt) (View.unwrap released_tgt)).
Proof.
  inv SIM; ss.
  { inv LESRC. inv LETGT. eapply semi_sim_view_join; eauto. }
  { eapply sim_view_join; eauto.
    { eapply sim_view_singleton_ur; eauto. }
    { eapply sim_view_bot; eauto. }
  }
Qed.

Lemma sim_opt_view_mon_opt_ver L f v0 v1 vw_src vw_tgt
      (SIM: sim_opt_view L f v0 vw_src vw_tgt)
      (VER: forall v0' (VER: v0 = Some v0'),
          exists v1', (<<VER: v1 = Some v1'>>) /\(<<VERLE: version_le v0' v1'>>))
      (WF: Mapping.wfs f)
      (VERWF: opt_version_wf f v1)
  :
    sim_opt_view L f v1 vw_src vw_tgt.
Proof.
  destruct v0.
  { hexploit VER; eauto. i. des. clarify.
    eapply sim_opt_view_mon_ver; eauto.
  }
  { inv SIM. econs. }
Qed.

Lemma sim_read_tview f flag_src rel_vers tvw_src tvw_tgt v
      loc to_src released_src ord to_tgt released_tgt
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (CLOSED: Mapping.closed (f loc) (Mapping.vers f loc) to_src)
      (RELEASED: sim_opt_view (fun loc0 => loc0 <> loc) f v released_src released_tgt)
      (WF: Mapping.wfs f)
      (VERWF: opt_version_wf f v)
      (LESRC: time_le_opt_view loc to_src released_src)
      (LETGT: time_le_opt_view loc to_tgt released_tgt)
  :
    sim_tview f flag_src rel_vers (TView.read_tview tvw_src loc to_src released_src ord) (TView.read_tview tvw_tgt loc to_tgt released_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  assert (TM: sim_timestamp (f loc) (Mapping.vers f loc) to_src to_tgt).
  { eapply sim_timestamp_exact_sim; eauto. }
  assert (JOIN: sim_view (fun loc0 => flag_src loc0 = None) f (Mapping.vers f)
                         (View.join (View.singleton_ur loc to_src) (View.unwrap released_src))
                         (View.join (View.singleton_ur loc to_tgt) (View.unwrap released_tgt))).
  { eapply sim_view_mon_locs.
    { eapply semi_sim_opt_view_join; eauto.
      eapply sim_opt_view_mon_opt_ver; eauto.
      i. clarify. splits; eauto.
    }
    { ss. }
  }
  econs.
  { eapply SIM. }
  { ss. rewrite View.join_assoc. rewrite View.join_assoc.
    eapply sim_view_join; eauto.
    { eapply SIM. }
    unfold View.singleton_ur_if. des_ifs.
    { eapply sim_view_join; eauto.
      { eapply sim_view_singleton_ur; eauto. }
      { eapply sim_view_bot; eauto. }
    }
    { destruct ord; ss. }
    { eapply sim_view_join; eauto.
      { eapply sim_view_singleton_rw; eauto. }
      { eapply sim_view_bot; eauto. }
    }
  }
  { ss. rewrite View.join_assoc. rewrite View.join_assoc.
    eapply sim_view_join; eauto.
    { eapply SIM. }
    unfold View.singleton_ur_if. des_ifs.
    { eapply sim_view_join; eauto.
      { eapply sim_view_singleton_rw; eauto. }
      { eapply sim_view_bot; eauto. }
    }
  }
  { i. eapply SIM. }
Qed.

Lemma sim_write_tview_normal f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      loc to_src ord to_tgt
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (ORD: ~ Ordering.le Ordering.acqrel ord)
      (CLOSED: Mapping.closed (f loc) (Mapping.vers f loc) to_src)
      (WF: Mapping.wfs f)
  :
    sim_tview f flag_src rel_vers (TView.write_tview tvw_src sc_src loc to_src ord) (TView.write_tview tvw_tgt sc_tgt loc to_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  assert (TM: sim_timestamp (f loc) (Mapping.vers f loc) to_src to_tgt).
  { eapply sim_timestamp_exact_sim; eauto. }
  assert (JOIN: sim_view (fun loc0 => flag_src loc0 = None) f (Mapping.vers f)
                         (View.singleton_ur loc to_src)
                         (View.singleton_ur loc to_tgt)).
  { apply sim_view_singleton_ur; eauto. }
  econs; ss.
  { ii. setoid_rewrite LocFun.add_spec. des_ifs.
    { eapply sim_view_join; eauto.
      { eapply SIM. }
      { apply sim_view_singleton_ur; eauto; ss. eapply SIM. }
      { eapply SIM. }
    }
    { eapply SIM. }
  }
  { eapply sim_view_join; eauto. eapply SIM. }
  { eapply sim_view_join; eauto. eapply SIM. }
  { eapply SIM. }
Qed.

Lemma sim_write_tview_release f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      loc to_src ord to_tgt
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (FLAG: forall loc, flag_src loc = None)
      (CLOSED: Mapping.closed (f loc) (Mapping.vers f loc) to_src)
      (WF: Mapping.wfs f)
  :
    sim_tview f flag_src (fun loc0 => if Loc.eq_dec loc0 loc then (Mapping.vers f) else rel_vers loc0) (TView.write_tview tvw_src sc_src loc to_src ord) (TView.write_tview tvw_tgt sc_tgt loc to_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  assert (TM: sim_timestamp (f loc) (Mapping.vers f loc) to_src to_tgt).
  { eapply sim_timestamp_exact_sim; eauto. }
  assert (JOIN: forall L, sim_view L f (Mapping.vers f)
                                   (View.singleton_ur loc to_src)
                                   (View.singleton_ur loc to_tgt)).
  { i. apply sim_view_singleton_ur; eauto. }
  econs; ss.
  { ii. setoid_rewrite LocFun.add_spec. des_ifs.
    { eapply sim_view_join; eauto.
      { eapply sim_view_mon_locs.
        { eapply SIM. }
        { i. ss. }
      }
    }
    { eapply sim_view_join; eauto.
      { eapply sim_view_mon_ver; auto.
        { eapply SIM. }
        { eapply version_le_version_wf. eapply SIM. }
      }
    }
    { eapply SIM. }
  }
  { eapply sim_view_join; eauto. eapply SIM. }
  { eapply sim_view_join; eauto. eapply SIM. }
  { i. des_ifs. eapply SIM. }
Qed.

Lemma sim_read_fence_tview f flag_src rel_vers tvw_src tvw_tgt
      ord
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (WF: Mapping.wfs f)
  :
    sim_tview f flag_src rel_vers (TView.read_fence_tview tvw_src ord) (TView.read_fence_tview tvw_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  econs; ss.
  { eapply SIM. }
  { des_ifs.
    { eapply SIM. }
    { eapply SIM. }
  }
  { eapply SIM. }
  { eapply SIM. }
Qed.

Lemma sim_write_fence_tview_normal f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      ord
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (ORD: ~ Ordering.le Ordering.acqrel ord)
      (WF: Mapping.wfs f)
  :
    sim_tview f flag_src rel_vers (TView.write_fence_tview tvw_src sc_src ord) (TView.write_fence_tview tvw_tgt sc_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  econs; ss.
  { des_ifs. eapply SIM. }
  { des_ifs.
    { destruct ord; ss. }
    { eapply SIM. }
  }
  { des_ifs.
    { destruct ord; ss. }
    { rewrite ! View.join_bot_r. eapply SIM. }
  }
  { eapply SIM. }
Qed.

Lemma sim_write_fence_tview_release f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      ord
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (SC: sim_timemap (fun _ => True) f (Mapping.vers f) sc_src sc_tgt)
      (FLAG: forall loc, flag_src loc = None)
      (WF: Mapping.wfs f)
  :
    sim_tview f flag_src (fun _ => Mapping.vers f) (TView.write_fence_tview tvw_src sc_src ord) (TView.write_fence_tview tvw_tgt sc_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  assert (JOIN: forall L, sim_timemap L f (Mapping.vers f)
                                      (TView.write_fence_sc tvw_src sc_src ord)
                                      (TView.write_fence_sc tvw_tgt sc_tgt ord)).
  { i. unfold TView.write_fence_sc. des_ifs.
    { eapply sim_timemap_join; eauto.
      { eapply sim_timemap_mon_locs; eauto. ss. }
      { eapply sim_timemap_mon_locs.
        { eapply SIM. }
        { ss. }
      }
    }
    { eapply sim_timemap_mon_locs; eauto. ss. }
  }
  econs; ss.
  { des_ifs.
    { i. eapply sim_view_mon_locs.
      { eapply SIM. }
      { ss. }
    }
    { i. eapply sim_view_mon_locs.
      { eapply sim_view_mon_ver; auto.
        { eapply SIM. }
        { eapply version_le_version_wf. eapply SIM. }
      }
      { ss. }
    }
  }
  { des_ifs. eapply SIM. }
  { eapply sim_view_join; auto.
    { eapply SIM. }
    { des_ifs. eapply sim_view_bot; auto. }
  }
Qed.

Lemma sim_write_fence_sc f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      ord
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (SC: sim_timemap (fun _ => True) f (Mapping.vers f) sc_src sc_tgt)
      (FLAG: Ordering.le Ordering.seqcst ord -> forall loc, flag_src loc = None)
      (WF: Mapping.wfs f)
  :
    sim_timemap (fun _ => True) f (Mapping.vers f) (TView.write_fence_sc tvw_src sc_src ord) (TView.write_fence_sc tvw_tgt sc_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  unfold TView.write_fence_sc. des_ifs. eapply sim_timemap_join; auto.
  eapply sim_timemap_mon_locs; eauto.
  { eapply SIM. }
  { ss. i. auto. }
Qed.

Lemma sim_write_released_normal f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      loc to_src ord to_tgt released_src released_tgt v
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (RELEASED: sim_opt_view (fun loc0 => loc0 <> loc) f v released_src released_tgt)
      (ORD: ~ Ordering.le Ordering.acqrel ord)
      (VER: Ordering.le Ordering.relaxed ord -> v = Some (rel_vers loc))
      (CLOSED: Mapping.closed (f loc) (Mapping.vers f loc) to_src)
      (WF: Mapping.wfs f)
  :
    sim_opt_view (fun loc0 => loc0 <> loc) f v
                 (TView.write_released tvw_src sc_src loc to_src released_src ord)
                 (TView.write_released tvw_tgt sc_tgt loc to_tgt released_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  unfold TView.write_released. des_ifs.
  { rewrite VER in *; auto. econs.
    eapply sim_view_join; auto.
    { eapply sim_opt_view_unwrap; eauto.
      { eapply SIM. }
      { i. clarify. }
    }
    { ss. setoid_rewrite LocFun.add_spec_eq. des_ifs.
      eapply sim_view_join; auto.
      { eapply SIM. }
      { eapply sim_view_singleton_ur; auto; ss. apply SIM. }
      { apply SIM. }
    }
    { apply SIM. }
  }
  { econs. }
Qed.

Lemma sim_write_released_release f flag_src rel_vers tvw_src tvw_tgt sc_src sc_tgt
      loc to_src ord to_tgt released_src released_tgt v
      (SIM: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
      (TO: sim_timestamp_exact (f loc) (f loc).(Mapping.ver) to_src to_tgt)
      (RELEASED: sim_opt_view (fun loc0 => loc0 <> loc) f v released_src released_tgt)
      (VERWF: opt_version_wf f v)
      (FLAG: forall loc, flag_src loc = None)
      (CLOSED: Mapping.closed (f loc) (Mapping.vers f loc) to_src)
      (WF: Mapping.wfs f)
  :
    sim_opt_view (fun loc0 => loc0 <> loc) f (Some (Mapping.vers f))
                 (TView.write_released tvw_src sc_src loc to_src released_src ord)
                 (TView.write_released tvw_tgt sc_tgt loc to_tgt released_tgt ord).
Proof.
  pose proof (mapping_latest_wf f).
  unfold TView.write_released. des_ifs; econs.
  eapply sim_view_join; auto.
  { eapply sim_opt_view_unwrap; eauto. i. clarify. }
  { ss. setoid_rewrite LocFun.add_spec_eq. des_ifs.
    { eapply sim_view_join; auto.
      { eapply sim_view_mon_locs; eauto.
        { eapply SIM. }
        { i. ss. }
      }
      { eapply sim_view_singleton_ur; auto; ss. }
    }
    { eapply sim_view_join; auto.
      { eapply sim_view_mon_ver; auto.
        { eapply SIM. }
        { eapply version_le_version_wf. eapply SIM. }
      }
      { eapply sim_view_singleton_ur; auto; ss. }
    }
  }
Qed.

Variant sim_local
        (f: Mapping.ts) (vers: versions)
        (flag_src: Loc.t -> option Time.t)
        (flag_tgt: Loc.t -> option Time.t)
  :
    Local.t -> Local.t -> Prop :=
| sim_local_intro
    tvw_src tvw_tgt prom_src prom_tgt rel_vers
    (TVIEW: sim_tview f flag_src rel_vers tvw_src tvw_tgt)
    (PROMISES: sim_promises flag_src flag_tgt f vers prom_src prom_tgt)
    (RELVERS: wf_release_vers vers prom_tgt rel_vers)
    (FLAGTGT: forall loc ts (FLAG: flag_tgt loc = Some ts),
        tvw_src.(TView.cur).(View.rlx) loc = ts)
    (FLAGSRC: forall loc ts (FLAG: flag_src loc = Some ts),
        tvw_src.(TView.cur).(View.rlx) loc = ts)
  :
    sim_local
      f vers flag_src flag_tgt
      (Local.mk tvw_src prom_src)
      (Local.mk tvw_tgt prom_tgt)
.


Variant sim_thread
        (f: Mapping.ts) (vers: versions)
        (flag_src: Loc.t -> option Time.t)
        (flag_tgt: Loc.t -> option Time.t)
        (vs_src: Loc.t -> option Const.t)
        (vs_tgt: Loc.t -> option Const.t)
        mem_src mem_tgt lc_src lc_tgt sc_src sc_tgt: Prop :=
| sim_thread_intro
    (* (SC: sim_timemap (fun _ => True) f (Mapping.vers f) sc_src sc_tgt) *)
    (* (MEM: sim_memory flag_src f vers mem_src mem_tgt) *)

    (TVIEW: sim_tview f flag_src rel_vers tvw_src tvw_tgt)

    (PROMISES: sim_promises flag_src flag_tgt f vers prom_src prom_tgt)
    (RELVERS: wf_release_vers vers prom_tgt rel_vers)
    (FLAGTGT: forall loc ts (FLAG: flag_tgt loc = Some ts),
        tvw_src.(TView.cur).(View.rlx) loc = ts)
    (FLAGSRC: forall loc ts (FLAG: flag_src loc = Some ts),
        tvw_src.(TView.cur).(View.rlx) loc = ts)

    (LOCAL: sim_local f vers flag_src flag_tgt lc_src lc_tgt)
    (MAXSRC: max_values_src vs_src mem_src lc_src)
    (MAXTGT: max_values_tgt vs_tgt mem_tgt lc_tgt)
    (PERM: forall loc, option_rel (fun _ _ => True) (vs_src loc) (vs_tgt loc))
.



Variant initial_finalized: Messages.t :=
| initial_finalized_intro
    loc
  :
    initial_finalized loc Time.bot Time.bot Message.elt
.

Lemma configuration_initial_finalized s
  :
    finalized (Configuration.init s) = initial_finalized.
Proof.
  extensionality loc.
  extensionality from.
  extensionality to.
  extensionality msg.
  apply Coq.Logic.PropExtensionality.propositional_extensionality.
  split; i.
  { inv H. ss. unfold Memory.init, Memory.get in GET.
    rewrite Cell.init_get in GET. des_ifs. }
  { inv H. econs; eauto. i. ss. unfold Threads.init in *.
    rewrite IdentMap.Facts.map_o in TID. unfold option_map in *. des_ifs.
  }
Qed.

Definition initial_mapping: Mapping.t :=
  Mapping.mk
    (fun v ts =>
       if PeanoNat.Nat.eq_dec v 0 then
         if (Time.eq_dec ts Time.bot) then Some (Time.bot)
         else None
       else None)
    0
    (fun _ ts => ts = Time.bot)
.

Definition initial_vers: versions :=
  fun loc ts =>
    if (Time.eq_dec ts Time.bot) then Some (fun _ => 0) else None.

Section LIFT.
  Let world := (Mapping.ts * versions)%type.

  Let world_bot: world := (fun _ => initial_mapping, initial_vers).

  Let world_messages_le (msgs: Messages.t) (w0: world) (w1: world): Prop :=
    let (f0, vers0) := w0 in
    let (f1, vers1) := w1 in
    Mapping.les f0 f1 /\ versions_le vers0 vers1.

  Let sim_memory (b: bool) (w: world) (views: Loc.t -> Time.t -> list View.t)
      (mem_src: Memory.t) (mem_tgt: Memory.t): Prop :=
    let (f, vers) := w in
    sim_memory (fun _ => None) f vers mem_src mem_tgt.

  Let sim_timemap (w: world)
      (tm_src: TimeMap.t) (tm_tgt: TimeMap.t): Prop :=
    let (f, vers) := w in
    sim_timemap (fun _ => True) f (Mapping.vers f) tm_src tm_tgt.

  Let sim_local (w: world) (views: Loc.t -> Time.t -> list View.t) (lc_src: Local.t) (lc_tgt: Local.t): Prop :=
    let (f, vers) := w in
    sim_local f vers (fun _ => None) (fun _ => None) lc_src lc_tgt.



  Lemma world_messages_le_PreOrder: forall msgs, PreOrder (world_messages_le msgs).
  Proof.
    ii. econs.
    { ii. red. des_ifs. splits; auto.
      { refl. }
      { refl. }
    }
    { ii. unfold world_messages_le in *. des_ifs. des. splits; auto.
      { etrans; eauto. }
      { etrans; eauto. }
    }
  Qed.

  Lemma sim_local_memory_bot:
    forall w views lc_src lc_tgt
           (SIM: sim_local w views lc_src lc_tgt)
           (BOT: (Local.promises lc_tgt) = Memory.bot),
      (Local.promises lc_src) = Memory.bot.
  Proof.
    ii. unfold sim_local in *. des_ifs. inv SIM. ss. subst.
    inv PROMISES. eapply Memory.ext. ii.
    rewrite Memory.bot_get.
    destruct (Memory.get loc ts prom_src) eqn:EQ; auto. destruct p.
    hexploit SOUND; eauto. i. des; ss. rewrite Memory.bot_get in GET. ss.
  Qed.

  Lemma world_messages_le_mon:
    forall msgs0 msgs1 w0 w1
           (LE: world_messages_le msgs1 w0 w1)
           (MSGS: msgs0 <4= msgs1),
      world_messages_le msgs0 w0 w1.
  Proof.
    unfold world_messages_le. ii. des_ifs.
  Qed.

  Lemma sim_lift_gsim lang_src lang_tgt sim_terminal
        (st_src: lang_src.(Language.state)) (st_tgt: lang_tgt.(Language.state))
        (SIM: @sim_seq_all _ _ sim_terminal st_src st_tgt)
    :
      @sim_thread_past
        world world_messages_le sim_memory sim_timemap sim_local
        lang_src lang_tgt sim_terminal false world_bot st_src Local.init TimeMap.bot Memory.init st_tgt Local.init TimeMap.bot Memory.init (JConfiguration.init_views, initial_finalized).
  Proof.
  Admitted.
End LIFT.
