# Epistemic Types for the Logic-Focused Pipeline

This document is the canonical reference for the *typed artifact system* used across the logic-focused pipeline. Every claim that flows from one skill to another carries tags that record its origin, the strength of its negations, and what was preserved or lost when it crossed a boundary. Boundary skills MUST preserve these tags — treating a CWA-absent fact as a Lean-disproved fact, or a Lean-universal property as a test-verified one, is a category error the tag system exists to prevent.

## The three-node ontology

The pipeline has three reasoning systems. Each is strong in a different dimension. Each weakness becomes the motivation for the next node.

| Node | Strong on | Weak on | Negation semantics |
|---|---|---|---|
| **Prolog** | *what is* — deterministic, closed, contradiction-native over a finite KB | generality beyond the KB; cannot reason about state it was never told about | `\+ P` = "not derivable" under closed-world assumption (CWA) — absence, not falsity |
| **Lean** | *what must be* — universal, constructive, ∀-quantified over arbitrary types | purely logical; cannot reason about side effects, I/O, state mutation, timing, concurrency | `¬ P` = logical negation — a theorem `¬P` proves P is inconsistent with axioms |
| **TDD** | *what does* — behavioral, imperative, implementation-bound, can assert against runtime | no universality — every assertion is over a specific fixture; no automatic generalisation | a failing test = implementation-does-not-satisfy-property-on-this-fixture, not ¬property |

The skills that cross between these nodes are the **edges of the ontology**. An edge must encode four facts about every claim that crosses it:

1. **What survived the crossing** (preserved strength)
2. **What was weakened** (downgraded but still present)
3. **What was lost entirely** (provenance stripped, distinction flattened)
4. **What new claims the destination introduces** (claims with no upstream backing)

## The tag system: two orthogonal dimensions plus one test classification

The pipeline uses two orthogonal claim-level dimensions and one test-level classification. They are *independent* — a single claim can carry one value from each. Dropping any dimension at a boundary is the failure mode this document is designed to prevent.

### Dimension 1 — `epistemic_label` on every claim

Every `claim/2` in `thoughts/hypothesis.pl` carries exactly one `epistemic_label`. The label says *what kind of claim it is* — what world the claim is about.

| Label | Meaning | World semantics |
|---|---|---|
| `descriptive` | What is currently true in the existing world | Prolog KB (CWA) — a positive assertion the existing-world.pl already entails |
| `counterfactual` | What must become false for the goal to hold | Prolog KB (CWA, inverted) — a fact that exists in existing-world.pl but must not exist in target-world.pl |
| `prescriptive` | What must exist or be provable in the target state | Lean proof (OWA) — a fact that does not yet exist; the implementation must make it true |

Downstream consumption:
- `model-obligations` reads the label to decide how each claim contributes to `target-world.pl`. A `counterfactual` claim removes a fact; a `prescriptive` claim adds one; a `descriptive` claim is already satisfied by `existing-world.pl`.
- `prove-invariants` reads the label to decide which claims become formal theorems and how to phrase them.
- `instantiate-properties` reads the label when sampling a property: counterfactual claims project to absence-style tests; prescriptive claims project to presence-style tests; descriptive claims project to invariant tests.

### Dimension 2 — `negation_provenance` on every negated premise

Whenever a claim's body involves a *negation* — every `counterfactual` claim plus any `prescriptive` claim with a `¬…` premise — that negation carries exactly one `negation_provenance` tag. The provenance says *why the fact is false*.

| Provenance | Meaning | Strength |
|---|---|---|
| `absent` | False because the fact is not declared in the KB (CWA default) | Fragile — depends on KB completeness; the negation can be wrong if the KB is incomplete |
| `contradicts` | False because the KB contains an explicit conflicting fact (negative fact, integrity constraint, or derivation of `false`) | Structurally necessary — holds regardless of KB completeness |

The two values are the entire domain. There is no third option.

The tag is most load-bearing at the `prolog → lean` boundary: when a negated premise enters Lean, Lean treats `¬P` as logical falsity regardless of provenance. Without the tag travelling with the premise, an `absent`-provenance negation silently becomes "mathematically proven false." Every Lean theorem with a negated premise must record the provenance in a docstring/comment block above the theorem.

### Test-level classification — `test_category`

Every test emitted by `instantiate-properties` carries exactly one `test_category`. The domain has exactly two values.

| Category | Derivation | Failure semantics |
|---|---|---|
| `projection` | Derived from a Lean proof applied to a specific fixture | Implementation bug: the proved property fails at this sample point |
| `behavioral_claim` | New claim introduced at the TDD boundary (I/O, state, concurrency, timing) | Contract failure — no upstream proof; the claim itself may need scrutiny |

`projection` covers everything that traces back to a proven property — including absence tests for counterfactual claims and guard tests for load-bearing necessity lemmas. `behavioral_claim` covers anything the formal layer never expressed.

## The three enforcement rules

These rules are invariants of the pipeline. Skills surface them in their guidance; tags exist to prevent silent violations.

1. **`cwa_negation_neq_lean_proof`** — A fact that is false because absent from the KB is categorically different from a formally disproved fact. Every Lean theorem with a `negation_provenance(absent)` premise carries that provenance forward; Lean cannot reconstruct it.

2. **`lean_universal_neq_test_verified`** — A passing test samples one point in a proof domain. It does not re-verify ∀x.P(x). A green `projection` test is a *witness*, not a re-proof; the upstream Lean theorem remains the authority on universality.

3. **`behavioral_claim_neq_proven_property`** — A test covering I/O, state, or concurrency has no proof ancestry. It must be distinguishable from a projection test. A failing `behavioral_claim` test cannot loop back to `decompose-proposition` or the prove skills — those nodes never expressed the claim.

## Boundary crossings

Two formal boundaries carry typed artifacts between nodes.

### `prolog → lean` boundary
Carrier: `thoughts/target-world.pl`.
- **Gain**: universal properties Prolog cannot state (∀x.P(x)).
- **Loss**: CWA negation provenance is stripped unless preserved. The two types of falseness are conflated: `absent(F)` vs `contradicts(F, G)`. The mechanism that prevents the loss from being silent is the `negation_provenance` annotation on every Lean theorem with a negated premise.

### `lean → tdd` boundary
Carrier: `thoughts/lean_proof_results.pl`.
- **Gain**: behavioral claims Lean cannot express — I/O, side effects, state mutation, concurrency, timing. These appear as `test_category(behavioral_claim)` tests.
- **Loss**: modality is discarded; universality is lost. A Lean proof of ∀x.P(x) becomes P(specific_fixture) when projected to a test. A green test does not re-verify the full proof strength. The mechanism that surfaces this loss is the `test_category` tag plus the per-test `unsampled_domain` annotation.

## Edge semantics, skill by skill

Each boundary-crossing skill carries explicit loss/gain obligations.

### `close-world` — source code → existing-world.pl
- **Preserved**: declared relationships, structural dependencies, named entities.
- **Lost**: runtime behaviour, state transitions, timing, I/O, concurrency.
- **Introduced**: CWA default — every fact not asserted is implicitly absent.

### `decompose-proposition` — existing-world.pl + proposition → hypothesis.pl
- **Preserved**: what the KB says positively and negatively.
- **Introduced**: claim decomposition. Every claim is tagged with an `epistemic_label`; every negated premise additionally with a `negation_provenance`.

### `model-obligations` — hypothesis.pl + existing-world.pl → target-world.pl + model_results.pl
- **Preserved**: CWA provenance is native; it travels through `negation_provenance` annotations on every removed-or-contradicted fact in target-world.pl.
- **Introduced**: per-property `verdict(PropertyId, consistent | inconsistent | gap)` records in `model_results.pl`.

### `prove-invariants` — hypothesis.pl + target-world.pl → lean_proof_results.pl
- **Preserved**: logical structure of each property (∀, ∃, →, ¬). The `negation_provenance` of every negated premise is preserved as a docstring/comment block above its theorem.
- **Lost (if not actively preserved)**: CWA provenance. Lean cannot distinguish a theorem with a genuinely false premise from one with a CWA-absent premise. The skill MUST record the `provenance(absent | contradicts)` annotation on every relevant theorem.
- **Introduced**: universal quantification over arbitrary types — real new strength when the type is larger than the KB's enumeration. Per-theorem `theorem_verdict(TheoremId, proven | unprovable)` facts in `lean_proof_results.pl`.

### `instantiate-properties` — lean_proof_results.pl + (optional) hypothesis.pl + target-world.pl + model_results.pl + .lean files → test suite
- **Preserved**: per-test reference to the source property; per-test `epistemic_label` and (if applicable) `negation_provenance` carried from the source claim.
- **Weakened — the sampling downgrade**: universality is lost. Each `projection` test records the quantified domain it samples and the values of that domain it does NOT cover.
- **Lost**: the ability to re-verify the full strength of the proof.
- **Introduced**: `behavioral_claim` tests. They have no upstream backing; they appear in their own phase and cannot loop back to upstream stages.

### `realize-specification` — test suite + (optional) lean_proof_results.pl + hypothesis.pl + target-world.pl + model_results.pl → source code + implementation_log.md
- **Preserved**: the test-to-property link via the implementation log. Each entry records the cited claim's `epistemic_label` and (if applicable) `negation_provenance`.
- **Routing**: the orchestrator chooses its briefing shape from `test_category` and the cited claim's `epistemic_label`. A `projection` test whose claim is `counterfactual` triggers a *removal* briefing (delete the fact's source location); a `projection` test whose claim is `descriptive` or `prescriptive` triggers an *addition* briefing; a `behavioral_claim` test triggers a *behavioral* briefing.
- **Loopback constraint**: `behavioral_claim` failures do NOT loop back into the formal pipeline. There is no upstream property to revise.

### `measure-entailment` — implemented codebase + implementation_log.md + hypothesis.pl → adherence_facts.pl + adherence_report.md
- **Obligation**: score how much the implemented system entails the original proposition. Per-claim breakdown surfaces how each `epistemic_label` was realized: counterfactual claims should have absent fact-sources; prescriptive claims should have provable evidence; descriptive claims should remain entailed.

## How skills should emit and consume tags

- **Emit**: every artifact a skill writes (hypothesis.pl, model_results.pl, lean_proof_results.pl, .lean source, test file, implementation log, adherence report) must tag each claim with the appropriate dimension(s). For Prolog facts, use the dimension's predicate name (`claim_label/2`, `negation_provenance/2`, `test_category/2`); for non-Prolog artifacts, use a comment block, a docstring, or a YAML field — but the vocabulary is this document's.
- **Consume**: when a skill reads a prior artifact, it propagates tags forward. Never emit a downstream claim with a stronger tag than its weakest upstream input. Adding strength mid-pipeline is how `negation_provenance(absent)` premises silently become "mathematically proven."
- **Never flatten**: when translating a claim into a different artifact's format (e.g., a Lean theorem becoming a test), the dimensions must travel with it. A `projection` test that samples a Lean theorem with a `negation_provenance(absent)` premise is still constrained by the fragile-CWA caveat — record it.

## Failure modes this system is designed to catch

- **CWA-as-truth**: Treating `\+ depends_on(A, B)` as a proof that A does not depend on B. It is a proof that the KB does not *say* A depends on B. The `negation_provenance(absent)` tag exists to keep this audible.
- **Universal-as-tested**: Treating a green test suite as re-verifying the upstream proof. Green means "the implementation passed the sampled witnesses." The proof is still the authority on universality; the suite is a tripwire. (`lean_universal_neq_test_verified`)
- **Behavioral-as-formal**: Treating a `behavioral_claim` test as though it were backed by a proof. A green behavioral test means the fixture passed on this run. It does not mean the behaviour is guaranteed for other inputs, other timings, or other environments. (`behavioral_claim_neq_proven_property`)
- **Loopback-to-wrong-stage**: Failing a `behavioral_claim` test and looping back to `decompose-proposition`. The decompose-proposition/prove stages never expressed a behavioral claim — there is nothing to revise upstream. The fix lives in the TDD layer or in a manual decision.
- **Silent dimension drop across a boundary**: Stripping `negation_provenance` when translating into Lean, or `epistemic_label` when translating into the test file, or `test_category` when entering implementation. Each strip is a category error that compounds downstream.
