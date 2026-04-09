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
- **prove-with-lean** — Direct code verification using Lean 4 with PostToolUse hooks
- **scaffold-pseudocode** — Logical pattern documents capturing invariants, types, and edge predicates

### c4-prolog

C4 architectural modeling and Prolog-based codebase analysis.

- **reason-with-prolog** — Maps codebases to C4 facts via orbital flow (Find > Define > Condense) and produces implementation plans grounded in formal analysis

### multi-plan

Parallel worktree orchestration with review cycles.

- **multi-plan** — Orchestrate multiple enhancements in parallel through a plan > review > human-vetting > implement > commit pipeline

### utilities

Standalone developer utilities.

- **make-commits** — Review all unstaged changes and organize them into logical commits
- **create-presentation** — Generate a self-contained HTML slideshow from any source material

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for formalize-in-lean and prove-with-lean. First build (`lake build` in `plugins/logic-focused/skills/prove-with-lean/lean/`) takes 10-20 minutes for Mathlib compilation.
- **SWI-Prolog** (`swipl`): Required for translate-to-prolog, query-hypothesis, reason-with-prolog, and multi-plan.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/logic-focused-claude
```

## License

Apache 2.0
