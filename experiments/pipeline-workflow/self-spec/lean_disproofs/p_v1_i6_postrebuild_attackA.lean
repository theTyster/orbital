import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# I-6 POST-REBUILD probe A — the OLD one-point-`Run` attack now FAILS to inhabit.

OLD attack 1 (`p_v1_i6.lean`, against the degenerate model):
  `theorem run_is_a_one_point_domain : ∀ r : Run, r = .r0 := by intro r; cases r; rfl`
That SUCCEEDED when `Run` had a single constructor. Over the FROZEN rebuilt model
`Run` has TWO inhabitants (`r0`, `r1`), so this MUST fail: after `cases r` the `r1`
branch leaves the goal `Run.r1 = Run.r0`, which `rfl` cannot close.

EXPECT: COMPILE FAILURE. A failure here is the survival signal — the degenerate
one-point witness can no longer be inhabited.
-/

set_option autoImplicit false

namespace AdversaryI6PostA

open TargetWorld

theorem run_is_a_one_point_domain : ∀ r : Run, r = .r0 := by
  intro r; cases r; rfl

end AdversaryI6PostA
