# logic-focused-claude

Logic-focused skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): a formal reasoning pipeline from logic translation through proof verification to test generation and implementation review, plus architectural analysis, parallel orchestration, and developer utilities.

## Plugins

This repository contains 4 plugins, decomposed by concern domain:

### logic-focused

Formal logic reasoning pipeline — from Prolog translation through Lean 4 proof verification to synthesized pseudocode, TDD tests, and implementation review.

```
a. translate-to-prolog    — Translate a codebase into a Prolog knowledge base
b. hypothesize            — Ingest a proposition and create a hypothesis based on the Prolog KB
c. prove-hypothesis       — Formally verify the hypothesis (loops back to b if unprovable)
d1. synthesize-pseudocode — Combine logical patterns from multiple sources (code, Lean, Prolog) into unified pseudocode
d2. translate-to-tests    — Combine logical patterns into TDD tests that verify those patterns
e. explain                — Explain whatever was done at any pipeline stage in plain language for non-technical review
```

Steps d1 and d2 are parallel — either or both can follow step c depending on what the implementation needs.

Also includes:
- **setup-lean-mathlib** — Set up and manage Lean 4 projects using a shared system-wide Mathlib installation
- **setup-lean-project** — Create a thin Lean 4 project referencing the shared Mathlib clone
- **measure-adherance** — Score how well two or more resources adhere to each other using Prolog-based relational analysis (shared facts, gaps, contradictions, extensions)

### c4-prolog

C4 architectural modeling and Prolog-based codebase analysis.

- **c4-find-patterns** — Map a codebase to C4 ontology facts
- **c4-define-patterns** — Verify a C4 facts file with structural queries
- **c4-condense-patterns** — Transform Prolog analysis into an implementation plan
- **c4-analyze** — Orchestrate the full pipeline (find > define > condense)

### multi-plan

Parallel worktree orchestration with review cycles.

- **multi-plan** — Orchestrate multiple enhancements in parallel through a plan > review > human-vetting > implement > commit pipeline

### utilities

Standalone developer utilities.

- **make-commits** — Review all unstaged changes and organize them into logical commits
- **create-presentation** — Generate a self-contained HTML slideshow from any source material

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for prove-hypothesis and setup-lean-mathlib. Use `setup-lean-mathlib` to install a shared Mathlib clone, avoiding repeated multi-hour compilations.
- **SWI-Prolog** (`swipl`): Required for translate-to-prolog, hypothesize, and multi-plan.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/logic-focused-claude
```

## License

Apache 2.0
