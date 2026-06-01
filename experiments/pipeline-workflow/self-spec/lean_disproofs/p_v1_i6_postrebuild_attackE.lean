import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# I-6 POST-REBUILD probe E — can the zero-attempt run be FORCED to pass the floor?

The decisive "still_vacuous" disproof would be to INHABIT the floor body for the
zero-attempt run, i.e. to produce `∃ a, RunAttemptCF .r1 a`. If ANY witness term
type-checks, the discrimination is fake and the verdict is `still_vacuous`.

We try every degenerate witness for `RunAttemptCF .r1 _`:
  - `⟨.a0, .r0_a0⟩`  — reuse r0's constructor for r1
  - `⟨.a1, .r0_a0⟩`  — wrong attempt id
  - `⟨.a0, .r1_a1⟩`  — there is no `r1` constructor in RunAttemptCF at all

EXPECT: COMPILE FAILURE on each — `RunAttemptCF` has NO `r1` constructor, so the
floor body for `r1` is genuinely uninhabitable. This is the survival lock: the
zero-attempt run CANNOT be smuggled past the floor.
-/

set_option autoImplicit false

namespace AdversaryI6PostE

open TargetWorld

-- Attempt to force the zero-attempt run past the floor by reusing r0's constructor.
theorem force_zero_run_past_floor : ∃ a : DisproveAttempt, RunAttemptCF .r1 a :=
  ⟨.a0, RunAttemptCF.r0_a0⟩

end AdversaryI6PostE
