import Proofs.TargetWorld
import Proofs.I6Floor

/-!
# I-6 POST-REBUILD probe C — the OLD "proof IS the lone ground fact" cert now FAILS.

OLD attack 4/5 (`p_v1_i6.lean`) certified the proof carried zero discriminating
content by exhibiting it as definitionally a `casesOn` of ONE hard-wired fact:
  `theorem i6_is_definitionally_the_ground_fact :
     i6_disprove_runs = (fun r => Run.casesOn r ⟨.a0, .r0_a0⟩) := rfl`
and
  `theorem the_floor_clause_is_inert :
     (i6_disprove_runs .r0) = ⟨DisproveAttempt.a0, RunAttempt.r0_a0⟩ := rfl`

Over the FROZEN model the proof is now `fun r => Run.casesOn r ⟨.a0, .r0_a0⟩
⟨.a1, .r1_a1⟩` — a TWO-arm case analysis that picks a DISTINCT witness per run
(r0 ↦ a0, r1 ↦ a1). The old single-arm `casesOn` shape is no longer the proof term.

We test the strongest form of the old cert: that the whole function equals the
ONE-arm-collapsed `fun _ => ⟨.a0, .r0_a0⟩` (a single constant witness for ALL runs).
If that held, the floor would be the old constant fiat. It must FAIL, because for
`r1` the proof returns `⟨.a1, .r1_a1⟩`, and `RunAttempt .r1 .a0` is uninhabited.

EXPECT: COMPILE FAILURE — the floor now discriminates per-run; it is not a constant.
-/

set_option autoImplicit false

namespace AdversaryI6PostC

open TargetWorld Proofs.I6

-- The old "constant lone-fact" reading: one witness ⟨.a0, .r0_a0⟩ serves EVERY run.
-- Over the rebuilt model this is ill-typed for r1 (RunAttempt .r1 .a0 has no ctor),
-- and even the proof term differs. This rfl must NOT close.
theorem i6_is_a_constant_ground_fact :
    i6_disprove_runs = (fun _ : Run => (⟨.a0, RunAttempt.r0_a0⟩ : ∃ a, RunAttempt _ a)) := rfl

end AdversaryI6PostC
