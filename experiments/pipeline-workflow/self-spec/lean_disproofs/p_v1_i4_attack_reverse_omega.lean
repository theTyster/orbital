import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# DECISIVE reverse-direction probe — strongest available closer

The constant-tactic probe (`p_v1_i4_attack_reverse.lean`) already fails to
type-check, but that only shows the OLD lazy tactic no longer works. The
decisive adversarial question is whether the reverse-direction statement is
PROVABLE AT ALL in the new model — so here we throw the SAME closer the forward
re-proof uses (`cases hi <;> cases hj <;> omega`), the strongest arithmetic
decision procedure available. If `omega` CANNOT close every case, the reverse
direction is genuinely refuted: there is a concrete `j ≤ i` pair (e.g.
j=0, i=2 on r0 → sj=3, si=0, goal `3 ≤ 0`) that is arithmetically FALSE.

A FAILED build here is the strong SURVIVAL signal: the theorem genuinely
constrains direction.
-/

set_option autoImplicit false

namespace ReverseAttackOmega

open TargetWorld Proofs.I4

theorem i4_holds_in_reverse_direction_omega :
    ∀ (r : Run) (i j si sj : Nat),
      j ≤ i → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj hji hi hj
  cases hi <;> cases hj <;> omega

end ReverseAttackOmega
