# Structural encoding — Prolog → Lean translation

The Prolog → Lean translation has two layers that must be applied together. Skipping either degrades Lean to "type-checked Prolog" and forfeits the kernel guarantee.

## Layer 1 — domain values become inductive enums; predicates become inductive `Prop`

Every closed-domain Prolog atom lifts to a constructor of an inductive enum. Every Prolog predicate over closed domains lifts to an inductive `Prop` with one constructor per ground fact. Strings stay strings only when the domain is genuinely open (file paths, free-form identifiers, content the codebase pulls from external systems).

```lean
-- Domain values lifted to enums
inductive ArtifactVariant where
  | lob_bound | sendgrid_attachment | azure_stored
  deriving DecidableEq, Repr

inductive ArtifactContent where
  | shared_invoice_body | address_overlay_zone_empty | audit_footer
  deriving DecidableEq, Repr

-- Predicate as inductive Prop, one constructor per ground fact
inductive ArtifactIncludes : ArtifactVariant → ArtifactContent → Prop where
  | lob_shared      : ArtifactIncludes .lob_bound           .shared_invoice_body
  | lob_address     : ArtifactIncludes .lob_bound           .address_overlay_zone_empty
  | sendgrid_shared : ArtifactIncludes .sendgrid_attachment .shared_invoice_body
  | azure_shared    : ArtifactIncludes .azure_stored        .shared_invoice_body
  | azure_audit     : ArtifactIncludes .azure_stored        .audit_footer
```

Why it works: `cases h` on an inductive predicate over inductive enum indices closes by *kernel-level constructor disjointness*. Lean reduces `.lob_bound ≟ .azure_stored` to "different constructors, contradiction" in one step. With `String` indices the same unification has no kernel rule, so `nomatch` and `rintro` fall back to propositional-equality machinery — and `decide`/`generalize` workarounds become tempting but forbidden (see hard rule below). Lifting closed domains to enums dissolves the dependent-elimination blocker rather than working around it.

This recovers CWA-style reasoning *inside* OWA in a principled way: when a Lean type is a finite inductive enum, Lean *does* know its inhabitants exhaustively by construction. Encoding a closed Prolog domain as an inductive enum is how the closed-world assumption gets typed *into* the Lean encoding rather than informally assumed.

For each counterfactual claim, declare a parallel inductive predicate (e.g., `InterfaceMethodCF4`, `ArtifactIncludesCF1`) that mirrors the target-world predicate plus the counterfactually-removed constructor. The necessity lemma proves the property holds in the CF-extended world by direct constructor citation. Constructor duplication between target-world and CF-augmented twins is acceptable for v1; with 4–5 counterfactuals on a single ticket this proliferates, and parameterization over an "extra facts" set is a future optimization.

## Layer 2 — theorems are stated as quantified invariants, not enumerated conjunctions

When the underlying claim has invariant shape — "every fact (a, b) with predicate P satisfies Q" — state the property as `∀ a b, P a b → Q a b`, not as a conjunction of specific pair facts. The invariant form expresses the underlying spec directly; the enumerated form is a list of test cases dressed up as a theorem.

```lean
-- Validated form (intra-predicate invariant; fp_i03 in 2312-Extra):
@[ontology .descriptive, .absent]
theorem fp_i03 :
    ∀ v : ArtifactVariant, ArtifactIncludes v .audit_footer → v = .azure_stored := by
  intro v h
  cases h <;> rfl
```

The four eliminated cases (`.lob_shared`, `.lob_address`, `.sendgrid_shared`, `.azure_shared`) close by index disagreement on the second argument; the surviving `.azure_audit` case discharges by `rfl`. The proof is two tactics over a five-constructor predicate.

The validated structural shapes (2312-Extra, 2026-05-06):

| Shape | Theorem | Proof |
|---|---|---|
| Empty inductive (vacuous universal) | `∀ n : LobNotice, ¬ ChangedNoticeIn2312 n` | `intro n h; cases h` |
| Cross-predicate disjointness | `∀ k v, SeededValue k v → ¬ IsExternalId v` | `intro k v h hext; cases h <;> cases hext` |
| Intra-predicate invariant | `∀ v, ArtifactIncludes v .audit_footer → v = .azure_stored` | `intro v h; cases h <;> rfl` |

The intra-predicate invariant case is load-bearing — it is the form most often needed for non-trivial structural claims, and it works.

Layer 2 is *enabled by* Layer 1: `cases h` over an invariant requires inductive-predicate hypotheses, which require the inductive-enum encoding. Skip Layer 1 and Layer 2 has no proof path.

## Hard rule — forbidden tactics in target-world context

In any theorem whose hypotheses or goal mention a predicate emitted from `target-world.pl`, the following tactics are **forbidden as the closing move**:

- `decide`
- `native_decide`
- `generalize` (when used to abstract concrete-string indices in order to enable `cases`)

If the proof requires one of these, **halt and report**: the upstream encoding is incorrect — the predicate's domain is being treated as open (strings, lists) when it should be lifted to an inductive enum (Layer 1). The remediation is to escalate back to `model-obligations` for re-encoding, not to find a different tactic. A trivial close on a structurally non-trivial claim is the same kind of debate foul as a fabricated counterexample: the proof exists but does not do the work the claim implies.

Legitimate uses NOT covered by the rule: `decide` on natural-number arithmetic, on a `Decidable` instance proof, on small literal goals with no target-world predicate, or as an internal step (`cases h <;> decide`) where the residual sub-goal is genuinely decidable and not target-world list membership; `generalize` in standard Mathlib idioms where the abstraction is not a workaround for a missing inductive-enum encoding. Bias toward false-positive (over-flag) — a flagged legitimate use is recoverable; a missed forbidden use entrenches the anti-pattern.

The full tactic vocabulary, hard-rule legitimate-use list, post-emit grep self-check, and worked before/after pairs live in `${CLAUDE_SKILL_DIR}/../../agents/lean-expert.md` and `${CLAUDE_SKILL_DIR}/../../agents/references/lean-tactics.md` (the agent the prove-invariants skill spawns). Read those rather than re-deriving the rule.

## Ontology scaffold import

The plugin ships a Lean scaffold at `${CLAUDE_SKILL_DIR}/../../lean/Ontology/Prelude.lean` exposing two enums (`Ontology.Origin`, `Ontology.NegationProvenance`), two tactic macros (`exhaust` = `intro h; cases h`, `witnesses .c1, .c2, …` = `refine ⟨c1, c2, …⟩`), and the `@[ontology X, Y]` marker attribute for machine-extractable origin and provenance metadata. Import it from emitted proof files:

```lean
import Ontology.Prelude
```

The scaffold is purely additive — failing to use it produces the same proof as today; using it produces a more uniform proof. `exhaust` and `witnesses` are the canonical replacements for the forbidden tactics in target-world context. The `@[ontology .X, .Y]` attribute is the structured replacement for the `/- provenance(...) -/` docstring; the docstring form is preserved as a fallback for proofs where the attribute is inconvenient (the value is the same in either form).

Wiring the user's `thoughts/lean/` project to see this import is part of `setup-lean-project`; if a build fails on `import Ontology.Prelude`, fall back to the docstring-only annotation form and surface a setup-needed note.
