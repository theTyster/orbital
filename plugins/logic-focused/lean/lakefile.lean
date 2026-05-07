import Lake
open Lake DSL

package Ontology where
  leanOptions := #[
    ⟨`autoImplicit, false⟩
  ]

@[default_target]
lean_lib Ontology where
  -- The library exposes `Ontology.Prelude`. Files live in `Ontology/`.

@[default_target]
lean_lib OntologySmoke where
  -- A tiny in-tree smoke test that imports `Ontology.Prelude` and exercises
  -- `Origin`, `NegationProvenance`, `exhaust`, `witnesses`, and `@[ontology …]`.
  -- Files live in `OntologySmoke/`.
