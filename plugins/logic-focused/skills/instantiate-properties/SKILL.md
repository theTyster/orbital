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

Structured artifacts are **Prolog facts files** (`.pl`) — query them by delegating to the `logic-focused:agent-of-questions` sub-agent (the Prolog query specialist), or with `swipl -g` for one-off spot checks. Never grep or Read the `.pl` files. The Lean source files are the exception: read them directly as text.

- **Primary input**: `thoughts/lean/Proofs/*.lean` — the actual Lean theorem source. Each theorem's statement is the specification to instantiate.
- **Required**: `thoughts/lean_proof_results.pl` from `prove-invariants`. Carries `theorem_verdict/2`, `proof_strategy/2`, `failure_mode/2`, `theorem_source/2`, `necessity_lemma_status/3`, and mandatory `provenance_annotation(TheoremId, FactId, absent | contradicts)` for any theorem with a negated premise. May also carry `cwa_check/3` and `lean_skipped/2` for properties gated out of Lean by `prove-invariants` (see `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/lean-proof-results.md`); treat a `cwa_check(Prop, _, verified)` exactly like `theorem_verdict(Prop, proven)` for projection emission, with `proof_strategy: prolog-cwa-check` in the test comment block instead of the Lean tactic chain.
- **Optional**: `thoughts/hypothesis.pl` — provides `claim/2`, `claim_label/2` (descriptive/counterfactual/prescriptive), `claim_status/2`, `claim_premise/2`, `claim_negation_provenance/3` (per-claim, 3-arg form), `formal_property/3`, edge predicates, and the original proposition's scope.
- **Optional**: `thoughts/model_results.pl` — Prolog model verification results that may supplement Lean proofs. A verified model fact can seed a `projection` test the same way a Lean universal can.
- **Optional**: `thoughts/target-world.pl` — records fact removals corresponding to counterfactual claims (used to drive counterfactual `projection` tests).
- **Optional**: Any other `.pl` files in `thoughts/` — Prolog KB facts expose dependency ordering, relationship constraints, and domain predicates that map to setup/teardown and edge case tests.
- **Optional env**: `target_codebase_dir` — target codebase directory for language/framework detection. **Without it, pseudotest format is used; with it, emit real tests in the detected framework — do not fall back to pseudotests.**

Read all available inputs before writing a single test. The richest test suites come from combining four sources: the Lean theorems themselves, proven-property verdicts (`lean_proof_results.pl`), hypotheses (`hypothesis.pl`), and supplementary Prolog model results (`model_results.pl`).

## Process

**When a target codebase directory is provided, Step 2 (Discover Test Patterns) happens immediately after Step 1, before any test mapping begins. This discovery ensures all subsequent steps generate tests that naturally conform to the project's existing testing conventions.**

### 1. Read All Inputs

**Delegate Prolog interrogation to the `logic-focused:agent-of-questions` sub-agent.** That agent is the Prolog query specialist — it discovers predicates and arities via `swipl` introspection (never by reading `.pl` files as text) and writes precise queries that surface exactly the facts this step needs. Invoke it with `Agent(subagent_type="logic-focused:agent-of-questions")` and hand it the list of `.pl` artifacts (`thoughts/lean_proof_results.pl`, `thoughts/target-world.pl`, `thoughts/hypothesis.pl`, `thoughts/model_results.pl`) along with the extraction checklist below. Have it return a structured summary you can map directly into the per-test comment blocks. Do NOT grep or Read the `.pl` files yourself — query them.

If you must run a one-off query inline (e.g., to spot-check the agent's output), use `swipl -g`:

- `swipl -g "consult('thoughts/lean_proof_results.pl'), forall(theorem_verdict(T,V), format('~w ~w~n',[T,V])), halt."`
- `swipl -g "consult('thoughts/target-world.pl'), forall(formal_property(P,NL,Sketch), format('~w | ~w | ~w~n',[P,NL,Sketch])), halt."` — `formal_property/3` is propagated verbatim into `target-world.pl`; query it there alongside the per-fact provenance.
- `swipl -g "consult('thoughts/lean_proof_results.pl'), forall(provenance_annotation(T,F,M), format('~w ~w ~w~n',[T,F,M])), halt."` — per-theorem negation-provenance echoes.

Extract for each verdict:

- Property name and its Lean theorem statement (or Prolog query)
- The natural language description (from `formal_property/3` and any companion `claim/2` in `hypothesis.pl`)
- The `proof_strategy/2` value (hints at what the implementation must do; surface in the test's `proof_strategy:` comment line)
- Which claim it was derived from
- **Proof mode** — `invariant` or `conditional`. **Derived**, not stored: `conditional` iff `hypothesis.pl` contains any `claim_label(_, counterfactual)`; otherwise `invariant`. Do not look for a `proof_mode` predicate — none exists in the schema.
- **`ontology_label`** for the source claim — `descriptive | counterfactual | prescriptive` (from `claim_label/2` in `hypothesis.pl`). This label flows onto every projection test that witnesses the claim.
- **`negation_provenance`** for any negated premise — `absent | contradicts`. Source on the hypothesis side: `claim_negation_provenance(ClaimId, Fact, Mode)` in `hypothesis.pl`. Source on the proof side: `provenance_annotation(TheoremId, FactId, Mode)` in `lean_proof_results.pl`. The two MUST agree; a divergence is a malformed run. Tests that depend on a negated premise inherit this provenance and must flag `absent` as fragile in their comment block.
- If `conditional`, also extract:
  - **Counterfactual facts** — the KB facts from `claim_label(_, counterfactual)` claims that had to be false for the property to hold (e.g., `cf_fact(cli_tool, logging)`). Cross-reference with `thoughts/target-world.pl` for the corresponding fact removals.
  - **Per-counterfactual status** — each fact is labelled `NECESSARY` (removing it is load-bearing) or `EXTRANEOUS` (the property holds without requiring its removal).
  - **Overall status** — `SUFFICIENT` (the counterfactual set proves the property) or `INSUFFICIENT` (the set was not enough).

If `thoughts/hypothesis.pl` exists, also extract (via the `agent-of-questions` sub-agent — or `swipl` directly when spot-checking — against `claim/2`, `claim_label/2`, `claim_status/2`, `claim_premise/2`, `claim_negation_provenance/3`, `formal_property/3`):

- The original proposition (context for naming tests meaningfully)
- The **counterfactual question** — "What about the existing KB would need to be false for `{proposition}` to be true?" — surfaces the intent behind every counterfactual-removal test
- Sub-claims and their `claim_status` (clear, conditional, open)
- **Counterfactual claims** — each `claim_label(C, counterfactual)` corresponds to a fact that must be falsified. These become `projection` tests sourced from the counterfactual claim.
- **Edge predicates** — boundary conditions identified during exploration. These become edge case tests.
- **Assumptions** — properties taken as given during proof. These become test preconditions or fixture setup.
- Counterevidence found during exploration — even refuted claims may need a "does NOT do X" test

If `thoughts/target-world.pl` exists, read the recorded fact removals so each counterfactual `projection` test can assert the right absence.

If `thoughts/model_results.pl` exists, treat verified model results as additional sources for `projection` tests (a Prolog model fact can be sampled the same way as a Lean universal).

If other `.pl` files exist in `thoughts/`, scan them for:
- Ordering relationships (e.g., `depends_on/2`, `before/2`, `requires/2`) → test ordering, setup/teardown, or integration sequence
- Multiplicity constraints (e.g., `has_exactly_one/2`, `at_most/3`) → cardinality tests
- Exclusion predicates (e.g., `mutually_exclusive/2`, `not_allowed/2`) → negative tests
- Domain facts that make good test fixtures (concrete entities the tests can use as inputs)

### 2. Discover Test Patterns (Early step — do this first when target provided)

**If a target codebase directory was provided**, use the Explore sub-agent to discover the testing landscape before mapping properties to tests. This ensures generated tests naturally conform to existing patterns without additional manual matching.

#### 2a. Invoke Explore Sub-Agent

Send the following request to the Explore sub-agent (via `Agent(Explore)`):

> Explore this codebase to understand its test infrastructure:
> 1. Identify the test framework(s) in use (jest, pytest, RSpec, JUnit, Go `testing` package, etc.)
> 2. Discover naming conventions: how are test files named? (e.g., `*.test.js`, `*_test.py`, `test*.rs`)
> 3. Find examples of assertion styles and patterns (e.g., `expect()`, `assert_that()`, `assertEqual`, custom matchers)
> 4. Identify fixture and setup patterns (beforeEach/beforeAll, setUp methods, fixture factories, test utilities)
> 5. Map test organization: describe/it nesting, flat function-based tests, parameterized/table-driven tests
> 6. Locate custom test helpers and utilities that should be reused in generated tests
> 7. Note any non-standard testing patterns specific to this project
>
> Provide a summary of findings for each category. Focus on patterns the generated tests should match.

The Explore agent returns a summary report of the test landscape.

#### 2b. Extract Testing Conventions from Explore Output

From the Explore report, extract:
- **Framework**: Jest, pytest, RSpec, JUnit, Go test, Mocha, etc.
- **File naming**: e.g., `foo.test.ts`, `test_foo.py`, `foo_spec.rb`
- **Test function naming**: e.g., `test "should do X"`, `def test_do_x`, `func TestDoX`
- **Assertion style**: library and idiom (expect, assert, assert!, @Test decorator, etc.)
- **Fixture patterns**: function, class method, factory, inline setup
- **Nesting conventions**: describe/it blocks, flat functions, parameterized arrays
- **Custom utilities**: helpers or test base classes to inherit from or import
- **Non-standard patterns**: project-specific idioms to match

**If no target directory was given, or Explore finds no test files**, skip to step 2c and use pseudotest format instead.

#### 2c. Match Detected Idioms Exactly

When a target framework is identified, match its idioms exactly in generated tests:
- Use `describe`/`it` for Jest/RSpec/Mocha
- Use `def test_` naming for pytest
- Use `func Test` for Go
- Use `@Test` annotations for JUnit/TestNG
- Use `#[test]` for Rust
- Replicate the project's nesting depth, assertion library, and fixture strategy

The goal is tests the implementor can run immediately without adaptation. A test that looks foreign will be rewritten.

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

From `thoughts/hypothesis.pl`, extract every boundary condition or edge predicate identified during exploration:

- **Empty inputs**: If the hypothesis explored "what happens at zero elements," write an empty-input test
- **Single elements**: If the hypothesis identified base-case behavior, write a singleton test
- **Maximum cardinality**: If the hypothesis identified upper bounds, write a test at that bound
- **Refuted sub-claims**: If exploration found that a claim does NOT hold, write a test asserting the correct (observed) behavior — this locks in the understanding
- **Open assumptions**: Write tests as `// TODO: assumption not proven — verify manually` stubs, or mark with a skip/pending annotation in the target framework

Each edge case test must comment which sub-claim or edge predicate it encodes. Edge-case tests that descend from a proven claim are `projection`; edge-case tests for behavior the formal layer never expressed are `behavioral_claim` (see Step 5.5).

### 5. Derive Structural Tests from Prolog KB

If Prolog KB files are present, extract structural constraints (dependency ordering, cardinality, exclusion, cycle prevention, functional dependencies, etc.) and translate them to tests. These are still `test_category: projection` — the projection source is the KB's relational structure rather than a per-property theorem.

The structural-pattern→test-shape table (12+ patterns), `swipl` discovery queries, domain-entity fixture extraction, and worked examples live in **`references/structural-tests.md`**. Consult it whenever the run has any `.pl` files beyond `lean_proof_results.pl`.

### 5.5. Identify Behavioral Additions

- Some test needs cannot be projections of any proven property. Side effects, I/O sequencing, timing, concurrency, error-mode behaviour, and integration-level state transitions live in the TDD layer and nowhere else — this is the *gain* crossing the `lean → tdd` boundary.
- If the implementor explicitly asked for behavioral tests, or if the target codebase clearly requires them (e.g., a server handler that must return 503 on backpressure), generate them — but tag each one `test_category: behavioral_claim` in its comment block and list them under a dedicated `## Behavioral Contracts` section at the bottom of the test file (above `COVERAGE GAPS`).
- `behavioral_claim` tests have no upstream formal backing. A failing `behavioral_claim` test cannot loop back to `decompose-proposition` or `model-obligations` / `prove-invariants` — those nodes never expressed the claim. The classification matters for `realize-specification`'s loopback logic.
- If no behavioral additions are needed, skip this step — but note in the suite header "no behavioral additions".

### 6. Assign Tests to Phases

Organize tests into phases that reflect the logical dependency ordering from the proofs. A phase's tests should only depend on behavior proven in earlier phases:

- **Phase 0 — Removal** *(conditional mode only)*: Counterfactual-removal and reintroduction tests from Step 3.5. These are `projection` tests sourced from `claim_label(_, counterfactual)` in `hypothesis.pl` and corresponding fact removals in `target-world.pl`. They come first because every later phase's property is stated against the target relation `R_target := R ∧ ¬cf`. Implementing Phase 1 before Phase 0 produces code that satisfies an invariant *while* the forbidden dependency still exists — passing tests for the wrong reason. Phase 0 forces the deletion/removal work to happen before any new behaviour is written.
- **Phase 1 — Foundations**: Tests for properties with no dependencies. These test base types, pure functions, stateless transformations.
- **Phase 2 — Compositions**: Tests for properties that compose Phase 1 behaviors. These may require Phase 1 to pass before they are meaningful.
- **Phase N — Integration**: Tests for end-to-end properties that span the full system.
- **Phase B — Behavioral Contracts**: `behavioral_claim` tests from Step 5.5. This phase runs AFTER all projection phases. Behavioral phase tests may remain red longer because they have no proof to lean on; the implementor decides when they pass.

Within each phase, order tests from simplest (empty/trivial cases) to most complex (boundary/stress cases). An implementor should be able to work top-to-bottom through the file.

### 7. Identify Coverage Gaps and Loopback Signals

Two distinct outputs come from this step. Keep them separate — they have different audiences.

**(7a) Coverage Gaps** — advisories for the implementor reading the test file. These do NOT loop back to upstream skills:

- Proven properties with pure existential statements ("there exists X") that are hard to assert deterministically without knowing the witness — flag as manual verification items.
- Properties about infinite structures (termination, totality) that require property-based testing tooling — flag and suggest a PBT library (Hypothesis, fast-check, QuickCheck) if appropriate.
- Properties that depend on unprovable assumptions (from Step 1) — stub the test with a clear TODO.
- **`negation_provenance: absent` premises**: CWA-default negations are fragile. Flag every projection test descended from a `claim_negation_provenance(_, _, absent)` (or its `provenance_annotation/3` echo) so the implementor knows the proof rests on a closed-world assumption.
- **Unsampled domain slices**: for each `∀`-quantified property, list values of the quantified variable NOT covered by any projection test. This is the shape of the universality loss at the `lean → tdd` boundary — surface it explicitly rather than pretending the suite re-verifies the proof.
- **Unbacked behavioral contracts**: list every `behavioral_claim` test so the reader can see which claims the suite asserts without formal support.

Render these in a `COVERAGE GAPS` comment block at the end of the test file.

**(7b) Loopback Signals** — actionable corrections to upstream skills. These DO loop back:

- **EXTRANEOUS counterfactuals** (from `necessity_lemma_status(_, _, extraneous)` in `lean_proof_results.pl`): the proof flagged the fact as non-load-bearing. Recommendation: loop back to `decompose-proposition` to prune the over-specified counterfactual. The removal test is still emitted, but the hypothesis was imprecise.
- **INSUFFICIENT proof status**: if the conditional proof was `INSUFFICIENT`, the counterfactual set did not close the gap. Recommendation: loop back to `decompose-proposition` — additional counterfactual requirements needed.
- **`conditional` mode with no enumerable counterfactual facts**: a property left in conditional mode but missing `cf_fact/N` entries cannot become a removal test. Recommendation: loop back to `decompose-proposition` to enumerate the counterfactuals or downgrade the property to `invariant` mode.
- **Hypothesis vs. proof provenance disagreement**: any `claim_negation_provenance(_, F, Mode₁)` whose corresponding `provenance_annotation(_, FactId, Mode₂)` disagrees on `Mode` is a malformed run. Recommendation: loop back to `prove-invariants` to reconcile.

Render these in a separate `LOOPBACK SIGNALS` comment block above the COVERAGE GAPS block. Loopback signals also surface in the report (Step 9 output) as a top-level item, not buried in a gap count.

### 8. Mark Every Generated Test as Skipped

**All tests start skipped — no exceptions.** Apply a skip/pending annotation to every test in the file using the target framework's idiom. The implementation skill (`realize-specification`) un-skips them one at a time. This ensures the newly-added suite does not turn CI red on merge — the tests are a specification, not a regression check on existing behavior.

The implementor's workflow is: pick the next skipped test top-to-bottom, remove the skip annotation, run the suite, watch it fail, implement until it passes, commit, repeat. The skip state is the TDD progress ledger.

Open-assumption stubs (from Step 4) stay skipped with their own reason — `skip(reason="assumption not proven — verify manually")` — so the implementor can distinguish "not yet implemented" from "needs manual verification."

### 9. Write the Test File

Write to `thoughts/tests/{filename}`. **Emit real framework tests whenever `target_codebase_dir` is set** — pseudotest format is a fallback for when no target codebase is provided (or when Step 2 found no detectable test infrastructure). Filename conventions and the full output structure are defined in `references/test-templates.md` — consult it before writing. Create `thoughts/tests/` if it doesn't exist.

## Output Format

The full test-file template — header block, per-test comment-block schema, phase ordering, framework-specific skip idioms, the `LOOPBACK SIGNALS` block, the `COVERAGE GAPS` block, filename conventions, and the pseudotest fallback — lives in `references/test-templates.md`. Load it before writing the file. The reference is the source of truth for output structure; do not improvise comment-block fields or phase headers from memory.

Three contracts the templates enforce that bear repeating here:

- Every test starts skipped, in the framework's idiom (`test.skip`, `@pytest.mark.skip`, `t.Skip`, `#[ignore]`, etc.). The skip state is the TDD progress ledger consumed by `realize-specification`.
- `LOOPBACK SIGNALS` (Step 7b output) and `COVERAGE GAPS` (Step 7a output) render as **two separate blocks**, in that order, at the end of the file. They have different audiences — never collapse them.
- `behavioral_claim` tests live in Phase B, always last, and omit `proof_strategy`, `ontology_label`, `sampled_from`, `fixture_set`, `unsampled_domain` from their comment block (those fields imply proof ancestry which `behavioral_claim` lacks).

## Output

All artifacts are written to `thoughts/tests/` (create the directory if it doesn't exist).

One test file: `thoughts/tests/{filename}` (language-appropriate name).

Report:
- File path
- Number of tests generated (total)
- Proven properties covered (e.g., 5/6)
- Edge case tests generated from hypothesis
- Structural tests generated from Prolog KB
- **Counterfactual-removal tests** generated from `claim_label(_, counterfactual)` claims (conditional mode only) — counted under `projection`
- **Reintroduction tests** generated for NECESSARY counterfactuals (conditional mode only) — counted under `projection`
- Coverage gaps (proven properties that couldn't be translated, with reasons) — from Step 7a
- **Loopback signals** — distinct from coverage gaps; each entry names the upstream skill (`decompose-proposition` or `prove-invariants`) and the trigger (EXTRANEOUS counterfactuals, INSUFFICIENT proof, conditional-without-cf, provenance disagreement). From Step 7b.
- **test_category breakdown**: N projection, M behavioral_claim (these are the only two values)
- **ontology_label breakdown** (diagnostic, **over projection tests only** — `behavioral_claim` tests carry no `ontology_label`): how many projections inherited `descriptive`, `counterfactual`, `prescriptive`
- **negation_provenance breakdown** (diagnostic, where applicable): how many tests rest on `absent` (CWA, fragile) vs `contradicts` (explicit, structural)
- Unsampled-domain count per property (from Step 7a)

## Guidance

The full principles — rule, failure mode, and how-to-apply for each — live in **`references/guidance.md`**. The 13 principles, in short:

1. **Tests ARE the plan** — no separate implementation plan document.
2. **Projection = witness, not re-proof** — universality stays in the proof; "sampled and passed" not "property verified".
3. **`behavioral_claim` has no proof ancestry** — visibly separated; failures do not loop back.
4. **Failing is correct, but skip by default** — every test fails on a blank implementation; trivially-true assertions are silent spec rot.
5. **Name tests after properties, not code** — names survive refactoring.
6. **Edge predicates are not optional** — proofs are on models; edges are where models diverge.
7. **Assumptions become TODOs** — open assumptions are stubs, never omissions.
8. **Prolog facts are free fixtures** — real domain names beat `foo`/`bar`.
9. **Flag gaps loudly** — never silently drop formal guarantees.
10. **Match the existing test style exactly** — foreign-looking tests get rewritten.
11. **Don't over-specify implementation** — assert the contract, not the strategy.
12. **Counterfactual-removal tests are first-class** — the counter-pressure to "only reason about what exists".
13. **Reintroduction tests lock in load-bearing reasoning** — the only mechanism preventing silent regression on NECESSARY counterfactuals.

Consult `references/guidance.md` when any of these meets resistance from the current task — that file documents the failure mode each principle defends against and the named enforcement rules (`behavioral_claim_neq_proven_property`, `cwa_negation_neq_lean_proof`, `lean_universal_neq_test_verified`).

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
