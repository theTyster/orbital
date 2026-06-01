import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# POSITIVE refutation of the reverse direction

To rule out an `omega`-implementation artifact, we POSITIVELY inhabit the
NEGATION of the reverse-direction statement. This is a buildable proof that the
reverse claim is FALSE in the new model: there is a concrete `j ≤ i` witness
(r0, i=2, j=0, si=0, sj=3) with `j ≤ i` (0 ≤ 2) and `StartIdx r0 2 0`,
`StartIdx r0 0 3`, yet `sj ≤ si` is `3 ≤ 0`, which is false.

If THIS file builds, the reverse direction is definitively non-inhabitable —
the rebuild fixed the vacuity in the direction-sensitive sense. This is the
SURVIVAL evidence stated as a constructive theorem rather than a build failure.
-/

set_option autoImplicit false

namespace ReverseRefuted

open TargetWorld Proofs.I4

/-- The reverse-direction antitone claim (`j ≤ i → sj ≤ si`) is FALSE in the new
    model. Witness: r0, i=2 (si=0), j=0 (sj=3); `0 ≤ 2` holds but `3 ≤ 0` does
    not. -/
theorem reverse_direction_is_false :
    ¬ (∀ (r : Run) (i j si sj : Nat),
        j ≤ i → StartIdx r i si → StartIdx r j sj → sj ≤ si) := by
  intro h
  -- instantiate at the falsifying witness: i=2 (si=0), j=0 (sj=3), j ≤ i is 0 ≤ 2
  have hbad : (3 : Nat) ≤ 0 :=
    h .r0 2 0 0 3 (by omega) .r0_step2 .r0_step0
  exact absurd hbad (by omega)

end ReverseRefuted
