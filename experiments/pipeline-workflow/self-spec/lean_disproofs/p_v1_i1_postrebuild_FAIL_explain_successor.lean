import Proofs.TargetWorld

/-! SHOULD-FAIL probe (survival signal for TERMINAL locus b): try to give
    `explain` a successor, i.e. inhabit `∃ s, StageOrder .explain s`. This is the
    direct negation of the terminal half `∀ s, ¬ StageOrder .explain s`. The
    7-edge `StageOrder` has NO constructor whose first argument is `.explain`
    (explain is the sink: the only edge touching it is the IN-edge
    `measure_entailment → explain`). So no witness `s` exists. This file MUST
    fail to compile; the failure proves the terminal half is structural, not an
    empty-relation artifact.

    We try the most natural surface successor (`close_world`, the chain head)
    by every constructor — none has `.explain` as its first index. -/

set_option autoImplicit false
namespace FAIL_explain_successor
open TargetWorld

-- Attempt 1: a direct existential successor.
theorem explain_has_a_successor : ∃ s : Stage, StageOrder .explain s := by
  refine ⟨.close_world, ?_⟩
  exact .s1_s2   -- s1_s2 : StageOrder .close_world .decompose_proposition, not .explain _

end FAIL_explain_successor
