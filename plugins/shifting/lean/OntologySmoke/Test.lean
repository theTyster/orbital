import Ontology.Prelude

set_option autoImplicit false

namespace OntologySmoke

/-! Smoke test for the ontology scaffold. Exercises every primitive in the v1 surface. -/

-- Two enums are usable as values.
example : Ontology.Origin := .descriptive
example : Ontology.Origin := .counterfactual
example : Ontology.Origin := .prescriptive
example : Ontology.NegationProvenance := .absent
example : Ontology.NegationProvenance := .contradicts

-- A miniature target-world domain to test `exhaust` and `witnesses` against.
inductive Color where
  | red | green | blue
  deriving DecidableEq, Repr

inductive Tone where
  | warm | cool
  deriving DecidableEq, Repr

inductive Pairing : Color → Tone → Prop where
  | red_warm   : Pairing .red   .warm
  | green_cool : Pairing .green .cool
  | blue_cool  : Pairing .blue  .cool

-- `exhaust` closes a vacuous-universal claim by case analysis on an inductive
-- predicate whose indices disagree on every constructor.
@[ontology .descriptive, .absent]
theorem no_red_cool : ¬ Pairing .red .cool := by
  exhaust

-- `witnesses` builds a conjunction-of-constructors proof. Mirrors the
-- prescriptive idiom from the 2312-Extra rework.
@[ontology .prescriptive, .absent]
theorem two_facts : Pairing .red .warm ∧ Pairing .green .cool := by
  witnesses .red_warm, .green_cool

-- Spec-shaped, intra-predicate invariant — the load-bearing case from
-- ticket-structural-prolog-lean-translation.md fp_i03. Closes by
-- `cases h <;> rfl`: the `red_warm` constructor is eliminated by index
-- disagreement on the second argument, and the surviving cases discharge by
-- reflexivity.
@[ontology .descriptive, .absent]
theorem warm_must_be_red :
    ∀ c, Pairing c .warm → c = .red := by
  intro c h
  cases h <;> rfl

end OntologySmoke
