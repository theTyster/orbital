import Mathlib
import Proofs.TargetWorld
import Proofs.I5Reserve

/-!
# Adversary — VACUITY probe against `Proofs.I5.i5_spend_ge_reserve`
                                  & `Proofs.I5.i5_target_ne_own_output`

The adversarial QUESTION is NOT "is the kernel proof valid" (it is) but
"does the THEOREM actually constrain the substrate it claims to be about?"

The ORIGINAL formal_property (target-world.pl `p_v1_i5`) is:

    ∀ a : DisproveAttempt, spend a ≥ reserve a ∧ target a ≠ ownOutput a

with `spend`, `reserve`, `target`, `ownOutput` as FUNCTIONS of the attempt.

The proof file `I5Reserve.lean` translates these FUNCTIONS into inductive
RELATIONS (`Spend : DisproveAttempt → Nat → Prop`, etc.) and then states the
reserve half EXISTENTIALLY:

    i5_spend_ge_reserve : ∀ a, ∃ s r : Nat, Spend a s ∧ Reserve a r ∧ r ≤ s

This file tests whether that existential restatement is a faithful encoding of
the universal/functional original, or a degenerate weakening.
-/

set_option autoImplicit false

namespace AdvProbeI5

open TargetWorld

/-! ## Probe 1 — the universal ranges over a SINGLETON domain.

`DisproveAttempt` has exactly one constructor, `.a0`. So `∀ a : DisproveAttempt`
in `i5_spend_ge_reserve` and `i5_target_ne_own_output` is a quantifier over a
one-element type: it asserts the property for the single canonical attempt and
NOTHING about any other (e.g. adversarial, below-reserve, self-targeting)
attempt — because no such attempt INHABITS the domain. The "∀" is decorative,
exactly the I-3 "substrate plays no role" shape. We make this precise: the
universal is definitionally equivalent to its single instance. -/
theorem probe1_universal_is_singleton :
    (∀ a : DisproveAttempt, ∃ s r : Nat, Spend a s ∧ Reserve a r ∧ r ≤ s)
      ↔ (∃ s r : Nat, Spend .a0 s ∧ Reserve .a0 r ∧ r ≤ s) := by
  constructor
  · intro h; exact h .a0
  · intro h a; cases a; exact h

/-! ## Probe 2 — the EXISTENTIAL restatement does not forbid a below-reserve spend.

The original property's spend half is the FUNCTIONAL/universal inequality
`spend a ≥ reserve a`. The proof restates it as the EXISTENTIAL
`∃ s r, Spend a s ∧ Reserve a r ∧ r ≤ s`. These are NOT equivalent when `Spend`
is a relation that can hold of more than one value: the existential is satisfied
by cherry-picking ONE compliant (s, r) pair, even while a BELOW-reserve pair
ALSO holds. We exhibit exactly such a relation.

`SpendBad .a0` holds of BOTH 5 (compliant) and 0 (below the reserve of 1).
`ReserveStd .a0` is 1, as in the real model. -/
inductive SpendBad : DisproveAttempt → Nat → Prop where
  | compliant : SpendBad .a0 5        -- a cherry-pickable compliant spend
  | below     : SpendBad .a0 0        -- the forbidden below-reserve spend, coexisting

inductive ReserveStd : DisproveAttempt → Nat → Prop where
  | a0 : ReserveStd .a0 1

/-- The proof's existential SHAPE holds of `SpendBad`/`ReserveStd` — it is
    satisfied by the cherry-picked compliant pair (5 ≥ 1). -/
theorem probe2_existential_satisfied :
    ∀ a : DisproveAttempt, ∃ s r : Nat, SpendBad a s ∧ ReserveStd a r ∧ r ≤ s := by
  intro a
  cases a
  exact ⟨5, 1, .compliant, .a0, by norm_num⟩

/-- …yet in the SAME model a below-reserve spend (0 < 1) ALSO holds. The
    existential theorem the proof proves is therefore TRUE of a model that
    VIOLATES the intended reserve discipline. The encoding does not bind the
    forbidden fact. -/
theorem probe2_below_reserve_coexists :
    ∃ a : DisproveAttempt, ∃ s r : Nat, SpendBad a s ∧ ReserveStd a r ∧ s < r := by
  exact ⟨.a0, 0, 1, .below, .a0, Nat.zero_lt_one⟩

/-- The decisive vacuity statement for the spend half: the existential reserve
    discipline and a reserve VIOLATION are SIMULTANEOUSLY inhabited by one model.
    A faithful encoding of `∀ a, spend a ≥ reserve a` could not admit this. -/
theorem probe2_shape_does_not_forbid_violation :
    (∀ a : DisproveAttempt, ∃ s r : Nat, SpendBad a s ∧ ReserveStd a r ∧ r ≤ s)
    ∧ (∃ a : DisproveAttempt, ∃ s r : Nat, SpendBad a s ∧ ReserveStd a r ∧ s < r) :=
  ⟨probe2_existential_satisfied, probe2_below_reserve_coexists⟩

/-! ## Probe 3 — the no-self-attack half is a FIXED two-constructor disequality;
    the attempt `a` is dead weight.

`i5_target_ne_own_output` is `∀ a t o, Target a t → OwnOutput a o → t ≠ o`. With
single-constructor `Target`/`OwnOutput`, the only inhabited `(t,o)` is
`(gate_target_descriptor, disproof_results)`, so the theorem reduces to the
constant fact `gate_target_descriptor ≠ disproof_results` — true of the enum
INDEPENDENT of any attempt. We exhibit it for an arbitrary (irrelevant) `a`,
proving the attempt argument never constrains the conclusion. This is the
exact I-3 "_step is dead weight" shape. -/
theorem probe3_target_disequality_is_attempt_independent
    (_a : DisproveAttempt) :
    (DisproveSurface.gate_target_descriptor ≠ DisproveSurface.disproof_results) := by
  intro h; cases h

/-- And the proof's own theorem, applied at the canonical attempt with the only
    inhabited target/output pair, is just that same fixed disequality — the
    self-attack discipline says nothing an attempt could ever violate, because
    `Target`/`OwnOutput` pin the surfaces to distinct constructors by fiat. -/
theorem probe3_no_self_attack_is_constructor_fiat :
    DisproveSurface.gate_target_descriptor ≠ DisproveSurface.disproof_results :=
  Proofs.I5.i5_target_ne_own_output .a0
    .gate_target_descriptor .disproof_results .a0 .a0

/-! ## Probe 4 — why the proof's NECESSITY lemmas do NOT defeat the vacuity charge.

The proof file anticipates the load-bearing objection with `i5_needs_no_below_reserve`
and `i5_needs_no_self_attack`. But those operate on FRESH predicates (`SpendCF`,
`TargetCF`) carrying ONLY the violating pair — they never show the SUFFICIENCY
theorem would FAIL in a model containing a violation. The sufficiency theorems
range over `Spend`/`Target`, which by construction can NEVER hold of a violating
value, so re-introducing a violation in a SEPARATE predicate cannot disturb them.

`probe2_shape_does_not_forbid_violation` is the sharper test the necessity lemmas
skip: a SINGLE relation carrying BOTH a compliant and a violating pair still
satisfies the sufficiency SHAPE. We restate it as the capstone — the existential
sufficiency theorem and a coexisting reserve violation are jointly inhabited, so
the theorem does not capture `∀ a, spend a ≥ reserve a`. -/
theorem probe4_sufficiency_shape_coexists_with_violation :
    (∀ a : DisproveAttempt, ∃ s r : Nat, SpendBad a s ∧ ReserveStd a r ∧ r ≤ s)
    ∧ (∃ a : DisproveAttempt, ∃ s r : Nat, SpendBad a s ∧ ReserveStd a r ∧ s < r) :=
  probe2_shape_does_not_forbid_violation

end AdvProbeI5
