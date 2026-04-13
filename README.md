# logic-focused-claude

Logic-focused skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): a formal reasoning pipeline from logic translation through proof verification to implementation planning, plus architectural analysis, parallel orchestration, and developer utilities.

## Plugins

This repository contains 4 plugins, decomposed by concern domain:

### logic-focused

Formal logic reasoning pipeline — from Prolog translation through Lean 4 proof verification to implementation planning.

```
1. translate-to-prolog    — Translate logic into Prolog facts
2. query-hypothesis       — Query Prolog to explore and write a hypothesis
3. formalize-in-lean      — Formalize hypothesis in Lean4 (loops back to 2 if unprovable)
4a. translate-proof-llm   — Translate proven Lean4 into logical description for LLM consumption
4b. translate-proof-human — Translate proven Lean4 into human-readable summary
5. plan-from-proof        — Create implementation plan from the logical description
```

Also includes:
- **setup-lean-mathlib** — Set up and manage Lean 4 projects using a shared system-wide Mathlib installation
- **prove-with-lean** — Direct code verification using Lean 4 with PostToolUse hooks
- **scaffold-pseudocode** — Logical pattern documents capturing invariants, types, and edge predicates

### c4-prolog

C4 architectural modeling and Prolog-based codebase analysis.

- **c4-find-patterns** — Map a codebase to C4 ontology facts
- **c4-define-patterns** — Verify a C4 facts file with structural queries
- **c4-condense-patterns** — Transform Prolog analysis into an implementation plan
- **c4-analyze** — Orchestrate the full pipeline (find > define > condense)
- **reason-with-prolog** — Legacy wrapper, redirects to c4-analyze

### multi-plan

Parallel worktree orchestration with review cycles.

- **multi-plan** — Orchestrate multiple enhancements in parallel through a plan > review > human-vetting > implement > commit pipeline

### utilities

Standalone developer utilities.

- **make-commits** — Review all unstaged changes and organize them into logical commits
- **create-presentation** — Generate a self-contained HTML slideshow from any source material

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for formalize-in-lean, prove-with-lean, and setup-lean-mathlib. Use `setup-lean-mathlib` to install a shared Mathlib clone, avoiding repeated multi-hour compilations.
- **SWI-Prolog** (`swipl`): Required for translate-to-prolog, query-hypothesis, reason-with-prolog, and multi-plan.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/logic-focused-claude
```

## License

Apache 2.0
