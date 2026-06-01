import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# I-3 post-rebuild REPLAY of the original vacuity attack (EXPECT: FAILS to compile)

The ORIGINAL attack (`p_v1_i3.lean`) inhabited the OLD vacuous `i3_termination`
by passing a CONSTANT measure and the IDENTITY (non-decreasing) step as FREE
arguments:

    i3_termination constMeasure idStep (measureWf constMeasure)

Against the rebuilt model, `i3_termination` has type `∀ s : State, Acc StepRev s`
— it takes NO measure/step/wf arguments. The free-argument application below is a
type error: there is nothing to which `constMeasure` could bind. If this file
FAILS to compile, the original vacuity witness can no longer be inhabited =>
SURVIVAL SIGNAL.

EXPECTED: `lake env lean` exits NON-ZERO on this file.
-/

set_option autoImplicit false

namespace I3PostRebuildReplay

open TargetWorld Proofs.I3

/-- The original degenerate measure, transcribed verbatim. -/
def constMeasure : State → Nat × Nat := fun _ => (0, 0)

/-- The original identity (non-decreasing) step, transcribed verbatim. -/
def idStep : State → State := id

/-- VERBATIM replay of the original vacuity witness. This bound to the OLD,
    free-measure/free-step `i3_termination`. Against the rebuilt theorem the
    application is ill-typed — `i3_termination` is now `∀ s, Acc StepRev s`,
    a function of a single `State`, not of a measure. EXPECT a type error. -/
theorem i3_accepts_constant_measure_and_identity_step :
    ∀ s : State, Acc (InvImage (Prod.Lex Nat.lt Nat.lt) constMeasure) s :=
  i3_termination constMeasure idStep (measureWf constMeasure)

end I3PostRebuildReplay
