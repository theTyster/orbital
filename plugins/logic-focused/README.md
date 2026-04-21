# logic-focused

Formal logic reasoning pipeline: Prolog translation, hypothesis exploration, Lean 4 or Prolog proof verification, test generation, and implementation review.

## Pipeline

```
a. translate-to-prolog    — Translate a codebase into a Prolog knowledge base
b. hypothesize            — Ingest a proposition and create a hypothesis based on the Prolog KB
c. prove-hypothesis-{lean,prolog}  — Formally verify the hypothesis (loops back to b if unprovable)
d. translate-to-tests    — Combine logical patterns into TDD tests that verify those patterns
e. explain                — Explain whatever was done at any pipeline stage in plain language for non-technical review
```

Step c has two alternative proof backends — use Lean for mathematical/abstract proofs, Prolog for model-based verification of relational/structural properties.

## Additional Skills

- **setup-lean-mathlib** — Set up and manage Lean 4 projects using a shared system-wide Mathlib installation
- **setup-lean-project** — Create a thin Lean 4 project referencing the shared Mathlib clone
- **measure-adherance** — Score how well two or more resources adhere to each other using Prolog-based relational analysis

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)) — use `setup-lean-mathlib` for initial setup
- **SWI-Prolog** (`swipl`)
