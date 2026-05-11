# Proof patterns — by ontology label

The ontology label on each property in `target-world.pl` selects the proof pattern. Read every property's label *before* writing any Lean. Every pattern below uses the structural encoding from `structural-encoding.md` — inductive enums for closed domains, inductive `Prop` predicates with one constructor per ground fact, theorems as quantified invariants closed by `cases` / `intro` / `exact` / `refine`.

## Descriptive properties

The property is asserted directly about the world. Encode the predicate inductively, then prove the universal claim over its constructors.

```lean
import Ontology.Prelude

set_option autoImplicit false

-- Property: {natural language description}
-- Source: thoughts/target-world.pl

{inductive enum domains and inductive Prop predicates,
 lifted from target-world.pl ground facts}

@[ontology .descriptive, .absent]
theorem {property_name} : ∀ {x …}, P x … → Q x … := by
  intro x … h
  cases h <;> {tactic that discharges the surviving sub-goals}
```

The descriptive class is where Layer 2's spec-shape pays off: the theorem reads as the underlying invariant, not as a list of pair facts.

## Counterfactual properties

The property holds *iff* certain facts are absent. `target-world.pl` already excludes those facts; the target predicate is the one you declare, with one constructor per surviving ground fact.

Each counterfactual property has two proof obligations:

1. **Sufficiency** — prove the property over the inductive predicate that mirrors the target-world world. The validated shape is `intro x …; cases h <;> cases hext` for cross-predicate disjointness, or `intro h; cases h` for a single-predicate empty-inductive negation.
2. **Necessity** — for each negated premise, declare a parallel inductive predicate (`PCF1`, `PCF2`, …) that adds the counterfactually-removed constructor. The necessity lemma proves the property *fails* in the CF-augmented world by direct constructor citation. A necessity lemma whose witness reduces to `False` means the fact was never load-bearing — flag as extraneous and loop back.

A counterfactual property is only proven when sufficiency closes *and* every necessity lemma closes.

```lean
import Ontology.Prelude

set_option autoImplicit false

-- Property: {natural language description}
-- Source: thoughts/target-world.pl

{inductive predicate over the target world}

inductive {P}CF1 : … → … → Prop where
  | … : {P}CF1 …                  -- mirror constructors
  | cf1_witness : {P}CF1 a₀ b₀    -- counterfactually-removed fact, restored
  …

/- provenance(contradicts) -/
@[ontology .counterfactual, .contradicts]
theorem {property_name}_sufficient : ∀ x …, P x … → ¬ Q x … := by
  intro x … h hQ
  cases h <;> cases hQ

/- provenance(contradicts) -/
@[ontology .counterfactual, .contradicts]
theorem {property_name}_needs_cf1 : ∃ x …, {P}CF1 x … ∧ Q x … := by
  exact ⟨a₀, b₀, …, .cf1_witness, …⟩
```

Both the `/- provenance(...) -/` docstring AND the `@[ontology .X, .Y]` attribute are acceptable; the attribute is preferred when emitting fresh proofs because the post-emit scanner reads it without parsing comment syntax. The docstring form remains valid for backward compatibility and as a fallback when the scaffold import is unavailable.

## Prescriptive properties

The property describes an *obligation* that should hold. `target-world.pl` already contains the obligation as a fact; the inductive predicate has a constructor for it.

```lean
import Ontology.Prelude

set_option autoImplicit false

-- Property: {natural language description}
-- Source: thoughts/target-world.pl (includes prescriptive obligation facts)

{inductive predicate including the prescriptive obligation as a constructor}

@[ontology .prescriptive, .absent]
theorem {property_name} : P arg₁ arg₂ ∧ … := by
  witnesses .{constructor₁}, .{constructor₂}, …
```

The `witnesses` macro from the ontology scaffold is the canonical form for prescriptive conjunctions of required facts. For mixed obligations (`witnesses .c1, .c2, ?_, ?_`), the unfilled holes become sub-goals that close with `exhaust` or with explicit constructor witnesses on CF-augmented predicates (the necessity-adjacent-to-prescriptive pattern from the 2312-Extra fp_i03 case).

## Genuinely open domains

Strings stay strings only when the domain is genuinely open — file paths, free-form identifiers, content the codebase pulls from external systems. For these, the ground-fact-list encoding remains valid, but theorems closing by `decide` over a `String`-indexed list are still forbidden in target-world context (hard rule in `structural-encoding.md`). If a property over a genuinely-open domain has no structural proof path, the property's encoding belongs in `model-obligations` as a `cwa_check` rather than a Lean theorem — escalate, don't `decide`.
