import Mathlib
import Proofs.TargetWorld
import Proofs.I5Reserve

/-!
# NEGATIVE PROBE — EXPECTED TO FAIL TO COMPILE.

The OLD attack's capstone `probe4_sufficiency_shape_coexists_with_violation`
jointly inhabited (sufficiency shape) ∧ (a coexisting reserve violation). This
file aims the SAME joint-inhabitation at the REAL frozen `Spend`/`Reserve`
relations: it asserts a below-reserve spend EXISTS in the real model.

Survival signal: this MUST FAIL to type-check. The real `Spend`/`Reserve` carry
only above-reserve pairs (a0: 5≥2, a1: 3≥3), so no `s < r` witness can be
constructed — there is no constructor of `Spend`/`Reserve` producing a
below-reserve pair, and the universal `i5_spend_ge_reserve` independently
forbids one.

We deliberately leave the violating arithmetic to be discharged by `omega` /
constructor citation; both must be UNABLE to produce the witness. If this file
COMPILES, the model is still degenerate and the verdict would be `still_vacuous`.
-/

set_option autoImplicit false

namespace AdvProbeI5CoexistFail

open TargetWorld

/-- ATTEMPT to inhabit a below-reserve spend in the REAL frozen model. There is
    no such (a,s,r) — every `Spend`/`Reserve` constructor pair is above-reserve.
    The final `omega` (or any constructor citation) cannot manufacture `s < r`
    from the available facts, so this MUST error / be unprovable. We force the
    witness explicitly at `a0` with the only candidate spend/reserve to make the
    failure concrete (5 < 2 is false). -/
theorem coexisting_violation_in_real_model_FAILS :
    ∃ (a : DisproveAttempt) (s r : Nat), Spend a s ∧ Reserve a r ∧ s < r := by
  refine ⟨.a0, 5, 2, .a0, .a0, ?_⟩
  omega

end AdvProbeI5CoexistFail
