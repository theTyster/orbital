import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# I-4 post-rebuild VACUITY probe (1/3) — REVERSE-direction witness must FAIL

OLD attack `p_v1_i4.lean` §2 inhabited `i4_holds_in_reverse_direction`
(`j ≤ i → sj ≤ si`) because the OLD `StartIdx` was the constant-0 relation, so
`sj ≤ si` was always `0 ≤ 0`. Over the FROZEN non-degenerate model
(r0: 3 → 1 → 0; r1: 2 → 0) the reverse universal is genuinely FALSE:

  r0, i = 2 (si = 0), j = 0 (sj = 3):  `j ≤ i` = `0 ≤ 2` TRUE,
                                       `sj ≤ si` = `3 ≤ 0` FALSE.

So this probe MUST FAIL to type-check — `omega` cannot close the `3 ≤ 0` goal
left open by the `r0_step0 / r0_step2` case of `cases hi <;> cases hj`.
A compile FAILURE here is the SURVIVAL signal: the degenerate reverse witness
can no longer be inhabited.
-/

set_option autoImplicit false

namespace I4PostRebuildReverse

open TargetWorld

/-- EXPECTED TO FAIL. The reverse-direction antitone read is false over the
    rebuilt model (`3 ≤ 0` survives `omega` in the `r0` step2/step0 cross-case). -/
theorem i4_reverse_direction_SHOULD_FAIL :
    ∀ (r : Run) (i j si sj : Nat),
      j ≤ i → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj _hji hi hj
  cases hi <;> cases hj <;> omega

end I4PostRebuildReverse
