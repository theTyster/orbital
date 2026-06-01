import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# I-6 POST-REBUILD probe B — the OLD `DisproveAttempt` one-point attack now FAILS.

OLD attack 2 (`p_v1_i6.lean`):
  `theorem disprove_attempt_is_a_one_point_domain : ∀ a : DisproveAttempt, a = .a0`
SUCCEEDED when `DisproveAttempt` had a single constructor `.a0`. Over the FROZEN
model `DisproveAttempt` has TWO inhabitants (`a0`, `a1`); the `a1` branch leaves
`DisproveAttempt.a1 = DisproveAttempt.a0`.

EXPECT: COMPILE FAILURE — the existential's witness domain is no longer one-point,
so the existential can express "at least one of several distinct", not a lone lookup.
-/

set_option autoImplicit false

namespace AdversaryI6PostB

open TargetWorld

theorem disprove_attempt_is_a_one_point_domain : ∀ a : DisproveAttempt, a = .a0 := by
  intro a; cases a; rfl

end AdversaryI6PostB
