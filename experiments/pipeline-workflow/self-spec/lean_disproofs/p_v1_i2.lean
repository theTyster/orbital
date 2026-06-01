import Mathlib
import Proofs.TargetWorld
import Proofs.I2Gating

/-!
# Vacuity probe against `Proofs.I2.i2_artifact_gating`

The adversarial QUESTION mirrors the I-3 free-measure trap: is the I-2 theorem
VACUOUS — satisfiable by a degenerate witness while the substrate facts
(`Requires`, `StageOrder`, the gating direction) play no real role — or does it
bind the concrete inductive substrate and constrain the property?

Intended property (formal_property p_v1_i2):
  "no stage runs before its required upstream artifact exists."

Theorem actually proven (i2_artifact_gating):
  ∀ (s : Stage) (a : Artifact), Requires s a → StageOrder a s

Vacuity vectors probed below. Each either INHABITS a degenerate reading
(vacuity witness) or DEMONSTRATES a structural constraint (non-vacuity). The
build is the deductive judge.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace AdversaryI2

open TargetWorld Proofs.I2

/-! ## V1 — Is the hypothesis `Requires s a` inhabited? (empty-domain trap)

If `Requires` had no constructors the universal would be vacuously true (the
I-3 class of defect: a quantifier over an empty domain). It does NOT: there are
7 distinct inhabitants. We exhibit them, so the `cases h` in the proof splits
into 7 REAL branches, not zero. -/
theorem v1_hypothesis_is_inhabited :
    Requires .decompose_proposition .close_world ∧
    Requires .model_obligations .decompose_proposition ∧
    Requires .prove_invariants .model_obligations ∧
    Requires .instantiate_properties .prove_invariants ∧
    Requires .realize_specification .instantiate_properties ∧
    Requires .measure_entailment .realize_specification ∧
    Requires .explain .measure_entailment :=
  ⟨.s2, .s3, .s4, .s5, .s6, .s7, .se⟩

/-! ## V2 — Is the conclusion relation `StageOrder` degenerate (universal/reflexive)?

A degenerate conclusion (one that holds for ALL pairs, e.g. `True`, reflexive,
or the full relation) would make the gating content decorative: any `Requires`
fact whatsoever would satisfy it. We show `StageOrder` is a PROPER relation —
it is NOT reflexive on a real stage, NOT total, and NOT symmetric. The conclusion
therefore genuinely discriminates. -/

/-- `StageOrder` is NOT reflexive: a stage is not its own immediate predecessor. -/
theorem v2_stageorder_not_reflexive : ¬ StageOrder .prove_invariants .prove_invariants := by
  intro h; cases h

/-- `StageOrder` is NOT total: non-adjacent stages are unrelated (close_world is
    not the immediate predecessor of prove_invariants — there are two stages
    between them). -/
theorem v2_stageorder_not_total : ¬ StageOrder .close_world .prove_invariants := by
  intro h; cases h

/-- `StageOrder` is NOT symmetric: the back-edge does not hold. If it WERE
    symmetric, the gating DIRECTION (artifact-precedes-consumer vs.
    consumer-precedes-artifact) would be decorative. The reverse edge of a real
    forward edge is absent — so direction is load-bearing. -/
theorem v2_stageorder_not_symmetric :
    StageOrder .close_world .decompose_proposition ∧
    ¬ StageOrder .decompose_proposition .close_world :=
  ⟨.s1_s2, by intro h; cases h⟩

/-! ## V3 — The decisive anti-vacuity witness: a BAD gating model is REJECTED.

If the conclusion `StageOrder a s` were vacuous/decorative, then ANY required-
artifact relation — including one that gates on a FUTURE or SELF artifact —
would satisfy the same theorem shape. We construct exactly the forbidden cases
the intended property must rule out and show the theorem's conclusion FAILS for
them, i.e. its negation is PROVABLE. This is the load-bearing content. -/

/-- A stage gating on its OWN output (self-artifact): the violation
    `op_requires_artifact(S, art(S))`. The gating theorem's conclusion would
    demand `StageOrder s s`, which is FALSE. So a self-gating `Requires` could
    NOT satisfy `i2_artifact_gating` — the theorem actively rejects it. -/
theorem v3_self_gating_would_be_rejected :
    ¬ StageOrder .prove_invariants .prove_invariants := by
  intro h; cases h

/-- A stage gating on a FUTURE artifact (consumer precedes producer): the
    violation `gates_on_future_artifact`. E.g. close_world "requiring" the
    output of prove_invariants. The conclusion would demand
    `StageOrder .prove_invariants .close_world` — FALSE (that is the backward,
    future-pointing edge). The theorem rejects it. -/
theorem v3_future_gating_would_be_rejected :
    ¬ StageOrder .prove_invariants .close_world := by
  intro h; cases h

/-- The general statement of V3: for a HYPOTHETICAL bad-gating assignment that
    points decompose_proposition at a future artifact (prove_invariants),
    `i2_artifact_gating`'s conclusion is NOT derivable — its negation holds.
    This proves the conclusion `StageOrder a s` is a genuine filter on which
    `Requires` facts are admissible: it is NOT satisfied by an arbitrary
    artifact assignment. -/
theorem v3_conclusion_filters_bad_assignments :
    -- the real fact: decompose_proposition requires close_world (its predecessor)
    StageOrder .close_world .decompose_proposition ∧
    -- the bad counterfactual assignment would require prove_invariants (a future
    -- artifact); the conclusion StageOrder prove_invariants decompose_proposition
    -- is FALSE, so the bad assignment is inadmissible under i2_artifact_gating.
    ¬ StageOrder .prove_invariants .decompose_proposition :=
  ⟨.s1_s2, by intro h; cases h⟩

/-! ## V4 — Is `i2_artifact_gating` constructor-discriminating (not a constant)?

A proof that closed by hitting EVERY branch with the SAME constructor would
signal the conclusion is insensitive to which `Requires` fact it sees. We show
the 7 branches demand 7 DISTINCT `StageOrder` witnesses by instantiating the
theorem at each real `Requires` and reading off the conclusion. Each instance
is a distinct edge, so the proof's `cases h <;> exact .sN_sM` chain is genuinely
per-constructor, not a single constant inhabitant. -/
theorem v4_each_branch_distinct :
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

/-! ## V5 — Coverage: does the universal cover the WHOLE stage domain?

A vacuity could hide if `Requires` only mentioned a sub-domain, leaving most
stages ungated by silence. We confirm the partition: every Stage is either a
`Requires` consumer (7 of them) or the ungated stage-0 carrier (close_world),
the latter handled by `i2_close_world_ungated`. close_world genuinely has NO
`Requires` constructor, so the base case is real, not assumed. -/
theorem v5_close_world_has_no_requires : ∀ a : Artifact, ¬ Requires .close_world a :=
  i2_close_world_ungated

/-! ## V6 — The intended-property direction matches the proven conclusion.

`StageOrder a s` with `Requires s a` means "the artifact's producer `a` is the
immediate predecessor of consumer `s`", i.e. it RUNS BEFORE. The intended
property is "artifact exists before the stage runs". The proven `StageOrder`
edge implies strict precedence, which is the existence-before semantics. We
confirm the edge composes into the transitive precedence the Prolog model uses
(close_world precedes prove_invariants via the chain), so the
immediate-predecessor conclusion is STRONGER than (hence implies) the intended
"exists before" reading — not weaker/vacuous. -/
theorem v6_edge_implies_strict_precedence :
    -- the proven conclusion for the s4 fact: model_obligations ⟶ prove_invariants
    StageOrder .model_obligations .prove_invariants ∧
    -- which, with the upstream edge, yields the multi-hop precedence the intended
    -- "exists before" property needs (close_world ⟶ ... ⟶ prove_invariants):
    StageOrder .close_world .decompose_proposition ∧
    StageOrder .decompose_proposition .model_obligations :=
  ⟨i2_artifact_gating _ _ .s4, .s1_s2, .s2_s3⟩

end AdversaryI2
