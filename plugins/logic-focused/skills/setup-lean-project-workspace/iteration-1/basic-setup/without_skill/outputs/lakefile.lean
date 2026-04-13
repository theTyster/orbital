import Lake
open Lake DSL

require mathlib from "/Users/ty/.lean/mathlib4"

package «leanProofs» where
  leanOptions := #[⟨`autoImplicit, false⟩]

@[default_target]
lean_lib LeanProofs
