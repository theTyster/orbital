import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# I-4 post-rebuild VACUITY probe (2/3) — NO-ORDERING witness must FAIL

OLD attack `p_v1_i4.lean` §2 inhabited `i4_holds_with_no_step_ordering`
(`StartIdx r i si → StartIdx r j sj → sj ≤ si`, NO ordering hypothesis at all)
because every start index was the constant 0. Over the FROZEN model
(r0: 3 → 1 → 0) dropping the `i ≤ j` premise exposes the bad pair:

  r0, i = 2 (si = 0), j = 0 (sj = 3):  conclusion `sj ≤ si` = `3 ≤ 0` FALSE.

With no ordering constraint that case is reachable, so the universal is FALSE
and this probe MUST FAIL to type-check (`omega` cannot close `3 ≤ 0`).
A compile FAILURE is the SURVIVAL signal: antitonicity genuinely DEPENDS on the
`i ≤ j` premise now — the premise is no longer decorative.
-/

set_option autoImplicit false

namespace I4PostRebuildNoOrder

open TargetWorld

/-- EXPECTED TO FAIL. Without the `i ≤ j` premise the conclusion is false over
    the rebuilt model — `i4_startidx_antitone`'s ordering antecedent is now
    load-bearing, so the order-free version cannot be inhabited. -/
theorem i4_no_ordering_SHOULD_FAIL :
    ∀ (r : Run) (i j si sj : Nat),
      StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj hi hj
  cases hi <;> cases hj <;> omega

end I4PostRebuildNoOrder
