---
name: translate-to-tests
description: >
  Reads proof_results.md and hypothesis.md if available; produces a skipped test suite where each test encodes a machine-verified invariant — including absence tests for counterfactual requirements — to drive implementation.
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Agent
argument-hint: "[proof_results.md path] [optional: target codebase directory]"
---

# Translate to Tests

Generate a TDD test suite from proven formal properties. The tests ARE the implementation plan: each test encodes a machine-verified invariant that the implementation must satisfy. An implementor runs the suite, watches it fail, and drives their code toward green. No separate plan document is produced — the test file is the deliverable.

**Two kinds of invariants to translate.** Invariant-mode proofs yield *presence tests* — assertions that something must hold. Conditional-mode proofs (where a property holds only after specific KB facts are falsified) yield **absence tests** and **guard tests** — assertions that a named counterfactual fact must no longer be reachable, and that each such fact was load-bearing (NECESSARY). Both must appear in the suite, because the "only reason about what exists" bias that this pipeline is designed to counter re-enters if absence tests are skipped.

**The sampling downgrade and the behavioral gain.** Every test that witnesses a proven universal is a *sample*: `∀ x : T, P(x)` becomes `P(specific_fixture)`. Green means this fixture satisfies the property; the universal is NOT re-proved by the suite. Conversely, TDD can express claims Lean cannot reason about at all: I/O, state mutation, timing, concurrency, side effects. These are behavioral additions with no upstream proof. Therefore every generated test carries an epistemic tag: `TEST_PROJECTED` (sampled from a proof), `TEST_ABSENCE` (sampled from a counterfactual requirement — doubly weak if the counterfactual was CWA-lifted), `TEST_GUARD` (behavioral witness of a necessity lemma), or `TEST_BEHAVIORAL` (no upstream proof — first-class TDD claim). Dropping these tags silently upgrades a fixture witness to "proven" and treats a behavioral claim as a formal guarantee. Reference: `../../references/epistemic-types.md`.

## Input

- **Required**: `thoughts/proof_results.md` from the prove-hypothesis-lean skill
- **Optional**: `thoughts/hypothesis.md` — provides edge predicates, open assumptions, and the original proposition's scope
- **Optional**: Any `.pl` files in `thoughts/` — Prolog KB facts expose dependency ordering, relationship constraints, and domain predicates that map to setup/teardown and edge case tests
- **Optional**: A target codebase directory — used to detect the target language and discover existing test conventions

Read all available inputs before writing a single test. The richest test suites come from combining three sources: proven properties (what must hold), hypotheses (what was explored), and Prolog facts (the structural ground truth).

## Process

**When a target codebase directory is provided, Step 2 (Discover Test Patterns) happens immediately after Step 1, before any test mapping begins. This discovery ensures all subsequent steps generate tests that naturally conform to the project's existing testing conventions.**

### 1. Read All Inputs

Read `thoughts/proof_results.md`. Extract for each proven property:
- Property name and its Lean theorem statement (or Prolog query)
- The natural language description
- The proof strategy (hints at what the implementation must do)
- Which hypothesis it was derived from
- **Proof mode** — `invariant` or `conditional`. The header of each result in `proof_results.md` carries this field.
- **Extract `Epistemic origin` for each property**: `LEAN_UNIVERSAL`, `LEAN_CONDITIONAL`, `LEAN_CWA_LIFTED`, or `PROLOG_MODEL_VERIFIED` — this tag flows onto every projected test that witnesses the property.
- **Note the `CWA-lifted premises` / `CWA-bound premises` field (if present)**. Tests that sample across those premises inherit `CWA_LIFTED` weakness and must flag it in their comment blocks.
- If `conditional`, also extract:
  - **Counterfactual facts** — the KB facts enumerated in the hypothesis that had to be false for the property to hold (e.g., `cf_fact(cli_tool, logging)`)
  - **Per-counterfactual status** — each fact is labelled `NECESSARY` (removing it is load-bearing) or `EXTRANEOUS` (the property holds without requiring its removal)
  - **Overall status** — `SUFFICIENT` (the counterfactual set proves the property) or `INSUFFICIENT` (the set was not enough)

If `thoughts/hypothesis.md` exists, also extract:
- The original proposition (context for naming tests meaningfully)
- The **counterfactual question** — "What about the existing KB would need to be false for `{proposition}` to be true?" — surfaces the intent behind every absence test
- Sub-hypotheses and their status: clear, conditional, or open
- **Counterfactual requirements** — for each conditional sub-hypothesis, the list of KB facts that must be falsified. These become absence tests.
- **Edge predicates** — boundary conditions identified during exploration. These become edge case tests.
- **Assumptions** — properties taken as given during proof. These become test preconditions or fixture setup.
- Counterevidence found during exploration — even refuted claims may need a "does NOT do X" test

If `.pl` files exist in `thoughts/`, scan them for:
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

For each proven property, produce at least one test. The mapping follows this logic:

| Property shape | Test type | What to assert |
|---------------|-----------|----------------|
| "For all X, P(X) holds" | Parameterized / table-driven test | P holds for a representative sample covering boundary values |
| "If A then B" | Conditional test | Given A is set up, assert B is produced |
| "A and B are equivalent" | Bidirectional test | Two cases: A→B holds; B→A holds |
| "There is no state S where invariant fails" | Negative/guard test | Assert that constructing invalid state S either raises or returns an error |
| "X is monotone / order-preserving" | Ordering test | Assert output ordering matches input ordering contract |
| "X terminates / is finite" | Bounds test | Assert result count, length, or depth is within expected bound |
| "X is idempotent" | Idempotency test | Assert applying operation twice equals applying it once |

For each property, write the test name to encode the property plainly:
- `test_sorted_output_preserves_all_elements`
- `test_auth_token_invalid_after_expiry`
- `test_no_duplicate_entries_after_insert`

The property name, or a compressed form of it, should appear in the test name. An implementor reading the failing test output should immediately know which formal invariant is violated.

**Record the sample.**

- Every projected test must document, in its comment block, (a) the proven property it samples (`sampled_from:`), (b) the specific fixture values chosen (`fixture_set:`), (c) the unsampled domain — what values of the quantified variable the test does NOT cover (`unsampled_domain:`), and (d) the inherited epistemic origin (`epistemic_origin:`, one of `TEST_PROJECTED` / `TEST_PROJECTED+CWA_LIFTED` / etc.).
- This turns each test into a typed witness, not a "proof restated." The suite is a tripwire; the proof is still the authority.

### 3.5. Translate Counterfactual Requirements into Absence & Guard Tests

**Only applies when at least one proven property is in `conditional` mode.** For every counterfactual fact extracted in Step 1, emit two tests:

**Absence test** — asserts that the fact no longer holds in the implementation. The exact assertion depends on the fact's shape:

| Counterfactual fact shape | Absence test asserts |
|---|---|
| `depends_on(cli_tool, logging)` | No import/require/use statement from `cli_tool`'s module to `logging`'s module |
| `calls(moduleA, functionB)` | Static search of `moduleA`'s source turns up zero references to `functionB` |
| `exposes(service, endpoint)` | `service`'s public surface does not include `endpoint` (route table, export list, etc.) |
| `reads(worker, resource)` | `worker` has no code path that opens/queries `resource` |
| `config_has(component, flag)` | The config file or initialisation code does not set `flag` for `component` |

Absence tests are typically architectural/lint-style tests: they use import-graph inspection, AST scans, grep-style assertions, or public-API snapshot diffs — not runtime behaviour. Prefer the project's existing architecture-test idiom if one was found in Step 2 (e.g., `dependency-cruiser`, `archunit`, `ts-arch`, `import-linter`, `depguard`, a bespoke `forbidden_imports_test.go`). If none exists, use a direct source-scan test (read the file, assert the forbidden identifier is absent).

**Guard test** — one per counterfactual fact labelled `NECESSARY` in the proof results. This test re-introduces the fact at runtime or in a fixture and asserts that the invariant breaks in a detectable way (compilation failure captured as a meta-test, a runtime error, a failing higher-level test). A guard test locks in the reason the counterfactual was enumerated in the first place: future maintainers cannot silently re-introduce the dependency without a visible failure.

If a counterfactual fact was labelled `EXTRANEOUS`, **do not emit a guard test** — the proof showed removing it was not load-bearing. Instead, add a single `COVERAGE GAPS` note that this fact should be pruned from the hypothesis next cycle. An absence test is still generated (the fact is still part of the target relation and should not creep back in during implementation) but its comment must flag the `EXTRANEOUS` status.

Naming convention for these tests:
- Absence: `test_no_{source}_depends_on_{target}` / `test_{module}_does_not_import_{other}` / `test_{component}_lacks_{endpoint}`
- Guard:   `test_reintroducing_{fact}_breaks_{property}` / `test_{property}_requires_absence_of_{fact}`

**Epistemic-origin tagging.** Every absence test carries `TEST_ABSENCE` and — if its counterfactual's origin in hypothesis.md was `KB_ABSENT_CWA` — additionally `CWA_LIFTED`. Every guard test carries `TEST_GUARD`. These tags go in the test's comment block and in the suite header summary.

### 4. Derive Edge Case Tests from Hypothesis

From `thoughts/hypothesis.md`, extract every boundary condition or edge predicate identified during exploration:

- **Empty inputs**: If the hypothesis explored "what happens at zero elements," write an empty-input test
- **Single elements**: If the hypothesis identified base-case behavior, write a singleton test
- **Maximum cardinality**: If the hypothesis identified upper bounds, write a test at that bound
- **Refuted sub-hypotheses**: If exploration found that a claim does NOT hold, write a test asserting the correct (observed) behavior — this locks in the understanding
- **Open assumptions**: Write tests as `// TODO: assumption not proven — verify manually` stubs, or mark with a skip/pending annotation in the target framework

Each edge case test must comment which sub-hypothesis or edge predicate it encodes.

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

- Some test needs cannot be projections of any proven property. Side effects, I/O sequencing, timing, concurrency, error-mode behaviour, and integration-level state transitions live in the TDD layer and nowhere else.
- If the implementor explicitly asked for behavioral tests, or if the target codebase clearly requires them (e.g., a server handler that must return 503 on backpressure), generate them — but tag each one `TEST_BEHAVIORAL` in its comment block and list them under a dedicated `## Behavioral Contracts` section at the bottom of the test file (above `COVERAGE GAPS`).
- `TEST_BEHAVIORAL` claims have no upstream formal backing. A failing behavioral test cannot loop back to `hypothesize` or `prove-hypothesis-*` — those nodes never expressed the claim. The classification matters for `translate-to-implementation`'s loopback logic.
- If no behavioral additions are needed, skip this step — but note in the suite header "no behavioral additions".

### 6. Assign Tests to Phases

Organize tests into phases that reflect the logical dependency ordering from the proofs. A phase's tests should only depend on behavior proven in earlier phases:

- **Phase 0 — Removal** *(conditional mode only)*: Absence and guard tests derived from counterfactual requirements (Step 3.5). These come first because every later phase's property is stated against the target relation `R_target := R ∧ ¬cf`. Implementing Phase 1 before Phase 0 produces code that satisfies an invariant *while* the forbidden dependency still exists — passing tests for the wrong reason. Phase 0 forces the deletion/removal work to happen before any new behaviour is written.
- **Phase 1 — Foundations**: Tests for properties with no dependencies. These test base types, pure functions, stateless transformations.
- **Phase 2 — Compositions**: Tests for properties that compose Phase 1 behaviors. These may require Phase 1 to pass before they are meaningful.
- **Phase N — Integration**: Tests for end-to-end properties that span the full system.
- **Phase B — Behavioral Contracts**: `TEST_BEHAVIORAL` tests from Step 5.5. This phase runs AFTER all projected phases. Behavioral phase tests may remain red longer because they have no proof to lean on; the implementor decides when they pass.

Within each phase, order tests from simplest (empty/trivial cases) to most complex (boundary/stress cases). An implementor should be able to work top-to-bottom through the file.

### 7. Identify Coverage Gaps

After mapping all proven properties, scan for anything that could not be translated:

- Proven properties with pure existential statements ("there exists X") that are hard to assert deterministically without knowing the witness — flag these as manual verification items
- Properties about infinite structures (termination, totality) that require property-based testing tooling — flag these and suggest a PBT library (Hypothesis, fast-check, QuickCheck) if appropriate
- Properties that depend on unprovable assumptions (from Step 1) — stub the test with a clear TODO
- **EXTRANEOUS counterfactuals** (from Step 1): each fact the proof flagged as non-load-bearing belongs in the gap block with the recommendation "prune from hypothesis next cycle" — the absence test is still emitted but the hypothesis was imprecise.
- **INSUFFICIENT proof status**: if the overall proof was `INSUFFICIENT`, the counterfactual set did not close the gap. Record the entire conditional property as a coverage gap with the recommendation "loop back to `hypothesize` — additional counterfactual requirements needed."
- Properties that were left in `conditional` mode but produced no enumerable counterfactual facts — these cannot become absence tests and must be flagged.
- **Unsampled domain slices**: for each `∀`-quantified property, list values of the quantified variable NOT covered by any projected test. This is the shape of the sampling downgrade — surface it explicitly rather than pretending the suite re-verifies the proof.
- **Unbacked behavioral contracts**: list every `TEST_BEHAVIORAL` test so the reader can see which claims the suite asserts without formal support.

Report every gap at the end of the test file in a dedicated comment block.

### 8. Mark Every Generated Test as Skipped

Before writing, apply a skip/pending annotation to every test in the file using the target framework's idiom. This ensures the newly-added suite does not turn CI red on merge — the tests are a specification, not a regression check on existing behavior.

The implementor's workflow is: pick the next skipped test top-to-bottom, remove the skip annotation, run the suite, watch it fail, implement until it passes, commit, repeat. The skip state is the TDD progress ledger.

Open-assumption stubs (from Step 4) stay skipped with their own reason — `skip(reason="assumption not proven — verify manually")` — so the implementor can distinguish "not yet implemented" from "needs manual verification."

### 9. Write the Test File

Write to `thoughts/tests/{filename}` where filename follows the target language convention:
- Python: `test_proof_properties.py`
- TypeScript/JavaScript: `proof_properties.test.ts` or `proof_properties.spec.ts`
- Go: `proof_properties_test.go`
- Ruby: `proof_properties_spec.rb`
- Java/Kotlin: `ProofPropertiesTest.java` / `ProofPropertiesTest.kt`
- Rust: `proof_properties_tests.rs` (or inline `mod tests` block)
- Pseudocode: `proof_properties.pseudotest`

Create `thoughts/tests/` if it doesn't exist.

## Output Format

### Language-specific test file

When a target language is detected, the file should open with a header comment block, then proceed in phases:

```
// =============================================================================
// TDD Test Plan: {hypothesis title}
// Generated from: thoughts/proof_results.md
// Proven properties covered: {N} / {total}
// Coverage gaps: {K} (see bottom of file)
// =============================================================================
//
// These tests encode machine-verified invariants. They are written to FAIL
// until the implementation is correct. Work top-to-bottom: each phase builds
// on the last. Every generated test is marked skipped/pending so the suite
// stays green in CI — the implementor unskips each test as they drive it to
// passing.

// --- Phase 1: {phase name} ---
// Implements properties: {list}

{framework import block}

{setup / fixture definitions drawn from Prolog KB domain entities}

test("{property_name}: {human description}", () => {
  // Property: {full property statement from proof_results.md}
  // Proven in: {.lean file name}
  // epistemic_origin: {TEST_PROJECTED | TEST_PROJECTED+CWA_LIFTED | TEST_ABSENCE | TEST_ABSENCE+CWA_LIFTED | TEST_GUARD | TEST_BEHAVIORAL}
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
  // Edge predicate from hypothesis: {sub-hypothesis text}
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
//   Suggested approach: {manual check / PBT / integration test}
// =============================================================================
```

### Pseudotest format (no language detected)

When no target language is identifiable, use a language-agnostic given/when/then format:

```
# =============================================================================
# TDD Test Plan: {hypothesis title}
# Generated from: thoughts/proof_results.md
# =============================================================================

## Phase 1: {phase name}

### TEST: {test_name}
Property: {full statement from proof_results.md}
Proven in: {.lean file}
epistemic_origin: {TEST_PROJECTED | TEST_PROJECTED+CWA_LIFTED | TEST_ABSENCE | TEST_ABSENCE+CWA_LIFTED | TEST_GUARD | TEST_BEHAVIORAL}
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
GIVEN: empty input
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
- **Absence tests** generated from counterfactual requirements (conditional mode only)
- **Guard tests** generated for NECESSARY counterfactuals (conditional mode only)
- Counterfactuals flagged EXTRANEOUS (to prune next cycle)
- Coverage gaps (proven properties that couldn't be translated, with reasons)
- Epistemic tag breakdown: N projected, M absence, K guard, B behavioral.
- Unsampled-domain count per property (from Step 7).

## Guidance

- **Tests ARE the plan**: Do not write a separate implementation plan document. The test file, read top-to-bottom, is the implementor's roadmap. Phase headers, property comments, and gap annotations carry all the planning information.

- **Failing is correct, but skip by default**: Every test in the file should fail on a blank implementation. If a test would pass without any implementation, it is not testing anything. Check your assertions — trivially-true assertions (e.g., `expect(undefined).toBeFalsy()`) are silent specification rot. Because these tests are generated ahead of implementation, mark every generated test as skipped/pending in the target framework's idiom so the newly-added suite does not break CI on merge. The implementor unskips each test one at a time as they drive it green — the skip annotation doubles as a progress marker.

- **Name tests after properties, not after code**: `test_auth_token_invalid_after_expiry` (what must hold) is better than `test_tokenService_checkExpiry` (which function is called). The property name survives refactoring; the function name may not.

- **Edge predicates are not optional**: Every boundary condition from `hypothesis.md` must appear as at least one test. Proofs are proven on models; edge cases are where models diverge from reality. Do not skip them.

- **Assumptions become TODOs, not omissions**: When a proven property depends on an open assumption (flagged in `hypothesis.md`), include the test as a clearly-marked stub — `it.todo(...)`, `@pytest.mark.skip(reason="...")`, or a `// ASSUMPTION: ...` comment. The implementor must know the gap exists.

- **Prolog facts are free fixtures**: Named entities from the KB (e.g., `depends_on(auth_lib, crypto_lib)`) are ready-made test inputs. Use `auth_lib` and `crypto_lib` as concrete values in tests rather than `foo` and `bar`. Real names produce more meaningful failure messages.

- **Flag gaps loudly**: If a proven property resists translation (existential witness, infinite structure, timing property), put it in the COVERAGE GAPS block at the bottom of the file. Do not silently drop formal guarantees. The gap section tells the implementor where additional test investment is needed.

- **Match the existing test style exactly**: The Explore sub-agent (Step 2) discovers the project's testing conventions early. Use those discoveries to ensure every generated test matches the framework, naming, assertion style, nesting, and fixture patterns already in use. Tests that look foreign are tests that get rewritten before they're run. Matching the style means generated tests integrate seamlessly and are run without adaptation.

- **Don't over-specify implementation**: A test that asserts the exact internal algorithm (e.g., checks a specific intermediate data structure) is fragile and defeats the purpose. Assert the proven property — the output contract — not the strategy for achieving it.

- **Absence tests are first-class**: In conditional mode, every counterfactual fact from the hypothesis must produce an absence test even if that test looks "trivial." The whole point of the counterfactual lens is that LLM-driven implementors habitually reason only about what should exist; the skipped absence test is the mechanical counter-pressure. Prefer a real architecture-test tool if the project already uses one; if not, a grep/AST-scan test is fine — what matters is that the forbidden identifier is an asserted-absent string that CI will fail on if it creeps back.

- **Guard tests lock in load-bearing reasoning**: A NECESSARY counterfactual was proven to be the reason the property holds. The guard test — "if we put it back, the property breaks" — is the only mechanism that prevents silent regression when a future contributor un-deletes the fact without re-running the proof. Do not skip these; they are the most high-value artifact conditional mode produces.

- **A green test is a sample, not a re-proof.** When a projected test passes, the fixture satisfies the property — the proof remains the authority on universality. Never describe a test-green state as "property verified" in downstream artifacts; use "property witnessed" or "sampled and passed."

- **Behavioral contracts have no upstream proof.** `TEST_BEHAVIORAL` tests assert things the formal layer never expressed — side effects, timing, concurrency. A failing behavioral test is not a loopback signal to `hypothesize`; it is a TDD-layer decision.
