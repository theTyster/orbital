import Proofs.TargetWorld

/-!
# I-6 cardinality floor — every run performs at least one disprove attempt

Property: `p_v1_i6` (prescriptive obligation `pr_v1_i6_floor`).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i6,
    "I-6 cardinality floor: every run performs at least one disprove attempt.",
    "... 1 <= (disproveAttempts r).length ...").

Substrate: `op_disprove_attempt(r0, a0)`, `disprove_floor(attempts_per_run, 1)`.

Structural reading of the sketch's `1 <= length`: over the closed `Run` domain,
"at least one attempt" is `∃ a, RunAttempt r a` — the canonical run `r0` performs
attempt `a0`. The universal closes by `cases` over the single-constructor `Run`.

Ontology: prescriptive obligation. No negated premise feeds this theorem, so the
provenance pair is `.absent` (the floor is an obligation to realize, not a
counterfactual removal). Recorded as `@[ontology .prescriptive, .absent]`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I6

open TargetWorld

@[ontology .prescriptive, .absent]
theorem i6_disprove_runs : ∀ r : Run, ∃ a : DisproveAttempt, RunAttempt r a := by
  intro r
  cases r
  exact ⟨.a0, .r0_a0⟩

end Proofs.I6
