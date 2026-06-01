import Mathlib
import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# Vacuity probe against `Proofs.I6.i6_disprove_runs` (canonical artifact)

A byte-identical build-validation copy lives at `lean/Proofs/I6VacuityProbe.lean`
inside the `Proofs/` source tree so `lake build` (the deductive judge) compiles it;
this file is the canonical adversarial artifact. Both compile cleanly (exit 0).

Original intended property (`target-world.pl`, `formal_property(p_v1_i6, ...)`):
  "I-6 cardinality floor: every run performs at least one disprove attempt."
  sketch: `∀ r : Run, 1 ≤ (disproveAttempts r).length`

Materialized form (`Proofs/I6Floor.lean`):
  `theorem i6_disprove_runs : ∀ r : Run, ∃ a : DisproveAttempt, RunAttempt r a`

The adversarial QUESTION: does `∃ a, RunAttempt r a` actually bind a CARDINALITY
FLOOR ("≥ 1, and a zero-attempt run would be REJECTED"), or is it the existential
mirror of a tautology over one-point domains — indistinguishable from "= 1",
"= 7", "exactly one fact asserted", none of which a *floor* model can violate?
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace AdversaryI6

open TargetWorld Proofs.I6

/-! ## Attack 1 — is the universal's domain `Run` a one-point type?

I-7's `∀ a : DisproveAttempt` ranges over a finite type whose ≥2 floor is bound by
a `x ≠ y` clause. I-6's `∀ r : Run` ranges over `Run`. We CONFIRM `Run` has exactly
ONE inhabitant — so the universal cannot present a counter-run; the quantifier is
decorative. (Contrast: this alone is not vacuity, but it removes the universal's
power to constrain anything.) -/
theorem run_is_a_one_point_domain : ∀ r : Run, r = .r0 := by
  intro r; cases r; rfl

/-! ## Attack 2 — is the existential's domain `DisproveAttempt` also one-point?

`∃ a : DisproveAttempt, …` cannot express "at least one of several distinct"; there
is only `.a0` to pick. So the existential degenerates to a single ground-fact lookup
`RunAttempt .r0 .a0`, NOT a count. We confirm the witness domain is one-point. -/
theorem disprove_attempt_is_a_one_point_domain : ∀ a : DisproveAttempt, a = .a0 := by
  intro a; cases a; rfl

/-! ## Attack 3 — the proof carries ZERO cardinality content.

The original `i6_disprove_runs` and the bare citation of the lone constructor
`RunAttempt.r0_a0` are the SAME proof term. No `≤`, no `length`, no count lemma
appears. The "1 ≤ length" reading is structurally ABSENT from the witness. -/
theorem the_floor_clause_is_inert :
    (i6_disprove_runs .r0) = ⟨DisproveAttempt.a0, RunAttempt.r0_a0⟩ := rfl

/-! ## Attack 4 — THE DECISIVE REGRESSION (the I-7 Attack-6 analogue, INVERTED).

For I-7, a degenerate ONE-adversary substrate FALSIFIES the `∃ x y, … ∧ x ≠ y`
body — that is what proved I-7's ≥2 floor load-bearing.

For I-6 we build the analogous degenerate substrate: a run that performs ZERO
disprove attempts (a relation with NO constructor for that run). The faithful "≥ 1"
floor MUST reject this run. We show the I-6 BODY `∃ a, RunAttemptCF0 r a` does fail
here (good) — BUT the actual `i6_disprove_runs` statement could NEVER be posed over
it, because `Run` is one-point and hard-wired to `RunAttempt.r0_a0`. The floor is
only "enforced" by the absence of any other constructor, i.e. by Closed-World fiat,
not by a quantified count the theorem checks. The degenerate substrate is
UNREACHABLE from the theorem's own domain. -/
inductive RunAttemptCF0 : Run → DisproveAttempt → Prop where
  -- DEGENERATE: zero attempts for r0. No constructor. A real "< floor" run.

theorem degenerate_zero_attempt_run_has_no_witness :
    ¬ (∃ a : DisproveAttempt, RunAttemptCF0 .r0 a) := by
  rintro ⟨a, h⟩
  cases h   -- no constructor of RunAttemptCF0 — vacuously impossible to inhabit

/-! ## Attack 5 — the vacuity verdict.

`degenerate_zero_attempt_run_has_no_witness` shows a zero-attempt run is
EXPRESSIBLE and would falsify the floor BODY. The faithful, non-vacuous I-6 would
be: `∀ r, (the model could present r with < floor attempts) → False`, i.e. the
floor must DISCRIMINATE between a ≥1 run and a 0 run. But `i6_disprove_runs`
discriminates nothing: it is `fun r => Run.casesOn r ⟨.a0, .r0_a0⟩` — it returns the
one hard-wired fact for the one hard-wired run. Swapping `RunAttempt` for ANY other
single-fact relation on a one-point `Run` would keep it provable. There is no
`x ≠ y`, no `length`, no `≤` — nothing the I-7 encoding used to make its floor bite.

Hence I-6 holds for the SAME structural reason a free-measure made I-3 vacuous: the
obligation's quantitative content ("≥ 1 *as opposed to* 0") is never the operative
clause; a constant/lone witness discharges it. We certify the proof is exactly the
casesOn-of-the-ground-fact: -/
theorem i6_is_definitionally_the_ground_fact :
    i6_disprove_runs = (fun r => Run.casesOn r ⟨.a0, .r0_a0⟩) := rfl

end AdversaryI6
