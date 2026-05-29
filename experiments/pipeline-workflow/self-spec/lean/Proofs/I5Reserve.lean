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
predicate and show the property FAILS there — proving the counterfactual removal
is load-bearing.

Ontology: counterfactual, `.contradicts` (both negated premises).
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I5

open TargetWorld

/-! ## Sufficiency — the property holds in target-world (forbidden facts absent) -/

/-- Reserve discipline: spend ≥ reserve. Canonical attempt `a0` spends 1, reserves
    1, so `1 ≤ 1`. -/
@[ontology .counterfactual, .contradicts]
theorem i5_spend_ge_reserve :
    ∀ a : DisproveAttempt, ∃ s r : Nat, Spend a s ∧ Reserve a r ∧ r ≤ s := by
  intro a
  cases a
  exact ⟨1, 1, .a0, .a0, Nat.le_refl 1⟩

/-- No self-attack: target ≠ own output. The two surfaces are distinct
    enum constructors (`gate_target_descriptor` vs `disproof_results`), so the
    disequality closes by constructor disjointness — NOT by `decide`. -/
@[ontology .counterfactual, .contradicts]
theorem i5_target_ne_own_output :
    ∀ (a : DisproveAttempt) (t o : DisproveSurface),
      Target a t → OwnOutput a o → t ≠ o := by
  intro a t o ht ho
  cases ht
  cases ho
  intro h
  cases h

/-! ## Necessity — re-introducing each forbidden fact falsifies the property -/

/-- **CF-augmentation for `disprove_spends_below_reserve`.** Restores an attempt
    whose spend (0) is below its reserve (1). -/
inductive SpendCF : DisproveAttempt → Nat → Prop where
  | a0_below : SpendCF .a0 0          -- restored: spend below reserve

/-- Necessity: with `disprove_spends_below_reserve` re-introduced, the reserve
    discipline FAILS — there is an attempt with spend < reserve. Load-bearing. -/
@[ontology .counterfactual, .contradicts]
theorem i5_needs_no_below_reserve :
    ∃ (a : DisproveAttempt) (s r : Nat), SpendCF a s ∧ Reserve a r ∧ s < r := by
  exact ⟨.a0, 0, 1, .a0_below, .a0, Nat.zero_lt_one⟩

/-- **CF-augmentation for `disprove_attacks_own_output`.** Restores an attempt
    whose target coincides with its own output (both `disproof_results`). -/
inductive TargetCF : DisproveAttempt → DisproveSurface → Prop where
  | a0_self : TargetCF .a0 .disproof_results   -- restored: target = own output

/-- Necessity: with `disprove_attacks_own_output` re-introduced, the no-self-attack
    discipline FAILS — there is an attempt whose target equals its own output.
    Load-bearing. -/
@[ontology .counterfactual, .contradicts]
theorem i5_needs_no_self_attack :
    ∃ (a : DisproveAttempt) (t o : DisproveSurface),
      TargetCF a t ∧ OwnOutput a o ∧ t = o := by
  exact ⟨.a0, .disproof_results, .disproof_results, .a0_self, .a0, rfl⟩

end Proofs.I5
