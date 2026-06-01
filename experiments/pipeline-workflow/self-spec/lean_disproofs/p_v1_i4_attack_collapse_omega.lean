import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# COLLAPSE-TO-EQUALITY vacuity probe (strongest closer)

Third probe from the original attack (`i4_collapses_to_equality`): in the OLD
constant-0 model the start index was pinned to 0 for every step, so
`i ≤ j → si = sj` held (both 0). That collapse meant antitonicity was a constant
function — both monotone and antitone. We re-attempt the equality-collapse with
the strongest closer. A FAILED build is the SURVIVAL signal: e.g. i=0/si=3,
j=1/sj=1 with `0 ≤ 1` gives goal `3 = 1`, FALSE — start indices genuinely VARY,
so the relation is not constant.
-/

set_option autoImplicit false

namespace CollapseAttackOmega

open TargetWorld Proofs.I4

theorem i4_collapses_to_equality_omega :
    ∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → si = sj := by
  intro r i j si sj hij hi hj
  cases hi <;> cases hj <;> omega

end CollapseAttackOmega
