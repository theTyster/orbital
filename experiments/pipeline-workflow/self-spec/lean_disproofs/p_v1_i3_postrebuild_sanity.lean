import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# I-3 post-rebuild SANITY probe (EXPECT: COMPILES)

Confirms the toolchain invocation, the import graph, and that the rebuilt
`Proofs.I3` namespace is reachable from a probe. This file must COMPILE; it
exercises the genuine, non-degenerate facts that the re-stated I-3 now exposes.
If this fails, the probe harness — not the theorem — is broken.
-/

set_option autoImplicit false

namespace I3PostRebuildSanity

open TargetWorld Proofs.I3

-- The re-stated termination theorem has NO free measure/step arguments:
-- it is `∀ s : State, Acc StepRev s`. Confirm its exact type.
example : ∀ s : State, Acc StepRev s := i3_termination

-- The concrete two-move step exists and a genuine forward transition inhabits it.
example : Step ⟨0, 1⟩ ⟨0, 0⟩ := Step.forward 0 0

-- A genuine loopback transition inhabits it.
example : Step ⟨1, 3⟩ ⟨0, 5⟩ := Step.loopback 0 3 5

-- The strict-decrease lemma fires on a real forward step.
example : Prod.Lex Nat.lt Nat.lt (M ⟨0, 0⟩) (M ⟨0, 1⟩) :=
  step_strictDecreasing (Step.forward 0 0)

end I3PostRebuildSanity
