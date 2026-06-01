import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# I-4 post-rebuild VACUITY probe (3/3) — COLLAPSE-to-equality witness must FAIL

OLD attack `p_v1_i4.lean` §3 inhabited `i4_collapses_to_equality`
(`i ≤ j → si = sj`) because the constant-0 relation pinned `si = sj = 0` for
every pair — the antitone property held the trivial way `0 = 0` holds and could
ALSO force the opposite inequality. Over the FROZEN model the start index
genuinely VARIES with the step:

  r0, i = 0 (si = 3), j = 2 (sj = 0):  `i ≤ j` = `0 ≤ 2` TRUE,
                                       `si = sj` = `3 = 0` FALSE.

So the collapse universal is FALSE and this probe MUST FAIL to type-check
(`omega` cannot prove `3 = 0`). A compile FAILURE is the SURVIVAL signal:
antitonicity no longer degenerates to a constant function.
-/

set_option autoImplicit false

namespace I4PostRebuildCollapse

open TargetWorld

/-- EXPECTED TO FAIL. The start index is not constant in the rebuilt model, so
    `i ≤ j` does NOT collapse `si` and `sj` to a common value — the equality
    witness cannot be inhabited (`3 = 0` survives `omega`). -/
theorem i4_collapse_to_equality_SHOULD_FAIL :
    ∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → si = sj := by
  intro r i j si sj _hij hi hj
  cases hi <;> cases hj <;> omega

end I4PostRebuildCollapse
