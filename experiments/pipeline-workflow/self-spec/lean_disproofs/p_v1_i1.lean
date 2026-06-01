import Mathlib
import Proofs.TargetWorld
import Proofs.I1Liveness

/-!
# Adversary A — vacuity probe against `Proofs.I1.i1_explain_always_runs`

Original intended property (`target-world.pl`, `formal_property(p_v1_i1, ...)`):
  "I-1 liveness: every TERMINATING run reaches the explain step."
  sketch: `∀ (r : Run), Terminates r → ReachesStep r Stage.explain`

As materialized in `Proofs/I1Liveness.lean`:
  `theorem i1_explain_always_runs : ∀ r : Run, Terminates r → ReachesExplain r`
  (proof: `intro r h; cases h; exact .r0`)

The adversarial QUESTION is NOT "is the kernel proof valid" (it is) but "is the
THEOREM VACUOUS" — does the implication `Terminates r → ReachesExplain r`
actually CONSTRAIN a liveness obligation, or does it hold for ANY encoding in
which `Terminates` and `ReachesExplain` are each total over a one-point `Run`,
making the antecedent dead weight and the conclusion an unconditional fact?

This is the SAME class of defect caught in I-3 (`p_v1_i3.lean`): there, a
FREE measure + identity step satisfied "termination"; here, a TOTAL antecedent
+ TOTAL consequent over a singleton domain satisfy "liveness" with the word
"terminating" carrying no filtering power. The probes below build DEGENERATE
witnesses. Each compiles under the shared Mathlib clone.
-/

set_option autoImplicit false

namespace AdversaryA_I1

open TargetWorld Proofs.I1

/-! ## Probe 1 — the antecedent `Terminates r` is DEAD WEIGHT

The intended property is CONDITIONAL: only *terminating* runs must reach explain.
A genuine liveness claim is informative only if "terminating" can FAIL — there must
be a conceivable run that does NOT terminate, which the antecedent then excludes.
But `Terminates` is TOTAL over `Run`: provable for every run with no hypothesis. So
the antecedent excludes nothing and the implication is `True → _`. -/
theorem terminates_is_total : ∀ r : Run, Terminates r := by
  intro r; cases r; exact .r0

/-- There is NO non-terminating run for the antecedent to filter. The "terminating"
    qualifier in the English property partitions the empty set out of `Run`. -/
theorem no_nonterminating_run : ¬ ∃ r : Run, ¬ Terminates r := by
  rintro ⟨r, hr⟩; cases r; exact hr .r0

/-! ## Probe 2 — the consequent `ReachesExplain r` is UNCONDITIONALLY TRUE

The conclusion holds for EVERY run with NO hypothesis at all. So liveness is not
"terminating runs (as opposed to others) reach explain" — it is "the one run we
encoded reaches explain, which it does by its lone constructor". -/
theorem reaches_explain_is_unconditional : ∀ r : Run, ReachesExplain r := by
  intro r; cases r; exact .r0

/-- There is NO run that fails to reach explain. The consequent carries no
    information: `ReachesExplain` is constantly `True` over the singleton domain. -/
theorem no_unreaching_run : ¬ ∃ r : Run, ¬ ReachesExplain r := by
  rintro ⟨r, hr⟩; cases r; exact hr .r0

/-! ## Probe 3 — VACUITY WITNESS: the hypothesis can be DISCARDED

The decisive witness. We re-derive the EXACT conclusion of `i1_explain_always_runs`
while THROWING THE HYPOTHESIS AWAY (`_h` is unused). Since this builds, the
`Terminates r →` premise is provably inert: the theorem is the implication-mirror
of the unconditional fact `∀ r, ReachesExplain r`. This parallels the I-3 finding
that the step argument was dead weight. -/
theorem liveness_holds_ignoring_hypothesis :
    ∀ r : Run, Terminates r → ReachesExplain r := by
  intro r _h
  exact reaches_explain_is_unconditional r

/-- Sharper: the original theorem and the hypothesis-discarding version are the
    SAME function. `i1_explain_always_runs` is definitionally the constant map that
    ignores its `Terminates` proof and returns the lone `ReachesExplain.r0`. The
    `Terminates` proof is consumed by `cases h` only to be discarded — it never
    constructs the answer. -/
theorem i1_discards_its_hypothesis :
    (fun (r : Run) (_ : Terminates r) => i1_explain_always_runs r ‹_›)
      = (fun (r : Run) (_ : Terminates r) => reaches_explain_is_unconditional r) := by
  funext r h
  cases r
  rfl

/-! ## Probe 4 — the universal ranges over a ONE-POINT domain

`∀ r : Run, P r` is, for the single-constructor `Run`, exactly `P .r0`. There is no
second run, no non-terminating run, no run stuck before explain. The quantifier is
decorative: it cannot present any counter-shape the liveness claim could fail on. -/
theorem run_is_a_one_point_domain : ∀ r : Run, r = .r0 := by
  intro r; cases r; rfl

/-- The I-1 universal collapses to its single `r0` instance — and that instance is
    `Terminates .r0 → ReachesExplain .r0`, i.e. `True → True`, the weakest possible
    non-trivial implication. -/
theorem i1_is_just_its_r0_instance :
    (∀ r : Run, Terminates r → ReachesExplain r)
      ↔ (Terminates .r0 → ReachesExplain .r0) := by
  constructor
  · intro h; exact h .r0
  · intro h r; cases r; exact h

/-! ## Contrast — what a NON-vacuous half of I-1 looks like (the terminal lemma)

For calibration: the SIBLING theorem `i1_explain_is_terminal` (`∀ s, ¬ StageOrder
.explain s`) is NOT vacuous. `StageOrder` relates REAL pairs — something maps INTO
explain (`measure_entailment → explain`) — and the proof that nothing maps OUT of
explain is genuine structural content over the full 8-stage / 7-edge relation. The
contrast (in-edge exists, out-edge does not) is the real terminal property. This
shows the vacuity is LOCALIZED to the liveness implication, not the whole file. -/
theorem terminal_half_is_nonvacuous :
    (∃ s, StageOrder s .explain) ∧ (∀ s, ¬ StageOrder .explain s) := by
  refine ⟨⟨.measure_entailment, .s7_se⟩, ?_⟩
  intro s
  exhaust

end AdversaryA_I1
