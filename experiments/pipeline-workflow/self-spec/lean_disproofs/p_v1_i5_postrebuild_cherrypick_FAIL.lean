import Mathlib
import Proofs.TargetWorld
import Proofs.I5Reserve

/-!
# NEGATIVE PROBE — EXPECTED TO FAIL TO COMPILE.

This file reconstructs the OLD attack's decisive cherry-pick (old `p_v1_i5.lean`
Probe 2/4) and aims it at the NEW UNIVERSAL form of the reserve discipline. The
survival signal is: this file must FAIL to type-check, because the universal
form admits no cherry-pick.

OLD ATTACK SHAPE (succeeded against the degenerate existential):
  `SpendBad .a0` holds of BOTH 5 (compliant) and 0 (below reserve 1); the
  EXISTENTIAL sufficiency `∀ a, ∃ s r, SpendBad a s ∧ ReserveStd a r ∧ r ≤ s`
  was satisfiable by cherry-picking the (5,1) pair while (0,1) coexisted.

NEW TARGET: the universal `∀ a s r, SpendBad a s → ReserveStd a r → r ≤ s`.
A faithful UNIVERSAL cannot be satisfied by `SpendBad`, because it must hold of
the BELOW-RESERVE pair (0,1) too, which forces `1 ≤ 0` — false. The `by omega`
below CANNOT close the `below` case, so the file must error.

If this file ever COMPILES, the universal restatement failed to kill D2 and the
verdict would be `still_vacuous`.
-/

set_option autoImplicit false

namespace AdvProbeI5CherryFail

open TargetWorld

/-- The old attack's coexisting-violation relation, verbatim shape: a0 spends
    BOTH 5 (compliant) and 0 (below the reserve of 1). -/
inductive SpendBad : DisproveAttempt → Nat → Prop where
  | compliant : SpendBad .a0 5
  | below     : SpendBad .a0 0

inductive ReserveStd : DisproveAttempt → Nat → Prop where
  | a0 : ReserveStd .a0 1

/-- ATTEMPTED cherry-pick against the UNIVERSAL form. This is the old Probe 2
    sufficiency reshaped as the NEW universal. It MUST NOT type-check: the
    `below` case forces `1 ≤ 0`. We deliberately try the same closing move
    (`omega`/`cases`) the real proof uses; it cannot discharge the violating
    case. -/
theorem cherrypick_universal_FAILS :
    ∀ (a : DisproveAttempt) (s r : Nat), SpendBad a s → ReserveStd a r → r ≤ s := by
  intro a s r hs hr
  cases hs <;> cases hr <;> omega

end AdvProbeI5CherryFail
