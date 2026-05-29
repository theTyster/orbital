import Lake
open Lake DSL

package Proofs where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib Proofs where

require mathlib from "/Users/ty/.lean/mathlib4"
require Ontology from "/Users/ty/Projects/mine/orbital/plugins/shifting/lean"
