import Proofs.TargetWorld
import Proofs.I2Gating

/-!
# I-2 VACUITY re-attack (post-rebuild, FROZEN model) — SURVIVING companion

Theorem under attack (`Proofs.I2.i2_artifact_gating`):
  ∀ (s : Stage) (a : Artifact), Requires s a → StageOrder a s

I-2 is a STRUCTURAL SURVIVOR. This file does two things:

  1. Positively INHABITS the NEGATIONS of the degenerate/vacuity witnesses —
     each `¬`-theorem below is the constructive proof that the corresponding
     degenerate reading CANNOT be inhabited (the EXPECT-FAIL probes
     `_ef*.lean` confirm the same facts from the other side: those files fail
     to compile).
  2. Proves a STRONGER index-binding lemma: every gating edge advances the
     cursor index by EXACTLY 1, so the gating conclusion genuinely ties each
     consumer to its REAL immediate-upstream producer — not to an incidental
     or decorative relation, and not vacuously.

The build of THIS file (exit 0) + the compile-FAILURE of every `_ef*.lean`
degenerate witness is the survival verdict.

NO `sorry` / `axiom` / `native_decide`. Closes by constructor citation,
constructor disjointness (`cases h`), and `omega`-free `rfl` over indices.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace AdversaryI2PostRebuild

open TargetWorld Proofs.I2

/-! ## (A) NEG of empty-hypothesis vacuity — `Requires` is genuinely inhabited.

If `Requires` were empty, the I-2 universal would be vacuous. It is not: all 7
gating facts are inhabited, so the `cases h` in `i2_artifact_gating` splits into
7 REAL branches. (The `_efA_requires_empty.lean` probe FAILS to compile: it
leaves 7 unsolved `False` goals.) -/
theorem A_requires_inhabited :
    Requires .decompose_proposition .close_world ∧
    Requires .model_obligations .decompose_proposition ∧
    Requires .prove_invariants .model_obligations ∧
    Requires .instantiate_properties .prove_invariants ∧
    Requires .realize_specification .instantiate_properties ∧
    Requires .measure_entailment .realize_specification ∧
    Requires .explain .measure_entailment :=
  ⟨.s2, .s3, .s4, .s5, .s6, .s7, .se⟩

/-! ## (B) NEG of degenerate-conclusion vacuity — `StageOrder` is a PROPER relation.

A decorative conclusion would be reflexive / total / symmetric. Each negation
is positively inhabited here; the matching `_efB*.lean` probes fail to compile. -/

/-- NOT reflexive (kills the self-gate vacuity): no `StageOrder s s`. -/
theorem B1_not_reflexive : ¬ StageOrder .prove_invariants .prove_invariants := by
  intro h; cases h

/-- NOT total: non-adjacent stages are unrelated. -/
theorem B2_not_total : ¬ StageOrder .close_world .prove_invariants := by
  intro h; cases h

/-- NOT symmetric: the back-edge of a real forward edge is absent, so the gating
    DIRECTION (producer-before-consumer) is load-bearing, not decorative. -/
theorem B3_not_symmetric :
    StageOrder .close_world .decompose_proposition ∧
    ¬ StageOrder .decompose_proposition .close_world :=
  ⟨.s1_s2, by intro h; cases h⟩

/-! ## (C) NEG of collapse vacuity — bad gates are REJECTED by the conclusion.

The decisive content: a self-gate or future/skip gate, if admitted, would make
the theorem decorative. The conclusion `StageOrder a s` actively rejects each
forbidden gate (its negation is provable). Matching `_efC*/_efD/_efE` probes
fail to compile. -/

/-- Self-gate rejected: a stage requiring its own artifact would need
    `StageOrder s s`, which is false. -/
theorem C1_self_gate_rejected : ¬ StageOrder .model_obligations .model_obligations := by
  intro h; cases h

/-- Future-gate rejected: consumer-before-producer (backward edge) is absent. -/
theorem C2_future_gate_rejected : ¬ StageOrder .prove_invariants .close_world := by
  intro h; cases h

/-- Re-route rejected: a gate pointing at a FUTURE artifact
    (model_obligations ← instantiate_properties) cannot satisfy the conclusion. -/
theorem C3_reroute_future_rejected : ¬ StageOrder .instantiate_properties .model_obligations := by
  intro h; cases h

/-- Skip-gate rejected: gating two hops back (close_world for prove_invariants)
    is not the immediate-predecessor edge the chain admits. -/
theorem C4_skip_gate_rejected : ¬ StageOrder .close_world .prove_invariants := by
  intro h; cases h

/-! ## (D) STRENGTHENED binding — gating ties each consumer to its REAL upstream.

The strongest non-vacuity guarantee: the gating conclusion is not just *some*
non-degenerate relation; it pins the producer to the position EXACTLY ONE step
upstream of the consumer in the `StageIndex` cursor. -/

/-- Every `StageOrder` edge advances the cursor index by EXACTLY 1. So the I-2
    conclusion is the genuine immediate-predecessor relation over real positions,
    not an incidental relation that happens to hold. -/
theorem D_stageorder_steps_index_by_one :
    ∀ (a s : Stage), StageOrder a s →
      ∀ (na ns : Nat), StageIndex a na → StageIndex s ns → ns = na + 1 := by
  intro a s ho na ns ha hs
  cases ho <;> cases ha <;> cases hs <;> rfl

/-- Composition of `i2_artifact_gating` with the index-step lemma: for EVERY
    `Requires` fact, the required artifact's producer sits at the cursor position
    immediately before the consumer. This is the operational meaning of "the
    required upstream artifact exists by the time the consumer runs": producer
    index + 1 = consumer index, witnessed on the real s4 fact. -/
theorem D_required_producer_is_immediate_predecessor :
    StageIndex .model_obligations 2 ∧
    StageIndex .prove_invariants 3 ∧
    -- gating conclusion for the s4 fact, obtained THROUGH the theorem:
    StageOrder .model_obligations .prove_invariants ∧
    -- and the index advances by exactly one (2 + 1 = 3):
    (3 = 2 + 1) :=
  ⟨.model_obligations, .prove_invariants, i2_artifact_gating _ _ .s4, rfl⟩

/-! ## (E) Coverage — the universal partitions the WHOLE stage domain.

7 consumers + the ungated stage-0 carrier (close_world), the latter via
`i2_close_world_ungated`. No stage escapes gating by silence. -/

theorem E_close_world_genuinely_ungated : ∀ a : Artifact, ¬ Requires .close_world a :=
  i2_close_world_ungated

/-- Each of the 7 branches yields a DISTINCT gating edge, obtained THROUGH the
    theorem — so the proof's `cases h <;> exact .sN_sM` is per-constructor, not a
    single constant inhabitant. -/
theorem E_each_branch_distinct_through_theorem :
    StageOrder .close_world .decompose_proposition ∧
    StageOrder .decompose_proposition .model_obligations ∧
    StageOrder .model_obligations .prove_invariants ∧
    StageOrder .prove_invariants .instantiate_properties ∧
    StageOrder .instantiate_properties .realize_specification ∧
    StageOrder .realize_specification .measure_entailment ∧
    StageOrder .measure_entailment .explain :=
  ⟨i2_artifact_gating _ _ .s2, i2_artifact_gating _ _ .s3,
   i2_artifact_gating _ _ .s4, i2_artifact_gating _ _ .s5,
   i2_artifact_gating _ _ .s6, i2_artifact_gating _ _ .s7,
   i2_artifact_gating _ _ .se⟩

end AdversaryI2PostRebuild
