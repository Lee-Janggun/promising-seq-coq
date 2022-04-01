# Sequential Reasoning for Optimizing Compilers Under Weak Memory Concurrency

Our Coq development is based on [the previous Coq formalization of PS 2.1](https://github.com/snu-sf/promising-ldrf-coq).

## Build
- Requirement: opam (>=2.0.0), Coq 8.15.0
- Install dependencies with opam
```
./configure
```
- Build the project
```
make build -j
```

## Code Structure

### The SEQ model (Section 2 & 3)
- `src/sequential/Sequential.v` - Semantics of SEQ (`Module SeqThread` / *Figure 1 in the paper*) and simulation relation (`sim_seq_all` / *Figure 6 in the appendix*)
- `src/sequential/SequentialBehavior.v` - Behavior (`Module SeqBehavior`/ *Definition 2.3 in the paper*) and Advanced behavior refinement (`refine` / *Figure 2 in the paper*)

### The PS 2.1 model extended with non-atomics (Section 5) and updated proofs
These are based on the Coq development of PS2.1 (https://github.com/snu-sf/promising-ldrf-coq)
- `src/lang/` - Semantics of PS 2.1 extended with non-atomic accesses
The following are updated proofs from existing formalization (i.e., they are not contribution of this paper.)
- `src/transformation/` - Soundness of compiler transformations on atomics
- `src/promotion/` - Soundness of register promotion
- `src/ldrfpf/LocalDRFPF.v`, `src/ldrfpf/LocalDRFRA.v`, and `src/ldrfsc/LocalDRFSC.v` - Local DRF theorems (PF, RA, and SC)

### Adequacy of reasoning in SEQ (Section 6)
- `src/sequential/SequentialAdequacy.v` - Adequacy of simulation in SEQ (`Theorem sequential_adequacy_concurrent_context` / *Theorem A.3 in the appendix*), and adequacy of behavioral refinement in SEQ (`Theorem sequential_refinement_adequacy_concurrent_context` / *Theorem 6.2 in the paper*)
- `src/sequential/SequentialRefinement.v` - Equivalence of simulation and behavioral refinement in SEQ (`Theorem refinement_implies_simulation` and `Theorem simulation_implies_refinement`)
- `src/itree/SequentialCompatibility.v` - Congruence lemmas of simulation (`Lemma sim_seq_itree_refl`, `Lemma sim_seq_itree_mon`, `Lemma sim_seq_itree_ret`, `Lemma sim_seq_itree_bind` and `Lemma sim_seq_itree_iter` / *Figure 7 in the appendix*)

### Optimizer and Soundness Proof (Section 4)
- `src/itree/ITreeLang.v` - A simple programming language for optimization (`Section Stmt`)
- `src/optimizer/WRforwarding.v` and `src/itree/WRforwardingProof2.v` - Store-to-Load Forwarding (`WRfwd_opt_alg`) and its simulation proof under SEQ (`Theorem WRfwd_sim`)
- `src/optimizer/RRforwarding.v` and `src/itree/RRforwardingProof2.v` - Load-to-Load Forwarding (`RRfwd_opt_alg`) and its simulation proof under SEQ (`Theorem RRfwd_sim`)
- `src/optimizer/LoadIntro.v` - Loop Invariant Code Motion (`licm`) and its simulation proof under SEQ (`Theorem LICM_LoadIntro_sim`)
- `src/optimizer/DeadStoreElim.v` and `src/itree/DeadStoreElimProof3.v` - Write-after-Write Elimination (`DSE_opt_alg`) and its simulation proof under SEQ (`Theorem DSE_sim`)  

and final soundness theorems for optimization passes
- `src/sequential/OptimizerAdequacy.v` - Contextual refinment under *Promising Semantics* (`Theorem WRforwarding_sound`, `Theorem RRforwarding_sound`, `Theorem LICM_LoadIntro_sound`, and `Theorem DeadStoreElim_sound`)


## Guides for Readers

### The PS model with non-atomics (Section 5)
Mapping between the new transition rules in the paper (*Figure 4*) and the definitions in Coq (`src/lang`)
- non-atomic message - `Message.undef` in `Cell.v`
- (MEMORY:NA-WRITE) - `Memory.write_na` in `Memory.v`
- (WRITE) with `o_w = na` - `Local.write_na_step` in `Local.v`
- (RACE-HELPER) - `Local.is_racy` in `Local.v`
- (RACY-READ) - `Local.racy_read_step` in `Local.v`
- (RACY-WRITE) - `Local.racy_write_step` in `Local.v`

### The SEQ model (Section 2)
Mapping between the transition rules in the paper (*Figure 1*) and the definitions in Coq (`src/sequential/Sequential.v`)
- <sigma, F, P, M> with an oracle `o` - `SeqThread.mk (SeqState.mk sigma (SeqMemory.mk M F) P o`  
where `(sigma: lang.(Language.state)) (M: ValueMap.t) (F: Flags.t) (P: Perms.t) (o: Oracle.t)`
- (NA-READ) and (RACY-NA-READ) - `SeqState.na_local_read_step`
- (NA-WRITE) and (RACY-NA-WRITE) - `SeqState.na_local_write_step`
- (ACQ-READ) - `SeqEvent.step_acquire`
- (REL-WRITE) - `SeqEvent.step_release`

How the Coq development is different from the paper presentation
- A racy non-atomic read can read *any* value rather than only the *undef* value. Since any value includes the undef value, two definitions are equivalent.
- There is no codition `P' <= P` in (REL-WRITE) rule of SEQ. Instead, we use `meet P' P` for a new permission to ensure `P <= meet P' P`.
- Similarly, there is a no codition `P <= P'` and `dom(V) = P' \ P` in (ACQ-READ) rule of SEQ. Instead, we use `join P' P` for a new permission and ignore `V(x)` for `x` not in `P' \ P`.
- There are rules for fences and atomic updates. In that cases, a program takes *all* corresponding effects. For example, when executing an acquire-release fence, it takes a (REL-WRITE) step after an (ACQ-READ) step.
- SEQ allows atomic operations on non-atomic locations. In that case, the permission and the value of that location are changed, following the rule `SeqEvent.step_update`. For example, when executing a release write, it takes a `SeqEvent.step_release` after `SeqEvent.step_update`

### Adequacy of reasoning in SEQ (Section 6)
Though the PS model allows mixing of atomic and non-atomic accesses to the same location, our adequacy theorem requires the absence of such mixing.
Therefore, there are assumptions `nomix` in `Theorem sequential_adequacy_concurrent_context` and `Theorem sequential_refinement_adequacy_concurrent_context`. `nomix` which is defined in `sequential/NoMix.v` says that there exist a set of atomic locations (`loc_at`) and a set of non-atomic locations (`loc_na`) such that the given program accesses locations in `loc_at` only by atomic accesses and vice versa.

There are more assumptions on `Theorem sequential_refinement_adequacy_concurrent_context` other than determinism of a source program. It requires (i) "receptiveness" (`receptive`) of a target program saying that if the program can take a read transition with some value, then it also can take a read transition with any other value, and (ii) "monotonicity" (`monotone_read_state`) of a source program saying that reading the undef value allows more behavior than reading another value. Note that both conditions trivially hold in a sane programming language.
