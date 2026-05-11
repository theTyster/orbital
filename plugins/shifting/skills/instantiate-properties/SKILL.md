---
name: instantiate-properties
description: >
  Stage 5 of the 7-stage pipeline. Reads `thoughts/lean/Proofs/*.lean` (primary) and `thoughts/lean_proof_results.pl` (required); optionally consumes `thoughts/hypothesis.pl`, `thoughts/model_results.pl`, `thoughts/target-world.pl`. Instantiates each universal Lean property as a `projection` test at a specific fixture, or emits a `behavioral_claim` test for an I/O / state / concurrency / timing claim that no upstream proof expressed. Universality is intentionally discarded at the lean → tdd boundary — this is a design choice, not a leak. Every test is tagged with exactly one of `projection` or `behavioral_claim`. All tests start skipped.
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Agent, Bash
argument-hint: "[optional: target codebase directory; without it, pseudotest format is used]"
---

# instantiate-properties

**Logical operation: `instantiate-properties`.** Instantiate: `∀x.P(x) → P(specific_fixture)`. Universality is **intentionally discarded** at the TDD boundary — this is not a loss of rigor but a deliberate sampling of one point from each proof domain, with the loss accounted for explicitly (see `unsampled_domain` in every projection test and the COVERAGE GAPS block).

Turn each universal Lean property into a `projection` test that samples the proof at a specific fixture, or emit a `behavioral_claim` test for an I/O / state / concurrency / timing claim that no upstream proof ever expressed. The implementor runs the suite, watches it fail, and drives their code toward green. No separate plan document is produced — the test file is the deliverable.

**Pipeline position:** Stage 5 of 7. Consumes `thoughts/lean/Proofs/*.lean` (primary input), `thoughts/lean_proof_results.pl` (required), and optionally `thoughts/hypothesis.pl`, `thoughts/model_results.pl`, `thoughts/target-world.pl` — all of these are **Prolog facts files, not markdown**. Produces `thoughts/tests/{file}`. Downstream: `realize-specification` un-skips one test at a time.

**Boundary semantics: `lean → tdd`** (carrier: `thoughts/lean_proof_results.pl`).

- **Gain crossing this boundary**: behavioral claims Lean cannot express — I/O, side effects, state mutation, concurrency, timing. The TDD layer is the only place these are asserted, and they enter as `test_category(behavioral_claim)`.
- **Loss crossing this boundary**: modality is discarded — universality is lost. A Lean proof of `∀x.P(x)` becomes `P(specific_fixture)` in the test suite. A green `projection` test is a *witness* of the universally-proved property at one fixture, NOT a re-proof. The suite is a tripwire; the proof remains the authority on universality.

**MANDATORY: every emitted test carries exactly one `test_category` tag — `projection` or `behavioral_claim`.** Enforcement rule `behavioral_claim_neq_proven_property`: a red `projection` test means the implementation broke a proven invariant; a red `behavioral_claim` test means a never-proven contract was violated. The two must be visibly separated in the suite (Phase B at the bottom) and in the report.

Quick rule for assignment: if the test descends from a Lean theorem, a `formal_property/3` in `lean_proof_results.pl`/`model_results.pl`, or a verified `model_results.pl` fact → `projection`. If it asserts I/O, state, concurrency, timing, HTTP status, logging, or any other runtime-observable behaviour Lean cannot state → `behavioral_claim`.

Each test also carries diagnostic tags (`ontology_label`, `negation_provenance`, `proof_strategy`, `proof_mode`, `sampled_from`, `fixture_set`, `unsampled_domain`) inherited from the source claim where applicable. **For the full taxonomy, decision tree, and canonical tag→source-predicate table, consult `references/tagging.md`.** That file is the contract; this section is the summary.

## Input

Structured artifacts are **Prolog facts files** (`.pl`) — query them via `Agent(subagent_type="shifting:agent-of-questions")` or `swipl -g` for one-off spot checks. Never grep or Read the `.pl` files. The Lean source files are the exception: read them directly.

- **Primary**: `thoughts/lean/Proofs/*.lean` — Lean theorem source.
- **Required**: `thoughts/lean_proof_results.pl` (from `prove-invariants`) — `theorem_verdict/2`, `proof_strategy/2`, `failure_mode/2`, `theorem_source/2`, `necessity_lemma_status/3`, `provenance_annotation/3` (mandatory for negated-premise theorems), and optional `cwa_check/3` + `lean_skipped/2` for gated-out properties. Treat `cwa_check(Prop, _, verified)` like `theorem_verdict(Prop, proven)`, with `proof_strategy: prolog-cwa-check` in the test comment.
- **Optional**: `thoughts/hypothesis.pl`, `thoughts/model_results.pl`, `thoughts/target-world.pl`, any other `.pl` in `thoughts/`. Wire format for each lives under `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/`.
- **Optional env**: `target_codebase_dir` — without it pseudotest format is used; with it emit real framework tests (no pseudotest fallback).

Richest suites come from combining all four sources (Lean source, `lean_proof_results.pl`, `hypothesis.pl`, `model_results.pl`).

## Process

**When a target codebase directory is provided, Step 2 (Discover Test Patterns) happens immediately after Step 1, before any test mapping begins. This discovery ensures all subsequent steps generate tests that naturally conform to the project's existing testing conventions.**

### 1. Read All Inputs

**Delegate Prolog interrogation to the `shifting:agent-of-questions` sub-agent.** That agent is the Prolog query specialist — it discovers predicates and arities via `swipl` introspection (never by reading `.pl` files as text) and surfaces exactly the facts this step needs. Hand it the `.pl` artifacts (`lean_proof_results.pl`, `target-world.pl`, `hypothesis.pl`, `model_results.pl`) and the extraction checklist below; do NOT grep or Read the `.pl` files yourself.

For a quick inline spot-check, `swipl -g "consult('FILE'), forall(P, format('...', [P])), halt."` works against any of `theorem_verdict/2`, `formal_property/3`, or `provenance_annotation/3`.

Extract per verdict (full source-predicate table in **`references/tagging.md`**):

- Property name, Lean theorem statement (or Prolog query), and natural-language description
- `proof_strategy/2` (surface in the test's `proof_strategy:` comment line)
- **Proof mode** — `invariant` or `conditional`, **derived**: `conditional` iff `hypothesis.pl` carries any `claim_label(_, counterfactual)`; otherwise `invariant`. No `proof_mode` predicate exists in the schema.
- **`ontology_label`** for the source claim (from `claim_label/2`) — flows onto every projection test that witnesses the claim
- **`negation_provenance`** for any negated premise (`claim_negation_provenance/3` on the hypothesis side, `provenance_annotation/3` on the proof side; the two MUST agree, a divergence is a malformed run)
- For `conditional`: counterfactual facts (cross-reference with `target-world.pl` removals), per-counterfactual NECESSARY/EXTRANEOUS status, overall SUFFICIENT/INSUFFICIENT status

From `thoughts/hypothesis.pl` (when present): the original proposition, counterfactual question, sub-claim `claim_status` values, edge predicates, assumptions, and any counterevidence.

From `thoughts/model_results.pl` (when present): verified model results — these can seed `projection` tests the same way Lean universals do.

From other `.pl` files in `thoughts/`: ordering relationships, multiplicity constraints, exclusion predicates, and domain-fact fixtures map to ordering/cardinality/negative tests. See `references/structural-tests.md` for the full pattern catalogue.

### 2. Discover Test Patterns (Early step — do this first when target provided)

When `target_codebase_dir` is set, spawn `Agent(Explore)` to map the codebase's test infrastructure: framework (Jest / pytest / RSpec / JUnit / Go / Mocha / Rust), file naming, test-function naming, assertion style, fixture patterns, nesting conventions (describe/it vs flat vs parameterized), custom utilities, and any project-specific idioms. The agent returns a summary you carry forward into Step 9.

Match the detected idioms exactly in generated tests. The goal is tests the implementor can run immediately without adaptation — foreign-looking tests get rewritten. If no target directory was given, or Explore found no test files, fall through to pseudotest format in Step 9.

### 3. Map Proven Properties to Tests

For each proven property, produce at least one `projection` test. The translation from property shape (∀, implication, equivalence, bounds, idempotency, monotone, existential, etc.) to test shape, plus naming conventions and worked examples, lives in **`references/test-shape-mapping.md`**. Consult it before mapping.

Two contracts that bind every projection test, regardless of shape:

- **Record the sample.** Every projection test's comment block must carry `sampled_from:`, `fixture_set:`, and `unsampled_domain:` — these capture the universality loss explicitly. Combined with `test_category`, `ontology_label`, `negation_provenance` (if applicable), and `proof_strategy`, they form the full tag block. See `references/tagging.md` for the field list and source predicates.
- **Name tests after properties, not code.** `test_auth_token_invalid_after_expiry` over `test_tokenService_checkExpiry`. Property names survive refactoring.

### 3.5. Translate Counterfactual Claims into Removal-Projection Tests

**Applies only when at least one `claim_label(_, counterfactual)` exists in `hypothesis.pl` (conditional mode).** For every counterfactual claim and its corresponding fact removal in `target-world.pl`, emit:

- A **removal test** (architectural / lint-style) asserting the fact no longer holds in the implementation — `test_category: projection`, `ontology_label: counterfactual`.
- A **reintroduction test** asserting the invariant breaks if the fact is put back — only for counterfactuals labelled NECESSARY by `necessity_lemma_status(_, _, proven)` in `lean_proof_results.pl`.

EXTRANEOUS counterfactuals (`necessity_lemma_status(_, _, extraneous)`) emit the removal test only and surface a LOOPBACK SIGNAL to `decompose-proposition`. INSUFFICIENT proofs surface a LOOPBACK SIGNAL to enumerate more counterfactuals.

The fact-shape→assertion mapping (12+ patterns), framework-specific architecture-test recommendations, NECESSARY/EXTRANEOUS/unprovable handling, the `absent` vs `contradicts` provenance distinction, naming conventions, and a full worked walkthrough live in **`references/counterfactual-tests.md`**. Consult that file when the run is in conditional mode — it is the contract.

### 4. Derive Edge Case Tests from Hypothesis

From `thoughts/hypothesis.pl`, surface every boundary condition or edge predicate from exploration: empty inputs, single elements, maximum cardinality, refuted sub-claims (assert the correct observed behavior — this locks in the understanding), and open assumptions (stub with a skip/pending annotation: `skip(reason="assumption not proven — verify manually")`).

Each edge case test must comment which sub-claim or edge predicate it encodes. Tests descended from a proven claim are `projection`; tests for behavior the formal layer never expressed are `behavioral_claim` (see Step 5.5).

### 5. Derive Structural Tests from Prolog KB

If Prolog KB files are present, extract structural constraints (dependency ordering, cardinality, exclusion, cycle prevention, functional dependencies, etc.) and translate them to tests. These are still `test_category: projection` — the projection source is the KB's relational structure rather than a per-property theorem.

The structural-pattern→test-shape table (12+ patterns), `swipl` discovery queries, domain-entity fixture extraction, and worked examples live in **`references/structural-tests.md`**. Consult it whenever the run has any `.pl` files beyond `lean_proof_results.pl`.

### 5.5. Identify Behavioral Additions

Side effects, I/O sequencing, timing, concurrency, error-mode behaviour, and integration-level state transitions live in the TDD layer and nowhere else — this is the *gain* crossing the `lean → tdd` boundary. When the implementor asks for them or the target codebase clearly requires them (e.g., a handler returning 503 on backpressure), tag each `test_category: behavioral_claim` and place them under a dedicated `## Behavioral Contracts` section above `COVERAGE GAPS`.

`behavioral_claim` tests have no upstream formal backing — a failing one cannot loop back to `decompose-proposition` or the prove skills (those nodes never expressed the claim). The classification matters for `realize-specification`'s loopback logic. If no behavioral additions are needed, note "no behavioral additions" in the suite header.

### 6. Assign Tests to Phases

Organize tests into phases reflecting the logical dependency ordering — a phase's tests should depend only on behavior proven in earlier phases:

- **Phase 0 — Removal** *(conditional mode only)*: counterfactual-removal and reintroduction tests from Step 3.5. Comes first so the forbidden-dependency deletion happens before any new behaviour is written; otherwise Phase 1 tests can pass for the wrong reason while the forbidden dependency still exists.
- **Phase 1 — Foundations**: properties with no dependencies (base types, pure functions, stateless transformations).
- **Phase 2 — Compositions**: properties composing Phase 1 behaviors.
- **Phase N — Integration**: end-to-end properties spanning the system.
- **Phase B — Behavioral Contracts**: `behavioral_claim` tests from Step 5.5. Last; may stay red longer since there is no proof to lean on.

Within each phase, order from simplest (empty/trivial) to most complex (boundary/stress). The implementor works top-to-bottom.

### 7. Identify Coverage Gaps and Loopback Signals

Two distinct outputs, kept separate (different audiences):

**(7a) Coverage Gaps** — advisories for the implementor; do NOT loop back. Render as a `COVERAGE GAPS` comment block at the end of the test file. Cover: proven properties with pure existential statements (manual-verification items), properties about infinite structures (suggest a PBT library), properties depending on unprovable assumptions (TODO stubs), every projection test descended from a `negation_provenance: absent` premise (CWA-fragile), unsampled-domain slices per `∀`-quantified property (the universality loss made explicit), and every `behavioral_claim` test (claims asserted without formal support).

**(7b) Loopback Signals** — actionable corrections to upstream skills. Render as a separate `LOOPBACK SIGNALS` comment block ABOVE the gaps block, and surface as top-level items in the report. Triggers and targets:

- `necessity_lemma_status(_, _, extraneous)` → `decompose-proposition` to prune the over-specified counterfactual.
- INSUFFICIENT conditional proof → `decompose-proposition` for additional counterfactual requirements.
- `conditional` mode missing `cf_fact/N` entries → `decompose-proposition` to enumerate, or downgrade the property to `invariant`.
- `claim_negation_provenance` / `provenance_annotation` mode disagreement → `prove-invariants` to reconcile.

### 8. Mark Every Generated Test as Skipped

**All tests start skipped — no exceptions.** Apply the target framework's skip/pending annotation to every test; `realize-specification` un-skips them one at a time. The skip state is the TDD progress ledger; the suite must not turn CI red on merge. Open-assumption stubs from Step 4 stay skipped with their own reason — `skip(reason="assumption not proven — verify manually")` — to distinguish "not yet implemented" from "needs manual verification".

### 9. Write the Test File

Write to `thoughts/tests/{filename}`. **Emit real framework tests whenever `target_codebase_dir` is set**; pseudotest format is the fallback for unset target or no detectable test infrastructure.

## Output Format

The full test-file template (header block, per-test comment-block schema, phase ordering, framework-specific skip idioms, `LOOPBACK SIGNALS` and `COVERAGE GAPS` blocks, filename conventions, pseudotest fallback) lives in **`references/test-templates.md`**. Load it before writing.

Three contracts the templates enforce:

- Every test starts skipped in the framework's idiom (`test.skip`, `@pytest.mark.skip`, `t.Skip`, `#[ignore]`, …).
- `LOOPBACK SIGNALS` and `COVERAGE GAPS` render as two separate blocks in that order at the end of the file — never collapse them.
- `behavioral_claim` tests live in Phase B last and omit `proof_strategy`, `ontology_label`, `sampled_from`, `fixture_set`, `unsampled_domain` (those fields imply proof ancestry the category lacks).

## Output

One test file at `thoughts/tests/{filename}` (create the directory if it doesn't exist; language-appropriate filename per `references/test-templates.md`).

Report breakdown:

- File path; total tests generated; proven properties covered (e.g., 5/6); edge-case and structural counts; counterfactual-removal and reintroduction counts (conditional mode, both under `projection`)
- **Coverage gaps** (Step 7a) and — separately — **loopback signals** (Step 7b, naming the upstream skill and trigger)
- **`test_category` breakdown**: N projection, M behavioral_claim
- **`ontology_label` breakdown** over projection tests only (behavioral_claim carries no ontology_label)
- **`negation_provenance` breakdown** where applicable (`absent` = CWA-fragile vs `contradicts` = structural)
- Unsampled-domain count per property

## Guidance

The 13 principles — each with its rule, failure mode, and how-to-apply — and the named enforcement rules (`behavioral_claim_neq_proven_property`, `cwa_negation_neq_lean_proof`, `lean_universal_neq_test_verified`) live in **`references/guidance.md`**. Load it whenever a principle decision arises; do not re-derive from this file.

## Additional Resources

| Reference | When to load |
|---|---|
| `references/test-templates.md` | Step 9 — before writing the test file. Header block, comment-block schema, framework skip idioms, LOOPBACK SIGNALS / COVERAGE GAPS blocks, filename conventions. |
| `references/tagging.md` | Whenever uncertain about a tag's domain or source predicate. Canonical taxonomy and decision tree. |
| `references/test-shape-mapping.md` | Step 3 — translating a property's logical shape (∀, →, ↔, idempotency, monotone, existential, etc.) to a concrete test shape. |
| `references/counterfactual-tests.md` | Step 3.5 — only in conditional mode. Fact-shape table, NECESSARY/EXTRANEOUS handling, architecture-test framework picks, worked walkthrough. |
| `references/structural-tests.md` | Step 5 — when the run has Prolog KB files beyond `lean_proof_results.pl`. Structural-pattern→test-shape table, swipl discovery queries. |
| `references/guidance.md` | Whenever a principle decision arises. 13 principles with failure-mode rationale and concrete examples. |
| `../../references/ontology.md` | Ontology label *semantics* — what each label means at a boundary. |
| `../../references/pipeline-schema/` | Wire format of every `.pl` artifact. The wiki wins when a skill's local doc disagrees. |
