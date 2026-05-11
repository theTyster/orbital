# Test file templates

Two output shapes for `instantiate-properties`. Pick by environment:

- **Language-specific** — when `target_codebase_dir` is set and Step 2 detected a test framework.
- **Pseudotest** — fallback when no target codebase is provided or no framework was detected.

Both shapes share the same comment-block schema (see SKILL.md "Canonical tag table"); only the surrounding syntax differs.

## File header (both shapes)

Open the file with a header that summarises the run:

- Hypothesis title (from the proposition in `hypothesis.pl`).
- Source artifact: `thoughts/lean_proof_results.pl`.
- Proven properties covered: `N / total`.
- `test_category` breakdown: `P projection, B behavioral_claim`.
- Loopback signals: count, with a pointer to the `LOOPBACK SIGNALS` block.
- Coverage gaps: count, with a pointer to the `COVERAGE GAPS` block.
- Boundary reminder: a green `projection` test is a witness at one fixture, not a re-proof of `∀x.P(x)`. `behavioral_claim` tests have no upstream proof.

## Phase ordering

Render phases in this order (omit any that have no tests):

1. **Phase 0 — Removal** (conditional mode only): counterfactual-removal and reintroduction tests.
2. **Phase 1 — Foundations**: `projection` tests for properties with no dependencies.
3. **Phase 2..N — Compositions / Integration**: `projection` tests that compose earlier phases.
4. **Phase B — Behavioral Contracts**: `behavioral_claim` tests, always last.

Each phase header lists the properties it implements and the phases it depends on.

## Per-test comment block

Every test — projection or behavioral — opens with a comment block carrying its tags. Order:

```
// Property: {full property statement from formal_property/3}
// Proven in: {theorem_source/2 path}
// proof_strategy: {proof_strategy/2 value}      // omit for behavioral_claim
// test_category: projection | behavioral_claim
// ontology_label: descriptive | counterfactual | prescriptive   // omit for behavioral_claim
// negation_provenance: absent | contradicts                       // omit if no negated premise
// sampled_from: {quantified domain}                               // projection only
// fixture_set: {concrete values}                                  // projection only
// unsampled_domain: {what this test does NOT cover}               // projection only
```

`behavioral_claim` tests omit `proof_strategy`, `ontology_label`, `sampled_from`, `fixture_set`, and `unsampled_domain` — they have no proof ancestry.

## Language-specific shape (TypeScript / Jest example)

```ts
// =============================================================================
// TDD Test Plan: {hypothesis title}
// Generated from: thoughts/lean_proof_results.pl
// Proven properties covered: {N} / {total}
// test_category breakdown: {P} projection, {B} behavioral_claim
// Loopback signals: {L} (see LOOPBACK SIGNALS block)
// Coverage gaps: {K} (see COVERAGE GAPS block)
// =============================================================================

// --- Phase 1: {phase name} ---
// Implements properties: {list}

{framework import block}
{setup / fixture definitions drawn from Prolog KB domain entities}

test.skip("{property_name}: {human description}", () => {
  // Property: {full statement}
  // Proven in: {.lean file}
  // proof_strategy: {strategy}
  // test_category: projection
  // ontology_label: {label}
  // negation_provenance: {mode}                 // omit if N/A
  // sampled_from: {domain}
  // fixture_set: {values}
  // unsampled_domain: {gaps}
  const input = {concrete fixture};
  const result = functionUnderTest(input);
  expect(result).to{assertion};
});

// --- Phase B: Behavioral Contracts ---
// No upstream proof. Failures indicate contract gaps, not invariant violations.

test.skip("{behavioral_test_name}", () => {
  // test_category: behavioral_claim
  ...
});

// =============================================================================
// LOOPBACK SIGNALS
// Each entry names the upstream skill to revisit and the trigger.
//
// SIGNAL: extraneous-counterfactual
//   Skill: decompose-proposition
//   Trigger: necessity_lemma_status({theorem}, {fact}, extraneous)
//   Action: prune {fact} from the hypothesis next cycle
// =============================================================================

// =============================================================================
// COVERAGE GAPS
// Advisory only — these do NOT loop back. Implementor handles manually.
//
// GAP: {property_name}
//   Reason: {why it couldn't be translated}
//   Suggested approach: {manual check / PBT / integration test}
// =============================================================================
```

Adapt the skip idiom and assertion library to the framework Step 2 detected:

| Framework | Skip idiom | Test idiom |
|---|---|---|
| Jest / Mocha | `test.skip(...)` / `it.skip(...)` | `test("...", () => {})` |
| pytest | `@pytest.mark.skip(reason="...")` | `def test_foo():` |
| RSpec | `xit "..."` or `skip "..."` | `it "..." do ... end` |
| Go | `t.Skip("...")` | `func TestFoo(t *testing.T)` |
| JUnit | `@Disabled("...")` | `@Test void foo()` |
| Rust | `#[ignore]` | `#[test] fn foo()` |

## Pseudotest shape (no framework detected)

```
# =============================================================================
# TDD Test Plan: {hypothesis title}
# Generated from: thoughts/lean_proof_results.pl
# =============================================================================

## Phase 1: {phase name}

### TEST: {test_name}                                 [skipped]
Property: {full statement from formal_property/3}
Proven in: {.lean file}
proof_strategy: {strategy}
test_category: projection
ontology_label: {label}
negation_provenance: {mode}                           # omit if N/A
sampled_from: {domain}
fixture_set: {values}
unsampled_domain: {gaps}

GIVEN:
  {setup — concrete values drawn from Prolog KB facts when available}
WHEN:
  {the operation under test is called with those inputs}
THEN:
  {the assertion — what must hold, in plain English}

### TEST: {behavioral_test_name}                      [skipped]
test_category: behavioral_claim
# No upstream proof — this is a TDD-layer claim about I/O / state /
# concurrency / timing. Failure indicates a contract gap, not a bug in
# any proven property.
GIVEN: ...
WHEN: ...
THEN: ...

## LOOPBACK SIGNALS
- extraneous-counterfactual → decompose-proposition: prune {fact}
- insufficient-proof → decompose-proposition: enumerate more counterfactuals

## COVERAGE GAPS
- GAP: {property_name} — {reason} — {suggested approach}
```

## Skip-state contract

Every emitted test is skipped — no exceptions. The skip annotation doubles as the TDD progress ledger: `realize-specification` un-skips one test at a time, drives the implementation to green, then commits.

Open-assumption stubs use a distinguishing reason: `skip(reason="assumption not proven — verify manually")`, so the implementor can tell "not yet implemented" from "needs manual verification".

## Filename conventions

| Language | Filename |
|---|---|
| Python | `test_proof_properties.py` |
| TypeScript / JavaScript | `proof_properties.test.ts` or `proof_properties.spec.ts` |
| Go | `proof_properties_test.go` |
| Ruby | `proof_properties_spec.rb` |
| Java / Kotlin | `ProofPropertiesTest.java` / `ProofPropertiesTest.kt` |
| Rust | `proof_properties_tests.rs` (or inline `mod tests`) |
| Pseudotest fallback | `proof_properties.pseudotest` |

Write to `thoughts/tests/{filename}`. Create the directory if it does not exist.
