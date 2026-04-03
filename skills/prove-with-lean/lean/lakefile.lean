import Lake
open Lake DSL

package proveWithLean where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib ProveWithLean where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4"
