import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# Adversary A — vacuity probe against `Proofs.I3.i3_termination`

The adversarial QUESTION is NOT "is the kernel proof valid" (it is) but
"is the THEOREM VACUOUS or MIS-STATED" — does it actually constrain the
materialized substrate, or does it hold for ANY measure (including a constant
one) and ANY step function, making the substrate facts decorative?

The probe below INHABITS the theorem with a DEGENERATE witness: a constant
measure `fun _ => (0,0)` and the identity step. If `i3_termination` accepts
this — and concludes `Acc` for every state — then "termination" here is just
"`Prod.Lex Nat.lt Nat.lt` is well-founded", a Mathlib fact, with the op_*
substrate (RecoveryBudget, EndIdx, StartIdx, the cursor loop) playing NO role.
-/

set_option autoImplicit false

namespace AdversaryA

open TargetWorld Proofs.I3

/-- The constant measure: every state maps to (0,0). This is a legitimate
    `State → ℕ × ℕ`. The substrate's recovery-budget-sum / cursor-distance are
    NOT used to construct it. -/
def constMeasure : State → Nat × Nat := fun _ => (0, 0)

/-- The identity step: a "transition" that NEVER changes state, i.e. a run that
    loops forever doing nothing. A genuine non-terminating control flow. -/
def idStep : State → State := id

/-- **Vacuity witness.** `i3_termination` accepts the constant measure and the
    identity (non-decreasing!) step, and STILL concludes accessibility for every
    state. The hypothesis `WellFounded (InvImage … constMeasure)` is discharged
    by `measureWf` — true for ANY measure. So the theorem's conclusion holds even
    for a step function that does not decrease the measure at all. -/
theorem i3_accepts_constant_measure_and_identity_step :
    ∀ s : State, Acc (InvImage (Prod.Lex Nat.lt Nat.lt) constMeasure) s :=
  i3_termination constMeasure idStep (measureWf constMeasure)

/-- Sharper: the theorem never mentions the step at all in its conclusion. The
    `_step` argument is dead (underscore-bound in the source). We exhibit TWO
    contradictory step functions satisfying the *same* theorem instance — proof
    that the step (the actual control flow whose termination is claimed) is not
    constrained. -/
theorem i3_step_is_dead_weight (bad : State → State) :
    ∀ s : State, Acc (InvImage (Prod.Lex Nat.lt Nat.lt) constMeasure) s :=
  i3_termination constMeasure bad (measureWf constMeasure)

/-- The decisive vacuity statement: the conclusion of `i3_termination` is, for
    every measure, ALREADY a theorem with no hypotheses (`measureWf … |>.apply`).
    So the `WellFounded …` antecedent is not a real constraint — it is always
    satisfiable, hence the implication is vacuously/trivially discharged and adds
    nothing over `i3_terminates_unconditionally`. We prove they are the same. -/
theorem i3_antecedent_is_free (measureM : State → Nat × Nat) :
    (∀ s : State, Acc (InvImage (Prod.Lex Nat.lt Nat.lt) measureM) s) :=
  i3_termination measureM id (measureWf measureM)

end AdversaryA
