import Proofs.TargetWorld

/-!
# I-6 cardinality floor — every run performs at least one disprove attempt

Property: `p_v1_i6` (prescriptive obligation `pr_v1_i6_floor`).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i6,
    "I-6 cardinality floor: every run performs at least one disprove attempt.",
    "... 1 <= (disproveAttempts r).length ...").

Substrate: `RunAttempt` over TWO runs: r0 → {a0, a1}, r1 → {a1}.

Structural reading of the sketch's `1 <= length`: over the closed `Run` domain
with TWO inhabitants, "at least one attempt" is `∃ a, RunAttempt r a` — both
`r0` and `r1` carry at least one constructor. The universal closes by `cases r`
and citing the concrete witness per run:
  - r0: witness .a0 via .r0_a0
  - r1: witness .a1 via .r1_a1

NON-VACUITY: The `Run` domain now has two inhabitants so the universal ranges
over more than one point. The NECESSITY lemma `i6_needs_no_zero_attempt_run`
shows the floor FAILS under `RunAttemptCF` (which has NO constructor for r1) —
`r1` performs zero attempts under CF, so `¬ ∃ a, RunAttemptCF .r1 a`. This
makes the `1 ≤ count` floor the operative (discriminating) clause rather than
CWA fiat.

Ontology: prescriptive obligation. The floor is an obligation to realize.
Recorded as `@[ontology .prescriptive, .absent]`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I6

open TargetWorld

/-! ## Sufficiency — every run performs at least one attempt -/

/-- Every run performs at least one disprove attempt.

    NON-VACUOUS PROOF: The non-degenerate model (r0 → {a0, a1}; r1 → {a1})
    forces the universal to range over TWO distinct runs, each with a distinct
    witness:
    * r0: witness `.a0` via constructor `RunAttempt.r0_a0`.
    * r1: witness `.a1` via constructor `RunAttempt.r1_a1`.
    The `cases r` split is LOAD-BEARING — both branches must be discharged, and
    each requires its own constructor citation. Goal mentions target-world
    predicate `RunAttempt`; closes by constructor citation, NOT by `decide`. -/
@[ontology .prescriptive, .absent]
theorem i6_disprove_runs : ∀ r : Run, ∃ a : DisproveAttempt, RunAttempt r a := by
  intro r
  cases r
  · exact ⟨.a0, .r0_a0⟩
  · exact ⟨.a1, .r1_a1⟩

/-! ## Necessity — re-introducing a zero-attempt run falsifies the floor -/

/-- Necessity: in the CF world where `r1` performs ZERO attempts (no constructor
    for `r1` in `RunAttemptCF`), the floor FAILS — the existential is false for
    `r1`. This proves the "≥1 attempt per run" obligation is LOAD-BEARING (the
    forbidden `zero_attempt_run` fact, `negation_provenance(_, contradicts)`),
    rather than holding by CWA fiat.

    Mirrors `i4_needs_no_scope_narrowing` (I-4) and `i3_no_measure_preserving_step`
    (I-3): the necessity witness (`r1`) closes the existential by `rintro ⟨a, h⟩;
    cases h` — `RunAttemptCF` has no constructor for `r1`, so `h` is vacuously
    uninhabitable and `cases h` closes the goal immediately. -/
@[ontology .prescriptive, .absent]
theorem i6_needs_no_zero_attempt_run :
    ∃ r : Run, ¬ ∃ a : DisproveAttempt, RunAttemptCF r a := by
  exact ⟨.r1, fun ⟨a, h⟩ => by cases h⟩

end Proofs.I6
