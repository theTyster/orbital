---
name: prove-hypothesis-lean
description: >
  Use this skill whenever the user wants to prove a hypothesis in Lean4 — "formalize this", "prove this in lean", "verify formally", "machine-check these properties". Reads thoughts/target-world.pl (the open-world Prolog model emitted by prove-hypothesis-prolog), translates each formal property into a Lean4 theorem with a mandatory provenance annotation, and proves it; loops back to hypothesize if unprovable.
user-invocable: true
model: opus
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[thoughts/target-world.pl path]"
---

# Formalize in Lean4

Logical operation: **prove_invariants** — machine-checked proof of universal properties (∀x.P(x)) against the open-world Prolog model in `thoughts/target-world.pl`.

The **only** input artifact is `thoughts/target-world.pl`. The upstream `prove-hypothesis-prolog` skill has already constructed it: existing-world facts ∪ counterfactual negations ∪ prescriptive obligations, with each fact carrying a provenance tag. Lean does not read `hypothesis.pl`, `existing-world.pl`, or any other intermediate — `target-world.pl` is the sole carrier across the prolog → lean boundary.

If a property is unprovable, loop back to `hypothesize` to refine.

## Boundary: prolog → lean (carrier: `thoughts/target-world.pl`)

This skill sits at the `prolog → lean` boundary. The mediating artifact is `thoughts/target-world.pl`.

- **Gain crossing this boundary**: Universal properties Prolog cannot state. Prolog can only enumerate ground queries under closed-world negation; Lean can express and discharge `∀x. P(x)` directly.
- **Loss crossing this boundary**: CWA negation provenance is stripped. Prolog distinguishes two kinds of falseness — `absent(F)` (F is not declared in the KB; false by closed-world default) and `contradicts(F, G)` (F is excluded because the KB asserts a conflicting fact G). Lean's `¬P` collapses both.

The `provenance` annotation is the **only** mechanism that prevents that loss from being silent. Every theorem in `thoughts/lean/Proofs/*.lean` MUST carry a `provenance` annotation drawn from the domain `[absent, contradicts]`:

- `absent` — "False because the fact is not declared in the KB (CWA default). Fragile — depends on KB completeness; does not hold if KB is incomplete."
- `contradicts` — "False because the KB contains an explicit conflicting fact. Structurally necessary — holds regardless of KB completeness."

The annotation value is **read off the provenance tag** attached to the corresponding fact in `target-world.pl`. Do not infer it.

**Enforcement rule** — `cwa_negation_neq_lean_proof`: A fact that is false because absent from the KB is categorically different from a formally disproved fact. Treat dropping or eliding this annotation as a correctness bug, not a style issue.

Reference: `../../references/epistemic-types.md`.

## Cited reference resources

This skill cites three reference resources. They are **not** pipeline predecessors — they are setup utilities and a downstream explainer that the user may run independently:

- `setup-lean-mathlib` — installs the shared Mathlib clone at `~/.lean/mathlib4`.
- `setup-lean-project` — initializes a thin Lean project at `thoughts/lean/` referencing the shared Mathlib clone.
- `explain` — produces plain-language explanations of pipeline output (including this skill's `lean_proof_results.pl`) for non-technical review.

The pipeline predecessor of this skill is `prove-hypothesis-prolog` (which produces `target-world.pl`); the pipeline successor is `translate-to-tests`.

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
4. **Required input** — `thoughts/target-world.pl` from the `prove-hypothesis-prolog` skill: the materialized world (existing facts ∪ counterfactual negations ∪ prescriptive obligations) with per-fact provenance tags. If absent, stop and tell the user to run `prove-hypothesis-prolog` first.

## Reading the input

`thoughts/target-world.pl` is the sole input. Load it with `swipl` (or read it directly) and enumerate:

- The ground facts of the world (these are what Lean proves universals over).
- The provenance tag on every fact whose negation participates in any theorem premise (domain: `[absent, contradicts]`).
- The formal properties to discharge (each carries a natural-language statement, an epistemic claim label of `descriptive | counterfactual | prescriptive`, and the list of negated premises with their provenance tags).

Counterfactual edges have already been excluded by the upstream skill, and prescriptive obligations have already been added — `target-world.pl` is the world to prove against, as-is.

## Proof patterns

The claim label on each property in `target-world.pl` selects the proof pattern. Read every property's label *before* writing any Lean.

### Descriptive properties

The property is asserted directly about the world. Prove the theorem as stated against the facts in `target-world.pl`.

```lean
import Mathlib

set_option autoImplicit false

-- Property: {natural language description}
-- Claim label: descriptive
-- Source: thoughts/target-world.pl

{Lean definitions modeling the domain, populated from target-world.pl ground facts}

/-
provenance(absent | contradicts)   -- value read from target-world.pl provenance tag
-/
theorem {property_name} : {formal statement} := by
  sorry -- start with sorry, then prove one tactic at a time
```

### Counterfactual properties

The property holds *iff* certain facts are absent. The upstream Prolog step has already removed those edges from `target-world.pl`, so the target relation here is read off `target-world.pl` directly.

Each counterfactual property has two proof obligations:

1. **Sufficiency** — prove the property over the relation defined by `target-world.pl`'s facts (the world with counterfactual edges removed).
2. **Necessity** — for each negated premise, prove the companion lemma `F → ¬P` (or `F → ¬P_target ∪ {F}`). A necessity lemma that reduces to `False` from hypotheses means the fact was never load-bearing — flag it as extraneous.

A counterfactual property is only proven when sufficiency closes *and* every necessity lemma closes.

```lean
import Mathlib

set_option autoImplicit false

-- Property: {natural language description}
-- Claim label: counterfactual
-- Source: thoughts/target-world.pl
-- Negated premises: see provenance tags in target-world.pl

{domain definitions}

-- Target relation: sourced directly from target-world.pl
-- (counterfactual edges already excluded upstream by prove-hypothesis-prolog)
def depends_on_target (x y : Module) : Prop := ...

/-
provenance(absent)
This theorem's premise `¬ depends_on x y` for the pair {x, y} originates
as Prolog's `\+ depends_on(x, y)` under closed-world absence. The fact is
not declared in target-world.pl. Strength: only as strong as KB completeness.
-/
theorem {property_name}_sufficient : {statement over depends_on_target} := by
  sorry

-- Necessity lemma — one per negated-premise fact for this property
/-
provenance(contradicts)
Premise `¬ depends_on cli_tool logging` is excluded because target-world.pl
asserts a conflicting fact. Structurally necessary — holds regardless of KB
completeness.
-/
theorem {property_name}_needs_{cf_id} :
    cf {cf_args} →
    ¬ {statement over relation reinstating cf_fact} := by
  sorry
```

The `provenance(...)` block is **mandatory** above every theorem. Annotation domain is exactly `[absent, contradicts]`. Read the value off the corresponding fact's provenance tag in `target-world.pl` — do not infer it.

### Prescriptive properties

The property describes an *obligation* that should hold. The upstream Prolog step has already added the obligation as a fact in `target-world.pl`. Prove the theorem against that augmented world.

```lean
-- Property: {natural language description}
-- Claim label: prescriptive
-- Source: thoughts/target-world.pl (includes prescriptive obligation facts)

{domain definitions sourced from target-world.pl, including obligation facts}

/-
provenance(absent | contradicts)   -- value read from target-world.pl provenance tag
-/
theorem {property_name} : {formal statement} := by
  sorry
```

For relations that already come from Mathlib (e.g. `SimpleGraph`, `Finset`-backed relations), prefer the native `\` / `Set.diff` constructions over manual `∧ ¬cf` — the wiki's graph section has idioms for this.

## Delegate to `lean-expert`

The primary way to execute this skill is to spawn the `logic-focused:lean-expert` sub-agent with the `Agent` tool. That agent is the Lean 4 proof engineer: it treats `lake build` as its reasoning tool rather than chain-of-thought, and applies adversarial verification patterns (interpretation checking, extracted-lemma counterexample search, calibrated abstention). Running Lean proofs through a sub-agent also isolates the noisy compiler output from your main context.

Brief the sub-agent with:
- The `thoughts/target-world.pl` path (the **sole** input — facts, provenance tags, and formal properties)
- The Lean project root (`thoughts/lean`) and proofs directory (`thoughts/lean/Proofs`)
- The shared Mathlib location (`~/.lean/mathlib4`)
- The per-property correction budget (5 inner / 3 outer, see §4)
- An instruction to emit `thoughts/lean_proof_results.pl` as **Prolog facts** (schema in §7) — not markdown
- An instruction that on genuine unprovability it must stop and report the failure mode rather than rewrite the property to make it go through
- The absolute path to the plugin's Mathlib wiki: `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/` — lean-expert reads this directly for lemma/theorem lookups
- A pointer to the skill-local `${CLAUDE_SKILL_DIR}/references/lean-proof-method.md` methodology doc
- An explicit instruction to first read every claim label and per-fact provenance tag from `target-world.pl` to decide proof pattern (descriptive vs. counterfactual vs. prescriptive). For counterfactual claims, each property becomes a sufficiency theorem over the target relation (read off `target-world.pl`) plus one necessity lemma per negated-premise fact. The sub-agent must not collapse a counterfactual property into a direct statement over the original relation — that theorem is guaranteed false and erases the constructive content of the hypothesis.
- Mandatory annotation rule: every theorem in `thoughts/lean/Proofs/*.lean` MUST carry a `provenance(absent)` or `provenance(contradicts)` docstring/comment block above the theorem statement. The value is read off the provenance tag of the corresponding fact in `target-world.pl`. Annotation domain is exactly `[absent, contradicts]`. Do not omit it — Lean has no way to reconstruct this provenance later, and it is required by `requires_annotation('thoughts/lean/Proofs/*.lean', provenance)`.

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

- Every formal property (natural-language statement, claim label, and per-premise provenance tags).
- The ground facts the property must hold over.
- Each negated premise's provenance value (`absent` or `contradicts`) — sourced from the corresponding fact's provenance tag in `target-world.pl`.

Record the proof-pattern selection and the provenance map at the top of each `.lean` file as comments. Treat any negated premise as a *contract* requiring a `provenance(absent|contradicts)` annotation on the theorem that consumes it.

### 2. Translate to Lean4

For each formal property, create a `.lean` file in `${LEAN_PROOFS}/` (i.e. `thoughts/lean/Proofs/`). Use the pattern matching the property's claim label:

- `descriptive` → single theorem over the facts in `target-world.pl`.
- `counterfactual` → sufficiency theorem over the (already-pruned) target relation in `target-world.pl`, plus one necessity lemma per negated-premise fact.
- `prescriptive` → single theorem over the augmented facts (obligation already present in `target-world.pl`).

For every theorem, place the `provenance(absent)` or `provenance(contradicts)` block immediately above the theorem statement. The value comes from the provenance tag in `target-world.pl`; do not derive it.

A necessity lemma that trivially cannot be closed is a signal: either the fact isn't load-bearing (flag as extraneous and loop back to `hypothesize`) or the target-relation encoding is wrong. Don't paper over it with `sorry` — abstain.

**Translation guidelines:**
- Map domain types to Lean types (use Mathlib where feasible)
- Express relationships as propositions, populated from `target-world.pl` ground facts
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
| Necessity lemma unprovable (counterfactual claim) | The negated fact is not load-bearing — the target property survives re-inclusion | **Loop back** to `hypothesize` to prune the negation premises |
| Sufficiency theorem unprovable (counterfactual claim) | The negation premise list is incomplete — the target relation still admits a violation | **Loop back** to `hypothesize` with the remaining counterexample; more facts must be named |

**Loop back to hypothesize:**

When a property appears genuinely unprovable (logical contradiction or persistent type mismatches after modeling revisions), stop and tell the user to re-run `hypothesize`, providing this context:

```
The following property from target-world.pl could not be proven:

Property: {id}
Statement: {formal statement}
Failure: {diagnostics summary}

Possible causes:
- The hypothesis may be too strong
- The property may need additional assumptions
- target-world.pl may be missing relevant facts (or carry the wrong provenance tag)

Please re-run hypothesize against the source KB to:
1. Check if the property has counterexamples in target-world.pl
2. Identify missing relationships that would make it provable
3. Formulate a revised, weaker hypothesis if needed
```

### 7. Produce Results

Write Prolog facts to `thoughts/lean_proof_results.pl` (create `thoughts/` if it doesn't exist). The file is consumed by downstream skills (`translate-to-tests`, `realize-specification`, and the `explain` reference) as a structured KB — **not** as prose.

Per the target-state contract:
> "Per-theorem verdict: `theorem_verdict(TheoremId, proven|unprovable)` with proof strategy, failure modes, and mandatory provenance annotation (`absent|contradicts`)."

**Schema:**

```prolog
% thoughts/lean_proof_results.pl
% Output of prove-hypothesis-lean over thoughts/target-world.pl

% Per-theorem verdict (mandatory, one per formal property in target-world.pl)
theorem_verdict(TheoremId, proven).
theorem_verdict(TheoremId, unprovable).

% Proof strategy summary (one per proven theorem)
proof_strategy(TheoremId, "brief description, e.g. 'induction on list, simp with List.append_nil'").

% Failure mode (one per unprovable theorem; values: tactic | type_mismatch | contradiction | timeout | insufficient_negations | extraneous_negation)
failure_mode(TheoremId, FailureMode).

% Provenance annotation surfaced from the .lean source.
% MANDATORY — one fact per theorem (and per negated premise on counterfactual theorems).
% Annotation domain is exactly [absent, contradicts]; the value must agree with
% the provenance tag of the corresponding fact in target-world.pl.
provenance_annotation(TheoremId, FactId, absent).
provenance_annotation(TheoremId, FactId, contradicts).

% Lean source location for each theorem
theorem_source(TheoremId, "thoughts/lean/Proofs/{File}.lean").

% For counterfactual claims: status of each necessity lemma
necessity_lemma_status(TheoremId, FactId, proven).
necessity_lemma_status(TheoremId, FactId, extraneous).   % reduced to False — loop back to hypothesize
necessity_lemma_status(TheoremId, FactId, unprovable).   % strategy failed — distinct from extraneous

% Optional: aggregate run summary
run_summary(properties_attempted, N).
run_summary(proven, M).
run_summary(unprovable, K).
```

`provenance_annotation/3` is the structured echo of the docstring above each theorem. It must agree with the provenance tag of the corresponding fact in `target-world.pl`. If a theorem has a negated premise but no `provenance_annotation/3` fact, the run is malformed.

## Verification

Never declare a proof complete while `sorry` placeholders or error diagnostics remain.

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

- One or more `.lean` files in `${LEAN_PROOFS}/`, each carrying mandatory `provenance(absent|contradicts)` annotations on every theorem (per `requires_annotation('thoughts/lean/Proofs/*.lean', provenance)`).
- A `thoughts/lean_proof_results.pl` Prolog facts file (schema above) — **not** markdown.
- If any properties looped back: a request to re-run `hypothesize`.

## Configuration

- **Inner corrections per property**: 5
- **Outer iterations (fresh approach)**: 3
- **Max properties per hypothesis**: no limit
- **Prover model**: opus (for sub-agents)

## Guidance

- **Negation provenance is the only thing carrying CWA semantics across this boundary.** Lean sees `¬P` regardless of whether P originated as `absent(F)` (closed-world default) or `contradicts(F, G)` (KB asserts a conflicting fact). The mandatory `provenance(absent|contradicts)` annotation in each `.lean` file plus the `provenance_annotation/3` facts in `lean_proof_results.pl` are the only mechanisms preserving the distinction. Per the `cwa_negation_neq_lean_proof` rule: a fact that is false because absent from the KB is categorically different from a formally disproved fact — treat dropping the annotation as a correctness bug, not a style issue.
- **`target-world.pl` is the single source of truth for this skill.** Do not reach back to `hypothesis.pl` or `existing-world.pl` — counterfactual edges have already been excluded and prescriptive obligations have already been added by `prove-hypothesis-prolog`. Any apparent need to re-read upstream artifacts means the upstream skill failed to materialize the world correctly; loop back rather than patch around it.
