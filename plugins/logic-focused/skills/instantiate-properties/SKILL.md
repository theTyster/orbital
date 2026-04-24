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

**MANDATORY: every emitted test carries exactly one `test_category` tag — `projection` or `behavioral_claim`.** No test is untagged. This distinction is structurally required (enforcement rule `behavioral_claim_neq_proven_property`): a red `projection` test means the implementation broke a proven invariant; a red `behavioral_claim` test means the implementation violated a contract that was never proven and cannot be proven in Lean. The two are not interchangeable and must be visibly separated in the suite (Phase B at the bottom) and in the summary report.

**How to decide which category applies:**

- If the test descends from a Lean theorem or a `formal_property/3` in `lean_proof_results.pl` / `model_results.pl` — it is `projection`. It has proof ancestry.
- If the test asserts I/O, side effects, state mutation, concurrency, timing, HTTP status codes, logging, or any other runtime-observable behavior that Lean cannot state — it is `behavioral_claim`. It has no proof ancestry.
- When in doubt, ask: "Is there a theorem in `lean_proof_results.pl` whose universal statement, when instantiated at my fixture, yields this assertion?" If yes → `projection`. If no → `behavioral_claim`.

**Two test categories — that is the entire domain.** Every emitted test carries `test_category(projection | behavioral_claim)`:

- `projection` — derived from a Lean proof applied to a specific fixture. Failure means "implementation bug: the proved property fails at this sample point." This bucket includes both positive sampling of `∀x.P(x)` AND counterfactual-removal tests (formerly absence/guard) that project a `claim_label(_, counterfactual)` claim from `hypothesis.pl` plus a corresponding fact removal recorded in `target-world.pl`. Counterfactual projections are still emitted — they are the structural counter-pressure to the "only reason about what exists" bias — they just live under `projection`.
- `behavioral_claim` — new claim introduced at the TDD boundary. Failure means "contract failure — no upstream proof; the claim itself may need scrutiny." Has no upstream proof ancestry. A failing `behavioral_claim` test is NOT a loopback signal to `decompose-proposition` or `model-obligations` / `prove-invariants` — those nodes never expressed the claim.

Alongside `test_category`, each test carries diagnostic dimensions inherited from the source claim where applicable:

- `epistemic_label: descriptive | counterfactual | prescriptive` — read from `claim_label/2` in `hypothesis.pl` for the claim this test descends from. `behavioral_claim` tests typically have no `epistemic_label` (no upstream claim).
- `negation_provenance: absent | contradicts` — applies only to tests that descend from a negated premise. `absent` (CWA default) is fragile; `contradicts` (explicit conflicting fact) is structurally necessary. Read from `negation_provenance/2` in `hypothesis.pl` / `lean_proof_results.pl`.

Reference: `../../references/epistemic-types.md`.

## Input

All structured inputs are **Prolog facts files** (`.pl`), not markdown. Query them with `swipl -g`, not with grep or Read.

- **Primary input**: `thoughts/lean/Proofs/*.lean` — the actual Lean theorem source. Each theorem's statement is the specification to instantiate.
- **Required**: `thoughts/lean_proof_results.pl` from `prove-invariants`. Carries `theorem_verdict/2`, `formal_property/3`, and mandatory provenance annotations (`absent | contradicts`).
- **Optional**: `thoughts/hypothesis.pl` — provides `claim/2`, `claim_label/2` (descriptive/counterfactual/prescriptive), `claim_status/2`, `negation_provenance/2`, `formal_property/3`, edge predicates, and the original proposition's scope.
- **Optional**: `thoughts/model_results.pl` — Prolog model verification results that may supplement Lean proofs. A verified model fact can seed a `projection` test the same way a Lean universal can.
- **Optional**: `thoughts/target-world.pl` — records fact removals corresponding to counterfactual claims (used to drive counterfactual `projection` tests).
- **Optional**: Any other `.pl` files in `thoughts/` — Prolog KB facts expose dependency ordering, relationship constraints, and domain predicates that map to setup/teardown and edge case tests.
- **Optional env**: `target_codebase_dir` — target codebase directory for language/framework detection. **Without it, pseudotest format is used; with it, emit real tests in the detected framework — do not fall back to pseudotests.**

Read all available inputs before writing a single test. The richest test suites come from combining four sources: the Lean theorems themselves, proven-property verdicts (`lean_proof_results.pl`), hypotheses (`hypothesis.pl`), and supplementary Prolog model results (`model_results.pl`).

## Process

**When a target codebase directory is provided, Step 2 (Discover Test Patterns) happens immediately after Step 1, before any test mapping begins. This discovery ensures all subsequent steps generate tests that naturally conform to the project's existing testing conventions.**

### 1. Read All Inputs

Query `thoughts/lean_proof_results.pl` directly with `swipl` (or `swipl -g`) rather than parsing markdown. Useful queries:

- `swipl -g "consult('thoughts/lean_proof_results.pl'), forall(theorem_verdict(T,V), format('~w ~w~n',[T,V])), halt."`
- `swipl -g "consult('thoughts/lean_proof_results.pl'), forall(formal_property(P,Stmt,Mode), format('~w | ~w | ~w~n',[P,Stmt,Mode])), halt."`

Extract for each verdict:

- Property name and its Lean theorem statement (or Prolog query)
- The natural language description (from any companion `claim/2` in `hypothesis.pl`)
- The proof strategy (hints at what the implementation must do)
- Which claim it was derived from
- **Proof mode** — `invariant` or `conditional`. Carried on the verdict or formal_property fact.
- **`epistemic_label`** for the source claim — `descriptive | counterfactual | prescriptive` (from `claim_label/2` in `hypothesis.pl`). This label flows onto every projection test that witnesses the claim.
- **`negation_provenance`** for any negated premise — `absent | contradicts` (from `negation_provenance/2` in `hypothesis.pl` and/or `lean_proof_results.pl`). Tests that depend on a negated premise inherit this provenance and must flag `absent` as fragile in their comment block.
- If `conditional`, also extract:
  - **Counterfactual facts** — the KB facts from `claim_label(_, counterfactual)` claims that had to be false for the property to hold (e.g., `cf_fact(cli_tool, logging)`). Cross-reference with `thoughts/target-world.pl` for the corresponding fact removals.
  - **Per-counterfactual status** — each fact is labelled `NECESSARY` (removing it is load-bearing) or `EXTRANEOUS` (the property holds without requiring its removal).
  - **Overall status** — `SUFFICIENT` (the counterfactual set proves the property) or `INSUFFICIENT` (the set was not enough).

If `thoughts/hypothesis.pl` exists, also extract (via `swipl` queries against `claim/2`, `claim_label/2`, `claim_status/2`, `negation_provenance/2`, `formal_property/3`):

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

For each proven property, produce at least one `projection` test. The mapping follows this logic:

| Property shape | Test type | What to assert | test_category |
|---------------|-----------|----------------|---------------|
| "For all X, P(X) holds" | Parameterized / table-driven test | P holds for a representative sample covering boundary values | `projection` |
| "If A then B" | Conditional test | Given A is set up, assert B is produced | `projection` |
| "A and B are equivalent" | Bidirectional test | Two cases: A→B holds; B→A holds | `projection` |
| "There is no state S where invariant fails" | Negative/guard test | Assert that constructing invalid state S either raises or returns an error | `projection` |
| "X is monotone / order-preserving" | Ordering test | Assert output ordering matches input ordering contract | `projection` |
| "X terminates / is finite" | Bounds test | Assert result count, length, or depth is within expected bound | `projection` |
| "X is idempotent" | Idempotency test | Assert applying operation twice equals applying it once | `projection` |

For each property, write the test name to encode the property plainly:
- `test_sorted_output_preserves_all_elements`
- `test_auth_token_invalid_after_expiry`
- `test_no_duplicate_entries_after_insert`

The property name, or a compressed form of it, should appear in the test name. An implementor reading the failing test output should immediately know which formal invariant is violated.

**Record the sample.**

- Every projection test must document, in its comment block, (a) the proven property it samples (`sampled_from:`), (b) the specific fixture values chosen (`fixture_set:`), (c) the unsampled domain — what values of the quantified variable the test does NOT cover (`unsampled_domain:`), (d) the source claim's `epistemic_label:` (`descriptive | counterfactual | prescriptive`), (e) `negation_provenance:` if any negated premise is involved (`absent | contradicts`), and finally (f) `test_category: projection`.
- This turns each test into a typed witness, not a "proof restated." The suite is a tripwire; the proof is still the authority.

### 3.5. Translate Counterfactual Claims into Removal-Projection Tests

**Only applies when at least one proven property is in `conditional` mode and at least one `claim_label(_, counterfactual)` exists in `hypothesis.pl`.** For every counterfactual claim — and the corresponding fact removal in `target-world.pl` — emit two tests, both classified as `test_category: projection` (they project a counterfactual claim).

**Removal test** — asserts that the fact no longer holds in the implementation. The exact assertion depends on the fact's shape:

| Counterfactual fact shape | Removal test asserts |
|---|---|
| `depends_on(cli_tool, logging)` | No import/require/use statement from `cli_tool`'s module to `logging`'s module |
| `calls(moduleA, functionB)` | Static search of `moduleA`'s source turns up zero references to `functionB` |
| `exposes(service, endpoint)` | `service`'s public surface does not include `endpoint` (route table, export list, etc.) |
| `reads(worker, resource)` | `worker` has no code path that opens/queries `resource` |
| `config_has(component, flag)` | The config file or initialisation code does not set `flag` for `component` |

Removal tests are typically architectural/lint-style tests: they use import-graph inspection, AST scans, grep-style assertions, or public-API snapshot diffs — not runtime behaviour. Prefer the project's existing architecture-test idiom if one was found in Step 2 (e.g., `dependency-cruiser`, `archunit`, `ts-arch`, `import-linter`, `depguard`, a bespoke `forbidden_imports_test.go`). If none exists, use a direct source-scan test (read the file, assert the forbidden identifier is absent).

**Reintroduction test** — one per counterfactual fact labelled `NECESSARY` in the proof results. This test re-introduces the fact at runtime or in a fixture and asserts that the invariant breaks in a detectable way (compilation failure captured as a meta-test, a runtime error, a failing higher-level test). It locks in the reason the counterfactual was enumerated in the first place: future maintainers cannot silently re-introduce the dependency without a visible failure.

If a counterfactual fact was labelled `EXTRANEOUS`, **do not emit a reintroduction test** — the proof showed removing it was not load-bearing. Instead, add a single `COVERAGE GAPS` note that this fact should be pruned from the hypothesis next cycle. A removal test is still generated (the fact is still part of the target relation and should not creep back in during implementation) but its comment must flag the `EXTRANEOUS` status.

Naming convention for these tests:
- Removal: `test_no_{source}_depends_on_{target}` / `test_{module}_does_not_import_{other}` / `test_{component}_lacks_{endpoint}`
- Reintroduction: `test_reintroducing_{fact}_breaks_{property}` / `test_{property}_requires_absence_of_{fact}`

**Tagging.** Every counterfactual-derived test carries `test_category: projection` and `epistemic_label: counterfactual` (inherited from the source claim). If the negated premise has `negation_provenance(_, absent)`, surface that — `absent`-provenance counterfactuals are fragile (CWA default) and the comment block must say so. `contradicts`-provenance counterfactuals are structurally necessary. These tags go in the test's comment block and in the suite header summary.

### 4. Derive Edge Case Tests from Hypothesis

From `thoughts/hypothesis.pl`, extract every boundary condition or edge predicate identified during exploration:

- **Empty inputs**: If the hypothesis explored "what happens at zero elements," write an empty-input test
- **Single elements**: If the hypothesis identified base-case behavior, write a singleton test
- **Maximum cardinality**: If the hypothesis identified upper bounds, write a test at that bound
- **Refuted sub-claims**: If exploration found that a claim does NOT hold, write a test asserting the correct (observed) behavior — this locks in the understanding
- **Open assumptions**: Write tests as `// TODO: assumption not proven — verify manually` stubs, or mark with a skip/pending annotation in the target framework

Each edge case test must comment which sub-claim or edge predicate it encodes. Edge-case tests that descend from a proven claim are `projection`; edge-case tests for behavior the formal layer never expressed are `behavioral_claim` (see Step 5.5).

### 5. Derive Structural Tests from Prolog KB

If Prolog KB files are present, extract structural constraints and translate them to tests:

**Dependency ordering → test phase ordering or setup chains:**
If `depends_on(B, A)` and `depends_on(C, B)` appear in the KB, the test for C's behavior should establish A and B preconditions in that order. Either write integration tests that exercise the chain, or use nested setup/teardown blocks.

**Multiplicity constraints → cardinality assertions:**
`has_exactly_one(user, session)` → assert that creating a second session revokes or replaces the first.

**Exclusion predicates → mutual exclusion tests:**
`mutually_exclusive(read_mode, write_mode)` → assert that activating both simultaneously is rejected.

**Domain entities → concrete fixtures:**
Use named entities from the KB as test inputs rather than abstract placeholders. Real domain names in tests make failures easier to diagnose.

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

### 7. Identify Coverage Gaps

After mapping all proven properties, scan for anything that could not be translated:

- Proven properties with pure existential statements ("there exists X") that are hard to assert deterministically without knowing the witness — flag these as manual verification items
- Properties about infinite structures (termination, totality) that require property-based testing tooling — flag these and suggest a PBT library (Hypothesis, fast-check, QuickCheck) if appropriate
- Properties that depend on unprovable assumptions (from Step 1) — stub the test with a clear TODO
- **EXTRANEOUS counterfactuals** (from Step 1): each fact the proof flagged as non-load-bearing belongs in the gap block with the recommendation "prune from hypothesis next cycle" — the removal test is still emitted but the hypothesis was imprecise.
- **INSUFFICIENT proof status**: if the overall proof was `INSUFFICIENT`, the counterfactual set did not close the gap. Record the entire conditional property as a coverage gap with the recommendation "loop back to `decompose-proposition` — additional counterfactual requirements needed."
- **`negation_provenance(_, absent)` premises**: a CWA-default negation is fragile. Flag every projection test that descends from such a premise so the implementor knows the proof rests on a closed-world assumption.
- Properties that were left in `conditional` mode but produced no enumerable counterfactual facts — these cannot become removal tests and must be flagged.
- **Unsampled domain slices**: for each `∀`-quantified property, list values of the quantified variable NOT covered by any projection test. This is the shape of the universality loss at the `lean → tdd` boundary — surface it explicitly rather than pretending the suite re-verifies the proof.
- **Unbacked behavioral contracts**: list every `behavioral_claim` test so the reader can see which claims the suite asserts without formal support.

Report every gap at the end of the test file in a dedicated comment block.

### 8. Mark Every Generated Test as Skipped

**All tests start skipped — no exceptions.** Apply a skip/pending annotation to every test in the file using the target framework's idiom. The implementation skill (`realize-specification`) un-skips them one at a time. This ensures the newly-added suite does not turn CI red on merge — the tests are a specification, not a regression check on existing behavior.

The implementor's workflow is: pick the next skipped test top-to-bottom, remove the skip annotation, run the suite, watch it fail, implement until it passes, commit, repeat. The skip state is the TDD progress ledger.

Open-assumption stubs (from Step 4) stay skipped with their own reason — `skip(reason="assumption not proven — verify manually")` — so the implementor can distinguish "not yet implemented" from "needs manual verification."

### 9. Write the Test File

Write to `thoughts/tests/{filename}`. **Emit real framework tests whenever `target_codebase_dir` is set** — pseudotest format is a fallback for when no target codebase is provided (or when Step 2 found no detectable test infrastructure). Filename follows the target language convention:
- Python: `test_proof_properties.py`
- TypeScript/JavaScript: `proof_properties.test.ts` or `proof_properties.spec.ts`
- Go: `proof_properties_test.go`
- Ruby: `proof_properties_spec.rb`
- Java/Kotlin: `ProofPropertiesTest.java` / `ProofPropertiesTest.kt`
- Rust: `proof_properties_tests.rs` (or inline `mod tests` block)
- Pseudocode (fallback only — no `target_codebase_dir`): `proof_properties.pseudotest`

Create `thoughts/tests/` if it doesn't exist.

## Output Format

### Language-specific test file

When a target language is detected, the file should open with a header comment block, then proceed in phases:

```
// =============================================================================
// TDD Test Plan: {hypothesis title}
// Generated from: thoughts/lean_proof_results.pl
// Proven properties covered: {N} / {total}
// test_category breakdown: {P} projection, {B} behavioral_claim
// Coverage gaps: {K} (see bottom of file)
// =============================================================================
//
// These tests encode machine-verified invariants. They are written to FAIL
// until the implementation is correct. Work top-to-bottom: each phase builds
// on the last. Every generated test is marked skipped/pending so the suite
// stays green in CI — the implementor unskips each test as they drive it to
// passing.
//
// Boundary: lean → tdd. A green `projection` test is a witness, not a re-proof
// of ∀x.P(x). `behavioral_claim` tests have no upstream proof — distinguish
// them from projections in the log.

// --- Phase 1: {phase name} ---
// Implements properties: {list}

{framework import block}

{setup / fixture definitions drawn from Prolog KB domain entities}

test("{property_name}: {human description}", () => {
  // Property: {full property statement from lean_proof_results.pl}
  // Proven in: {.lean file name}
  // test_category: projection
  // epistemic_label: {descriptive | counterfactual | prescriptive}
  // negation_provenance: {absent | contradicts}   // omit if not applicable
  // sampled_from: {quantified domain}
  // fixture_set: {concrete values}
  // unsampled_domain: {what this test does NOT cover}
  // Given
  const input = {concrete fixture};
  // When
  const result = functionUnderTest(input);
  // Then
  expect(result).to{assertion};
});

test("{property_name} — edge: {edge predicate description}", () => {
  // Edge predicate from hypothesis: {sub-claim text}
  // Given
  ...
});

// --- Phase 2: {phase name} ---
// Implements properties: {list}
// Depends on: Phase 1 ({specific properties})

...

// =============================================================================
// COVERAGE GAPS
// The following proven properties could not be directly translated to tests.
// Manual verification or property-based testing is required.
//
// GAP: {property_name}
//   Reason: {why it couldn't be translated}
//   test_category breakdown affected: {projection | behavioral_claim}
//   Suggested approach: {manual check / PBT / integration test}
// =============================================================================
```

### Pseudotest format (no language detected)

When no target language is identifiable, use a language-agnostic given/when/then format:

```
# =============================================================================
# TDD Test Plan: {hypothesis title}
# Generated from: thoughts/lean_proof_results.pl
# =============================================================================

## Phase 1: {phase name}

### TEST: {test_name}
Property: {full statement from lean_proof_results.pl}
Proven in: {.lean file}
test_category: projection
epistemic_label: {descriptive | counterfactual | prescriptive}
negation_provenance: {absent | contradicts}   # omit if not applicable
sampled_from: {quantified domain}
fixture_set: {concrete values}
unsampled_domain: {what this test does NOT cover}

GIVEN:
  {setup — concrete values drawn from Prolog KB facts when available}
WHEN:
  {the operation under test is called with those inputs}
THEN:
  {the assertion — what must hold, in plain English}

EDGE CASE: {test_name}_empty
Edge predicate from hypothesis: {text}
test_category: projection
GIVEN: empty input
WHEN: ...
THEN: ...

### TEST: {behavioral_test_name}
test_category: behavioral_claim
# No upstream proof — this is a TDD-layer claim about I/O / state /
# concurrency / timing. Failure indicates a contract gap, not a bug in
# any proven property.
GIVEN: ...
WHEN: ...
THEN: ...
```

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
- Counterfactuals flagged EXTRANEOUS (to prune next cycle)
- Coverage gaps (proven properties that couldn't be translated, with reasons)
- **test_category breakdown**: N projection, M behavioral_claim (these are the only two values)
- **epistemic_label breakdown** (diagnostic): how many tests inherited `descriptive`, `counterfactual`, `prescriptive`
- **negation_provenance breakdown** (diagnostic, where applicable): how many tests rest on `absent` (CWA, fragile) vs `contradicts` (explicit, structural)
- Unsampled-domain count per property (from Step 7)

## Guidance

- **Tests ARE the plan**: Do not write a separate implementation plan document. The test file, read top-to-bottom, is the implementor's roadmap. Phase headers, property comments, and gap annotations carry all the planning information.

- **A passing projection test samples one point in a proof domain. It does not re-verify ∀x.P(x).** When a `projection` test passes, the fixture satisfies the property — the proof remains the authority on universality. Never describe a test-green state as "property verified" in downstream artifacts; use "property witnessed" or "sampled and passed." This is the universality-loss enforcement at the `lean → tdd` boundary.

- **A `behavioral_claim` test has no proof ancestry — distinguish it from a projection in the log.** Tests covering I/O, state, concurrency, or timing live entirely in the TDD layer. They must be visibly separated from `projection` tests in both the suite (Phase B at the bottom) and the report (test_category breakdown). Do not let a behavioral assertion masquerade as a formal guarantee.

- **Failing is correct, but skip by default**: Every test in the file should fail on a blank implementation. If a test would pass without any implementation, it is not testing anything. Check your assertions — trivially-true assertions (e.g., `expect(undefined).toBeFalsy()`) are silent specification rot. Because these tests are generated ahead of implementation, mark every generated test as skipped/pending in the target framework's idiom so the newly-added suite does not break CI on merge. The implementor unskips each test one at a time as they drive it green — the skip annotation doubles as a progress marker.

- **Name tests after properties, not after code**: `test_auth_token_invalid_after_expiry` (what must hold) is better than `test_tokenService_checkExpiry` (which function is called). The property name survives refactoring; the function name may not.

- **Edge predicates are not optional**: Every boundary condition from `hypothesis.pl` must appear as at least one test. Proofs are proven on models; edge cases are where models diverge from reality. Do not skip them.

- **Assumptions become TODOs, not omissions**: When a proven property depends on an open assumption (flagged in `hypothesis.pl`), include the test as a clearly-marked stub — `it.todo(...)`, `@pytest.mark.skip(reason="...")`, or a `// ASSUMPTION: ...` comment. The implementor must know the gap exists.

- **Prolog facts are free fixtures**: Named entities from the KB (e.g., `depends_on(auth_lib, crypto_lib)`) are ready-made test inputs. Use `auth_lib` and `crypto_lib` as concrete values in tests rather than `foo` and `bar`. Real names produce more meaningful failure messages.

- **Flag gaps loudly**: If a proven property resists translation (existential witness, infinite structure, timing property), put it in the COVERAGE GAPS block at the bottom of the file. Do not silently drop formal guarantees. The gap section tells the implementor where additional test investment is needed.

- **Match the existing test style exactly**: The Explore sub-agent (Step 2) discovers the project's testing conventions early. Use those discoveries to ensure every generated test matches the framework, naming, assertion style, nesting, and fixture patterns already in use. Tests that look foreign are tests that get rewritten before they're run. Matching the style means generated tests integrate seamlessly and are run without adaptation.

- **Don't over-specify implementation**: A test that asserts the exact internal algorithm (e.g., checks a specific intermediate data structure) is fragile and defeats the purpose. Assert the proven property — the output contract — not the strategy for achieving it.

- **Counterfactual-removal tests are first-class**: In conditional mode, every `claim_label(_, counterfactual)` claim from the hypothesis must produce a `projection` removal test even if that test looks "trivial." The whole point of the counterfactual lens is that LLM-driven implementors habitually reason only about what should exist; the skipped removal test is the mechanical counter-pressure. Prefer a real architecture-test tool if the project already uses one; if not, a grep/AST-scan test is fine — what matters is that the forbidden identifier is an asserted-absent string that CI will fail on if it creeps back. Tests rooted in `negation_provenance(_, absent)` are fragile (CWA default) — flag them; tests rooted in `negation_provenance(_, contradicts)` are structurally necessary.

- **Reintroduction tests lock in load-bearing reasoning**: A NECESSARY counterfactual was proven to be the reason the property holds. The reintroduction test — "if we put it back, the property breaks" — is the only mechanism that prevents silent regression when a future contributor un-deletes the fact without re-running the proof. Do not skip these; they are the most high-value artifact conditional mode produces.

- **A failing `behavioral_claim` test is not a loopback signal.** `projection` test failures can loop back to `decompose-proposition` or `model-obligations` / `prove-invariants` because the upstream proof produced the property. `behavioral_claim` failures stop at the TDD layer — the formal pipeline never expressed the claim, so there is nothing to re-prove. The implementor decides whether the claim is correct or the implementation is wrong.
