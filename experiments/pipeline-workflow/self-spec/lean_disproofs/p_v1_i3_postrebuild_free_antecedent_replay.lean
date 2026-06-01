import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# I-3 post-rebuild FREE-ANTECEDENT replay (EXPECT: FAILS to compile)

Transcribes the original `i3_antecedent_is_free` decisive-vacuity witness: in
the OLD theorem the `WellFounded (InvImage … measure)` antecedent was free for
ANY measure, so termination held for an arbitrary measure with `id` as the step.

Against the rebuilt `i3_termination : ∀ s, Acc StepRev s` there is NO measure
parameter and NO free well-foundedness antecedent — the measure `M` and the
relation `Step` are pinned in the statement. The application below is ill-typed.

EXPECTED: `lake env lean` exits NON-ZERO on this file.
-/

set_option autoImplicit false

namespace I3PostRebuildFreeAntecedent

open TargetWorld Proofs.I3

/-- VERBATIM replay of the original decisive-vacuity witness over an arbitrary
    measure. EXPECT a type error: `i3_termination` takes a `State`, not a measure
    and an `id` step. -/
theorem i3_antecedent_is_free (measureM : State → Nat × Nat) :
    (∀ s : State, Acc (InvImage (Prod.Lex Nat.lt Nat.lt) measureM) s) :=
  i3_termination measureM id (measureWf measureM)

end I3PostRebuildFreeAntecedent
