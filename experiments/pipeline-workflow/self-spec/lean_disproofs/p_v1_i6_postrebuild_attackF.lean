import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# I-6 POST-REBUILD probe F — does the universal genuinely range over BOTH runs?

If the sufficiency floor `∀ r, ∃ a, RunAttempt r a` could be discharged by a SINGLE
constant witness term `fun _ => ⟨.a0, RunAttempt.r0_a0⟩` (ignoring `r`), then the
`cases r` split in the proof would be decorative and `r1` would be unconstrained —
the old vacuity. We attempt exactly that constant proof.

EXPECT: COMPILE FAILURE — `RunAttempt .r1 .a0` is uninhabited (no `r1_a0` ctor; r1
only fans to a1). The universal genuinely forces a per-run witness, so the `cases r`
split is LOAD-BEARING and r1 is a real, distinct constraint point.
-/

set_option autoImplicit false

namespace AdversaryI6PostF

open TargetWorld

-- Constant-witness proof of the floor: ignore r, always return ⟨.a0, .r0_a0⟩.
theorem floor_by_constant_witness : ∀ r : Run, ∃ a : DisproveAttempt, RunAttempt r a :=
  fun _ => ⟨.a0, RunAttempt.r0_a0⟩

end AdversaryI6PostF
