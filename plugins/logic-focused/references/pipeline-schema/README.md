# Pipeline Schema Wiki

Canonical Prolog predicate schema for artifacts that cross skill boundaries in the logic-focused pipeline. One file per artifact. When a skill's local documentation disagrees with a file in this wiki, **the wiki wins** and the skill is out of date.

Companion: `../ontology.md` defines the *semantics* of the ontology labels (`claim_label`, `negation_provenance`, etc.); this wiki defines the *syntax* — which predicate, which arity, which argument order — that carries those labels across boundaries.

## Artifact flow

```
  decompose-proposition  →  hypothesis.pl
                                ↓
           existing-world.pl ─→ model-obligations  →  target-world.pl
                                                       model_results.pl
                                                         ↓
                                                     prove-invariants  →  lean_proof_results.pl
                                                         ↓
                                                     instantiate-properties  →  skipped test suite
```

Every arrow labelled with an artifact is a schema boundary.

## Files in this wiki

| File | Artifact | Emitter | Consumer(s) |
|---|---|---|---|
| [`hypothesis.md`](hypothesis.md) | `thoughts/hypothesis.pl` | `decompose-proposition` | `model-obligations` |
| [`target-world.md`](target-world.md) | `thoughts/target-world.pl` | `model-obligations` | `prove-invariants` |
| [`model-results.md`](model-results.md) | `thoughts/model_results.pl` | `model-obligations` | `instantiate-properties` |
| [`lean-proof-results.md`](lean-proof-results.md) | `thoughts/lean_proof_results.pl` | `prove-invariants` | `instantiate-properties` |
| [`cross-skill-map.md`](cross-skill-map.md) | — | — | — |

Start with `cross-skill-map.md` for the quick name-translation table across artifacts, then drill into the specific file you're emitting or consuming.

## Enforcement

When updating any of `decompose-proposition`, `model-obligations`, or `prove-invariants`, verify that the predicate names and arities emitted/consumed match the relevant file in this wiki exactly. If a skill needs a new predicate or a different arity, update *the wiki file first*, then update every skill that crosses the affected boundary. Never let a skill's local schema diverge from this reference.
