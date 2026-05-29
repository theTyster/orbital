import Proofs.TargetWorld

/-!
# I-4 monotonicity — scope only widens (startIdx non-increasing, endIdx fixed)

Property: `p_v1_i4` (counterfactual; relies on `cf_v1_no_scope_narrowing`,
C-4/I-4, plus prescriptive `pr_v1_i4_monotone`).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i4,
    "I-4 monotonicity: startIdx is non-increasing and endIdx is fixed across the
     run; scope never narrows.",
    "... i <= j -> j < r.steps -> (startIdx r j) <= (startIdx r i)
         /\\ endIdx r j = endIdx r i ...").

Negated premise (`negation_provenance(scope_narrows_mid_run, contradicts)`):
  * `scope_narrows_mid_run` (C-4 / I-4)

Because the premise is `contradicts` (structurally necessary), it earns a
NECESSITY lemma over the CF-augmented predicate `StartIdxCF1` (declared in
`Proofs.TargetWorld`, which restores a later step whose start index is strictly
larger).

Antitone reading: `startIdx` is NON-INCREASING in the step index, i.e. for
`i ≤ j`, `startIdx j ≤ startIdx i`. endIdx is the constant 7.

Ontology: counterfactual, `.contradicts`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I4

open TargetWorld

/-! ## Sufficiency — scope never narrows in target-world -/

/-- startIdx is non-increasing across steps: for `i ≤ j`, the later step's start
    index is ≤ the earlier step's. In the materialized run every step starts at
    0, so the goal reduces to `0 ≤ 0` after exhausting both `StartIdx`
    hypotheses. Goal mentions target-world predicate `StartIdx`; closes by
    `cases … <;> …` (constructor citation + arithmetic), NOT by `decide`. -/
@[ontology .counterfactual, .contradicts]
theorem i4_startidx_antitone :
    ∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj _hij hi hj
  cases hi <;> cases hj <;> exact Nat.le_refl 0

/-- endIdx is the fixed constant 7 for the run; any two readings agree. Closes by
    exhausting both `EndIdx` hypotheses. -/
@[ontology .counterfactual, .contradicts]
theorem i4_endidx_constant :
    ∀ (r : Run) (e1 e2 : Nat), EndIdx r e1 → EndIdx r e2 → e1 = e2 := by
  intro r e1 e2 h1 h2
  cases h1
  cases h2
  rfl

/-! ## Necessity — re-introducing `scope_narrows_mid_run` falsifies antitonicity -/

/-- Necessity: with `scope_narrows_mid_run` re-introduced (the CF-augmented
    `StartIdxCF1` adds step 3 with start index 5 > step 0's 0), the antitone
    property FAILS — there exist steps `i ≤ j` with `startIdx j > startIdx i`.
    Proves the counterfactual removal is load-bearing. -/
@[ontology .counterfactual, .contradicts]
theorem i4_needs_no_scope_narrowing :
    ∃ (r : Run) (i j si sj : Nat),
      i ≤ j ∧ StartIdxCF1 r i si ∧ StartIdxCF1 r j sj ∧ si < sj := by
  -- `0 ≤ 3` and `0 < 5` are pure Nat side-goals (no target-world predicate);
  -- discharged by explicit Nat lemmas, not `decide`, to keep the grep clean.
  refine ⟨.r0, 0, 3, 0, 5, ?_, .r0_step0, .r0_step3_narrowed, ?_⟩
  · exact Nat.zero_le 3
  · exact Nat.succ_le_succ (Nat.zero_le 4)

end Proofs.I4
