import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# POSITIVE refutation of the equality-collapse

Inhabits the NEGATION of the collapse-to-equality claim. Witness: r0, i=0
(si=3), j=1 (sj=1); `0 ≤ 1` holds but `si = sj` is `3 = 1`, false. If this
builds, the start indices genuinely vary across steps — the relation is NOT the
constant function the old model degenerated to, so antitonicity is a real
(strict-decrease-tolerant) constraint, not a `0 = 0` triviality.
-/

set_option autoImplicit false

namespace CollapseRefuted

open TargetWorld Proofs.I4

/-- The equality-collapse claim is FALSE: start indices vary (3 at step0, 1 at
    step1 for r0). -/
theorem collapse_is_false :
    ¬ (∀ (r : Run) (i j si sj : Nat),
        i ≤ j → StartIdx r i si → StartIdx r j sj → si = sj) := by
  intro h
  have hbad : (3 : Nat) = 1 := h .r0 0 1 3 1 (by omega) .r0_step0 .r0_step1
  exact absurd hbad (by omega)

end CollapseRefuted
