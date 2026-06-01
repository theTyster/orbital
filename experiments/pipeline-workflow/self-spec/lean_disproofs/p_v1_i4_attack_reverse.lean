import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# Re-attack of `Proofs.I4.i4_startidx_antitone` — REVERSE-DIRECTION vacuity probe

This is the FIRST of the three probes from the original successful attack
(`lean_disproofs/p_v1_i4.lean`, `theorem i4_holds_in_reverse_direction`),
re-aimed at the REBUILT model.

ORIGINAL THEOREM (forward, the re-proof):
    ∀ r i j si sj, i ≤ j → StartIdx r i si → StartIdx r j sj → sj ≤ si

ATTACK (reverse ordering): claim the SAME conclusion holds with the ordering
hypothesis REVERSED to `j ≤ i`. In the OLD constant-0 model this compiled
(`cases hi <;> cases hj <;> exact Nat.le_refl 0`) because every start index was
0, so `sj ≤ si` was always `0 ≤ 0`. If the rebuild genuinely made `StartIdx`
decreasing (r0: 3→1→0), this MUST NOT compile: e.g. with j=0 ≤ i=2 we have
sj = StartIdx r0 0 = 3 and si = StartIdx r0 2 = 0, so `sj ≤ si` is `3 ≤ 0`,
FALSE. A FAILED build of this file is the SURVIVAL signal.

We use the IDENTICAL closing tactic the original attack used. If the model is
non-degenerate, `Nat.le_refl 0` cannot close the cross-step goals (they are not
`0 ≤ 0`), so the build fails — which is exactly what we want to observe.
-/

set_option autoImplicit false

namespace ReverseAttack

open TargetWorld Proofs.I4

theorem i4_holds_in_reverse_direction :
    ∀ (r : Run) (i j si sj : Nat),
      j ≤ i → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj _hji hi hj
  cases hi <;> cases hj <;> exact Nat.le_refl 0

end ReverseAttack
