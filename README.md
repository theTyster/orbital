# logic-focused-claude

Logic-focused skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): a formal reasoning pipeline from logic translation through proof verification to test generation and implementation review, plus architectural analysis, parallel orchestration, and developer utilities.

## Plugins

This repository contains 4 plugins, decomposed by concern domain:

### logic-focused

Formal logic reasoning pipeline — from Prolog translation through proof verification to TDD tests and implementation review.

```
a. translate-to-prolog    — Translate a codebase into a Prolog knowledge base
b. hypothesize            — Ingest a proposition and create a hypothesis based on the Prolog KB
c. prove-hypothesis-{lean,prolog} — Formally verify the hypothesis (loops back to b if unprovable)
d. translate-to-tests     — Combine proven logical patterns into TDD tests that verify those patterns
e. translate-to-implementation — Orchestrate sub-agents to drive the TDD suite to green, refactoring against the proofs as the spec
f. explain                — Explain whatever was done at any pipeline stage in plain language for non-technical review
```

Step c has two alternative proof backends — use Lean for mathematical/abstract proofs, Prolog for model-based verification of relational/structural properties.

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

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for prove-hypothesis-lean and setup-lean-mathlib. Use `setup-lean-mathlib` to install a shared Mathlib clone, avoiding repeated multi-hour compilations.
- **SWI-Prolog** (`swipl`): Required for translate-to-prolog, hypothesize, and multi-plan.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/logic-focused-claude
```

## Versioning

Plugin versions are tracked in `.claude-plugin/marketplace.json` — one `version` field per plugin entry. This is what the plugin manager reads. When asked to "bump the version", update the relevant plugin's version in `.claude-plugin/marketplace.json`.

## License

Apache 2.0
