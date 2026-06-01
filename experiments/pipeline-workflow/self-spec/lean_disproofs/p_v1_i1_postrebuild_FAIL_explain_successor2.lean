import Proofs.TargetWorld

/-! SHOULD-FAIL probe (survival signal, exhaustive form of locus b): rather than
    hand-pick a constructor, let Lean search for ANY successor edge out of
    `explain` via `constructor` (tries every StageOrder constructor in turn).
    If even one constructor had `.explain` as its first index, this would close.
    None does, so `constructor` must fail. This file MUST fail to compile. -/

set_option autoImplicit false
namespace FAIL_explain_successor2
open TargetWorld

theorem explain_has_a_successor2 : ∃ s : Stage, StageOrder .explain s := by
  refine ⟨?_, ?_⟩
  · exact .close_world
  · constructor   -- no StageOrder constructor has `.explain` as its source

end FAIL_explain_successor2
