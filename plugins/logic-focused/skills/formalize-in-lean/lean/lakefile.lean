import Lake
open Lake DSL

package formalizeInLean where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib FormalizeInLean where

-- Mathlib require is added dynamically by the skill's prerequisites step,
-- pointing at the shared system-wide clone (~/.lean/mathlib4).
-- Do not add a git require here — use setup-lean-mathlib instead.
