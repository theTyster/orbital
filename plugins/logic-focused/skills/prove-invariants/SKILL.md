---
name: prove-invariants
description: >
  Use this skill whenever the user wants to prove a hypothesis in Lean4 — "formalize this", "prove this in lean", "verify formally", "machine-check these properties". Reads thoughts/target-world.pl (the open-world Prolog model emitted by model-obligations), translates each formal property into a Lean4 theorem with a mandatory provenance annotation, and proves it; loops back to decompose-proposition if unprovable.
user-invocable: true
model: sonnet
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[thoughts/target-world.pl path]"
---

# prove-invariants

Logical operation: **prove-invariants** — machine-checked proof of universal properties (∀x.P(x)) against the open-world Prolog model in `thoughts/target-world.pl`.

The **only** input artifact is `thoughts/target-world.pl`. The upstream `model-obligations` skill has already constructed it: existing-world facts ∪ counterfactual negations ∪ prescriptive obligations, with each fact carrying a ontology label. Lean does not read `hypothesis.pl`, `existing-world.pl`, or any other intermediate — `target-world.pl` is the sole carrier across the prolog → lean boundary.

If a property is unprovable, loop back to `decompose-proposition` to refine.

## Boundary: prolog → lean (carrier: `thoughts/target-world.pl`)

This skill sits at the `prolog → lean` boundary. The mediating artifact is `thoughts/target-world.pl`.

- **Gain crossing this boundary**: Universal properties Prolog cannot state. Prolog can only enumerate ground queries under closed-world negation; Lean can express and discharge `∀x. P(x)` directly.
- **Loss crossing this boundary**: CWA negation provenance is stripped. Prolog distinguishes two kinds of falseness — `absent(F)` (F is not declared in the KB; false by closed-world default) and `contradicts(F, G)` (F is excluded because the KB asserts a conflicting fact G). Lean's `¬P` collapses both.

The `provenance` annotation is the **only** mechanism that prevents that loss from being silent. Every theorem in `thoughts/lean/Proofs/*.lean` MUST carry a `provenance` annotation drawn from the domain `[absent, contradicts]`:

- `absent` — "False because the fact is not declared in the KB (CWA default). Fragile — depends on KB completeness; does not hold if KB is incomplete."
- `contradicts` — "False because the KB contains an explicit conflicting fact. Structurally necessary — holds regardless of KB completeness."

The annotation value is **read off the ontology label** attached to the corresponding fact in `target-world.pl`. Do not infer it.

**Enforcement rule** — `cwa_negation_neq_lean_proof`: A fact that is false because absent from the KB is categorically different from a formally disproved fact. Treat dropping or eliding this annotation as a correctness bug, not a style issue.

Reference: `../../references/ontology.md`.

## Encoding shape — structural translation, not list transcription

The Prolog → Lean translation has two layers that must be applied together. Skipping either degrades Lean to "type-checked Prolog" and forfeits the kernel guarantee.

### Layer 1 — domain values become inductive enums; predicates become inductive `Prop`

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

### Layer 2 — theorems are stated as quantified invariants, not enumerated conjunctions

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

### Hard rule — forbidden tactics in target-world context

In any theorem whose hypotheses or goal mention a predicate emitted from `target-world.pl`, the following tactics are **forbidden as the closing move**:

- `decide`
- `native_decide`
- `generalize` (when used to abstract concrete-string indices in order to enable `cases`)

If the proof requires one of these, **halt and report**: the upstream encoding is incorrect — the predicate's domain is being treated as open (strings, lists) when it should be lifted to an inductive enum (Layer 1). The remediation is to escalate back to `model-obligations` for re-encoding, not to find a different tactic. A trivial close on a structurally non-trivial claim is the same kind of debate foul as a fabricated counterexample: the proof exists but does not do the work the claim implies.

Legitimate uses NOT covered by the rule: `decide` on natural-number arithmetic, on a `Decidable` instance proof, on small literal goals with no target-world predicate, or as an internal step (`cases h <;> decide`) where the residual sub-goal is genuinely decidable and not target-world list membership; `generalize` in standard Mathlib idioms where the abstraction is not a workaround for a missing inductive-enum encoding. Bias toward false-positive (over-flag) — a flagged legitimate use is recoverable; a missed forbidden use entrenches the anti-pattern.

The full tactic vocabulary, hard-rule legitimate-use list, post-emit grep self-check, and worked examples live in `${CLAUDE_SKILL_DIR}/../../agents/lean-expert.md` (the agent the briefing in §Delegate below spawns). Read that file rather than re-deriving the rule.

### Ontology scaffold import

The plugin ships a Lean scaffold at `${CLAUDE_SKILL_DIR}/../../lean/Ontology/Prelude.lean` exposing two enums (`Ontology.Origin`, `Ontology.NegationProvenance`), two tactic macros (`exhaust` = `intro h; cases h`, `witnesses .c1, .c2, …` = `refine ⟨c1, c2, …⟩`), and the `@[ontology X, Y]` marker attribute for machine-extractable origin and provenance metadata. Import it from emitted proof files:

```lean
import Ontology.Prelude
```

The scaffold is purely additive — failing to use it produces the same proof as today; using it produces a more uniform proof. `exhaust` and `witnesses` are the canonical replacements for the forbidden tactics in target-world context. The `@[ontology .X, .Y]` attribute is the structured replacement for the `/- provenance(...) -/` docstring; the docstring form is preserved as a fallback for proofs where the attribute is inconvenient (the value is the same in either form).

Wiring the user's `thoughts/lean/` project to see this import is part of `setup-lean-project`; if a build fails on `import Ontology.Prelude`, fall back to the docstring-only annotation form and surface a setup-needed note.

## Cited reference resources

This skill cites three reference resources. They are **not** pipeline predecessors — they are setup utilities and a downstream explainer that the user may run independently:

- `setup-lean-mathlib` — installs the shared Mathlib clone at `~/.lean/mathlib4`.
- `setup-lean-project` — initializes a thin Lean project at `thoughts/lean/` referencing the shared Mathlib clone.
- `explain` — produces plain-language explanations of pipeline output (including this skill's `lean_proof_results.pl`) for non-technical review.

The pipeline predecessor of this skill is `model-obligations` (which produces `target-world.pl`); the pipeline successor is `instantiate-properties`.

## Prerequisites

1. **Lean tools installed**: `lean --version` and `lake --version` must succeed.
2. **`mathlib_clone` env**: Shared Mathlib clone must exist at `~/.lean/mathlib4`:
   ```bash
   MATHLIB_ROOT="$(cd ~/.lean/mathlib4 2>/dev/null && pwd)" || echo "NOT FOUND"
   ```
   If not found, tell the user to run the `setup-lean-mathlib` skill first and stop.
3. **`lean_project_built` env**: Lean project must be built at `thoughts/lean/.lake/build/`:
   ```bash
   LEAN_PROJECT="thoughts/lean"
   LEAN_PROOFS="${LEAN_PROJECT}/Proofs"
   ```
   If `${LEAN_PROJECT}/.lake/build/` does not exist, invoke the `setup-lean-project` skill to create and build it before continuing.
4. **Required input** — `thoughts/target-world.pl` from the `model-obligations` skill: the materialized world (existing facts ∪ counterfactual negations ∪ prescriptive obligations) with per-fact ontology labels. If absent, stop and tell the user to run `model-obligations` first.

## Reading the input

`thoughts/target-world.pl` is the sole input. Load it with `swipl` (or read it directly) and enumerate:

- The ground facts of the world (these are what Lean proves universals over).
- The per-fact ontology labels: `provenance(Fact, descriptive|prescriptive)` for asserted facts, and `negation_provenance(Fact, absent|contradicts)` for counterfactually-removed facts. Domain of the negation tag: `[absent, contradicts]`.
- The formal properties to discharge — enumerate `formal_property/3` facts directly from `target-world.pl` (propagated there verbatim by `model-obligations`). Each `formal_property(Id, NLDescription, LeanSketch)` gives the property identifier, natural-language statement, and a Lean sketch to start from. Claim labels (`descriptive | counterfactual | prescriptive`) and negated-premise provenance are read off the corresponding `cf_fact/N` and `negation_provenance/2` facts in the same file.

The canonical wire format for `target-world.pl` lives in `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/target-world.md` (and `lean-proof-results.md` in the same directory for the output file this skill emits). Use them as the authoritative source when enumerating predicates.

Counterfactual edges have already been excluded by the upstream skill, and prescriptive obligations have already been added — `target-world.pl` is the world to prove against, as-is.

## Proof patterns

The ontology label on each property in `target-world.pl` selects the proof pattern. Read every property's label *before* writing any Lean. Every pattern below uses the structural encoding from "Encoding shape" above — inductive enums for closed domains, inductive `Prop` predicates with one constructor per ground fact, theorems as quantified invariants closed by `cases` / `intro` / `exact` / `refine`.

### Descriptive properties

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

### Counterfactual properties

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

### Prescriptive properties

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

### Genuinely open domains

Strings stay strings only when the domain is genuinely open — file paths, free-form identifiers, content the codebase pulls from external systems. For these, the ground-fact-list encoding remains valid, but theorems closing by `decide` over a `String`-indexed list are still forbidden in target-world context (hard rule above). If a property over a genuinely-open domain has no structural proof path, the property's encoding belongs in `model-obligations` as a `cwa_check` rather than a Lean theorem — escalate, don't `decide`.

## Proof-as-specification frame

The default purpose of a Lean proof in this pipeline is to serve as an **identifiable specification** — a readable formal artifact that other readers and downstream tools (`instantiate-properties`, the test generator, a human revisiting the file a year from now) can interpret directly as the underlying invariant. Concept-validation is sometimes the goal; often it is not. When choosing between two valid proof shapes, prefer the one that reads more like a spec:

- The theorem statement reads as the underlying invariant — a single quantified claim, not an enumerated conjunction of pair facts.
- Constructor names and witness chains describe the domain in named terms (`.lob_shared`, `.notification_pdf_renderer`) rather than positional tuples.
- The tactic chain is short and structural; the proof term itself is small.
- A reader who has never seen the file can recognize what is being asserted from the theorem statement alone, without running Lean.

Concept-validation is the right choice when the underlying claim genuinely requires it — existence/impossibility checks (necessity lemmas with constructor witnesses), induction-heavy reasoning, or any property that does not compress into a structural one-liner. The frame is not "always produce spec-shaped proofs" — it is "default to spec-shape; choose concept-validation only when the underlying claim genuinely requires it." When in doubt, ask: would a non-Lean reader understand what is being asserted from the theorem statement alone?

## Delegate to `lean-expert`

The primary way to execute this skill is to spawn the `logic-focused:lean-expert` sub-agent with the `Agent` tool. That agent is the Lean 4 proof engineer: it treats `lake build` as its reasoning tool rather than chain-of-thought, and applies adversarial verification patterns (interpretation checking, extracted-lemma counterexample search, calibrated abstention). Running Lean proofs through a sub-agent also isolates the noisy compiler output from your main context.

Brief the sub-agent with:
- The `thoughts/target-world.pl` path (the **sole** input — facts, ontology labels, and formal properties)
- The Lean project root (`thoughts/lean`) and proofs directory (`thoughts/lean/Proofs`)
- The shared Mathlib location (`~/.lean/mathlib4`)
- The per-property correction budget (5 inner / 3 outer, see §4)
- An instruction to emit `thoughts/lean_proof_results.pl` as **Prolog facts** (schema in §7) — not markdown
- An instruction that on genuine unprovability it must stop and report the failure mode rather than rewrite the property to make it go through
- The absolute path to the plugin's Mathlib wiki: `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/` — lean-expert reads this directly for lemma/theorem lookups
- A pointer to the skill-local `${CLAUDE_SKILL_DIR}/references/lean-proof-method.md` methodology doc
- An explicit instruction to first read every claim label and per-fact ontology label from `target-world.pl` to decide proof pattern (descriptive vs. counterfactual vs. prescriptive). For counterfactual claims, each property becomes a sufficiency theorem over the target relation (read off `target-world.pl`) plus one necessity lemma per negated-premise fact. The sub-agent must not collapse a counterfactual property into a direct statement over the original relation — that theorem is guaranteed false and erases the constructive content of the hypothesis.
- Mandatory annotation rule: every theorem in `thoughts/lean/Proofs/*.lean` MUST carry a `provenance(absent)` or `provenance(contradicts)` docstring/comment block above the theorem statement. The value is read off the ontology label of the corresponding fact in `target-world.pl`. Annotation domain is exactly `[absent, contradicts]`. Do not omit it — Lean has no way to reconstruct this provenance later, and it is required by `requires_annotation('thoughts/lean/Proofs/*.lean', provenance)`.

Do the work inline only when the user has explicitly asked you to prove it yourself in this turn. Proof size is not a reason — even a one-liner benefits from the specialist's `lake build` discipline and Mathlib familiarity, and inline execution floods the main context with compiler output. When in doubt, delegate. The rest of this file is both your guide for the inline case and the briefing material for the sub-agent.

## Proof Methodology

Read `references/lean-proof-method.md` before writing any proofs. The key principles are summarized here but the reference has full detail with examples.

### One Step at a Time

Write one tactic, check diagnostics (use `done` to see unsolved goals), repeat. Never write multiple tactics before checking. This is the single most important discipline — multi-tactic writes cause cascading errors that waste correction attempts.

- `by sorry` is acceptable for placeholders you're not actively working on.
- `done` is required when you expect there to be next steps in an active proof.

### Error Priority

Fix errors in this exact order — higher-priority errors make lower-priority ones unreliable:

1. **Syntax errors** → 2. **Type errors** → 3. **Unsolved goals / tactic failures** → 4. **Linter warnings**

"Unsolved goals" errors appear on `by` or `=>` lines, NOT where you add tactics. If there's an "unsolved goals" on line 59 but a tactic error on line 65 — fix line 65 FIRST.

Stop writing tactics after any error.

### Work on the Hardest Case First

**Across theorems**: Go directly to the target theorem. Don't fill in `sorry`s in helper lemmas first — Lean treats `sorry` as an axiom, so dependent theorems still work. Move sorries earlier in the file by factoring into lemmas:

```lean
-- Before:
theorem main_theorem : A = C := by sorry

-- After:
theorem lemma1 : A = B := by sorry
theorem lemma2 : B = C := by sorry
theorem main_theorem : A = C := by
  rw [lemma1, lemma2]
```

**Within a proof**: When a proof has multiple cases, `sorry` the easy cases and work on the hardest one first. If the hard case fails, effort on easy cases is wasted.

### Dependent Type Rewriting

When you encounter "motive is not type correct" or similar errors during rewriting, the cause is usually rewriting a term that appears in dependent types. The fix is to generalize first, instantiate last:

```lean
suffices ∀ s, statement_about s by
  have h_specific := the_equality_you_have
  convert this ?_ <;> exact h_specific
intro s
-- Now prove the general statement for arbitrary s
```

## Mathlib Reference

A curated Mathlib wiki ships with this plugin at `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/`. **Don't read it yourself** — wiki content flows through `lean-expert`, which has direct access and returns task-shaped lemma recommendations. Include the absolute wiki path in the briefing when delegating (see above); for inline proofs, spawn `lean-expert` anyway rather than opening the wiki from this context.

This keeps heavy lemma content out of the main context window and preserves the separation between skill orchestration (what this file is) and Mathlib expertise (what the agent provides).

## Process

### 1. Read the Input

Load `thoughts/target-world.pl`. Enumerate:

- Every formal property (natural-language statement, claim label, and per-premise ontology labels).
- The ground facts the property must hold over.
- Each negated premise's provenance value (`absent` or `contradicts`) — sourced from the corresponding fact's ontology label in `target-world.pl`.

Record the proof-pattern selection and the provenance map at the top of each `.lean` file as comments. Treat any negated premise as a *contract* requiring a `provenance(absent|contradicts)` annotation on the theorem that consumes it.

### 2. Translate to Lean4

For each formal property, create a `.lean` file in `${LEAN_PROOFS}/` (i.e. `thoughts/lean/Proofs/`). Use the pattern matching the property's claim label:

- `descriptive` → single theorem over the facts in `target-world.pl`.
- `counterfactual` → sufficiency theorem over the (already-pruned) target relation in `target-world.pl`, plus one necessity lemma per negated-premise fact.
- `prescriptive` → single theorem over the augmented facts (obligation already present in `target-world.pl`).

For every theorem, place either an `@[ontology .X, .Y]` attribute (preferred when `import Ontology.Prelude` resolves) or a `/- provenance(absent | contradicts) -/` docstring block immediately above the theorem statement. The values come from the ontology label and per-fact negation provenance in `target-world.pl`; do not derive them.

A necessity lemma that trivially cannot be closed is a signal: either the fact isn't load-bearing (flag as extraneous and loop back to `decompose-proposition`) or the target-relation encoding is wrong. Don't paper over it with `sorry` — abstain.

If a proof requires `decide` / `native_decide` / `generalize` as the closing move on a target-world predicate, halt and report — the upstream encoding is wrong, not the tactic. The remediation is to escalate back to `model-obligations` for re-encoding (see Layer 1 of "Encoding shape" above and the lean-expert agent's hard-rule paragraph).

**Translation guidelines:**
- **Read `thoughts/target-world-shape.lean` first.** If `model-obligations` emitted it, the inductive enums and inductive `Prop` predicates are already declared — import them rather than re-deriving. If absent and the run has closed-domain predicates, write a note and loop back.
- Map closed domains to `inductive ... where` enums (one constructor per atom); map open domains to `String`.
- Express predicates as `inductive ... → ... → Prop where` with one constructor per ground fact; write theorems as quantified invariants closing by `cases h <;> ...`.
- For prescriptive conjunctions, prefer the scaffold's `witnesses .c1, .c2, ...` macro over hand-rolled `refine ⟨...⟩`.
- For empty-inductive negations, prefer `exhaust` over `intro h; cases h`.
- Graph properties → use Mathlib's `SimpleGraph` or model with `Finset`
- Set properties → use `Finset` or `Set`
- Ordering properties → use `PartialOrder`, `LinearOrder`
- Numeric properties → try `omega` first
- Consult the wiki for appropriate lemmas before inventing custom definitions

### 3. Verify Each Property

Write one tactic at a time, building the proof incrementally:

```bash
cd thoughts/lean && lake build
```

After each build:
- If it succeeds with no errors, add the next tactic
- If it fails, stop and fix the error before writing any more tactics
- Use `done` to check what goals remain

**On success** (no `sorry` remaining): The property is machine-checked. Record `theorem_verdict(Id, proven)`.

**On failure**: Self-correct following error priority order:
1. Fix syntax errors first
2. Fix type errors second
3. Fix tactic failures / unsolved goals last
4. Linter warnings are lowest priority

**Tactic discovery** (in order of preference):
1. Consult the bundled Mathlib wiki (`references/lean4-wiki/`) for a lemma matching your goal shape
2. Use `exact?` to find an exact lemma match
3. Use `apply?` to find applicable lemmas
4. Use `simp?` to discover simplification lemmas
5. Try `omega` for arithmetic goals, `decide` for decidable goals, `norm_num` for numeric goals

### 4. Correction Budget

Each property gets a correction budget to prevent infinite loops:

- **Inner corrections** (fix-and-retry on the same approach): 5 attempts
- **Outer iterations** (fundamentally different approach): 3 attempts
- **Total**: 5 inner × 3 outer = 15 attempts max per property

After exhausting inner corrections, step back and try a fundamentally different proof strategy — different tactic, different lemma, different decomposition.

### 5. Proof Cleanup

After getting a proof to work, clean it up immediately:
- Combine redundant steps (`rw [a]; rw [b]` → `rw [a, b]`)
- Test if `simp` can handle more (remove earlier steps one by one)
- Find the truly minimal proof

### 6. Handle Unprovable Properties

If a property exhausts its correction budget:

**Diagnose the failure mode:**

| Failure type | Meaning | Action |
|-------------|---------|--------|
| Tactic failure | Proof strategy wrong, property may still hold | Try fundamentally different approach |
| Type mismatch | Lean model doesn't match domain | Revise definitions |
| Logical contradiction | Property may be false | **Loop back** |
| Timeout | Property too complex for automation | Decompose into sub-properties |
| Necessity lemma unprovable (counterfactual claim) | The negated fact is not load-bearing — the target property survives re-inclusion | **Loop back** to `decompose-proposition` to prune the negation premises |
| Sufficiency theorem unprovable (counterfactual claim) | The negation premise list is incomplete — the target relation still admits a violation | **Loop back** to `decompose-proposition` with the remaining counterexample; more facts must be named |

**Loop back to decompose-proposition:**

When a property appears genuinely unprovable (logical contradiction or persistent type mismatches after modeling revisions), stop and tell the user to re-run `decompose-proposition`, providing this context:

```
The following property from target-world.pl could not be proven:

Property: {id}
Statement: {formal statement}
Failure: {diagnostics summary}

Possible causes:
- The hypothesis may be too strong
- The property may need additional assumptions
- target-world.pl may be missing relevant facts (or carry the wrong ontology label)

Please re-run decompose-proposition against the source KB to:
1. Check if the property has counterexamples in target-world.pl
2. Identify missing relationships that would make it provable
3. Formulate a revised, weaker hypothesis if needed
```

### 7. Produce Results

Write Prolog facts to `thoughts/lean_proof_results.pl` (create `thoughts/` if it doesn't exist). The file is consumed by downstream skills (`instantiate-properties`, `realize-specification`, and the `explain` reference) as a structured KB — **not** as prose.

Emit against the canonical schema in
`${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/lean-proof-results.md`.
Every theorem must carry a `provenance_annotation/3` fact whose value agrees
with the `negation_provenance/2` tag of the corresponding fact in
`target-world.pl`. A theorem with a negated premise but no matching
`provenance_annotation/3` is malformed.

## Verification

Never declare a proof complete while `sorry` placeholders or error diagnostics remain.

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

- One or more `.lean` files in `${LEAN_PROOFS}/`, each carrying mandatory `provenance(absent|contradicts)` annotations on every theorem (per `requires_annotation('thoughts/lean/Proofs/*.lean', provenance)`).
- A `thoughts/lean_proof_results.pl` Prolog facts file (schema above) — **not** markdown.
- If any properties looped back: a request to re-run `decompose-proposition`.

## Configuration

- **Inner corrections per property**: 5
- **Outer iterations (fresh approach)**: 3
- **Max properties per hypothesis**: no limit
- **Prover model**: opus with xhigh reasoning effort (for `lean-expert` sub-agent).

## Guidance

- **Negation provenance is the only thing carrying CWA semantics across this boundary.** Lean sees `¬P` regardless of whether P originated as `absent(F)` (closed-world default) or `contradicts(F, G)` (KB asserts a conflicting fact). The mandatory `provenance(absent|contradicts)` annotation in each `.lean` file plus the `provenance_annotation/3` facts in `lean_proof_results.pl` are the only mechanisms preserving the distinction. Per the `cwa_negation_neq_lean_proof` rule: a fact that is false because absent from the KB is categorically different from a formally disproved fact — treat dropping the annotation as a correctness bug, not a style issue.
- **`target-world.pl` is the single source of truth for this skill.** Do not reach back to `hypothesis.pl` or `existing-world.pl` — counterfactual edges have already been excluded and prescriptive obligations have already been added by `model-obligations`. Any apparent need to re-read upstream artifacts means the upstream skill failed to materialize the world correctly; loop back rather than patch around it.
