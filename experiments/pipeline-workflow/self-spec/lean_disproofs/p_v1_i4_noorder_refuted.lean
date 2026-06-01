import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# POSITIVE refutation of the no-ordering claim

Inhabits the NEGATION of the no-ordering antitone claim. Witness identical to
the reverse case (the no-ordering claim is strictly stronger than reverse, so
the same witness refutes it): r0, i=2 (si=0), j=0 (sj=3); no ordering premise
is needed, yet `sj ≤ si` is `3 ≤ 0`, false. If this builds, the no-ordering
attack is definitively non-inhabitable.
-/

set_option autoImplicit false

namespace NoOrderRefuted

open TargetWorld Proofs.I4

/-- The no-ordering antitone claim is FALSE in the new model. -/
theorem no_ordering_is_false :
    ¬ (∀ (r : Run) (i j si sj : Nat),
        StartIdx r i si → StartIdx r j sj → sj ≤ si) := by
  intro h
  have hbad : (3 : Nat) ≤ 0 := h .r0 2 0 0 3 .r0_step2 .r0_step0
  exact absurd hbad (by omega)

end NoOrderRefuted
