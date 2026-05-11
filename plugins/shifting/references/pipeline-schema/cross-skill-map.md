# Cross-skill name map

Quick translation table for how the same concept is named across artifacts. Use this when a concept flows across a boundary and the predicate name or arity changes.

| Concept | `hypothesis.pl` | `target-world.pl` | `model_results.pl` | `lean_proof_results.pl` |
|---|---|---|---|---|
| Negated premise | `claim_negation_provenance(ClaimId, Fact, Mode)` | `negation_provenance(Fact, Mode)` | — | `provenance_annotation(TheoremId, FactId, Mode)` |
| Claim body fact | `claim_premise(ClaimId, Fact)` | `cf_fact/N` (for counterfactuals) | — | — |
| Ground-fact provenance | — | `provenance(Fact, descriptive \| prescriptive)` | — | — |
| Formal property | `formal_property(Id, NL, LeanSketch)` | `formal_property(Id, NL, LeanSketch)` (verbatim copy) | referenced by Id in `verdict/2` | referenced by Id in `proof_verdict/2` |
| Property verdict (model) | — | `verdict(Id, consistent \| inconsistent \| gap)` (directive-asserted) | `verdict(Id, consistent \| inconsistent \| gap)` | — |
| Property verdict (proof) | — | — | — | `theorem_verdict(TheoremId, proven \| unprovable)` |
| Epistemic label | `claim_label(ClaimId, descriptive \| counterfactual \| prescriptive)` | carried implicitly via per-fact `provenance/2` + `negation_provenance/2` | — | — |

## Boundary translations

Each cell below is a transformation a specific skill performs.

### `decompose-proposition → model-obligations` (at `hypothesis.pl`)

| Input | Output |
|---|---|
| `claim_label(Id, counterfactual)` + `claim_premise(Id, F)` + `claim_negation_provenance(Id, F, Mode)` | — (consumed; used to build target-world) |
| `claim_label(Id, prescriptive)` + `claim_premise(Id, F)` | — (consumed; used to assert F in target-world) |
| `formal_property(Id, NL, Sketch)` | — (consumed + propagated verbatim) |

### `model-obligations → prove-invariants` (at `target-world.pl`)

| Input from hypothesis | Output in target-world |
|---|---|
| `claim_negation_provenance(Id, F, Mode)` (per-claim, 3-arg) | `negation_provenance(F, Mode)` (per-fact, 2-arg) |
| `claim_premise(Id, F)` where `claim_label(Id, counterfactual)` | fact `F` *omitted* + `cf_fact/N` entry |
| `claim_premise(Id, F)` where `claim_label(Id, prescriptive)` | fact `F` *asserted* + `provenance(F, prescriptive)` |
| existing-world fact `F` not negated by any counterfactual | fact `F` carried over + `provenance(F, descriptive)` |
| `formal_property(Id, NL, Sketch)` | `formal_property(Id, NL, Sketch)` *verbatim* |

### `prove-invariants → instantiate-properties` (at `lean_proof_results.pl`)

| Input | Output |
|---|---|
| `formal_property/3` from target-world | `theorem_verdict(TheoremId, _)` for each |
| `negation_provenance(F, Mode)` for negated-premise F | `provenance_annotation(TheoremId, FactId, Mode)` for theorems that cite F |

## Stable names — do not rename

These names are the contract. A skill that renames one is broken, not the wiki.

- `formal_property/3` — **not** `property/2`.
- `claim_negation_provenance/3` (in hypothesis) — **not** `negation_provenance/2` or `negation_provenance/3` here; the 3-argument per-claim form is what `model-obligations` reads.
- `negation_provenance/2` (in target-world) — **not** `provenance/2`; reserved for counterfactually-removed facts only. Use `provenance/2` for asserted facts.
- `theorem_verdict/2` (in lean_proof_results) — **not** `verdict/2`; the latter is reserved for model-level verdicts in `model_results.pl`.
