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

This skill sits at the `prolog → lean` boundary. The boundary gains universal quantification (Lean can state and discharge `∀x. P(x)` directly) and loses CWA negation provenance (Lean's `¬P` collapses Prolog's `absent` / `contradicts` distinction).

The `provenance` annotation is the **only** mechanism that prevents that loss from being silent. Every theorem in `thoughts/lean/Proofs/*.lean` MUST carry a `provenance(absent | contradicts)` annotation, value read off the corresponding fact's ontology label in `target-world.pl` — do not infer it. Enforcement rule: `cwa_negation_neq_lean_proof` — treat dropping the annotation as a correctness bug, not a style issue.

Full semantics of the two annotation values, the boundary's gain/loss table, and the cross-skill ontology label propagation rules live in **`../../references/ontology.md`**.

## Encoding shape — structural translation, not list transcription

The Prolog → Lean translation has two layers, applied together: domain values become inductive enums, predicates become inductive `Prop`s with one constructor per ground fact (Layer 1); theorems are stated as quantified invariants closed by `cases h <;> ...`, not enumerated conjunctions (Layer 2). Skipping either degrades Lean to "type-checked Prolog" and forfeits the kernel guarantee.

The validated structural shapes (2312-Extra, 2026-05-06):

| Shape | Theorem | Proof |
|---|---|---|
| Empty inductive (vacuous universal) | `∀ n : LobNotice, ¬ ChangedNoticeIn2312 n` | `intro n h; cases h` |
| Cross-predicate disjointness | `∀ k v, SeededValue k v → ¬ IsExternalId v` | `intro k v h hext; cases h <;> cases hext` |
| Intra-predicate invariant | `∀ v, ArtifactIncludes v .audit_footer → v = .azure_stored` | `intro v h; cases h <;> rfl` |

In any theorem whose hypotheses or goal mention a target-world predicate, `decide` / `native_decide` / `generalize` are **forbidden as the closing move** — halt and report rather than route around the encoding. Imports rely on the plugin's scaffold (`import Ontology.Prelude`) for the `exhaust` / `witnesses` macros and the `@[ontology .X, .Y]` marker attribute.

Full Layer 1 / Layer 2 derivation, the hard rule's legitimate-use carve-outs, and the ontology scaffold details live in **`references/structural-encoding.md`**. The lean-expert agent (`agents/lean-expert.md` and `agents/references/lean-tactics.md`) carries the worked before/after pairs and post-emit grep self-check; do not re-derive them here.

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

## Pre-flight: version hygiene check

Before reading `target-world.pl` or `hypothesis.pl` in earnest, run the
version-hygiene diagnostic to catch stale cache from a prior pipeline pass.
The check is a Prolog module under `${CLAUDE_SKILL_DIR}/../../prolog/version_hygiene.pl`:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "use_module('${PROLOG}/version_hygiene'),
          (check_hygiene -> halt(0) ; halt(1))" -t halt
```

It detects three drift signals:

- **theorem_id_drift** — `lean_proof_results.pl` carries a
  `theorem_verdict/2` whose property id is absent from the current
  `hypothesis.pl`'s `formal_property/3` set.
- **fact_id_drift** — `lean_proof_results.pl` carries a
  `provenance_annotation/3` whose (Fact, Mode) pair is absent from the
  current `claim_negation_provenance/3` records in `hypothesis.pl`.
- **timestamp_inversion** — `lean_proof_results.pl` is older than
  `hypothesis.pl` (a refined hypothesis without a fresh proof run).

On clean: prints `hygiene_clean.` and exits 0; this skill proceeds.
On warning: prints `[hygiene_warning]` lines to stderr and exits nonzero.
**Halt and tell the user to re-run from `model-obligations`** — building on
top of stale `lean_proof_results.pl` silently leaks v1 evidence into a v2
run, which is exactly the failure mode the diagnostic exists to catch.

The check is also re-runnable standalone for forensic review of an old
ticket's `thoughts/` directory; the same one-liner above works from any
working directory whose `thoughts/` subtree carries the relevant artifacts.

## Reading the input

`thoughts/target-world.pl` is the sole input. Load it with `swipl` (or read it directly) and enumerate:

- The ground facts of the world (these are what Lean proves universals over).
- The per-fact ontology labels: `provenance(Fact, descriptive|prescriptive)` for asserted facts, and `negation_provenance(Fact, absent|contradicts)` for counterfactually-removed facts. Domain of the negation tag: `[absent, contradicts]`.
- The formal properties to discharge — enumerate `formal_property/3` facts directly from `target-world.pl` (propagated there verbatim by `model-obligations`). Each `formal_property(Id, NLDescription, LeanSketch)` gives the property identifier, natural-language statement, and a Lean sketch to start from. Claim labels (`descriptive | counterfactual | prescriptive`) and negated-premise provenance are read off the corresponding `cf_fact/N` and `negation_provenance/2` facts in the same file.

The canonical wire format for `target-world.pl` lives in `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/target-world.md` (and `lean-proof-results.md` in the same directory for the output file this skill emits). Use them as the authoritative source when enumerating predicates.

Counterfactual edges have already been excluded by the upstream skill, and prescriptive obligations have already been added — `target-world.pl` is the world to prove against, as-is.

## Gating — route each property by ontology label

Not every property earns a Lean proof. Route each `formal_property/3` by its ontology label and negation provenance:

| Ontology label | Provenance | Action |
|---|---|---|
| `counterfactual` | `contradicts` | **Run Lean.** Necessity lemma proves the CF is load-bearing. |
| `counterfactual` | `absent` | **Skip Lean.** Emit a `cwa_check` artifact in `lean_proof_results.pl`. |
| `prescriptive` | (any) | **Run Lean iff structurally rich** — induction, quantification over an open domain, cross-predicate reasoning. Skip if the property reduces to literal-list membership over an inductive enum. |
| `descriptive` | (any) | **Skip Lean.** Descriptive claims are KB readouts; the Prolog model already entails them. |

Bias toward false-run during initial rollout — false-skip means losing a real proof; false-run means burning build time on a tautology. The hard rule on forbidden tactics is the recoverable signal in the other direction: a property that can *only* close via `decide` halts the run rather than gating through.

For each property gated out of Lean, emit `cwa_check(PropId, AbsentFactId, verified | violated)` plus `lean_skipped(PropId, Reason)` in `lean_proof_results.pl`. The `provenance_annotation/3` chain is still required so `instantiate-properties` keeps the ontology label intact.

Full table commentary, the `cwa_check` worked example, the `swipl` absence-check command, and the `lean_skipped` reason taxonomy live in **`references/gating.md`**.

## Proof patterns

The ontology label on each property in `target-world.pl` selects the proof pattern; read every property's label *before* writing any Lean. Three patterns + one fallback:

- **Descriptive** → single theorem, `∀ x … P x → Q x` closed by `cases h <;> tactic`.
- **Counterfactual** → sufficiency theorem over the (already-pruned) target predicate, plus one necessity lemma per negated-premise fact citing the parallel CF-augmented predicate.
- **Prescriptive** → conjunction of constructor witnesses via `witnesses .c1, .c2, …`.
- **Genuinely open domains** (file paths, free-form identifiers) → ground-fact-list encoding remains valid, but `decide` over a `String`-indexed list is still forbidden; if no structural proof path exists, escalate the property to `model-obligations` as a `cwa_check`.

Full templates per pattern (file headers, inductive-predicate scaffolding, sufficiency / necessity decomposition, ontology-attribute placement) live in **`references/proof-patterns.md`**.

The proof-as-specification frame — defaulting to spec-shaped proofs over concept-validation when both are valid, with constructor names that read as the domain — lives in **`agents/lean-expert.md`** (the canonical home; this skill points there rather than duplicating).

## Delegate to `lean-expert`

The primary execution path is to spawn the `logic-focused:lean-expert` sub-agent with the `Agent` tool. That agent treats `lake build` as its reasoning tool and applies adversarial verification patterns; running proofs through it also isolates compiler output from the main context.

Brief the sub-agent with:

- `thoughts/target-world.pl` (sole input — facts, ontology labels, formal properties)
- Lean project root (`thoughts/lean`), proofs directory (`thoughts/lean/Proofs`), Mathlib (`~/.lean/mathlib4`)
- Mathlib wiki path: `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/`
- Methodology pointer: `${CLAUDE_SKILL_DIR}/references/lean-proof-method.md`
- Per-property correction budget: 5 inner / 3 outer (§4)
- Output contract: `thoughts/lean_proof_results.pl` as Prolog facts (schema in §7), not markdown
- Pattern-selection contract: read every claim label and per-fact ontology label from `target-world.pl` first; counterfactual properties become sufficiency theorem + one necessity lemma per negated-premise fact (do not collapse them)
- Mandatory annotation: every theorem carries a `provenance(absent | contradicts)` docstring or `@[ontology .X, .Y]` attribute, value read off `target-world.pl` (`requires_annotation` enforced)
- Halt-and-report contract on genuine unprovability rather than rewriting the property

Do the work inline only when the user has explicitly asked. Proof size is not a reason to skip the specialist — even a one-liner benefits from the agent's `lake build` discipline and Mathlib familiarity. The rest of this file is both your inline guide and the briefing material for the sub-agent.

## Proof Methodology

Read **`references/lean-proof-method.md`** before writing any proofs. The methodology covers: one tactic at a time + `done` checkpoints, error-priority order (syntax → type → unsolved goals → linter), hardest-case-first across theorems and within a single proof, and the dependent-type rewriting / `suffices` idiom for "motive is not type correct" errors. The reference has full detail with examples; do not re-derive the principles from this file.

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

**First, gate.** Apply the routing in `references/gating.md` to every formal property. Properties routed to `cwa_check` skip Lean translation entirely; record `cwa_check/3` and `lean_skipped/2` for the skipped set when emitting `lean_proof_results.pl` in step 7. Only properties routed to "Run Lean" continue.

For each property routed to Lean, create a `.lean` file in `${LEAN_PROOFS}/` and use the pattern from `references/proof-patterns.md` matching the property's claim label. Read `thoughts/target-world-shape.lean` first — if `model-obligations` emitted it, the inductive enums and inductive `Prop` predicates are already declared; import them rather than re-deriving. If absent and the run has closed-domain predicates, loop back.

Every theorem carries either an `@[ontology .X, .Y]` attribute (preferred) or a `/- provenance(absent | contradicts) -/` docstring block. Values come from the ontology label and per-fact negation provenance in `target-world.pl` — do not derive them.

A necessity lemma that cannot be closed is a signal — flag the fact as extraneous and loop back to `decompose-proposition` rather than papering with `sorry`. If a proof requires `decide` / `native_decide` / `generalize` as the closing move on a target-world predicate, halt and report; the upstream encoding is wrong, not the tactic.

### 3. Verify Each Property

Write one tactic at a time, running `cd thoughts/lean && lake build` between writes; stop on the first error and fix it before adding more tactics. On success with no `sorry` remaining, record `theorem_verdict(Id, proven)`. On failure, follow the error-priority order and tactic-discovery sequence in `references/lean-proof-method.md`.

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

If a property exhausts its correction budget, diagnose the failure mode:

| Failure type | Action |
|---|---|
| Tactic failure | Try fundamentally different approach |
| Type mismatch | Revise definitions |
| Logical contradiction | **Loop back** to `decompose-proposition` |
| Timeout | Decompose into sub-properties |
| Necessity lemma unprovable (counterfactual) | **Loop back** — the negated fact is not load-bearing; prune the premise |
| Sufficiency theorem unprovable (counterfactual) | **Loop back** — the negation premise list is incomplete; more facts must be named |

When loopback is the action, stop and tell the user to re-run `decompose-proposition`, citing the property id, the formal statement, the diagnostic, and the possible-causes shortlist (hypothesis too strong; missing assumptions; `target-world.pl` carries the wrong ontology label or lacks relevant facts).

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

- **`target-world.pl` is the single source of truth for this skill.** Do not reach back to `hypothesis.pl` or `existing-world.pl` — `model-obligations` has already excluded counterfactual edges and added prescriptive obligations. Any apparent need to re-read upstream artifacts means the upstream skill failed to materialize the world correctly; loop back rather than patch around it.
- **Provenance annotations are non-optional** — see the boundary section above and `references/ontology.md` for the full enforcement rule.
