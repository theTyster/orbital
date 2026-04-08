# orbital

Orbital workflow skills for Claude Code: a formal reasoning pipeline from logic translation through proof verification to implementation planning.

## Workflow

```
1. translate-to-prolog    — Translate logic into Prolog facts
2. query-hypothesis       — Query Prolog to explore and write a hypothesis
3. formalize-in-lean      — Formalize hypothesis in Lean4 (loops back to 2 if unprovable)
4a. translate-proof-llm   — Translate proven Lean4 into logical description for LLM consumption
4b. translate-proof-human — Translate proven Lean4 into human-readable summary
5. plan-from-proof        — Create implementation plan from the logical description
```

## Skills

### translate-to-prolog
Translate domain logic, requirements, or code behavior into a Prolog facts file using C4 ontology predicates.

### query-hypothesis
Query a Prolog knowledge base to explore relationships, derive hypotheses, and write them to a structured hypothesis file.

### formalize-in-lean
Formalize a hypothesis as Lean4 theorems with machine-checked proofs. Loops back to query-hypothesis if the hypothesis is unprovable.

### translate-proof-llm
Translate a proven Lean4 file into a precise natural language logical description formatted for LLM consumption.

### translate-proof-human
Translate a proven Lean4 file into a clear natural language summary for human readers.

### plan-from-proof
Create a concrete implementation plan grounded in the proven logical description.

## Prerequisites

- **SWI-Prolog** (`swipl`): Required for translate-to-prolog and query-hypothesis.
- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for formalize-in-lean.

## License

Apache 2.0
