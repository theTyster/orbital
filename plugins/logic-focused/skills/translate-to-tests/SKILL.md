---
name: translate-to-tests
description: >
  Translate proven formal properties into TDD test cases that serve as the implementation plan. Reads proof_results.md and optionally hypothesis.md and Prolog KB to generate tests where each test verifies a proven invariant. An implementor uses these failing tests to drive implementation. Use when: "translate proof to tests", "generate tests from proof", "create TDD plan", "tests from verified logic".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Agent
argument-hint: "[proof_results.md path] [optional: target codebase directory]"
---

# Translate to Tests

Generate a TDD test suite from proven formal properties. The tests ARE the implementation plan: each test encodes a machine-verified invariant that the implementation must satisfy. An implementor runs the suite, watches it fail, and drives their code toward green. No separate plan document is produced — the test file is the deliverable.

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
- Property name and its Lean theorem statement
- The natural language description
- The proof strategy (hints at what the implementation must do)
- Which hypothesis it was derived from

If `thoughts/hypothesis.md` exists, also extract:
- The original proposition (context for naming tests meaningfully)
- Sub-hypotheses and their status: confirmed, refuted, or assumed
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

### 6. Assign Tests to Phases

Organize tests into phases that reflect the logical dependency ordering from the proofs. A phase's tests should only depend on behavior proven in earlier phases:

- **Phase 1 — Foundations**: Tests for properties with no dependencies. These test base types, pure functions, stateless transformations.
- **Phase 2 — Compositions**: Tests for properties that compose Phase 1 behaviors. These may require Phase 1 to pass before they are meaningful.
- **Phase N — Integration**: Tests for end-to-end properties that span the full system.

Within each phase, order tests from simplest (empty/trivial cases) to most complex (boundary/stress cases). An implementor should be able to work top-to-bottom through the file.

### 7. Identify Coverage Gaps

After mapping all proven properties, scan for anything that could not be translated:

- Proven properties with pure existential statements ("there exists X") that are hard to assert deterministically without knowing the witness — flag these as manual verification items
- Properties about infinite structures (termination, totality) that require property-based testing tooling — flag these and suggest a PBT library (Hypothesis, fast-check, QuickCheck) if appropriate
- Properties that depend on unprovable assumptions (from Step 1) — stub the test with a clear TODO

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
- Coverage gaps (proven properties that couldn't be translated, with reasons)

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
