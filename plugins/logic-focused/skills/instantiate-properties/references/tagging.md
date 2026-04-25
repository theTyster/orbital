# Test Tag Taxonomy — `instantiate-properties`

Canonical tag reference for tests emitted by Stage 5 of the logic-focused pipeline. Every test in the generated suite carries a tag vector drawn from this taxonomy; every field has exactly one source predicate in an upstream `.pl` artifact (or is explicitly derived). A reader landing on this file with no other context should be able to classify and tag any candidate test correctly.

## 1. Overview

Every emitted test carries exactly one **primary classification** plus a set of **orthogonal diagnostic dimensions**. The primary classification decides how the test behaves with respect to loopback; the diagnostic dimensions surface the provenance of the test so downstream skills (`realize-specification`, `measure-entailment`) and human reviewers can trace each assertion back to its formal ancestor — or recognise that no ancestor exists.

### Two test categories

The classification `test_category` has exactly two values — nothing else:

- **`projection`** — the test descends from a Lean theorem, a `formal_property/3` entry, or a verified Prolog model fact. It samples a universally-quantified proven property at a specific fixture. A red projection test means the implementation broke a proven invariant; it loops back through `realize-specification` to the proof layer if the proof itself needs revisiting.
- **`behavioral_claim`** — the test asserts a runtime-observable contract (I/O, state mutation, concurrency, timing, HTTP status, logging, error-mode behaviour) that no upstream proof ever expressed. It has no proof ancestry. A red behavioral_claim test means a contract was violated, but the pipeline has no upstream representation of that contract; loopback stops at the TDD layer.

These two categories exhaust the domain. There is no `formal_property` test class, no `edge_case` test class, no `structural` test class at the `test_category` level. Edge-case and structural tests that descend from proven claims are `projection`; edge-case and structural tests for behaviour the formal layer never expressed are `behavioral_claim`. Categorise by ancestry, not by shape.

### Seven orthogonal diagnostic dimensions

In addition to `test_category`, a test may carry any combination of the following fields. Each has exactly one source predicate:

| Field | Role |
|---|---|
| `epistemic_label` | What kind of claim the test descends from (`descriptive` / `counterfactual` / `prescriptive`). |
| `negation_provenance` | Why a negated premise is false (`absent` / `contradicts`). Only present when the source claim has a negated premise. |
| `proof_strategy` | Freeform string describing how Lean proved the parent theorem. Tells the implementor *how* the property was established. |
| `proof_mode` | Derived: `invariant` (every claim is descriptive) vs `conditional` (at least one counterfactual claim exists). |
| `sampled_from` | Natural-language name of the `formal_property/3` the test samples. |
| `fixture_set` | The specific values chosen for the quantified variable. |
| `unsampled_domain` | Values of the quantified variable the test does NOT cover — the explicit universality-loss annotation. |

## 2. Decision Tree

The litmus test: **is there a theorem in `lean_proof_results.pl` whose universal statement, when instantiated at this fixture, yields this assertion?**

```
Does the candidate test descend from …
├─ a Lean theorem (theorem_verdict/2 in lean_proof_results.pl)?        → projection
├─ a formal_property/3 in hypothesis.pl or target-world.pl?            → projection
├─ a verified model fact (verdict(_, consistent) in model_results.pl)? → projection
├─ a counterfactual claim + corresponding fact removal in
│  target-world.pl? (covers Phase 0 removal and reintroduction tests)  → projection
└─ none of the above — asserts I/O, state mutation, concurrency,
   timing, HTTP status, logging, or any other runtime-observable
   contract with no upstream formal representation?                    → behavioral_claim
```

If the answer is unclear, construct the universal statement explicitly and ask whether the candidate assertion is an instance. If no upstream universal statement can be written down without inventing one mid-pipeline, the test is `behavioral_claim`. Inventing a universal retroactively is silent strength-inflation — do not.

### Examples

- **Projection (positive sample).** Lean proves `∀m. ¬ Reach depends_on_target m Module.logging` for every module in `cli_tool`'s transitive cone. A test fixes `m = cli_tool` and asserts no import chain to `logging`. Source: `theorem_verdict(t_no_cli_to_logging, proven)`.
- **Projection (counterfactual removal).** `claim_label(c_001, counterfactual)` with `claim_premise(c_001, depends_on(cli_tool, logging))` triggers a Phase 0 removal test asserting no import edge from `cli_tool` to `logging`. Source: the counterfactual claim plus the corresponding `cf_fact(cli_tool, logging)` in `target-world.pl`.
- **Projection (reintroduction).** `necessity_lemma_status(t_no_cli_to_logging, f_cli_logging, proven)` triggers a reintroduction test that re-adds the edge and asserts the invariant breaks detectably. Still `projection` — the test witnesses a proved necessity lemma.
- **Behavioral claim.** "The `/health` endpoint returns HTTP 503 when the DB pool saturates." No Lean theorem expresses this — Lean has no representation for HTTP status codes or pool saturation timing. Classify `behavioral_claim`.
- **Behavioral claim.** "The logger writes a structured JSON line on every request." An I/O side-effect the formal layer cannot state. Classify `behavioral_claim`.

## 3. Tag-Source-Predicate Table

Every tag has exactly one source predicate (or a fully specified derivation rule). This is the contract — do **not** invent new predicate names; do **not** change arity; do **not** read a tag from the wrong artifact.

| Tag on test | Domain | Source predicate | Artifact |
|---|---|---|---|
| `test_category` | `projection` \| `behavioral_claim` | derived — see Section 2 decision tree | — |
| `epistemic_label` | `descriptive` \| `counterfactual` \| `prescriptive` | `claim_label(ClaimId, Label)` | `hypothesis.pl` |
| `negation_provenance` (claim side) | `absent` \| `contradicts` | `claim_negation_provenance(ClaimId, Fact, Mode)` | `hypothesis.pl` |
| `negation_provenance` (theorem side echo) | `absent` \| `contradicts` | `provenance_annotation(TheoremId, FactId, Mode)` | `lean_proof_results.pl` |
| `proof_strategy` | NL string | `proof_strategy(TheoremId, Strategy)` | `lean_proof_results.pl` |
| `proof_mode` | `invariant` \| `conditional` | derived: `conditional` iff any `claim_label(_, counterfactual)` exists in `hypothesis.pl`; else `invariant` | `hypothesis.pl` (presence test) |
| `sampled_from` | NL string | `formal_property(Id, NL, Sketch)` — use the `NL` argument | `target-world.pl` (propagated verbatim from `hypothesis.pl`) |
| `fixture_set` | author-chosen values | selected by the test author from the domain of the `formal_property/3` quantified variable | `target-world.pl` (property); test file (fixture) |
| `unsampled_domain` | author-chosen description | complement of `fixture_set` within the quantified domain | author-chosen; reported in COVERAGE GAPS |

### Critical arity and artifact facts

- **`claim_negation_provenance/3`** lives in `hypothesis.pl`. Three arguments: `(ClaimId, Fact, Mode)`. Do not look for a 2-argument form in `hypothesis.pl`.
- **`negation_provenance/2`** lives in `target-world.pl` — per-fact, 2-argument. Do **not** use `negation_provenance/2` as the source when tagging a test; use `claim_negation_provenance/3` from `hypothesis.pl` (claim-scoped) or `provenance_annotation/3` from `lean_proof_results.pl` (theorem-scoped).
- **`provenance_annotation/3`** lives in `lean_proof_results.pl`. Three arguments: `(TheoremId, FactId, Mode)`. This is the theorem-side echo of the hypothesis-side claim_negation_provenance; the two MUST agree. Disagreement is a malformed run — emit a LOOPBACK SIGNAL rather than silently pick one.
- **`formal_property/3`** — not `property/2`. Arity 3: `(PropertyId, NLDescription, LeanSketch)`. Consumed from `target-world.pl` (which propagates it verbatim from `hypothesis.pl`).
- **`proof_strategy/2`** lives only in `lean_proof_results.pl`, keyed on `TheoremId`.

### Concrete source queries

Resolve each tag with an actual `swipl` query, not by reading prose:

```bash
# epistemic_label for a claim
swipl -g "consult('thoughts/hypothesis.pl'), claim_label(c_001, L), write(L), halt."

# negation provenance — both sides, check agreement
swipl -g "consult('thoughts/hypothesis.pl'), claim_negation_provenance(c_001, F, M), format('~w ~w~n',[F,M]), halt."
swipl -g "consult('thoughts/lean_proof_results.pl'), provenance_annotation(t_no_cli_to_logging, FactId, M), format('~w ~w~n',[FactId,M]), halt."

# proof_strategy
swipl -g "consult('thoughts/lean_proof_results.pl'), proof_strategy(t_no_cli_to_logging, S), write(S), halt."

# proof_mode — derived
swipl -g "consult('thoughts/hypothesis.pl'), (claim_label(_, counterfactual) -> write(conditional) ; write(invariant)), halt."

# sampled_from
swipl -g "consult('thoughts/target-world.pl'), formal_property(p_001, NL, _), write(NL), halt."
```

## 4. Per-Category Required Fields

### `projection` — required fields

A `projection` test must carry every tag below. Missing any of them makes the test untraceable to its formal ancestor:

- `test_category: projection`
- `sampled_from:` — NL description from the source `formal_property/3` (or the source claim if sampling a counterfactual).
- `fixture_set:` — the specific values chosen for the quantified variable.
- `unsampled_domain:` — values of the quantified variable NOT covered; also aggregated into the COVERAGE GAPS block.
- `epistemic_label:` — `descriptive` \| `counterfactual` \| `prescriptive`, read from `claim_label/2`.
- `proof_strategy:` — the `proof_strategy/2` string from `lean_proof_results.pl`, when a Lean theorem is the parent. If the parent is a Prolog model fact rather than a Lean theorem, omit this field or set it to `"prolog-model"` with the verification query noted in the comment.
- `proof_mode:` — `invariant` \| `conditional`, derived from `hypothesis.pl`.
- `negation_provenance:` — **required iff** the source claim has a negated premise (every counterfactual claim; prescriptive claims with a `¬…` premise). Values `absent` or `contradicts`. Absent-provenance projections are fragile — the comment must flag this explicitly so a future reader knows the proof rests on CWA completeness.

### `behavioral_claim` — required and forbidden fields

A `behavioral_claim` test has **no proof ancestry**. It must:

- Carry `test_category: behavioral_claim`.
- Live under the dedicated `## Behavioral Contracts` section / Phase B at the bottom of the test file.
- Document in its comment block why the claim cannot be expressed formally (e.g., "asserts HTTP 503 on pool saturation — Lean has no representation for HTTP status").

It must **omit** the following fields — they imply formal ancestry that does not exist:

- `proof_strategy` — no parent theorem.
- `epistemic_label` — no parent `claim/2`.
- `sampled_from` — no parent `formal_property/3`.
- `fixture_set` — nothing is being sampled; the test's inputs are simply inputs.
- `unsampled_domain` — no quantified domain to partition.
- `negation_provenance` — no negated premise flows from upstream.

`proof_mode` is a suite-level property, not a per-test one — it applies uniformly to the projection layer of the file. Behavioral_claim tests do not carry it either.

## 5. Why These Distinctions Matter

The tag system exists to make three structural distinctions auditable rather than folklore. Flattening any of them is a category error with downstream consequences.

**`behavioral_claim_neq_proven_property`** is the enforcement rule that makes `test_category` load-bearing. A red `projection` test is a signal the implementation broke an invariant the proof layer already established — the fix lives in the code, and if the code is correct then the proof or hypothesis is wrong and must be re-visited upstream. A red `behavioral_claim` test is a signal that a contract *never proven* has been violated; there is no upstream to return to. If these two test shapes are merged, `realize-specification`'s loopback logic silently routes behavioral-contract failures into `decompose-proposition`, which has no representation of the behavioural claim. The result: a runaway loop or a fabricated upstream claim.

**`cwa_negation_neq_lean_proof`** is the enforcement rule that makes the `absent`/`contradicts` split load-bearing on projection tests. A test that rests on `negation_provenance(absent)` is a witness at one fixture of a proved property whose negated premise is false under closed-world assumption — the proof holds only to the extent the KB is complete. A test that rests on `negation_provenance(contradicts)` rests on an explicitly-asserted conflict in the KB and is structurally necessary regardless of KB completeness. Flattening the two silently upgrades CWA-absence into logical falsity — a green test under `absent` provenance looks the same as a green test under `contradicts`, but the first is fragile and the second is not. Surface `absent` explicitly in the comment block; surface aggregate `absent`-count in the summary.

**`lean_universal_neq_test_verified`** is the enforcement rule that makes `fixture_set` and `unsampled_domain` load-bearing. A green `projection` test is a *witness* of the universally-proved property at one point. It does not re-prove ∀x.P(x); the Lean theorem remains the authority on universality. Recording the fixture chosen and the domain NOT sampled keeps this honest — it is the only place in the pipeline where the universality-loss at the `lean → tdd` boundary is made explicit. Dropping `unsampled_domain` turns the suite into a tacit claim of full proof re-verification, which it is not.

All three rules are invariants of the pipeline. The tag vector on each test is what lets later skills and human reviewers verify the invariants still hold.

## 6. Cross-References

- **`../../../references/epistemic-types.md`** — canonical semantics of `epistemic_label`, `negation_provenance`, and `test_category`. The three-node ontology (Prolog / Lean / TDD), the gain/loss accounting at each boundary, and the three enforcement rules. Read this to understand *why* the tags exist.
- **`../../../references/pipeline-schema/`** — wire format of every `.pl` artifact in the pipeline. The `README.md` in that directory maps each artifact to its producer and consumer.
- **`../../../references/pipeline-schema/hypothesis.md`** — schema for `thoughts/hypothesis.pl`. Source of truth for `claim/2`, `claim_label/2`, `claim_status/2`, `claim_premise/2`, `claim_negation_provenance/3` (note arity 3), and `formal_property/3`.
- **`../../../references/pipeline-schema/target-world.md`** — schema for `thoughts/target-world.pl`. Source of truth for `formal_property/3` propagation, `cf_fact/N`, `negation_provenance/2` (note arity 2 — different from hypothesis), and target-relation helpers.
- **`../../../references/pipeline-schema/lean-proof-results.md`** — schema for `thoughts/lean_proof_results.pl`. Source of truth for `theorem_verdict/2`, `proof_strategy/2`, `provenance_annotation/3`, `failure_mode/2`, `theorem_source/2`, and `necessity_lemma_status/3`.
- **`./test-templates.md`** — the complete output template for the emitted test file, including the header block, per-test comment-block schema, phase ordering, framework-specific skip idioms, and the LOOPBACK SIGNALS / COVERAGE GAPS blocks. Consult this when writing the file; consult *this* document when deciding what each test should be tagged with.
