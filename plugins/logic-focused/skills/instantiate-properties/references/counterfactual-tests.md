# Counterfactual Tests

Reference for Stage 5 (`instantiate-properties`). Covers the translation of
counterfactual claims — facts the KB must *stop* asserting for a proposition
to hold — into paired architectural tests: a **removal test** and, where the
proof earns it, a **reintroduction test**.

This is the mechanical counter-pressure that distinguishes the logic-focused
pipeline from conventional TDD generation. Every fact-shape mapping, status
rule, framework recommendation, and worked example for counterfactual
handling lives here; `SKILL.md` retains only a pointer.

---

## 1. When this applies

Apply this reference **only in conditional proof mode**.

`proof_mode` is derived — there is no `proof_mode/1` predicate. The rule:

- `conditional` iff `hypothesis.pl` contains at least one
  `claim_label(_, counterfactual)` fact.
- `invariant` otherwise.

For `invariant`-mode proofs, skip this entire reference. No counterfactual
claims means no removal tests, no reintroduction tests, and no Phase 0 —
proceed directly to `projection` tests for the universal properties and
`behavioral_claim` tests for TDD-layer additions.

In `conditional` mode, every `claim_label(ClaimId, counterfactual)` MUST
have been emitted alongside:

- `claim_premise(ClaimId, Fact)` — the specific ground fact the claim
  negates (for example, `depends_on(cli_tool, logging)`).
- `claim_negation_provenance(ClaimId, Fact, absent | contradicts)` — the
  per-claim, 3-argument negation-provenance record.

Correspondingly, `target-world.pl` records the fact removal as:

- An **omission** of the fact itself (CWA — the counterfactual fact is
  simply not asserted in target-world).
- `negation_provenance(Fact, absent | contradicts)` — the per-fact,
  2-argument marker that survives the translation from `claim_negation_provenance/3`.
- `cf_fact/N` — the counterfactual-removed fact keyed on the original
  relation and arity (for example, `cf_fact(cli_tool, logging)`).
- A target-relation helper scoped to each base relation (for example,
  `depends_on_target(X, Y) :- depends_on(X, Y), \+ cf_fact(X, Y).`).

If any of these artifacts are missing while `conditional` mode is in
effect, emit a `LOOPBACK SIGNAL` to `decompose-proposition` (to enumerate
missing counterfactuals) or to `model-obligations` (to reconcile the
target-world translation).

---

## 2. The counterfactual lens

LLM-driven implementors habitually reason about what should *exist*: which
modules to add, which functions to call, which configuration to set. What
gets skipped is the inverse — what must *not* exist for the proposition to
hold. The skipped removal test is the mechanical counter-pressure.

The pipeline makes this explicit at every stage:

- `decompose-proposition` flags the claim with `claim_label/2 =
  counterfactual` and records the specific fact in `claim_premise/2`.
- `model-obligations` removes the fact from target-world and records the
  translation as `negation_provenance/2` + `cf_fact/N`.
- `prove-invariants` proves the property over the `_target` relation (for
  example, `depends_on_target`) and records per-fact necessity via
  `necessity_lemma_status/3`.
- `instantiate-properties` emits two architectural tests per fact — a
  removal test (always) and a reintroduction test (when the fact is
  NECESSARY).

The removal test is an *asserted absence* that CI will fail on if the fact
creeps back in. The reintroduction test locks the load-bearing reasoning
itself into the suite — future contributors cannot silently un-delete the
fact without a visible failure.

Both tests are classified `test_category: projection` and
`ontology_label: counterfactual`. They project a counterfactual claim at
a specific fixture; they are not `behavioral_claim` tests.

---

## 3. Two tests per counterfactual fact

### Removal test (always emit)

Assert that the counterfactual fact no longer holds in the implementation.
This is an architectural / lint-style test — import-graph inspection, AST
scans, public-API snapshot diffs, grep-style forbidden-identifier checks.
It does not exercise runtime behavior; it inspects the shape of the code.

Emit one removal test per counterfactual fact, regardless of
`necessity_lemma_status`. Even `extraneous` and `unprovable` facts get a
removal test — the fact was part of the target-relation specification and
should not creep back in during implementation. Only the *reintroduction*
test depends on proven necessity.

Tags:

- `test_category: projection`
- `ontology_label: counterfactual`
- `negation_provenance: absent | contradicts` (inherited from
  `claim_negation_provenance/3` or its `provenance_annotation/3` echo)

### Reintroduction test (emit only when NECESSARY)

Re-introduce the fact at runtime or in a fixture and assert the invariant
breaks in a detectable way — a runtime error, a failing higher-level test,
a compilation failure captured as a meta-test, or a raised exception on
initialization.

Emit **only** when
`necessity_lemma_status(TheoremId, FactId, proven)` appears in
`lean_proof_results.pl`. `proven` corresponds to the NECESSARY label: the
Lean necessity lemma showed that re-introducing the fact falsifies the
property. That proof is the basis for the reintroduction test's
assertion; without it, the test has no formal backing.

Tags identical to the removal test. The reintroduction test is still a
`projection` because it projects the NECESSARY lemma at a specific
fixture — it samples one concrete reintroduction, not a universal
"every reintroduction breaks X."

---

## 4. Fact-shape → removal-test assertion table

Each counterfactual fact shape maps to a concrete architectural assertion.
Prefer the project's existing architecture-test tooling (Section 7); fall
back to a direct source scan only when no tool is configured.

| Fact shape | Removal test asserts |
|---|---|
| `depends_on(cli_tool, logging)` | No import/require/use statement from `cli_tool`'s module to `logging`'s module |
| `calls(moduleA, functionB)` | Static search of `moduleA`'s source has zero references to `functionB` |
| `exposes(service, endpoint)` | `service`'s public surface omits `endpoint` (route table, export list) |
| `reads(worker, resource)` | `worker` has no code path that opens/queries `resource` |
| `config_has(component, flag)` | The config file or init code does not set `flag` for `component` |
| `inherits(classA, classB)` | `classA`'s declared superclass/prototype chain does not include `classB` |
| `uses_global(module, globalName)` | Static scan of `module`'s source finds zero references to `globalName`; the symbol is not in the module's free-variable set |
| `mutates(handler, state)` | `handler`'s source contains no assignment/write to `state` (AST scan of assignment targets); no reducer/action reassigns it |
| `subscribes_to(listener, topic)` | `listener`'s registration code contains no `on(topic, ...)` / `subscribe(topic, ...)` call; the event router's topic map omits the listener |
| `has_field(record, field)` | `record`'s type/schema/struct definition omits `field` (type declaration, schema file, migration list) |
| `extends(pluginA, pluginB)` | `pluginA`'s manifest / extension declaration / `extends` keyword does not reference `pluginB` |
| `writes_to(service, sink)` | `service`'s code contains no write/emit/publish call targeting `sink`; the DI graph has no edge to the sink client |

Where the project uses an architecture-test tool with a native vocabulary
(for example, `dependency-cruiser` rules or `archunit` `noClasses()`
predicates), express the assertion in that tool's DSL rather than in a
hand-rolled grep. The rule of thumb: the forbidden identifier must be an
**asserted-absent string** that CI will fail on if it creeps back into the
codebase.

---

## 5. NECESSARY / EXTRANEOUS handling

Read `necessity_lemma_status(TheoremId, FactId, proven | extraneous | unprovable)`
from `lean_proof_results.pl`. The domain is exactly those three values.

### `proven` — NECESSARY

The Lean necessity lemma showed that re-introducing the fact falsifies the
property. The fact is load-bearing.

- Emit **both** the removal test and the reintroduction test.
- The reintroduction test's comment block cites the
  `necessity_lemma_status/3` verdict as its formal basis.
- No loopback signal.

### `extraneous` — EXTRANEOUS

The property holds without requiring the fact's removal. The Lean proof
reduced the "re-introducing breaks the property" lemma to False — the
fact was not actually load-bearing.

- Emit the removal test **only**.
- The removal test's comment block must flag the `EXTRANEOUS` status and
  note that the fact is still part of the target-relation specification
  for this implementation cycle (it should not creep back in), but the
  hypothesis over-specified.
- Add a `LOOPBACK SIGNAL` entry pointing back to `decompose-proposition`:
  "Prune counterfactual fact `<Fact>` from the hypothesis next cycle —
  necessity lemma reduced to False."
- Do **not** emit a reintroduction test. There is no formal basis for one:
  re-introducing this fact does not break the property.

### `unprovable`

The necessity lemma strategy failed. Distinct from `extraneous`: the
proof engine could not close the necessity proof, but that does not mean
the fact is non-load-bearing — only that the current strategy budget was
exhausted.

- Emit the removal test.
- Flag the fact in the `COVERAGE GAPS` block as a manual-verification
  item: "Necessity unproven for `<Fact>` — reintroduction behavior
  requires manual verification."
- Do **not** emit a reintroduction test. No proof basis means no
  grounded assertion.

### INSUFFICIENT overall proof status

Distinct from per-fact necessity. A conditional proof is INSUFFICIENT
when the counterfactual set did not close the gap — the property cannot
be proven even against the `_target` relation.

- Emit removal tests for every enumerated counterfactual fact (Phase 0
  still runs).
- Add a `LOOPBACK SIGNAL` to `decompose-proposition`: "Conditional proof
  INSUFFICIENT — enumerate additional counterfactual requirements."
- Skip reintroduction tests for any fact whose necessity was never
  evaluated (no `necessity_lemma_status/3` entry). Only emit
  reintroduction tests for facts explicitly tagged `proven`.

---

## 6. `absent` vs `contradicts` provenance

Read `claim_negation_provenance(ClaimId, Fact, absent | contradicts)` from
`hypothesis.pl`. The same mode is echoed per-theorem by
`provenance_annotation(TheoremId, FactId, absent | contradicts)` in
`lean_proof_results.pl`; a disagreement between the two is a malformed
run and triggers a LOOPBACK SIGNAL to `prove-invariants`.

The per-fact form in `target-world.pl` is `negation_provenance(Fact, Mode)`
(2-argument). That variant lives only in `target-world.pl` — never
search for `negation_provenance/2` in `hypothesis.pl` or
`lean_proof_results.pl`.

### `absent` — CWA default, fragile

The proof rests on closed-world absence: the fact is not asserted in
target-world, and Lean lifted that absence into `¬ Fact`. This is
fragile. A future addition to the KB or to the codebase could silently
re-introduce the fact without a corresponding update to the proof's
universe, breaking the CWA grounding.

Requirements:

- The removal test's comment block must contain: `negation_provenance:
  absent — CWA-default; this test guards against silent reintroduction
  of the fact.`
- List the test in the `COVERAGE GAPS` block under
  "absent-provenance fragility."
- If the reintroduction test is emitted (fact is NECESSARY), it inherits
  the same `absent` flag and carries the same caveat.

### `contradicts` — explicit, structural

The KB contains an explicit conflicting fact (for example, a
`legacy(deploy)` fact that contradicts a `deploy` fact). The negation
derives from a positive contradiction, not from absence. This is
structurally stronger: the proof does not depend on closed-world
reasoning.

- The removal test's comment block records
  `negation_provenance: contradicts — structural.`
- No `COVERAGE GAPS` entry for provenance fragility.
- The reintroduction test, if emitted, is stronger: re-introducing the
  fact produces an explicit contradiction, not just a CWA violation.

---

## 7. Architecture-test framework recommendations

Prefer the project's existing tooling whenever Step 2 of `SKILL.md`
(Discover Test Patterns) detected an architecture-test setup. The removal
test is a first-class use case for these tools.

- **JavaScript / TypeScript**: `dependency-cruiser` (forbidden-edge
  rules), `ts-arch` (fluent assertions on project structure),
  `eslint-plugin-boundaries` (module-boundary linting).
- **Python**: `import-linter` (contracts file), `pytest-archon` (pytest
  plugin for import constraints).
- **Java / Kotlin**: `archunit` — `noClasses().that().resideIn(...)
  .should().dependOnClassesThat().resideIn(...)`.
- **Go**: `depguard` (gate-keeping linter), or a custom
  `forbidden_imports_test.go` that walks `go/packages` and asserts edge
  absence.
- **Rust**: `cargo-deny` for crate-level bans; a custom
  `tests/architecture_test.rs` for intra-crate assertions using
  `syn`/`proc-macro2` AST walks.
- **Ruby**: `packwerk` (package-boundary enforcement with privacy and
  dependency rules).

When no architecture-test tool is configured, a direct grep or AST-scan
test is acceptable. What matters is that the forbidden identifier is an
asserted-absent string that fails CI on reintroduction. Prefer an AST
scan over grep when possible — grep false positives (comments, strings,
variable names that coincidentally contain the identifier) undermine the
test's signal.

---

## 8. Naming conventions

### Removal tests

Encode the absent relation in the name:

- `test_no_{source}_depends_on_{target}`
- `test_{module}_does_not_import_{other}`
- `test_{component}_lacks_{endpoint}`
- `test_{handler}_does_not_mutate_{state}`
- `test_{listener}_not_subscribed_to_{topic}`
- `test_{record}_has_no_{field}`

### Reintroduction tests

Encode the load-bearing relationship:

- `test_reintroducing_{fact}_breaks_{property}`
- `test_{property}_requires_absence_of_{fact}`
- `test_re_adding_{fact}_triggers_{expected_failure}`

The property name, or a compressed form of it, must survive in the test
name. An implementor reading a failing test line should immediately know
which counterfactual was violated.

---

## 9. Worked example — `depends_on(cli_tool, logging)`

A full walkthrough of the predicate trail from hypothesis through proof to
the emitted tests.

### 9.1. Hypothesis — `thoughts/hypothesis.pl`

```prolog
claim(c_001, "cli_tool must not transitively depend on logging").
claim_label(c_001, counterfactual).
claim_status(c_001, conditional).

claim_premise(c_001, depends_on(cli_tool, logging)).
claim_negation_provenance(c_001, depends_on(cli_tool, logging), absent).

formal_property(p_001,
    "cli_tool has no transitive path to logging in the target relation",
    "theorem cli_tool_not_reaches_logging : ¬ Reach depends_on_target Module.cli_tool Module.logging := by sorry").
```

### 9.2. Target-world — `thoughts/target-world.pl`

The counterfactual fact is *omitted* from the ground fact list (CWA). The
per-fact marker and helper rule survive:

```prolog
% The fact depends_on(cli_tool, logging) is NOT asserted here.

negation_provenance(depends_on(cli_tool, logging), absent).
cf_fact(cli_tool, logging).

depends_on_target(X, Y) :-
    depends_on(X, Y),
    \+ cf_fact(X, Y).

formal_property(p_001,
    "cli_tool has no transitive path to logging in the target relation",
    "theorem cli_tool_not_reaches_logging : ¬ Reach depends_on_target Module.cli_tool Module.logging := by sorry").
```

### 9.3. Lean proof results — `thoughts/lean_proof_results.pl`

```prolog
theorem_verdict(t_no_cli_to_logging, proven).
proof_strategy(t_no_cli_to_logging,
    "case analysis on depends_on_target, unfold cf_fact, contradiction").
theorem_source(t_no_cli_to_logging, "thoughts/lean/Proofs/NoCliToLogging.lean").

provenance_annotation(t_no_cli_to_logging, f_cli_logging, absent).
necessity_lemma_status(t_no_cli_to_logging, f_cli_logging, proven).
```

`necessity_lemma_status(_, _, proven)` means NECESSARY — both tests emit.

### 9.4. Emitted removal test

```python
# test_category: projection
# ontology_label: counterfactual
# negation_provenance: absent  — CWA-default; guards silent reintroduction.
# sampled_from: p_001 (cli_tool has no transitive path to logging in the
#   target relation)
# fixture_set: cli_tool module, logging module, project import graph
# unsampled_domain: other potential transitive paths are covered by the
#   Lean ∀-proof; this test samples the direct forbidden edge only.
# proof_strategy: case analysis on depends_on_target, unfold cf_fact,
#   contradiction
# source claim: c_001 — "cli_tool must not transitively depend on logging"
# source fact: depends_on(cli_tool, logging)
# necessity: proven (NECESSARY — reintroduction test also emitted)
@pytest.mark.skip(reason="awaiting implementation")
def test_cli_tool_does_not_import_logging():
    graph = build_import_graph(project_root)
    assert "logging" not in graph.transitive_imports("cli_tool"), (
        "cli_tool must not transitively depend on logging; "
        "counterfactual claim c_001 forbids this edge."
    )
```

### 9.5. Emitted reintroduction test

```python
# test_category: projection
# ontology_label: counterfactual
# negation_provenance: absent  — CWA-default; the reintroduction assertion
#   rests on the NECESSARY lemma, not on CWA alone.
# sampled_from: necessity_lemma_status(t_no_cli_to_logging, f_cli_logging,
#   proven) — re-introducing depends_on(cli_tool, logging) falsifies p_001.
# fixture_set: test-only cli_tool variant with an injected logging import
# unsampled_domain: only one reintroduction path is sampled — direct edge.
#   Transitive reintroductions (for example via an intermediate module) are
#   covered by the Lean necessity lemma, not by this test.
# proof_strategy: case analysis on depends_on_target, unfold cf_fact,
#   contradiction
# source claim: c_001
# source fact: depends_on(cli_tool, logging)
# necessity: proven — this test locks in the load-bearing reasoning.
@pytest.mark.skip(reason="awaiting implementation")
def test_reintroducing_cli_to_logging_breaks_no_transitive_path():
    with inject_import("cli_tool", "logging"):
        graph = build_import_graph(project_root)
        with pytest.raises(InvariantViolation):
            assert_no_transitive_path(graph, "cli_tool", "logging")
```

---

## 10. Cross-references

- [`tagging.md`](./tagging.md) — sibling; the canonical tag table and the
  source-predicate-per-tag contract.
- [`test-shape-mapping.md`](./test-shape-mapping.md) — sibling; the full
  property-shape → test-type mapping for non-counterfactual projections.
- [`../../../references/pipeline-schema/hypothesis.md`](../../../references/pipeline-schema/hypothesis.md)
  — `claim/2`, `claim_label/2`, `claim_premise/2`,
  `claim_negation_provenance/3`, `formal_property/3`.
- [`../../../references/pipeline-schema/target-world.md`](../../../references/pipeline-schema/target-world.md)
  — `cf_fact/N`, `negation_provenance/2`, target-relation helpers,
  propagated `formal_property/3`.
- [`../../../references/pipeline-schema/lean-proof-results.md`](../../../references/pipeline-schema/lean-proof-results.md)
  — `theorem_verdict/2`, `proof_strategy/2`,
  `provenance_annotation/3`, `necessity_lemma_status/3`.
- [`../../../references/ontology.md`](../../../references/ontology.md)
  — semantics of `descriptive`, `counterfactual`, `prescriptive`;
  `absent` vs `contradicts`; the
  `cwa_negation_neq_lean_proof` distinction.
