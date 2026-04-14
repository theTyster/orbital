# logic-focused

Formal logic reasoning pipeline: Prolog translation, hypothesis exploration, Lean 4 proof verification, pseudocode synthesis, test generation, and implementation review.

## Pipeline

```
a. translate-to-prolog    — Translate a codebase into a Prolog knowledge base
b. hypothesize            — Ingest a proposition and create a hypothesis based on the Prolog KB
c. prove-hypothesis       — Formally verify the hypothesis (loops back to b if unprovable)
d1. synthesize-pseudocode — Combine logical patterns from multiple sources (code, Lean, Prolog) into unified pseudocode
d2. translate-to-tests    — Combine logical patterns into TDD tests that verify those patterns
e. explain-proof          — Document all decisions and artifacts and explain them in natural language for review
```

Steps d1 and d2 are alternatives (OR) — either, both, or neither can follow step c depending on what the implementation needs.

## Additional Skills

- **setup-lean-mathlib** — Set up and manage Lean 4 projects using a shared system-wide Mathlib installation
- **setup-lean-project** — Create a thin Lean 4 project referencing the shared Mathlib clone

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)) — use `setup-lean-mathlib` for initial setup
- **SWI-Prolog** (`swipl`)
