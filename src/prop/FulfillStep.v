From sflib Require Import sflib.
From Paco Require Import paco.

From PromisingLib Require Import Axioms.
From PromisingLib Require Import Basic.
From PromisingLib Require Import Loc.
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

Require Import MemorySplit.
Require Import MemoryMerge.

Set Implicit Arguments.


Inductive fulfill_step (lc1:Local.t) (sc1:TimeMap.t) (loc:Loc.t) (from to:Time.t) (val:Const.t) (releasedm released:option View.t) (ord:Ordering.t): forall (lc2:Local.t) (sc2:TimeMap.t), Prop :=
| step_fulfill
    promises2
    (REL_LE: View.opt_le (TView.write_released (Local.tview lc1) sc1 loc to releasedm ord) released)
    (REL_WF: View.opt_wf released)
    (WRITABLE: TView.writable (TView.cur (Local.tview lc1)) sc1 loc to ord)
    (REMOVE: Memory.remove (Local.promises lc1) loc from to (Message.concrete val released) promises2)
    (TIME: Time.lt from to):
    fulfill_step lc1 sc1 loc from to val releasedm released ord
                 (Local.mk (TView.write_tview (Local.tview lc1) sc1 loc to ord) promises2)
                 sc1
.

Inductive fulfill_undef_step (lc1:Local.t) (sc1:TimeMap.t) (loc:Loc.t) (from to:Time.t) (ord:Ordering.t):
  forall (lc2:Local.t) (sc2:TimeMap.t), Prop :=
| step_fulfill_undef
    promises2
    (NA: Ordering.le ord Ordering.na)
    (WRITABLE: TView.writable lc1.(Local.tview).(TView.cur) sc1 loc to ord)
    (REMOVE: Memory.remove lc1.(Local.promises) loc from to Message.undef promises2)
    (TIME: Time.lt from to):
    fulfill_undef_step lc1 sc1 loc from to ord (Local.mk lc1.(Local.tview) promises2) sc1
.

Lemma fulfill_step_future lc1 sc1 mem1 loc from to val releasedm released ord lc2 sc2
      (STEP: fulfill_step lc1 sc1 loc from to val releasedm released ord lc2 sc2)
      (REL: Memory.closed_opt_view releasedm mem1)
      (WF1: Local.wf lc1 mem1)
      (SC1: Memory.closed_timemap sc1 mem1)
      (CLOSED1: Memory.closed mem1):
  <<WF2: Local.wf lc2 mem1>> /\
  <<SC2: Memory.closed_timemap sc2 mem1>> /\
  <<SC_FUTURE: TimeMap.le sc1 sc2>>.
Proof.
  inv STEP.
  hexploit Memory.remove_future; try apply REMOVE; try apply WF1; eauto. i. des.
  exploit Memory.remove_get0; eauto. i. des.
  inversion WF1. exploit PROMISES; eauto. i.
  exploit TViewFacts.write_future_fulfill; try apply x; try apply SC1; try apply WF1; eauto.
  { inv CLOSED1. exploit CLOSED; eauto. i. des. inv MSG_CLOSED. eauto. }
  i. des.
  esplits; eauto; try refl.
  econs; eauto; ss.
  ii. erewrite Memory.remove_o; eauto. condtac; ss.
Qed.

Lemma fulfill_undef_step_future
      lc1 sc1 mem1 loc from to ord lc2 sc2
      (STEP: fulfill_undef_step lc1 sc1 loc from to ord lc2 sc2)
      (WF1: Local.wf lc1 mem1)
      (SC1: Memory.closed_timemap sc1 mem1)
      (CLOSED1: Memory.closed mem1):
  <<WF2: Local.wf lc2 mem1>> /\
  <<SC2: Memory.closed_timemap sc2 mem1>> /\
  <<SC_FUTURE: TimeMap.le sc1 sc2>>.
Proof.
  inv STEP.
  hexploit Memory.remove_future; try apply REMOVE; try apply WF1; eauto. i. des.
  splits; auto; try refl.
  inv WF1. econs; eauto; ss.
  eapply Memory.remove_bot_none; eauto.
Qed.

Lemma write_promise_fulfill
      lc0 sc0 mem0 loc from to val releasedm released ord lc2 sc2 mem2 kind
      (WRITE: Local.write_step lc0 sc0 mem0 loc from to val releasedm released ord lc2 sc2 mem2 kind)
      (REL_WF: View.opt_wf releasedm)
      (REL_CLOSED: Memory.closed_opt_view releasedm mem0)
      (WF0: Local.wf lc0 mem0)
      (SC0: Memory.closed_timemap sc0 mem0)
      (MEM0: Memory.closed mem0):
  exists lc1,
    <<STEP1: Local.promise_step lc0 mem0 loc from to (Message.concrete val released) lc1 mem2 kind>> /\
    <<STEP2: fulfill_step lc1 sc0 loc from to val releasedm released ord lc2 sc2>> /\
    <<REL: released = TView.write_released (Local.tview lc0) sc0 loc to releasedm ord>> /\
    <<ORD: Ordering.le Ordering.strong_relaxed ord -> Memory.nonsynch_loc loc (Local.promises lc0)>>.
Proof.
  exploit Local.write_step_future; eauto. i. des.
  inv WRITE. inv WRITE0. esplits; eauto.
  refine (step_fulfill _ _ _ _ _ _ _); auto.
  - refl.
  - eapply MemoryFacts.promise_time_lt; eauto.
    inv PROMISE; ss.
Qed.

Lemma write_undef_promise_fulfill_undef
      lc0 sc0 mem0 loc from to ord lc2 sc2 mem2 kind
      (WRITE: Local.write_undef_step lc0 sc0 mem0 loc from to ord lc2 sc2 mem2 kind)
      (WF0: Local.wf lc0 mem0)
      (SC0: Memory.closed_timemap sc0 mem0)
      (MEM0: Memory.closed mem0):
  exists lc1,
    <<STEP1: Local.promise_step lc0 mem0 loc from to Message.undef lc1 mem2 kind>> /\
    <<STEP2: fulfill_undef_step lc1 sc0 loc from to ord lc2 sc2>>.
Proof.
  inv WRITE. inv WRITE0. esplits; eauto.
  refine (step_fulfill_undef _ _ _ _ _); auto.
  exploit Memory.remove_get0; eauto. i. des.
  eapply MemoryFacts.promise_time_lt; eauto.
  inv PROMISE; ss.
Qed.

Lemma promise_fulfill_write
      lc0 sc0 mem0 loc from to val releasedm released ord lc1 lc2 sc2 mem2 kind
      (PROMISE: Local.promise_step lc0 mem0 loc from to (Message.concrete val released) lc1 mem2 kind)
      (FULFILL: fulfill_step lc1 sc0 loc from to val releasedm released ord lc2 sc2)
      (REL_WF: View.opt_wf releasedm)
      (REL_CLOSED: Memory.closed_opt_view releasedm mem0)
      (ORD: Ordering.le Ordering.strong_relaxed ord -> Memory.nonsynch_loc loc (Local.promises lc0))
      (WF0: Local.wf lc0 mem0)
      (SC0: Memory.closed_timemap sc0 mem0)
      (MEM0: Memory.closed mem0)
      (REL: released = TView.write_released (Local.tview lc0) sc0 loc to releasedm ord):
  Local.write_step lc0 sc0 mem0 loc from to val releasedm released ord lc2 sc2 mem2 kind.
Proof.
  exploit Local.promise_step_future; eauto. i. des.
  inv PROMISE. inv FULFILL.
  exploit MemorySplit.remove_promise_remove;
    try exact REMOVE; eauto; try apply WF2; try refl.
Qed.

Lemma promise_fulfill_undef_write_undef
      lc0 sc0 mem0 loc from to msg ord lc1 lc2 sc2 mem2 kind
      (PROMISE: Local.promise_step lc0 mem0 loc from to msg lc1 mem2 kind)
      (FULFILL: fulfill_undef_step lc1 sc0 loc from to ord lc2 sc2)
      (WF0: Local.wf lc0 mem0)
      (SC0: Memory.closed_timemap sc0 mem0)
      (MEM0: Memory.closed mem0):
  Local.write_undef_step lc0 sc0 mem0 loc from to ord lc2 sc2 mem2 kind.
Proof.
  inv PROMISE. inv FULFILL. ss.
  exploit Memory.remove_get0; eauto. s. i. des.
  exploit Memory.promise_get0; eauto.
  { inv PROMISE0; ss.
    exploit Memory.remove_get0; try exact PROMISES. i. des. congr. }
  i. des.
  rewrite GET in *. inv GET_PROMISES.
  exploit Local.promise_step_future; eauto.
Qed.

Lemma fulfill_step_promises_diff
      lc1 sc1 loc1 from to val releasedm released ord lc2 sc2 loc2
      (LOC: loc1 <> loc2)
      (FULFILL: fulfill_step lc1 sc1 loc1 from to val releasedm released ord lc2 sc2):
  (Local.promises lc1) loc2 = (Local.promises lc2) loc2.
Proof.
  inv FULFILL. inv REMOVE. unfold LocFun.add. s.
  condtac; [congr|]. auto.
Qed.

Lemma fulfill_undef_step_promises_diff
      lc1 sc1 loc1 from to ord lc2 sc2 loc2
      (LOC: loc1 <> loc2)
      (FULFILL: fulfill_undef_step lc1 sc1 loc1 from to ord lc2 sc2):
  lc1.(Local.promises) loc2 = lc2.(Local.promises) loc2.
Proof.
  inv FULFILL. inv REMOVE. unfold LocFun.add. s.
  condtac; [congr|]. auto.
Qed.
