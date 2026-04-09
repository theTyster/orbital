# logic-focused

Formal logic reasoning pipeline: Prolog translation, hypothesis exploration, Lean 4 proof verification, proof translation, and proof-grounded planning.

## Pipeline

```
1. translate-to-prolog    — Translate logic into Prolog facts
2. query-hypothesis       — Query Prolog to explore and write a hypothesis
3. formalize-in-lean      — Formalize hypothesis in Lean4 (loops back to 2 if unprovable)
4a. translate-proof-llm   — Translate proven Lean4 into logical description for LLM consumption
4b. translate-proof-human — Translate proven Lean4 into human-readable summary
5. plan-from-proof        — Create implementation plan from the logical description
```

## Additional Skills

- **prove-with-lean** — Direct code verification using Lean 4 with PostToolUse hooks
- **scaffold-pseudocode** — Logical pattern documents capturing invariants, types, and edge predicates

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan))
- **SWI-Prolog** (`swipl`)
