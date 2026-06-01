# TargetWorld.lean Non-Degenerate Rebuild — Spec / Brief

**Purpose.** The pre-kimmy vacuity audit found **5 of 7 invariant proofs vacuous**
(I-1, I-3, I-4, I-5, I-6) because `self-spec/lean/Proofs/TargetWorld.lean` is a
*degenerate* model: constant-valued / one-point inductives collapse the universals
and make hypotheses dead weight. I-3 was already re-stated non-degenerate during the
dogfood; this spec rebuilds the model so **all 7 re-prove non-vacuously**, validated
by re-running each invariant's `lean-adversary` (the adversary must now FAIL = the
proof SURVIVES). I-2 + I-7 already constrain genuinely; preserve them.

This file is BOTH the design record (compaction-resilient) and the precise brief for
the model-rebuild agent. The gating adversary self-corrects an imperfect rebuild.

## The proven template — I-3 (`Proofs/I3Termination.lean`)

I-3 was vacuous (a free measure `fun _ => (0,0)` + identity step type-checked). It was
fixed by:
1. a **concrete `structure State`** carrying the real measure components;
2. a **concrete `inductive Step`** with ≥2 genuinely-distinct moves (`forward`,
   `loopback`) that actually change state;
3. `step_strictDecreasing` — the load-bearing lemma the identity step CANNOT satisfy;
4. **regression lemmas** (`i3_identity_step_is_rejected`, `i3_no_measure_preserving_step`)
   that explicitly reject the degenerate witness.

Every rebuilt invariant must follow this shape: bind a concrete substrate where the
property's hypothesis is **load-bearing**, and add a **regression/necessity lemma**
that a violating instance is rejected. The adversary's surviving attack on the old
model is the acceptance criterion to defeat.

## Defect catalog (what made each vacuous)

- **I-1 liveness** (`Terminates r → ReachesExplain r`): `Run` is one-point (`r0`);
  `Terminates` is TOTAL and `ReachesExplain` UNCONDITIONAL → implication is `True→True`,
  the "terminating" antecedent filters nothing (`p_v1_i1.lean` Probes 1-4). NOTE the
  **terminal half** (`i1_explain_is_terminal : ∀ s, ¬StageOrder .explain s`) is already
  NON-vacuous over the genuine 8-stage StageOrder — preserve it.
- **I-4 monotone scope**: `StartIdx` pins every start to the literal `0` → conclusion is
  always `0≤0`, `i≤j` discarded as `_hij`; adversary proves it reversed and with no
  ordering (`p_v1_i4.lean`).
- **I-5 reserve + no-self-attack**: reserve half stated EXISTENTIALLY
  (`∃ s r, Spend a s ∧ Reserve a r ∧ r≤s`) — a relation carrying both a compliant (5)
  and a below-reserve (0) spend satisfies it by cherry-pick; no-self-attack reduces to a
  constant constructor-fiat disequality independent of the attempt (`p_v1_i5.lean`).
- **I-6 disprove floor** (`∃ a, RunAttempt r a`): `Run` + `DisproveAttempt` one-point →
  single ground-fact lookup, zero cardinality content (no `length`, no `≤`); a 0-attempt
  run is expressible and would falsify the floor body but the theorem can never be posed
  over it (CWA fiat, not a checked count) (`p_v1_i6.lean`).

## Rebuild requirements (the new model)

**Change these (de-degenerate):**
- **`Run` → ≥2 inhabitants** with DISTINCT outcomes: `r0` (complete / happy path) and
  `r1` (hard_stop mid-pipeline). Carry an explicit `Outcome` (`complete | hard_stop`) and
  an `RunOutcome : Run → Outcome → Prop`.
- **`DisproveAttempt` → ≥2 inhabitants** (`a0`, `a1`) so I-5's `∀ attempt` and I-6's
  `∃ attempt` range over >1.
- **`StartIdx` → ≥2 distinct DECREASING values** per run (e.g. r0: step0→3, step1→1,
  step2→0). Antitonicity must hold for `i≤j` AND the reverse direction must FAIL
  (so `3≤1` is unprovable → adversary's reverse/no-ordering probes die). The re-proof
  must genuinely USE `i≤j` (cross-cases discharged by contradiction via `omega`).
- **`Spend`/`Reserve`**: state the discipline UNIVERSALLY in the proof
  (`∀ a s r, Spend a s → Reserve a r → r ≤ s`) so a coexisting below-reserve spend would
  falsify it. Keep `Spend` single-valued for the real attempts (compliant), and add a
  **CF predicate** (`SpendCF`/`StartIdxCF1`-style) carrying a below-reserve value for the
  NECESSITY lemma (the violation is rejected).
- **`Target`/`OwnOutput`**: make the disequality genuinely attempt-dependent (vary the
  surface across `a0`/`a1`) and add a **CF self-attack** predicate (target = ownOutput)
  for the necessity lemma showing self-attack is rejected.
- **`RunAttempt`**: attest ≥1 attempt for BOTH runs; add a **CF zero-attempt run**
  predicate (no constructor for some run) + a necessity lemma that the floor FAILS there
  — the I-6 floor must discriminate ≥1 from 0 (mirror I-7's `x≠y` biting clause).

**Preserve (already genuine — do NOT weaken):**
- `Stage` (8 stages), `StageIndex`, `StageOrder` (7 edges), `Requires` — the real chain
  I-2 gating + I-1 terminality rely on.
- `Adversary` (`adv1`, `adv2`) + `AttemptAdversary` + `AdversariesParallel` — I-7's ≥2
  fan-out floor; its `x≠y` clause is robust.
- `RecoveryKey` (s3..s6) + `RecoveryBudget` — I-3's bounded first lex component.
- The `Proofs/I3Termination.lean` concrete-Step machinery — already non-vacuous.

**Every rebuilt invariant adds a regression/necessity lemma** (the I-3 / I-4-CF pattern):
a violating instance is expressible and is proven to falsify the property.

**Provenance discipline (unchanged):** the two `negation_provenance(_, absent)`
premises (workflow_artifact_exists_on_disk, self_verification_run_completed) stay
CWA-fragile — NOT encoded as closed-domain disproofs (CWA-absent ≠ Lean-disproved).
Update `self-spec/target-world.pl` in lockstep so the Prolog and Lean models agree.

## Acceptance criteria (the gate)

For each invariant, after the rebuild + re-proof, its `lean-adversary` must report
**attack = failed** (the vacuity probe can no longer inhabit a degenerate witness):
- I-4: the reverse-direction and no-ordering probes must FAIL to type-check.
- I-1: the hypothesis-discarding liveness probe must FAIL; the antecedent must bite.
- I-5: a model carrying a coexisting below-reserve spend must FAIL the universal.
- I-6: the zero-attempt-run regression must be the operative clause (floor discriminates).
- I-2, I-7: re-confirm they still SURVIVE structurally over the richer model.
- `lake build` clean (the deductive judge). Keep `maxHeartbeats 400000` bounds.
