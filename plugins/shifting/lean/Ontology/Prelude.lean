import Lean

/-!
# Ontology scaffold prelude

The shared ontology vocabulary for orbital-shifting Lean proofs.

The scaffold is *purely additive*. A theorem that does not import this file,
or that imports it but uses none of its surface, elaborates exactly as it
would have without the scaffold. The four primitives below codify the
canonical idioms produced by the validated 2312-Extra rework; nothing
forces a theorem into a particular shape.

v1 scope is intentionally locked to four primitives:

* `Ontology.Origin` — claim-origin label (`descriptive | counterfactual | prescriptive`).
* `Ontology.NegationProvenance` — negation-provenance label (`absent | contradicts`).
* `exhaust` — case-exhaust tactic for inductive predicates whose negation is closed
  by kernel-level constructor disagreement; the canonical replacement for
  `decide` / `generalize` workarounds in target-world context.
* `witnesses` — comma-separated constructor list for proving a conjunction of
  required facts; the canonical replacement for hand-rolled `refine ⟨...⟩`.
* `@[ontology ...]` — marker attribute carrying machine-extractable origin and
  provenance values. Tooling reads the attribute argument syntax directly; the
  Lean elaborator does not interpret the values.

No `worldFact` macro, no `WorldFact` structure, no `FactBase` typeclass.
The scaffold encodes conventions, not constraints.
-/

namespace Ontology

/-- Ontology label for claim origin. Mirrors `claim_label/2` in `hypothesis.pl`. -/
inductive Origin where
  | descriptive
  | counterfactual
  | prescriptive
  deriving DecidableEq, Repr

/-- Ontology label for negation provenance. Mirrors `claim_negation_provenance/3`
    in `hypothesis.pl` and `negation_provenance/2` in `target-world.pl`. -/
inductive NegationProvenance where
  | absent
  | contradicts
  deriving DecidableEq, Repr

/-- Case-exhaust an inductive-predicate hypothesis whose constructors yield
    kernel-level index disagreement. Canonical proof shape for negations of
    inductive predicates over inductive enum domains.

    Expands to `intro h; cases h`. Use when a goal of the form
    `¬ Foo .a .b → False` (after `intro`) becomes `Foo .a .b → False` and the
    inductive predicate `Foo` has no constructor unifying with the indices —
    `cases h` then closes the goal vacuously.

    Forbidden alternative under the lean-expert hard rule: `decide` /
    `native_decide` over a transcribed list. If `exhaust` does not close the
    goal, the upstream encoding is wrong, not the tactic. -/
macro "exhaust" : tactic => `(tactic| (intro h; cases h))

/-- Provide a comma-separated list of constructor witnesses for a conjunction
    of required facts. Expands to `refine ⟨w₁, w₂, …⟩`.

    Use for prescriptive theorems whose statement is a conjunction of
    inductive-predicate constructions; one constructor per conjunct. Mixed
    `witnesses .a, .b, ?_, ?_` is supported — unfilled witnesses become
    sub-goals. -/
syntax "witnesses " term,+ : tactic
macro_rules
  | `(tactic| witnesses $ws,*) => `(tactic| refine ⟨$ws,*⟩)

end Ontology

/-! ## `@[ontology ...]` marker attribute

    Marker attribute attached to theorems to record the ontology label pair
    (origin, negation provenance). The arguments are written in the
    `.constructor` form for `Ontology.Origin` and `Ontology.NegationProvenance`.

    Example:

    ```lean
    @[ontology .prescriptive, .absent]
    theorem fp_i07 :
        SeededValue .InvoiceNoticePhysicalMail .InternalPhysicalPath ∧
        SeededValue .InvoiceNoticeEmail        .InternalEmailPath := by
      witnesses .physical_internal, .email_internal
    ```

    The Lean elaborator does not interpret the argument list; it accepts and
    discards it. A post-emit scanner reads `@[ontology ...]` attributes from
    `Proofs/*.lean` directly and extracts them into `provenance_annotation/3`
    facts in `lean_proof_results.pl`. -/

open Lean

syntax (name := ontology) "ontology " term,+ : attr

initialize Lean.registerBuiltinAttribute {
  ref             := by exact decl_name%
  name            := `ontology
  descr           := "Ontology label carried by the theorem: origin and negation provenance. Marker only — Lean does not interpret the arguments."
  applicationTime := .afterCompilation
  add             := fun _ _ _ => pure ()
  erase           := fun _ => pure ()
}
