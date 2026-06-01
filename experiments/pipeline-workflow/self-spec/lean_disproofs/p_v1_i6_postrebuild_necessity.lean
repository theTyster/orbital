import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# I-6 POST-REBUILD probe D — NECESSITY: the floor DISCRIMINATES ≥1 from 0.

The single most important post-rebuild question for I-6: is the floor still a CWA
fiat (constant ground-fact lookup), or does it genuinely DISCRIMINATE a ≥1-attempt
run from a 0-attempt run?

`RunAttemptCF` is the zero-attempt-run counterfactual: it carries `r0 ↦ a0` but
has NO constructor for `r1`. So `r1` performs zero attempts under CF.

This probe POSITIVELY INHABITS (as buildable theorems, no `sorry`/`axiom`/
`native_decide`):

  (D1) The floor BODY genuinely FAILS for the zero-attempt run `r1`:
       `¬ ∃ a, RunAttemptCF .r1 a`  (the floor is violated).
  (D2) The floor still HOLDS for the ≥1-attempt run `r0` under the SAME CF
       relation: `∃ a, RunAttemptCF .r0 a`. So CF does not trivially kill the
       floor everywhere — it discriminates: PASS for r0, FAIL for r1.
  (D3) The necessity existential the proof file claims:
       `∃ r, ¬ ∃ a, RunAttemptCF r a` (witness r1), re-derived independently.

Together D1+D2 are the discrimination signal: the `≥1` clause is OPERATIVE, not
fiat — the same relation accepts r0 and rejects r1 purely on attempt-count.
-/

set_option autoImplicit false

namespace AdversaryI6PostD

open TargetWorld

/-- (D1) The zero-attempt run `r1` FALSIFIES the floor body under CF.
    `RunAttemptCF` has no constructor for `r1`, so `cases h` is vacuous. -/
theorem zero_attempt_run_falsifies_floor :
    ¬ ∃ a : DisproveAttempt, RunAttemptCF .r1 a := by
  rintro ⟨a, h⟩
  cases h

/-- (D2) Under the SAME CF relation the ≥1-attempt run `r0` STILL satisfies the
    floor: it carries the `r0_a0` constructor. This proves CF does not kill the
    floor blindly — it discriminates PASS(r0) vs FAIL(r1) on attempt-count alone. -/
theorem ge_one_attempt_run_satisfies_floor :
    ∃ a : DisproveAttempt, RunAttemptCF .r0 a :=
  ⟨.a0, .r0_a0⟩

/-- (D3) The necessity existential, re-derived independently of the proof file:
    SOME run performs zero attempts under CF, so the universal floor would FAIL
    over the CF world. Witness `r1`. -/
theorem floor_fails_for_some_run_under_cf :
    ∃ r : Run, ¬ ∃ a : DisproveAttempt, RunAttemptCF r a :=
  ⟨.r1, zero_attempt_run_falsifies_floor⟩

/-- Sanity bridge: the proof file's own necessity lemma is the SAME proposition we
    just inhabited (it type-checks against our re-derivation's type). -/
theorem necessity_matches_proof_file :
    (∃ r : Run, ¬ ∃ a : DisproveAttempt, RunAttemptCF r a) :=
  Proofs.I6.i6_needs_no_zero_attempt_run

end AdversaryI6PostD
