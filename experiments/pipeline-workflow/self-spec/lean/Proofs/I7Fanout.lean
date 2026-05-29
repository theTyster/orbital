import Proofs.TargetWorld

/-!
# I-7 cardinality floor — every disprove attempt fans out to ≥2 parallel adversaries

Property: `p_v1_i7` (prescriptive obligation `pr_v1_i7_fanout`).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i7,
    "I-7 cardinality floor: every disprove attempt spawns at least two
     adversaries, run in parallel.",
    "... 2 <= (adversaries a).length /\\ Parallel (adversaries a) ...").

Substrate: `op_adversary(a0, adv1)`, `op_adversary(a0, adv2)`,
`op_adversaries_parallel(a0)`, `disprove_floor(adversaries_per_attempt, 2)`.

Structural reading of `2 <= length /\ Parallel`: over the closed domains,
"at least two adversaries" is the existence of two *distinct* adversaries
fanned out from the attempt, conjoined with the parallel-run fact. The canonical
attempt `a0` fans out to `adv1` and `adv2` (distinct by enum-constructor
disjointness) and runs them in parallel.

Ontology: prescriptive obligation, no negated premise → `.absent`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I7

open TargetWorld

@[ontology .prescriptive, .absent]
theorem i7_disprove_fans_out :
    ∀ a : DisproveAttempt,
      (∃ x y : Adversary, AttemptAdversary a x ∧ AttemptAdversary a y ∧ x ≠ y)
      ∧ AdversariesParallel a := by
  intro a
  cases a
  refine ⟨⟨.adv1, .adv2, .a0_adv1, .a0_adv2, ?_⟩, .a0⟩
  intro h
  cases h

end Proofs.I7
