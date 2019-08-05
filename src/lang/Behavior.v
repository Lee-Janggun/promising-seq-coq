Require Import sflib.
From Paco Require Import paco.

Require Import Basic.
Require Import Event.
Require Import Language.
Require Import View.
Require Import Cell.
Require Import Memory.
Require Import TView.
Require Import Local.
Require Import Thread.
Require Import Configuration.

Set Implicit Arguments.

(* NOTE: We currently consider only finite behaviors of program: we
 * ignore non-terminating executions.  This simplification affects two
 * aspects of the development:
 *
 * - Liveness.  In our definition, the liveness matters only for
 *   non-terminating execution.
 *
 * - Simulation.  We do not introduce simulation index for inftau
 *   behaviors (i.e. infinite loop without system call interactions).
 *
 * We will consider infinite behaviors in the future work.
 *)
(* NOTE: We serialize all the events within a behavior, but it may not
 * be the case.  The *NIX kernels are re-entrant: system calls may
 * race.
 *)

Inductive behaviors
          (step: forall (e:option MachineEvent.t) (tid:Ident.t) (c1 c2:Configuration.t), Prop):
  forall (conf:Configuration.t) (b:list Event.t), Prop :=
| behaviors_nil
    c
    (TERMINAL: Configuration.is_terminal c):
    behaviors step c nil
| behaviors_syscall
    e tid c1 c2 beh
    (STEP: step (Some (MachineEvent.syscall e)) tid c1 c2)
    (NEXT: behaviors step c2 beh):
    behaviors step c1 (e::beh)
| behaviors_abort
    tid c1 c2 beh
    (STEP: step (Some MachineEvent.abort) tid c1 c2):
    behaviors step c1 beh
| behaviors_tau
    tid c1 c2 beh
    (STEP: step None tid c1 c2)
    (NEXT: behaviors step c2 beh):
    behaviors step c1 beh
.

Lemma rtc_tau_step_behavior
      step c1 c2 b
      (STEPS: rtc (union (step None)) c1 c2)
      (BEH: behaviors step c2 b):
  behaviors step c1 b.
Proof.
  revert BEH. induction STEPS; auto. inv H.
  i. specialize (IHSTEPS BEH). econs 4; eauto.
Qed.
