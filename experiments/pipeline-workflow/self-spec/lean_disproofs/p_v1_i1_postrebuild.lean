import Proofs.TargetWorld
import Proofs.I1Liveness

/-!
# Adversary A — POST-REBUILD re-attack of I-1 for VACUITY (survival probes)

The ORIGINAL attack (`p_v1_i1.lean`) succeeded against the OLD degenerate model
where `Run` was a one-point domain (`r0` only) and both `Terminates` and
`ReachesExplain` were total over that singleton, so the liveness implication
`Terminates r → ReachesExplain r` collapsed to `True → True` and the antecedent
was dead weight with no run for it to filter.

This file re-attacks the FROZEN rebuilt model. The non-vacuity of I-1 now lives,
by design, in two loci (NOT in the sufficiency antecedent — per D-8 explain runs
on EVERY path, so `ReachesExplain` is total and the discardable antecedent is the
faithful shape, not a defect):

  (a) the NECESSITY lemma `i1_needs_explain_on_hard_stop`
        `∃ r, Terminates r ∧ ¬ ReachesExplainCF r`   (witness r1), and
  (b) the STRUCTURAL terminal half `i1_explain_is_terminal`
        `∀ s, ¬ StageOrder .explain s`               (over the real 7-edge order).

The probes here POSITIVELY INHABIT the negations of the degenerate claims that
the original attack relied on — i.e. they are buildable theorems demonstrating
the model is now non-degenerate. The SHOULD-FAIL companions (which must NOT
type-check) live in the sibling `p_v1_i1_postrebuild_FAIL_*.lean` files.

No `sorry` / `axiom` / `native_decide`.
-/

set_option autoImplicit false

namespace AdversaryA_I1_PostRebuild

open TargetWorld Proofs.I1

/-! ## Survival 1 — `Run` is NO LONGER a one-point domain

The original attack's keystone was `run_is_a_one_point_domain : ∀ r, r = .r0`.
That is now FALSE: `r1 ≠ r0`. We positively inhabit the negation of the
singleton-collapse: there exist two DISTINCT runs. So the `∀ r` quantifier is no
longer decorative — it ranges over a genuine ≥2 domain. -/
theorem run_is_not_one_point : ∃ a b : Run, a ≠ b := by
  exact ⟨.r0, .r1, by decide⟩

/-- The two runs carry DISTINCT outcomes (`r0` completes, `r1` hard-stops); the
    `Outcome` discriminator the old singleton could not express now witnesses two
    behaviorally different terminating runs. -/
theorem outcomes_are_distinct :
    RunOutcome .r0 .complete ∧ RunOutcome .r1 .hard_stop ∧ (Outcome.complete ≠ .hard_stop) := by
  exact ⟨.r0, .r1, by decide⟩

/-! ## Survival 2 — the NECESSITY lemma genuinely BITES (locus a)

The CF world `ReachesExplainCF` (explain skipped on the hard-stop path) has NO
constructor for `r1`. So `r1` is a TERMINATING run that FAILS to reach explain
under the CF — `¬ ReachesExplainCF .r1` is positively inhabited. This is the
teeth: dropping the D-8 explain-on-hard-stop fact genuinely falsifies liveness
for `r1`. (If `ReachesExplainCF .r1` were inhabitable, the necessity lemma would
be vacuous — see the SHOULD-FAIL file `..._FAIL_cf_inhabits_r1.lean`.) -/
theorem cf_omits_r1 : Terminates .r1 ∧ ¬ ReachesExplainCF .r1 := by
  exact ⟨.r1, by exhaust⟩

/-- Sharper: the necessity witness is r1 SPECIFICALLY, and it is a run the REAL
    (D-8) world DOES carry into explain. So the gap is exactly "the hard-stop
    path": the same run reaches explain in the real world (`ReachesExplain .r1`)
    yet not in the CF world (`¬ ReachesExplainCF .r1`). The CF removal is
    load-bearing, not CWA fiat. -/
theorem cf_gap_is_the_hard_stop_path :
    ReachesExplain .r1 ∧ ¬ ReachesExplainCF .r1 := by
  exact ⟨.r1, by exhaust⟩

/-- The necessity lemma is NOT satisfiable by `r0` (the complete run): `r0` DOES
    reach explain even in the CF world, so the witness MUST be `r1`. This rules
    out a "fake" necessity that any run could discharge — the CF teeth are
    specific to the hard-stop path. -/
theorem cf_does_not_omit_r0 : ReachesExplainCF .r0 := .r0

/-! ## Survival 3 — the TERMINAL half is structural (locus b)

`StageOrder` relates REAL pairs: `measure_entailment → explain` is an in-edge to
explain, yet explain has NO out-edge. The terminal property `∀ s, ¬ StageOrder
.explain s` is therefore genuine structural content over the 7-edge chain, not a
fact about an empty relation. We positively inhabit the in-edge AND the absence
of any out-edge in one theorem. -/
theorem terminal_half_is_structural :
    (∃ s, StageOrder s .explain) ∧ (∀ s, ¬ StageOrder .explain s) := by
  refine ⟨⟨.measure_entailment, .s7_se⟩, ?_⟩
  intro s
  exhaust

/-- Explain cannot be given a successor: for EACH concrete stage, `StageOrder
    .explain s` is uninhabited. We spell out all 8 targets to show the absence is
    exhaustive over the closed `Stage` domain, not an artifact of an open type. -/
theorem explain_has_no_successor_anywhere :
    ¬ StageOrder .explain .close_world ∧
    ¬ StageOrder .explain .decompose_proposition ∧
    ¬ StageOrder .explain .model_obligations ∧
    ¬ StageOrder .explain .prove_invariants ∧
    ¬ StageOrder .explain .instantiate_properties ∧
    ¬ StageOrder .explain .realize_specification ∧
    ¬ StageOrder .explain .measure_entailment ∧
    ¬ StageOrder .explain .explain := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;> exhaust

/-! ## Survival 4 — the antecedent is discardable BY DESIGN, not by degeneracy

We DO confirm the antecedent `Terminates r` is discardable (the sufficiency
holds ignoring the hypothesis). Per the briefing this is the CORRECT shape for a
D-8 always-runs property — NOT a vacuity defect. We record it explicitly so the
verdict is not mistaken for "still_vacuous": the discardability is FAITHFUL
because `ReachesExplain` is total by D-8, and the non-vacuity has MOVED to the
necessity lemma + terminal half above. -/
theorem antecedent_discardable_by_d8 :
    ∀ r : Run, Terminates r → ReachesExplain r := by
  intro r _h
  cases r
  · exact .r0
  · exact .r1

/-- The DIFFERENCE from the old model: there `ReachesExplain` was total over a
    ONE-point domain (vacuous). Here `ReachesExplain` is total over a ≥2 domain
    AND the CF sibling `ReachesExplainCF` is PARTIAL (omits r1). Totality of the
    real predicate + partiality of the CF predicate is exactly the non-vacuous
    shape: the real world carries r1 to explain, the CF world does not. -/
theorem real_total_cf_partial :
    (ReachesExplain .r0 ∧ ReachesExplain .r1) ∧
    (ReachesExplainCF .r0 ∧ ¬ ReachesExplainCF .r1) := by
  exact ⟨⟨.r0, .r1⟩, ⟨.r0, by exhaust⟩⟩

end AdversaryA_I1_PostRebuild
