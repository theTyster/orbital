# Structural tests from the Prolog KB

Reference for Step 5 of `instantiate-properties` — turning structural patterns in `thoughts/existing-world.pl`, `thoughts/hypothesis.pl`, and `thoughts/target-world.pl` into concrete, skipped TDD tests.

Related reading:

- `tagging.md` — every structural test still carries the full `test_category` / `ontology_label` / `negation_provenance` tag block.
- `test-shape-mapping.md` — mappings keyed on property shape rather than KB structure.
- `counterfactual-tests.md` — counterfactual-removal patterns live there; this file does not duplicate them.
- `../../../references/pipeline-schema/` — the canonical wire format for every `.pl` artifact referenced below.

## 1. Scope

Structural tests arise from relational patterns embedded in the Prolog knowledge base itself, not from a per-property theorem in Lean. No `formal_property/3` entry authored them; they are projections of invariants that the KB's shape implies.

Classification is still `test_category: projection` — a structural test projects a structural invariant onto a concrete fixture the same way a property-derived test projects `∀x.P(x)` onto one witness. The difference is the source: the projection source is the relational structure of the KB, not a theorem. Because there is no upstream theorem, the `proof_strategy` field is omitted (or set to the literal string `"kb-structural"` so the downstream report can bucket them separately), and `sampled_from` names the KB relation rather than a quantified domain.

Structural tests live in Phase 1 or Phase 2 alongside formal-property projections — they precede Phase B (behavioural contracts) and they follow Phase 0 (counterfactual removal) when conditional mode is in play. Dependency-ordering tests usually anchor Phase 1 because later phases compose over them.

Rule of thumb: if the assertion can be read off the KB by a `swipl` query alone, it is a structural test. If the assertion requires a Lean theorem or a behavioural contract to justify it, it is not.

## 2. Structural-pattern → test-type table

Extension of the existing matrix in SKILL.md. The left column is the predicate pattern; the right columns are the test shape and the assertion obligation.

| KB pattern | Test type | What to assert |
|---|---|---|
| `depends_on(B, A)` chains | Setup-ordering / integration | Establish A before B in the fixture; an integration test exercises the chain in order |
| `has_exactly_one(user, session)` | Cardinality | Creating a second session revokes or replaces the first |
| `mutually_exclusive(read_mode, write_mode)` | Mutual-exclusion / negative | Activating both simultaneously is rejected |
| `before(X, Y)` / `requires(X, Y)` | Phase-ordering | Y is not invoked before X completes |
| Domain entities (e.g. `auth_lib`, `crypto_lib` named in facts) | Fixture seed | Use named entities as concrete test inputs, not `foo` / `bar` |
| Acyclicity invariant on a relation R (e.g. `depends_on`) | Cycle prevention | Attempting to create a cycle `R(a,b), R(b,a)` (or longer) is rejected; a topological sort succeeds |
| `fd(R, X -> Y)` (functional dependency) | Functional-dependency | For a given X, at most one Y exists; writing a second (X, Y') either overwrites or errors |
| `total_coverage(X, Y)` (every X has at least one Y) | Total-coverage | For every inhabitant of X in the fixture, query for its Y and assert non-empty |
| `partitions(X, [P1, P2, ...])` | Disjoint-decomposition | Every member of X belongs to exactly one Pi; the union of Pi equals X; the pairwise intersection is empty |
| `symmetric(R)` / `antisymmetric(R)` | Relation-algebra | For symmetric: `R(a,b) -> R(b,a)`. For antisymmetric: `R(a,b) and R(b,a) -> a = b`. Assert on concrete inhabitants |
| `transitive_closure(R, Rplus)` | Closure obligation | For every derivable chain `R(a,b), R(b,c)`, assert `Rplus(a,c)`; assert the closure is idempotent |
| `unique_key(Entity, Field)` / `identity(Entity, Id)` | Identity / unique-key | Inserting a second row with the same key raises; lookups by key return at most one |

Each row implies a test name pattern. Keep names property-shaped, not code-shaped:

- `test_depends_on_is_acyclic_across_auth_stack`
- `test_fd_user_to_email_rejects_second_email`
- `test_every_order_has_at_least_one_line_item`
- `test_read_mode_and_write_mode_cannot_coexist`

## 3. Reading the KB

Structural patterns are discovered by `swipl` queries, not by grep. The KB is the ground truth; the SKILL.md process step is discovery, not invention.

Discover all relations and their arities:

```bash
swipl -g "consult('thoughts/existing-world.pl'), \
          forall(current_predicate(P/N), \
                 (P \\= '$$' -> format('~w/~w~n', [P, N]) ; true)), \
          halt."
```

Find two-step chains on an ordering relation:

```bash
swipl -g "consult('thoughts/existing-world.pl'), \
          findall(X-Y-Z, (depends_on(X,Y), depends_on(Y,Z)), L), \
          length(L, N), format('chains: ~w~n', [N]), \
          forall(member(T, L), format('  ~w~n', [T])), halt."
```

Find cardinality constraints by predicate name:

```bash
swipl -g "consult('thoughts/existing-world.pl'), \
          forall(current_predicate(P/N), \
                 (atom_concat('has_', _, P) ; \
                  atom_concat('at_most_', _, P) ; \
                  atom_concat('exactly_', _, P)) -> \
                 format('cardinality: ~w/~w~n', [P, N]) ; true), halt."
```

Find exclusion predicates:

```bash
swipl -g "consult('thoughts/existing-world.pl'), \
          forall(current_predicate(P/N), \
                 (sub_atom(P, _, _, _, '_exclusive') ; \
                  atom_concat('not_', _, P) ; \
                  atom_concat('forbidden_', _, P)) -> \
                 format('exclusion: ~w/~w~n', [P, N]) ; true), halt."
```

Cross-reference with `target-world.pl` for the **target** relation after counterfactual removals. The same relation name in existing-world and target-world may have different inhabitants, and the structural test must be written against whichever relation the implementation is obliged to satisfy:

```bash
swipl -g "consult('thoughts/target-world.pl'), \
          findall(X-Y, depends_on_target(X,Y), Es), \
          sort(Es, S), forall(member(E, S), format('  ~w~n', [E])), halt."
```

When in doubt, emit the test against the `_target` helper relation (e.g. `depends_on_target/2`) rather than the raw existing-world relation. The target-world view is the one the implementation is being driven toward.

## 4. Domain-entity fixtures

Prolog facts are free fixtures. Named entities in the KB produce more informative failure messages than synthetic placeholders. Use them directly.

- `depends_on(auth_lib, crypto_lib)` → write the test with `auth_lib` and `crypto_lib` as literal strings or module handles, not `foo` and `bar`.
- A failure message like `expected auth_lib to not import crypto_lib, but it did` tells the implementor exactly which module to open; `expected A to not import B` sends them to grep.

Pull the inhabitant set for a given relation position:

```bash
swipl -g "consult('thoughts/existing-world.pl'), \
          findall(X, depends_on(X, _), Xs), \
          sort(Xs, S), \
          forall(member(E, S), format('~w~n', [E])), halt."
```

For tests that exercise a relation in both directions, pull both projections:

```bash
swipl -g "consult('thoughts/existing-world.pl'), \
          findall(Y, depends_on(_, Y), Ys), \
          sort(Ys, S), \
          forall(member(E, S), format('~w~n', [E])), halt."
```

When a relation has more than a handful of inhabitants, the test does not iterate them all — it samples, and records the sampling in the test's `fixture_set` and `unsampled_domain` fields. This mirrors how a universal-property projection documents its sample point.

## 5. Edge predicates from `hypothesis.pl`

Boundary conditions are recorded in `hypothesis.pl` during exploration. They enter the test suite as edge-case projections (or, when no formal layer expressed them, as `behavioral_claim` — see `tagging.md`).

- **Empty inputs**: zero-element behaviour — the empty list, the empty set, the empty configuration. Assert the operation is well-defined at zero.
- **Single elements**: singleton / base-case behaviour. Many inductive proofs have a trivial base; the test for the base case is the cheapest guard against a mistake in the inductive step.
- **Maximum cardinality**: if a `claim/2` or `coverage/2` entry identifies an upper bound, write a test exactly at that bound (and, if feasible, at `bound + 1` to assert the boundary is respected).
- **Refuted sub-claims**: when exploration in `hypothesis.pl` produced `evidence/3` that refuted a sub-claim, emit a test asserting the **correct** behaviour observed during exploration. This locks the understanding into the suite so the regression cannot reappear silently.
- **Open assumptions**: for every `assumption(Id, _)` in `hypothesis.pl`, emit a stub test with `skip(reason="assumption not proven — verify manually")`. The test body can be empty or contain a `// TODO` pointing back to the assumption id. These stubs make the gap visible without adding noise to CI.

Tag inheritance follows the claim the edge descends from:

- Descends from a claim in `hypothesis.pl` that was subsequently proven (or whose `formal_property/3` was proven in `lean_proof_results.pl`) → `test_category: projection`, `ontology_label` inherited from `claim_label/2`.
- Describes boundary behaviour that no claim captured → `test_category: behavioral_claim`, no `ontology_label`.

## 6. Coverage and ordering

Within a phase, ordering matters — both for readability and for the TDD loop in `realize-specification`.

- **Simplest first**: empty and trivial cases come before boundary and stress cases. The implementor should be able to work top-to-bottom and see the complexity ramp.
- **Setup-ordering tests precede composition tests** that depend on them. A `depends_on` chain test that establishes the fixture order belongs above the integration test that exercises the chain end-to-end.
- **Cardinality and exclusion tests precede integration tests** over the same relation. A violation of `has_exactly_one` or `mutually_exclusive` should surface before the integration test composes the same entities — otherwise the integration test fails for the wrong reason and the implementor chases a symptom.
- **Identity / unique-key tests precede functional-dependency tests**. If identity is broken, FD assertions are meaningless.

Within Phase 1, structural projections and property-shape projections interleave only when their dependencies permit it. When in doubt, put the structural test first — a broken structural invariant is almost always the proximate cause of a broken property.

## 7. Worked examples

Three concrete structural patterns, end to end.

### 7a. Dependency-chain integration

KB:

```prolog
depends_on(audit, db).
depends_on(api, audit).
```

Emitted test (pseudotest form):

```
### TEST: test_api_call_surface_exercises_audit_and_db_in_order   [skipped]
test_category: projection
ontology_label: descriptive
sampled_from: depends_on-chain rooted at api
fixture_set: [db, audit, api]
unsampled_domain: other roots (e.g. cli_tool) not exercised here

GIVEN:
  db is initialised.
  audit is initialised with a handle to db.
  api is initialised with a handle to audit.
WHEN:
  api.handle_request(sample_request) is invoked.
THEN:
  audit.record(_) is called exactly once before db.write(_).
  db.write(_) is called at least once.
```

The `fixture_set` lists the three named entities from the KB. The `unsampled_domain` acknowledges that other `depends_on` roots exist and are not exercised here.

### 7b. Cardinality

KB:

```prolog
has_exactly_one(user, active_session).
```

Emitted test:

```
### TEST: test_creating_second_active_session_invalidates_first   [skipped]
test_category: projection
ontology_label: descriptive
sampled_from: has_exactly_one(user, active_session)
fixture_set: user u_001
unsampled_domain: multi-user contention; session eviction under load

GIVEN:
  user u_001 exists with one active session s_a.
WHEN:
  a second session s_b is created for u_001.
THEN:
  s_a is marked invalid OR replaced by s_b (exactly one of the two).
  exactly one session is active for u_001 after the operation.
```

The assertion is framed as exactly-one because the KB constraint is `has_exactly_one` — the test is not about *which* strategy (revoke vs. replace) the implementation picks, only that the cardinality invariant survives.

### 7c. Mutual exclusion

KB:

```prolog
mutually_exclusive(read_only, write_only).
```

Emitted test:

```
### TEST: test_activating_read_only_and_write_only_simultaneously_raises   [skipped]
test_category: projection
ontology_label: descriptive
sampled_from: mutually_exclusive(read_only, write_only)
fixture_set: modes [read_only, write_only]
unsampled_domain: other mode pairings; transitional states

GIVEN:
  a fresh connection with no mode set.
WHEN:
  read_only is activated.
  write_only is activated on the same connection.
THEN:
  the second activation raises a ModeConflictError (or the framework's equivalent).
  the connection's effective mode remains read_only.
```

The second assertion — that the original mode is retained — is not strictly required by the mutual-exclusion invariant, but it locks in a sensible recovery behaviour. If the implementor wants to instead roll back to no-mode, the test is amended in review; what it must not do is silently accept both modes.

## 8. Cross-references

- `tagging.md` — every structural test still carries the full tag block (`test_category`, `ontology_label` when inherited, `negation_provenance` when applicable). Do not omit tags for structural tests just because their source is the KB rather than a theorem.
- `test-shape-mapping.md` — mappings keyed on property shape (`forall`, `implies`, `equivalent`, etc.) rather than on KB structure. Use that reference when the test source is a `formal_property/3`; use this one when the source is a relational pattern.
- `counterfactual-tests.md` — counterfactual-removal patterns (`claim_label(_, counterfactual)` plus the corresponding `negation_provenance/2` in `target-world.pl`) are documented there and live in Phase 0, not here.
- `../../../references/pipeline-schema/` — canonical wire format for `hypothesis.pl`, `target-world.pl`, `model_results.pl`, and `lean_proof_results.pl`. When any predicate name or arity in this file disagrees with the schema wiki, the wiki wins and this file is out of date.
