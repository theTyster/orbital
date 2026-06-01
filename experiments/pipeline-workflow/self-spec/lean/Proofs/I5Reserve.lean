import Proofs.TargetWorld

/-!
# I-5 safety — disprove reserve discipline & no self-attack

Property: `p_v1_i5` (counterfactual; relies on `cf_v1_no_self_attack`,
`cf_v1_no_below_reserve`, plus prescriptive `pr_v1_i5_reserve`).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i5,
    "I-5 safety: every disprove attempt spends at or above the reserve and
     never targets its own output.",
    "... spend a >= reserve a /\\ target a <> ownOutput a ...").

Negated premises (BOTH `negation_provenance(_, contradicts)` in target-world.pl):
  * `disprove_attacks_own_output`  (C-3 / I-5)
  * `disprove_spends_below_reserve` (C-3 / I-5)

Because the premises are `contradicts` (structurally necessary, not CWA-fragile),
each earns a NECESSITY lemma: re-introduce the forbidden fact in a CF-augmented
predicate (declared in `Proofs.TargetWorld`) and show the property FAILS there —
proving the counterfactual removal is load-bearing.

NON-DEGENERACY NOTE (why this proof is non-vacuous):
  * `Spend` / `Reserve` vary genuinely: a0 spends 5 ≥ reserve 2; a1 spends 3 ≥
    reserve 3. The universal `∀ a s r, Spend a s → Reserve a r → r ≤ s` ranges
    over both and `omega` must discharge distinct concrete inequalities for each.
  * `Target` / `OwnOutput` are attempt-dependent: a0 has gate_target_descriptor vs
    disproof_results; a1 has disproof_results vs counterexamples. The disequality
    closes by constructor disjointness (`cases`), not by a single constant fiat.
  * Both necessity lemmas cite the CF predicates from TargetWorld (SpendCF, TargetCF)
    with concrete witnesses that falsify the sufficiency properties.

Ontology: counterfactual, `.contradicts` (both negated premises).
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I5

open TargetWorld

/-! ## Sufficiency — the property holds in target-world (forbidden facts absent) -/

/-- Reserve discipline: every disprove attempt's spend is at or above its reserve.

    UNIVERSAL form (non-vacuous): `∀ a s r, Spend a s → Reserve a r → r ≤ s`.
    The model provides two genuinely distinct data points:
      * a0: spend 5 ≥ reserve 2  →  `2 ≤ 5` (closed by `omega`)
      * a1: spend 3 ≥ reserve 3  →  `3 ≤ 3` (closed by `omega`)
    A coexisting below-reserve spend (see `i5_needs_no_below_reserve`) would
    add a case `s < r` that `omega` cannot close — the forbidden fact is
    load-bearing.

    Goal mentions target-world predicates `Spend` and `Reserve`; closes by
    constructor citation + arithmetic (`omega`), NOT by `decide`. -/
@[ontology .counterfactual, .contradicts]
theorem i5_spend_ge_reserve :
    ∀ (a : DisproveAttempt) (s r : Nat), Spend a s → Reserve a r → r ≤ s := by
  intro a s r hs hr
  cases hs <;> cases hr <;> omega

/-- No self-attack: every attempt's target differs from its own output.

    ATTEMPT-DEPENDENT (non-vacuous): the (target, own-output) pair varies:
      * a0: gate_target_descriptor vs disproof_results  →  distinct constructors
      * a1: disproof_results vs counterexamples          →  distinct constructors
    Each case closes by constructor disjointness — after `cases ht <;> cases ho`
    the goal `t ≠ o` becomes e.g. `gate_target_descriptor ≠ disproof_results`;
    `intro h; cases h` then yields `False` via kernel-level index disagreement.

    Goal mentions target-world predicates `Target` and `OwnOutput`; closes by
    `cases` (constructor citation), NOT by `decide`. -/
@[ontology .counterfactual, .contradicts]
theorem i5_target_ne_own_output :
    ∀ (a : DisproveAttempt) (t o : DisproveSurface),
      Target a t → OwnOutput a o → t ≠ o := by
  intro a t o ht ho
  cases ht <;> cases ho <;> intro h <;> cases h

/-! ## Necessity — re-introducing each forbidden fact falsifies the property -/

/-- **Necessity for reserve discipline.** With `disprove_spends_below_reserve`
    re-introduced (the `SpendCF` predicate from `TargetWorld`), the universal
    reserve discipline FAILS: `a0` spends 0, which is strictly below its reserve
    of 2. This makes the EXISTENTIAL `∃ a s r, SpendCF a s ∧ Reserve a r ∧ s < r`
    inhabited — a direct falsifier of `i5_spend_ge_reserve`.

    Cites `SpendCF.a0_below` (from TargetWorld) and `Reserve.a0`; the arithmetic
    `0 < 2` is closed by `omega`. No target-world predicate is closed by `decide`.
    Mirrors `i4_needs_no_scope_narrowing` from I4Monotone. -/
@[ontology .counterfactual, .contradicts]
theorem i5_needs_no_below_reserve :
    ∃ (a : DisproveAttempt) (s r : Nat), SpendCF a s ∧ Reserve a r ∧ s < r := by
  exact ⟨.a0, 0, 2, .a0_below, .a0, by omega⟩

/-- **Necessity for no-self-attack.** With `disprove_attacks_own_output`
    re-introduced (the `TargetCF` predicate from `TargetWorld`), the no-self-attack
    discipline FAILS: `a0` targets `disproof_results`, which is also `a0`'s own
    output. This makes `∃ a s, TargetCF a s ∧ OwnOutput a s` inhabited — a direct
    falsifier of `i5_target_ne_own_output`.

    Cites `TargetCF.a0_self` and `OwnOutput.a0` (both from TargetWorld); `rfl`
    witnesses the surface equality. No target-world predicate is closed by `decide`.
    Mirrors `i4_needs_no_scope_narrowing` from I4Monotone. -/
@[ontology .counterfactual, .contradicts]
theorem i5_needs_no_self_attack :
    ∃ (a : DisproveAttempt) (s : DisproveSurface), TargetCF a s ∧ OwnOutput a s := by
  exact ⟨.a0, .disproof_results, .a0_self, .a0⟩

end Proofs.I5
