# test-shape-mapping

Reference for translating the *shape* of a proven property into the *shape* of a concrete projection test. Sibling references: `tagging.md` (per-test comment-block fields), `counterfactual-tests.md` (removal / reintroduction handling). Up-tree: `../../../references/epistemic-types.md` for the semantics of the universality-loss tags.

## 1. Overview

Every projection test emitted by `instantiate-properties` is a **witness** of a universally-proven property at a single fixture. It is not a re-proof. The pipeline's authority on universality lives in `thoughts/lean/Proofs/*.lean` and `thoughts/lean_proof_results.pl`; the test suite is a tripwire that fires when the implementation diverges from a sample point.

Universality is **intentionally discarded** at the `lean → tdd` boundary. A Lean theorem of shape `∀x ∈ D. P(x)` becomes `P(fixture)` for `fixture ∈ D' ⊂ D` in the suite. The lost generality is not papered over — it is recorded explicitly through three comment-block fields on every projection test:

- `sampled_from:` — the quantified domain `D` carried over from `formal_property/3` (read from `target-world.pl`, which propagates it from `hypothesis.pl`).
- `fixture_set:` — the concrete `D'` the test exercises.
- `unsampled_domain:` — what the test does **not** cover. This is the shape of the universality loss made auditable.

Aggregate `unsampled_domain` counts roll up into the suite-level `COVERAGE GAPS` block (Step 7a of SKILL.md). The pipeline never claims a passing test verifies universality; downstream language uses "witnessed" or "sampled and passed", never "verified".

`behavioral_claim` tests do not participate in this discipline because they have no upstream universal — they are new claims introduced at the TDD boundary. The mapping below applies to `projection` tests only.

## 2. Property-shape → test-shape table

For every `formal_property(Id, NLDescription, Sketch)` in `target-world.pl` whose corresponding `theorem_verdict(_, proven)` holds in `lean_proof_results.pl`, classify the property by shape and emit the matching test type. All test categories below are `projection` unless otherwise noted.

| Property shape | Test type | What to assert |
|---|---|---|
| "For all X, P(X) holds" | Parameterized / table-driven | P holds for a representative sample covering boundary values |
| "If A then B" | Conditional | Given A is set up, assert B is produced |
| "A and B are equivalent" | Bidirectional | Two cases: A→B holds; B→A holds |
| "There is no state S where invariant fails" | Negative / guard | Constructing invalid state S either raises or returns an error |
| "X is monotone / order-preserving" | Ordering | Output ordering matches input ordering contract |
| "X terminates / is finite" | Bounds | Result count, length, or depth is within expected bound |
| "X is idempotent" | Idempotency | Applying operation twice equals applying it once |
| "There exists X such that P(X)" | Witness construction (or PBT) | Construct or search for the witness; assert P(witness). Pure existentials with no constructive witness are flagged for manual / property-based testing in `COVERAGE GAPS` |
| "(X • Y) • Z = X • (Y • Z)" (associativity) | Algebraic-law | Apply operation in both groupings on a fixture triple; assert results equal |
| "X • Y = Y • X" (commutativity) | Algebraic-law | Apply operation in both orders on a fixture pair; assert results equal |
| "Set A is a subset of set B" (refinement) | Containment | Every member of fixture A appears in B; A's predicate is strictly stronger than B's |
| "X is defined for every member of D" (totality) | Domain-coverage | Iterate fixtures spanning D; assert no fixture raises an undefined / partial-function error |
| "X distributes over Y" | Algebraic-law | Compute `f(a, g(b, c))` and `g(f(a, b), f(a, c))` on a fixture triple; assert equality |
| "X is a fixed point of F" (`F(x) = x`) | Fixed-point | Apply F to fixture; assert result equals input under the relevant equality |
| "X preserves invariant I across operation Op" | Round-trip / invariant-preservation | Apply Op to fixture satisfying I; assert result still satisfies I |
| "Encoding/decoding round-trips" | Round-trip | `decode(encode(x)) == x` for fixture x |

Three reading rules for the table:

- The shape comes from the `formal_property/3` natural-language string and the Lean theorem statement together — neither alone is reliable. A `∀` quantifier in the Lean source plus prose hedging like "if A then…" means the property is conditional, and the conditional-test row applies inside the parameterized sample.
- A single property may have more than one shape. Idempotent + monotone is common; emit one parameterized test per shape and let them share fixtures.
- The `proof_strategy/2` value from `lean_proof_results.pl` is a hint about implementation, not test shape. It belongs in the `proof_strategy:` comment line, not in the assertion logic.

## 3. Naming conventions

Test names encode the **property**, not the code path. Property names survive refactoring; function names may not. The pattern is:

> `test_<observable-property>_<qualifying-condition>`

Anchor each name in domain entities pulled from the Prolog KB (`hypothesis.pl`, `target-world.pl`, the underlying facts file). Real names produce diagnosable failures.

Examples:

- `test_sorted_output_preserves_all_elements`
- `test_auth_token_invalid_after_expiry`
- `test_no_duplicate_entries_after_insert`
- `test_session_count_matches_active_users`
- `test_serialize_then_deserialize_returns_input`
- `test_no_{source}_depends_on_{target}` — counterfactual-removal projection test (e.g., `test_no_cli_tool_depends_on_logging`)
- `test_reintroducing_{fact}_breaks_{property}` — counterfactual reintroduction test (e.g., `test_reintroducing_cli_to_logging_dependency_breaks_layering`)
- `test_{property}_requires_absence_of_{fact}` — alternative reintroduction phrasing

What to avoid in names:

- Function-call shape: `test_TokenService_validate` says nothing about the property.
- Implementation strategy: `test_uses_lru_cache` couples the test to a strategy the proof never required.
- `foo` / `bar` / `obj1` placeholders — when the KB names `auth_lib`, `crypto_lib`, `cli_tool`, `logging`, use those.

The first segment after `test_` should match (or compress) the property's natural-language predicate. A reader scanning a failing-test report should be able to point at the violated invariant without opening the test file.

## 4. Sampling discipline (universality loss)

Every projection test carries three explicit fields documenting the universality discarded at this boundary. They are not optional — `tagging.md` defines them as part of the mandatory comment block.

- **`sampled_from:`** — the quantified domain stated by the property. Read from the natural-language description in `formal_property(_, NL, _)` (in `target-world.pl`). Example: `sampled_from: "all modules M such that depends_on*(cli_tool, M)"`.
- **`fixture_set:`** — the literal values the test instantiates. Pull these from the KB where possible: `cli_tool`, `formatter`, `logging` are better than fresh placeholders. Example: `fixture_set: [cli_tool, formatter, logging]`.
- **`unsampled_domain:`** — everything in `sampled_from` that the `fixture_set` does not cover. State this concretely, not as "the rest". Example: `unsampled_domain: "all modules introduced after the run, plus modules with no transitive depends_on edge to cli_tool"`.

Three rules govern sampling discipline:

- **Pick boundary values first.** Empty, singleton, maximum-cardinality, and the smallest counterexample shape from exploration (`evidence/3` in `hypothesis.pl`) carry more diagnostic weight than typical-case fixtures.
- **Reuse fixtures across tests in the same phase.** Shared fixtures make `unsampled_domain` annotations comparable and reduce the surface a future `realize-specification` invocation must un-skip.
- **Aggregate at suite level.** Each `unsampled_domain:` line contributes one entry to the COVERAGE GAPS block. The block is the suite's audit trail of universality loss; the report (Step 9 of SKILL.md) surfaces a count.

Tests that descend from a `claim_label(_, counterfactual)` claim and a corresponding `cf_fact/N` removal in `target-world.pl` use the same three fields, but `sampled_from` names the *target relation* (e.g., `depends_on_target/2`) rather than the original relation, and `unsampled_domain` covers any source/target pair the removal test does not touch.

## 5. Worked examples

Each example shows the upstream artifact, the inferred shape, the test name, and a pseudotest skeleton. Real-framework form is generated when `target_codebase_dir` is set (Step 2 of SKILL.md).

### 5.1 ∀ → parameterized

Upstream:

```prolog
% target-world.pl
formal_property(p_001,
    "for every user u, sessions(u) has at most one active session",
    "theorem at_most_one_active_session : ∀ u, ActiveCount sessions u ≤ 1 := by ...").
% lean_proof_results.pl
theorem_verdict(t_at_most_one_active_session, proven).
proof_strategy(t_at_most_one_active_session, "case-split on session list, simp with filter_length_le").
```

Test:

```
test_each_user_has_at_most_one_active_session [PARAMETERIZED]
  fixtures: [alice_admin, bob_guest, carol_disabled, dana_with_no_sessions]
  for u in fixtures:
    assert active_count(sessions_of(u)) <= 1

  # comment block
  test_category: projection
  epistemic_label: descriptive
  proof_strategy: "case-split on session list, simp with filter_length_le"
  sampled_from: "all users in the directory"
  fixture_set: [alice_admin, bob_guest, carol_disabled, dana_with_no_sessions]
  unsampled_domain: "users created after the run; users with > 1024 historical sessions"
```

### 5.2 Implication → conditional

Upstream:

```prolog
formal_property(p_002,
    "if a token is past its expiry, validation rejects it",
    "theorem expired_token_rejected : ∀ t, expired t → ¬ valid t := by ...").
theorem_verdict(t_expired_token_rejected, proven).
```

Test:

```
test_auth_token_invalid_after_expiry [CONDITIONAL]
  given: token_with_expiry(now() - 1s)         # set up A: token is expired
  expect: validate(token) == reject_expired    # assert B: validation rejects

  test_category: projection
  epistemic_label: descriptive
  sampled_from: "all tokens t with expired(t) holding"
  fixture_set: ["token issued now-1s"]
  unsampled_domain: "tokens expired by clock skew rather than absolute time;
                     tokens whose expiry is set in a non-UTC zone"
```

### 5.3 Existential → flagged for manual / PBT

Upstream:

```prolog
formal_property(p_003,
    "there exists an ordering O of jobs such that no deadline is missed",
    "theorem feasible_schedule_exists : ∃ O, all_meet_deadline (schedule O) := by ...").
theorem_verdict(t_feasible_schedule_exists, proven).
```

Pure existentials cannot be exhausted by sampling. Emit a witness-construction test if the proof was constructive (the Lean term reduces to a concrete `O`), otherwise flag and stub:

```
test_feasible_schedule_exists [WITNESS — manual / PBT]
  TODO: Lean proof was non-constructive. Either:
    (a) replay the Lean term to extract O, then assert all_meet_deadline(schedule(O)),
    (b) use a property-based testing tool (Hypothesis / fast-check / QuickCheck)
        to search the ordering space.

  test_category: projection
  epistemic_label: descriptive
  proof_strategy: "non-constructive existence via pigeonhole"
  sampled_from: "the space of job orderings"
  fixture_set: []
  unsampled_domain: "the entire ordering space — see COVERAGE GAPS"

  # also added to COVERAGE GAPS block:
  #   p_003 — pure existential, non-constructive proof; manual verification required.
```

### 5.4 Idempotency → repeated-apply equality

Upstream:

```prolog
formal_property(p_004,
    "normalising a path twice equals normalising it once",
    "theorem normalize_idempotent : ∀ p, normalize (normalize p) = normalize p := by ...").
theorem_vertdict(t_normalize_idempotent, proven).
```

Test:

```
test_normalize_path_is_idempotent [IDEMPOTENCY]
  fixtures: ["/a/b/../c", "//a//b", "./a/./b", "", "/"]
  for p in fixtures:
    once  = normalize(p)
    twice = normalize(normalize(p))
    assert once == twice

  test_category: projection
  epistemic_label: descriptive
  sampled_from: "all path strings p"
  fixture_set: ["/a/b/../c", "//a//b", "./a/./b", "", "/"]
  unsampled_domain: "paths exceeding PATH_MAX; paths with non-UTF-8 byte sequences;
                     Windows-style paths with backslashes"
```

### 5.5 Counterfactual removal → architectural assertion

Upstream:

```prolog
% hypothesis.pl
claim(c_001, "cli_tool must not transitively depend on logging").
claim_label(c_001, counterfactual).
claim_premise(c_001, depends_on(cli_tool, logging)).
claim_negation_provenance(c_001, depends_on(cli_tool, logging), absent).
% target-world.pl
cf_fact(cli_tool, logging).
negation_provenance(depends_on(cli_tool, logging), absent).
% lean_proof_results.pl
necessity_lemma_status(t_no_cli_to_logging, f_cli_logging, proven).
provenance_annotation(t_no_cli_to_logging, f_cli_logging, absent).
```

Tests (see `counterfactual-tests.md` for full handling):

```
test_no_cli_tool_depends_on_logging [REMOVAL — architectural]
  scan(import_graph(cli_tool)).does_not_contain(logging)

  test_category: projection
  epistemic_label: counterfactual
  negation_provenance: absent     # FRAGILE — CWA default
  ...

test_reintroducing_cli_to_logging_dependency_breaks_layering [REINTRODUCTION]
  given: a fixture that adds the import
  expect: layering check fails

  test_category: projection
  epistemic_label: counterfactual
  negation_provenance: absent
```

## 6. Anti-patterns

Avoid each of the following. Most produce tests that compile and even pass, but no longer test the proven property.

- **Asserting the implementation strategy instead of the contract.** `expect(foo.cache.size).toBe(1)` couples the test to a memoization strategy the proof never required. Assert the observable behaviour the property states.
- **Trivially-true assertions.** `expect(undefined).toBeFalsy()`, `assert True`, `assert x == x` — all pass on a blank implementation. Silent specification rot. Every projection test must fail on an empty body.
- **Generic placeholders.** `foo`, `bar`, `obj1` discard the diagnostic value of named domain entities. Use the names from the Prolog KB.
- **Duplicating the proof in the assertion.** Re-deriving the property in the test body (e.g., manually walking a graph the proof already traversed) makes the test an executable copy of the proof rather than a witness. Witness one fixture; trust the proof for the rest.
- **Dropping `unsampled_domain`.** Without it, the universality loss at the `lean → tdd` boundary is invisible to readers. Every projection test must record what it does not cover.
- **Mixing `projection` and `behavioral_claim` shapes.** A behavioural claim (I/O, timing, HTTP status) given the projection shape implies proof ancestry that does not exist. Send behavioural claims to Phase B and tag them `behavioral_claim`.
- **Using `negation_provenance: absent` without a fragility note.** CWA-default negations are structurally fragile. The comment block must surface the fragility so the implementor and downstream readers see it.
- **Naming after the function under test.** `test_TokenService_validate` rots when the function is renamed. Name after the property: `test_auth_token_invalid_after_expiry`.

## 7. Cross-references

- `tagging.md` (sibling) — full schema for the per-test comment block, including the fields referenced in Sections 4 and 5 above (`test_category`, `epistemic_label`, `negation_provenance`, `proof_strategy`, `sampled_from`, `fixture_set`, `unsampled_domain`).
- `counterfactual-tests.md` (sibling) — special handling for `claim_label(_, counterfactual)` claims: removal tests, reintroduction tests, and the EXTRANEOUS / NECESSARY split fed by `necessity_lemma_status/3`.
- `../../../references/epistemic-types.md` — semantics of `descriptive | counterfactual | prescriptive` and `absent | contradicts`, including why CWA-absent and explicit-contradicts negations carry different logical strength and therefore different test fragility.
- `../../../references/pipeline-schema/hypothesis.md`, `target-world.md`, `lean-proof-results.md` — the wire format of the upstream artifacts cited throughout this reference.
