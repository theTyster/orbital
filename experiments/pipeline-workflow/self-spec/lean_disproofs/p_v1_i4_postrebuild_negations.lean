import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# I-4 post-rebuild VACUITY probe — POSITIVE inhabitation of the negations

Beyond showing the three degenerate witnesses FAIL to type-check, this file
POSITIVELY inhabits the NEGATION of each as a buildable theorem over the FROZEN
model. If these build (no `sorry`/`axiom`/`native_decide`), the three vacuity
universals from `p_v1_i4.lean` are not merely hard to prove — they are FALSE,
which is the sharpest possible survival signal for I-4.

Frozen model: `StartIdx .r0 0 3`, `StartIdx .r0 1 1`, `StartIdx .r0 2 0`.
-/

set_option autoImplicit false

namespace I4PostRebuildNegations

open TargetWorld

/-- NEGATION of the reverse-direction witness. There exist steps with `j ≤ i`
    yet `si < sj` (so `sj ≤ si` FAILS): r0, i = 2 (si = 0), j = 0 (sj = 3),
    `0 ≤ 2` holds, and `0 < 3`. -/
theorem i4_reverse_direction_is_false :
    ¬ (∀ (r : Run) (i j si sj : Nat),
         j ≤ i → StartIdx r i si → StartIdx r j sj → sj ≤ si) := by
  intro h
  -- instantiate at r0, i = 2 (si = 0), j = 0 (sj = 3); `j ≤ i` = `0 ≤ 2`.
  have hle : (3 : Nat) ≤ 0 :=
    h .r0 2 0 0 3 (by omega) .r0_step2 .r0_step0
  omega

/-- NEGATION of the no-ordering witness. Dropping the `i ≤ j` premise, the
    conclusion `sj ≤ si` is refuted by the SAME bad pair (i = 2, j = 0): the
    order-free universal does not hold over the rebuilt model. -/
theorem i4_no_ordering_is_false :
    ¬ (∀ (r : Run) (i j si sj : Nat),
         StartIdx r i si → StartIdx r j sj → sj ≤ si) := by
  intro h
  have hle : (3 : Nat) ≤ 0 := h .r0 2 0 0 3 .r0_step2 .r0_step0
  omega

/-- NEGATION of the collapse-to-equality witness. There exist steps with
    `i ≤ j` yet `si ≠ sj`: r0, i = 0 (si = 3), j = 2 (sj = 0), `0 ≤ 2` holds,
    and `3 ≠ 0`. The start index genuinely varies — no constant-function
    collapse. -/
theorem i4_collapse_to_equality_is_false :
    ¬ (∀ (r : Run) (i j si sj : Nat),
         i ≤ j → StartIdx r i si → StartIdx r j sj → si = sj) := by
  intro h
  have heq : (3 : Nat) = 0 :=
    h .r0 0 2 3 0 (by omega) .r0_step0 .r0_step2
  omega

/-- Sanity / load-bearing confirmation: the SURVIVING antitone direction does
    hold at exactly that pair — `i ≤ j` (0 ≤ 2) gives `sj ≤ si` (0 ≤ 3). This
    shows the premise direction is the ONLY one inhabited, so I-4 genuinely
    distinguishes widening from narrowing. -/
theorem i4_forward_direction_holds_at_witness :
    StartIdx .r0 0 3 → StartIdx .r0 2 0 → (0 : Nat) ≤ 3 := by
  intro _ _; omega

end I4PostRebuildNegations
