import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# NO-ORDERING vacuity probe (strongest closer)

Second probe from the original attack (`i4_holds_with_no_step_ordering`):
claim `sj ≤ si` holds with NO ordering hypothesis between the steps at all.
In the OLD constant-0 model this compiled. We attempt it with the strongest
closer (`cases <;> omega`). A FAILED build is the SURVIVAL signal: without the
`i ≤ j` premise there are cross-step pairs (e.g. i=0/si=3, j=2/sj=0 gives goal
`0 ≤ 3` true, but i=2/si=0, j=0/sj=3 gives `3 ≤ 0` FALSE) so the unconditional
claim cannot hold.
-/

set_option autoImplicit false

namespace NoOrderAttackOmega

open TargetWorld Proofs.I4

theorem i4_holds_with_no_step_ordering_omega :
    ∀ (r : Run) (i j si sj : Nat),
      StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj hi hj
  cases hi <;> cases hj <;> omega

end NoOrderAttackOmega
