import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# I-3 post-rebuild SECOND-ORDER vacuity attacks

Two further degenerate readings a careful adversary would press against the
re-stated `i3_termination : ∀ s, Acc StepRev s`:

  (A) EMPTY-RELATION vacuity. `Acc` is trivially true if the relation has no
      predecessors. If `Step` (hence `StepRev`) were uninhabited, termination
      would be decorative again. We REFUTE this by inhabiting `Step` with both
      genuine moves — so the relation is nonempty and the descent does real work.

  (B) FREE-ANTECEDENT vacuity (the original `i3_antecedent_is_free`). The OLD
      theorem let you pick ANY measure and conclude `Acc (InvImage … measure)`.
      The probe below transcribes that application against the rebuilt theorem.
      It must FAIL: `i3_termination` no longer takes a measure argument.

This file contains BOTH a part that must compile (A, the nonemptiness witness)
and a part that must fail (B). To keep the harness verdict crisp we split:
  * the nonemptiness witness lives here and MUST compile;
  * the free-antecedent replay is in `..._free_antecedent_replay.lean` (separate
    file) so its non-zero exit is unambiguous.

EXPECTED: `lake env lean` exits ZERO on THIS file (nonemptiness holds).
-/

set_option autoImplicit false

namespace I3PostRebuildEmptyRel

open TargetWorld Proofs.I3

/-- **Anti-empty-relation witness.** `Step` is genuinely inhabited by BOTH moves
    over distinct states — so `Acc StepRev` is not vacuously true by absence of
    predecessors. The forward move advances the cursor; the loopback consumes a
    recovery unit. Both are real `Step`s. -/
theorem step_is_inhabited :
    Step ⟨0, 1⟩ ⟨0, 0⟩ ∧ Step ⟨2, 0⟩ ⟨1, 7⟩ :=
  ⟨Step.forward 0 0, Step.loopback 1 0 7⟩

/-- The reverse relation `StepRev` is likewise inhabited (predecessors exist),
    so the accessibility claim is over a relation that actually has edges. -/
theorem stepRev_is_inhabited : StepRev ⟨0, 0⟩ ⟨0, 1⟩ :=
  Step.forward 0 0

/-- A state WITH a `StepRev`-predecessor is still `Acc` — termination is not
    achieved by the predecessor being absent, but by the descent bottoming out.
    `⟨0,0⟩` is reachable-from `⟨0,1⟩` yet accessible; this exercises the real
    well-founded recursion, not an empty-relation shortcut. -/
theorem acc_holds_despite_predecessors : Acc StepRev ⟨0, 1⟩ :=
  i3_termination ⟨0, 1⟩

end I3PostRebuildEmptyRel
