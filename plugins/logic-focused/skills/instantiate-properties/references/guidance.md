# instantiate-properties — Guiding Principles

## Introduction

This file is the long-form companion to the SKILL.md `Guidance` summary. SKILL.md keeps a short, scannable list of principle headings; the depth, justification, and concrete worked examples for each principle live here. Consult this file the first time a new contributor or model picks up `instantiate-properties`, whenever a principle needs to be defended in a code review, and whenever a generated test suite seems to violate one of the named enforcement rules in `../../../references/ontology.md`.

The meta-principle that ties every entry below together: **each guideline is a defense against a specific failure mode the pipeline has seen in practice.** None of these rules are stylistic. Each one corresponds to a way the `lean → tdd` boundary has been mis-crossed before — universality silently flattened into a passing test, a counterfactual quietly dropped from a hypothesis, a behavioral contract masquerading as a proven invariant, a CWA-default negation hardened into a load-bearing claim. The rules read as imperative defaults; the rationale sections explain what goes wrong without them.

When a generated suite triggers a review comment, the fastest path to resolution is to identify which principle was violated and follow the corresponding "How to apply" check. The cross-cutting failure-mode index at the bottom maps each enforcement rule from the ontology reference to the principles that defend it.

## Tests ARE the plan

**The rule.** Do not produce a separate implementation plan document. The test file, read top-to-bottom, is the implementor's roadmap.

**Why.** A separate plan document and a generated test suite drift apart almost immediately. The plan describes intent; the suite encodes acceptance. When they disagree — and they always will, after the first round of refactoring — the implementor faces a choice between honoring the plan (and ignoring the failing test) or honoring the test (and silently invalidating the plan). Worse, plan documents tend to leak implementation strategy ("first build a parser, then a normalizer"), which is a fragile-test antipattern at the planning level. The downstream skill `realize-specification` is built around the test file as the authoritative artifact; a plan document has no consumer in the pipeline.

**How to apply.** Treat phase headers, per-test comment blocks, the `LOOPBACK SIGNALS` block, and the `COVERAGE GAPS` block as the entire planning surface. If a piece of guidance does not fit naturally into one of these slots, it probably does not belong in the artifact at all. Resist the urge to write a top-of-file narrative summary beyond the mandatory header.

**Concrete example.** Phase 0 (Removal), Phase 1 (Foundations), Phase 2 (Compositions), Phase B (Behavioral Contracts) form a dependency-ordered work queue. The implementor un-skips the next test, runs it, watches it fail, implements until green, commits, repeats. No plan document is needed because the phase ordering already encodes the work order.

## Projection equals witness, not re-proof

**The rule.** A passing `projection` test samples one point in a proof domain. It does not re-verify `∀x.P(x)`. Use "property witnessed" or "sampled and passed" — never "property verified" — in any downstream artifact that describes a green projection test.

**Why.** This is the universality-loss enforcement at the `lean → tdd` boundary, captured by the `lean_universal_neq_test_verified` and `universal_neq_test_verified` enforcement rules. A Lean proof of `∀x.P(x)` is universal; a passing test against a specific fixture is existential — it shows that for *this* fixture, P holds. Treating the green test as if it re-established universality flattens the modality and erases the proof's contribution. Once the language slips, the suite begins to be reasoned about as if it were the source of truth: contributors start "deleting redundant proofs because the test covers it," which is exactly backwards. The proof remains the authority; the suite is a tripwire.

**How to apply.** In every projection test's comment block, fill in `sampled_from`, `fixture_set`, and `unsampled_domain`. The presence of `unsampled_domain` is a structural reminder that the test is a sample, not a proof. In the report and in any prose summary, prefer phrasings like "five projections sampled across the domain `{empty, singleton, max, ...}` and all passed at their fixtures" rather than "the property is verified by the suite."

**Concrete example.** A Lean theorem `∀ xs : List Int, sorted (sort xs)` becomes a projection test `test_sort_produces_sorted_output` with `fixture_set: [[], [1], [3,1,2], [1,1,1]]` and `unsampled_domain: lists longer than 100, lists of negatives, lists containing Int.minValue`. The test green means the four fixtures pass; universality is still owned by the Lean proof.

## behavioral_claim has no proof ancestry

**The rule.** Every `behavioral_claim` test is visibly separated from `projection` tests, both in the suite (Phase B at the bottom) and in the report. A failing `behavioral_claim` is not a loopback signal upstream — the formal nodes never expressed the claim — so the implementor is the one who decides whether the claim is wrong or the implementation is wrong.

**Why.** This is the `behavioral_claim_neq_proven_property` enforcement rule. Behavioral claims (I/O, side effects, state, concurrency, timing, HTTP status codes, logging) cannot be expressed in Lean and never appeared in `lean_proof_results.pl`, `model_results.pl`, or `hypothesis.pl`. If a `behavioral_claim` failure is mistakenly routed back to `decompose-proposition` or `prove-invariants`, those skills have nothing to act on — there is no proposition to re-decompose, no theorem to re-prove. The result is a wasted loop and, worse, an erosion of the property/contract distinction: contributors begin to assume every red test means a proof was wrong, and the strength of the formal layer dilutes.

**How to apply.** Place `behavioral_claim` tests in Phase B at the very bottom of the file, after every projection phase. Omit the proof-ancestry comment fields (`proof_strategy`, `ontology_label`, `sampled_from`, `fixture_set`, `unsampled_domain`) — including them implies an ancestry that does not exist. In the report, the `test_category` breakdown surfaces the behavioral count separately from projection counts, and the `ontology_label` breakdown is computed over projections only.

**Concrete example.** A test asserting that `POST /login` returns HTTP 503 under backpressure is a `behavioral_claim`. If it fails, the implementor must decide: is 503 the right code (perhaps 429 was intended)? Is the backpressure detector miswired? Either resolution is local to the TDD layer; no Lean theorem can settle it.

## Failing is correct, but skip by default

**The rule.** Every generated test must fail on a blank implementation. Mark every test as skipped/pending in the framework's idiom; the implementor un-skips one test at a time as TDD progress.

**Why.** Two distinct failure modes are prevented here. First, a test that passes against an empty implementation is silent specification rot — it asserts nothing meaningful, and its green status will be cited as evidence that "the property is covered" when in fact nothing is being checked. Examples: `expect(undefined).toBeFalsy()`, `assert result is not None` after a function that always returns a non-`None` sentinel, `assertTrue(True)` left over from a stub. Second, an unskipped suite added in a single commit will turn CI red the moment it merges, which forces a rushed implementation or a revert — either way the careful sampling work is lost.

**How to apply.** Two checks. (1) Audit every assertion: does it mention a value or shape that depends on the implementation? If not, the assertion is trivial and must be tightened. (2) Apply the framework's skip annotation to every test (`it.skip`, `@pytest.mark.skip`, `t.Skip`, `#[ignore]`, `xit`, `describe.skip`). Open-assumption stubs use a distinct skip reason — `skip(reason="assumption not proven — verify manually")` — so the implementor can distinguish "not yet implemented" from "needs manual verification."

**Concrete example.** `test_no_duplicate_entries_after_insert` asserts `expect(set.size).toBe(initial_size + 1)` after inserting an existing element — this fails on a blank implementation because there is no `insert` yet. It is annotated `it.skip(...)`. The implementor unskips it, runs the suite, sees the failure, implements `insert`, watches it pass, commits, moves on.

## Name tests after properties, not code

**The rule.** Test names encode the property being asserted, not the function being called.

**Why.** Code names change. `tokenService.checkExpiry` becomes `auth.isExpired` becomes `Token::expired?` over the lifetime of a project. A test named `test_tokenService_checkExpiry` becomes a stale signpost pointing at a renamed function; the test still exercises the property, but its name no longer tells anyone what the property is. Property names — `test_auth_token_invalid_after_expiry` — are stable across refactors because they describe an invariant of the domain, not an artifact of the current code structure.

**How to apply.** Default to the form `test_{subject}_{verb}_{condition}` where the verb describes a state predicate, not a method invocation. Use the natural-language description from `formal_property/3` as the seed. If the test name reads like a sentence ("auth token is invalid after expiry"), it is well-named. If it reads like a function call trace, rewrite it.

**Concrete example.** Prefer `test_sorted_output_preserves_all_elements` over `test_sortFunction_outputLength`. Prefer `test_no_duplicate_entries_after_insert` over `test_insert_calls_dedup`.

## Edge predicates are not optional

**The rule.** Every boundary condition or edge predicate in `hypothesis.pl` must produce at least one test.

**Why.** Proofs are proven on models. Models are deliberate simplifications: an integer in a Lean proof is an unbounded mathematical integer, but the implementation runs on `i32`/`i64` with overflow. A list in a model has no maximum length; in production it has a heap budget. Edge cases are precisely where the model and reality diverge, and the formal layer cannot warn about that divergence — it is invisible to the proof. Skipping edge predicates is how a "fully proven" property crashes on an empty input or wraps around at `INT_MAX`.

**How to apply.** Walk every `claim_premise/2` and edge predicate in `hypothesis.pl` after Step 1. For each, ask: does any existing projection test exercise this boundary? If not, add a test. Empty input, singleton input, maximum cardinality, and refuted sub-claims are the four edge categories that must always be covered when present in the hypothesis.

**Concrete example.** A property "for all non-empty lists, `head xs` returns the first element" needs an explicit `test_head_on_empty_list_raises` — the proof excluded the empty case, so the test must lock in the implementation's handling of it.

## Assumptions become TODOs, not omissions

**The rule.** When a proven property depends on an open assumption (flagged in `hypothesis.pl`), include the test as a clearly-marked stub — `it.todo(...)`, `@pytest.mark.skip(reason="assumption not proven — verify manually")`, or a `// ASSUMPTION: ...` comment. Never silently omit it.

**Why.** Omission is invisible. A test that was never written cannot be discovered by reading the suite, by running coverage, or by grepping for known property names. The implementor will assume the absence of a test means the property is either trivially true or covered elsewhere — neither of which is the case. A loud TODO stub, on the other hand, is a structural admission of incompleteness: it appears in the test list, in the skip count, and in the COVERAGE GAPS block, and the implementor cannot ship the feature without addressing it.

**How to apply.** When an assumption is flagged, write the test as if it were a normal projection but mark it with the framework's "intentionally pending" idiom (distinct from the default skip). In the comment block, name the assumption explicitly and link to the hypothesis claim id. The COVERAGE GAPS block at the end of the file enumerates every such stub.

**Concrete example.** `it.todo('test_payment_idempotency_under_clock_skew — assumption: monotonic clock')` is a visible reminder that the property holds only under a clock-monotonicity assumption that the proof took as given.

## Prolog facts are free fixtures

**The rule.** Use named entities from the Prolog KB as concrete test inputs. Avoid `foo`, `bar`, `baz`.

**Why.** Anonymous fixtures produce anonymous failure messages. `expected foo to depend on bar but it did not` tells the implementor nothing about the actual relationship under test. `expected auth_lib to depend on crypto_lib but it did not` immediately points to the real components and likely the real bug. KB-derived fixtures also mean the test exercises real ontology relationships, which catches name-mismatch bugs (the test's `auth_lib` and the implementation's `auth_lib` had better refer to the same module) that anonymous fixtures hide.

**How to apply.** When choosing test inputs, query the KB for an entity that satisfies the relevant predicate and use it directly. Reserve `foo`/`bar` for the rare case where the test must demonstrate name-irrelevance.

**Concrete example.** Given `depends_on(auth_lib, crypto_lib)` in the KB, the dependency-ordering test uses `auth_lib` and `crypto_lib` literally rather than abstract placeholders — the failure message becomes a domain-meaningful diagnostic.

## Flag gaps loudly

**The rule.** Proven properties that resist translation (existential witnesses, infinite structures, timing properties, properties about asynchrony) go in the `COVERAGE GAPS` block at the bottom of the file. Do not silently drop them.

**Why.** Silent dropping erases the formal guarantee from the artifact entirely. The implementor reading the suite has no way to know that `forall n. exists prime p > n` was proven but not tested — the proof remains in `lean_proof_results.pl` but disappears from the implementation-facing surface. The COVERAGE GAPS block is the channel that keeps the loss visible. It also serves as the queue for additional test investment: if the project later adopts a property-based testing library, the gaps section is the prioritized list of properties to retroactively cover.

**How to apply.** For each proven property without a corresponding projection test, add a COVERAGE GAPS entry naming the property, the reason translation failed (existential, infinite, timing, async), and a suggested remediation (e.g., "Hypothesis-style PBT with custom strategy," "manual verification only," "deferred until SchedulerTrace lands"). The block is also where unsampled-domain slices and unbacked behavioral contracts are surfaced.

**Concrete example.** `// COVERAGE GAP: termination of compaction loop — proven by well-founded recursion in Lean, no finite test can re-witness; recommend manual review on each compaction algorithm change.`

## Match the existing test style exactly

**The rule.** Generated tests must match the project's framework, file naming, function naming, assertion style, nesting conventions, fixture patterns, and custom utilities — as discovered by the Explore sub-agent in Step 2.

**Why.** Foreign-looking tests get rewritten. An implementor who sees a `describe`/`it` block in a project that uses flat `def test_` functions will either rewrite the suite (losing the careful sampling work in the process) or, worse, ignore it as "not how we test here." Matching the style is a cheap way to ensure the suite is actually adopted. It also reduces the chance of subtle correctness bugs from importing the wrong assertion library or using a fixture pattern that does not interoperate with the project's setup/teardown.

**How to apply.** Run Step 2 (Explore) before any test mapping work begins, when a target codebase directory is provided. Extract framework, file naming, function naming, assertion style, nesting, and custom utilities. Replicate them exactly. If the project uses `expect(x).toEqual(y)` rather than `assert x == y`, the generated tests use `expect(...).toEqual(...)`. If fixtures are factories rather than inline setup, the generated tests use factories.

**Concrete example.** A pytest project with `tests/test_*.py` files, `def test_*` function naming, `assert` statements, and a `conftest.py` of fixture factories must receive tests that look identical to existing ones — not Jest-style `describe`/`it` blocks even if those would technically run under `pytest-describe`.

## Don't over-specify implementation

**The rule.** Assert the contract — the output, the externally-observable property — not the strategy. Internal data structures, intermediate states, and algorithm choices are out of scope.

**Why.** Over-specified tests are fragile tests. A test that asserts the sort function uses a particular pivot selection breaks every time the sort is reimplemented, even when the new implementation is correct. The implementor either has to update the test on every refactor (negating the test's value as a regression check) or they delete the assertion (negating its value as a specification). The proof is about the contract; the test should be too.

**How to apply.** Before writing an assertion, ask: "Is this property true for every correct implementation, or only for the current one?" If only for the current one, weaken the assertion to the contract. Resist the temptation to assert intermediate steps as a debugging aid — that is what `--verbose` flags and unit-level introspection are for, not the property suite.

**Concrete example.** For a `dedupe` function, assert `expect(output.length).toBeLessThanOrEqual(input.length)` and `expect(new Set(output).size).toBe(output.length)` — properties of the output. Do not assert that the implementation uses a `Set` internally; that is a strategy choice, not a contract.

## Counterfactual-removal tests are first-class

**The rule.** In conditional mode, every `claim_label(_, counterfactual)` claim from the hypothesis must produce a `projection` removal test. Use the project's existing architecture-test idiom if available; otherwise, a grep/AST-scan or import-graph test is fine.

**Why.** This is the structural counter-pressure to the "only reason about what exists" bias. LLM-driven implementors — and human ones, for that matter — habitually reason additively: "to make the property hold, what code do I need to add?" Counterfactuals invert the question: "to make the property hold, what code must NOT be there?" Without an enforced removal test, the implementation can satisfy every positive projection test while still containing the forbidden dependency, and the property holds for the wrong reason. The skipped removal test is the mechanical guarantee that the deletion work happens before the addition work — which is why these tests live in Phase 0, before Foundations.

**How to apply.** For each counterfactual fact in `target-world.pl`, emit a removal test of the appropriate shape (import absence, call absence, route absence, config absence). Tag with `test_category: projection`, `ontology_label: counterfactual`, and the `negation_provenance` mode. If `Mode = absent`, the comment block must flag the test as fragile (CWA default). If `Mode = contradicts`, the test is structurally necessary — say so.

**Concrete example.** A counterfactual `cf_fact(cli_tool, logging)` produces `test_cli_tool_does_not_import_logging` — an architectural test that scans `cli_tool`'s source and asserts zero import statements referencing `logging`. Tagged `projection`, `counterfactual`, and (if relevant) `negation_provenance: contradicts` because the project explicitly forbids this dependency.

## Reintroduction tests lock in load-bearing reasoning

**The rule.** For every counterfactual fact labelled `NECESSARY` in `lean_proof_results.pl`, emit a reintroduction test that puts the fact back at runtime or in a fixture and asserts the invariant breaks in a detectable way.

**Why.** A removal test alone does not lock in the *reason* the counterfactual was enumerated. A future contributor un-deletes the dependency, the removal test goes red, the contributor reads the test, sees only "must not import logging," and either disables the test or moves the import to a "compatibility shim" — neither of which preserves the invariant. The reintroduction test is the only mechanism that says "if you put this back, this concrete invariant breaks, here is the failure," making the counterfactual's load-bearing role visible at the moment of attempted regression. Without it, the proof's most subtle reasoning (why the counterfactual was needed) is invisible to anyone who has not read the proof.

**How to apply.** Generate one reintroduction test per `NECESSARY` counterfactual. Naming convention: `test_reintroducing_{fact}_breaks_{property}`. The test sets up the fact (imports the module, calls the function, sets the config flag) and asserts that the invariant fails — by compilation error captured as a meta-test, runtime error, or higher-level test failure. Do not emit a reintroduction test for `EXTRANEOUS` counterfactuals; the proof showed removing them was not load-bearing, and the reintroduction would not break anything to assert.

**Concrete example.** If `cf_fact(cli_tool, logging)` is `NECESSARY` for the property "the CLI tool's startup is deterministic," emit `test_reintroducing_cli_tool_logging_breaks_deterministic_startup`: the test imports `logging` in the CLI tool's startup path and asserts that startup output is no longer byte-identical across two runs. A future contributor who restores the dependency sees this test go red and learns *why* the counterfactual mattered.

## Cross-cutting failure-mode index

The named enforcement rules in `../../../references/ontology.md` are each defended by one or more principles above:

| Enforcement rule | Principles that defend it |
|---|---|
| `behavioral_claim_neq_proven_property` | Projection equals witness, not re-proof; behavioral_claim has no proof ancestry |
| `cwa_negation_neq_lean_proof` | Flag gaps loudly; counterfactual-removal tests are first-class (see also `counterfactual-tests.md`) |
| `universal_neq_test_verified` | Projection equals witness, not re-proof |
| `lean_universal_neq_test_verified` | Projection equals witness, not re-proof |

When a review flags one of these rule names, find the corresponding principle row, follow its "How to apply" check, and confirm the suite or the report has been corrected accordingly.

## Cross-references

- `tagging.md` — exact tag-emission contract for `test_category`, `ontology_label`, `negation_provenance`, and the proof-ancestry fields
- `test-shape-mapping.md` — the property-shape to test-shape table that drives Step 3
- `counterfactual-tests.md` — full removal/reintroduction test patterns including the CWA fragility annotation
- `structural-tests.md` — Prolog KB to structural-test translation patterns
- `../../../references/ontology.md` — tag semantics and the named enforcement rules indexed above
