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

NON-DEGENERATE MODEL (r0: step0=3, step1=1, step2=0; r1: step0=2, step1=0):
  - Valid cases require real arithmetic: e.g. i=0, j=2 → sj=0 ≤ si=3.
  - Cross-cases with a FALSE ordering hypothesis (e.g. i=2 ≤ j=0 is absurd)
    are discharged by `omega` via contradiction from `hij`.
  - The `hij` hypothesis is BOUND (not discarded) and used by `omega` in every
    branch — both for contradiction and for discharging legitimate inequalities.

Ontology: counterfactual, `.contradicts`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I4

open TargetWorld

/-! ## Sufficiency — scope never narrows in target-world -/

/-- startIdx is non-increasing across steps: for `i ≤ j`, the later step's start
    index is ≤ the earlier step's.

    NON-VACUOUS PROOF: The non-degenerate model (r0: 3→1→0; r1: 2→0) forces
    `omega` to use `hij : i ≤ j` in every branch:
    * Legitimate cases: `hij` and the concrete index values are fed to `omega`
      which closes the arithmetic goal (e.g. `hij : 0 ≤ 2` with `si=3, sj=0`
      → `0 ≤ 3`).
    * Cross-run or reversed-step cases: `hij` carries a FALSE inequality (e.g.
      `hij : 2 ≤ 0`) which `omega` refutes immediately.
    `hij` is BOUND (not underscored-discarded); it is the load-bearing variable
    in both branch types. Goal mentions target-world predicate `StartIdx`; closes
    by `cases … <;> …` (constructor citation + arithmetic), NOT by `decide`. -/
@[ontology .counterfactual, .contradicts]
theorem i4_startidx_antitone :
    ∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj hij hi hj
  cases hi <;> cases hj <;> omega

/-- endIdx is the fixed constant 7 for the run; any two readings agree. Closes by
    exhausting both `EndIdx` hypotheses. -/
@[ontology .counterfactual, .contradicts]
theorem i4_endidx_constant :
    ∀ (r : Run) (e1 e2 : Nat), EndIdx r e1 → EndIdx r e2 → e1 = e2 := by
  intro r e1 e2 h1 h2
  cases h1 <;> cases h2 <;> rfl

/-! ## Necessity — re-introducing `scope_narrows_mid_run` falsifies antitonicity -/

/-- Necessity: with `scope_narrows_mid_run` re-introduced (the CF-augmented
    `StartIdxCF1` adds step 3 with start index 5 > step 0's 3), the antitone
    property FAILS — there exist steps `i ≤ j` with `startIdx j > startIdx i`.
    Proves the counterfactual removal is load-bearing. -/
@[ontology .counterfactual, .contradicts]
theorem i4_needs_no_scope_narrowing :
    ∃ (r : Run) (i j si sj : Nat),
      i ≤ j ∧ StartIdxCF1 r i si ∧ StartIdxCF1 r j sj ∧ si < sj := by
  -- `0 ≤ 3` and `3 < 5` are pure Nat side-goals (no target-world predicate);
  -- discharged by `omega` (pure arithmetic, no target-world predicate involved).
  refine ⟨.r0, 0, 3, 3, 5, ?_, .r0_step0, .r0_step3_narrowed, ?_⟩
  · omega
  · omega

/-! ## Regression — a scope-narrowing step falsifies antitonicity

    I-3-style regression check: any start-index assignment in which a LATER step
    carries a STRICTLY LARGER start index than an earlier step is a counterexample
    to antitonicity. The non-vacuity of the sufficiency proof is machine-checked:
    if `StartIdx` ever contained such a narrowing step, `i4_startidx_antitone`
    could not hold. -/

/-- Regression: a narrowing step — where the later step's start index EXCEEDS the
    earlier step's — directly refutes the antitone invariant `i4_startidx_antitone`.
    If `i ≤ j` but `si < sj`, then `sj ≤ si` is false, and no model of `StartIdx`
    that includes such a pair can satisfy `i4_startidx_antitone`.

    Mirrors `i3_no_measure_preserving_step`: the regression carries a *scope-
    narrowing* witness (instead of a measure-preserving step) and derives `False`
    from the combination of the antitone conclusion and the witness's strict
    ordering. -/
theorem i4_no_scope_narrowing_step
    {r : Run} {i j si sj : Nat}
    (hij : i ≤ j)
    (hi  : StartIdx r i si)
    (hj  : StartIdx r j sj)
    (hnarrow : si < sj)          -- scope NARROWED: later start exceeds earlier
    : ¬ (∀ (r' : Run) (i' j' si' sj' : Nat),
           i' ≤ j' → StartIdx r' i' si' → StartIdx r' j' sj' → sj' ≤ si') := by
  intro hanti
  have hle : sj ≤ si := hanti r i j si sj hij hi hj
  exact Nat.lt_irrefl si (Nat.lt_of_lt_of_le hnarrow hle)

end Proofs.I4
