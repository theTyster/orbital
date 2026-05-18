# orbital

Intent-shaped skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): a formal reasoning pipeline from logic translation through proof verification to test generation and implementation review, plus architectural analysis, parallel orchestration, and developer utilities.

> Formerly `orbital-shift` (and before that `logic-focused-claude`). See [MIGRATION.md](MIGRATION.md) if you have an existing install under an old name.

## Plugins

This repository contains 4 plugins, decomposed by concern domain:

### orbital-shifting

Formal logic reasoning pipeline — from Prolog translation through proof verification to TDD tests and implementation review.

```
a. close-world    — Translate a codebase into a Prolog knowledge base
b. decompose-proposition  — Ingest a proposition and create a hypothesis based on the Prolog KB
c. model-obligations / prove-invariants — Formally verify the hypothesis (loops back to b if unprovable)
d. instantiate-properties     — Combine proven logical patterns into TDD tests that verify those patterns
e. realize-specification — Orchestrate sub-agents to drive the TDD suite to green, refactoring against the proofs as the spec
f. explain                — Explain whatever was done at any pipeline stage in plain language for non-technical review
```

Step c has two alternative proof backends — use Lean for mathematical/abstract proofs, Prolog for model-based verification of relational/structural properties.

Also includes:
- **measure-entailment** — Score how well two or more resources adhere to each other using Prolog-based relational analysis (shared facts, gaps, contradictions, extensions)

### orbital-scaffolding

Adopter onboarding, environment provisioning, and C4 architectural modeling. Owns the marketplace-wide `setup` flow plus the Lean toolchain bootstrapping that the shifting pipeline depends on.

- **setup** — First-time bootstrap. Interviews the adopter, creates `thoughts/`, appends `.gitignore` entries, writes the `.claude/orbital-setup.json` marker, and delegates to the Lean setup skills below if needed. Re-run with `--check` as a health audit.
- **setup-lean-mathlib** — Set up and manage a shared system-wide Mathlib clone at `~/.lean/mathlib4`. Avoids re-downloading Mathlib for every project.
- **setup-lean-project** — Create a thin Lean 4 project at `thoughts/lean/` referencing the shared Mathlib clone.
- **c4-find-patterns** — Map a codebase to C4 ontology facts
- **c4-define-patterns** — Verify a C4 facts file with structural queries
- **c4-condense-patterns** — Transform Prolog analysis into an implementation plan
- **c4-analyze** — Orchestrate the full pipeline (find > define > condense)

### orbital-trajectory

End-to-end orchestration of the orbital-shifting pipeline.

- **pipeline** — Run a single ticket through the full pipeline (close-world → decompose-proposition → model-obligations → prove-invariants → instantiate-properties → realize-specification) and finish with `explain`. Renamed from `single-ticket-pipeline`. The previous `multi-plan` parallel orchestrator has been retired; its design is preserved at `thoughts/archive/multi-plan-skill-design.md`.

### orbital-telemetry

Standalone developer utilities.

- **make-commits** — Review all unstaged changes and organize them into logical commits
- **create-presentation** — Generate a self-contained HTML slideshow from any source material

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)): Required for prove-invariants. Use `scaffolding:setup-lean-mathlib` to install a shared Mathlib clone, avoiding repeated multi-hour compilations.
- **SWI-Prolog** (`swipl`): Required for close-world, decompose-proposition, and the `trajectory:pipeline` skill.

All of the above are verified by `scaffolding:setup` — run that once and the result is recorded in `.claude/orbital-setup.json` so downstream skills don't re-probe.

## Installation

```bash
claude /install-plugin https://github.com/theTyster/orbital
```

After install, run `/setup` in your project. It interviews you about which plugins you'll use, then provisions the silent prerequisites (`thoughts/` directory, `.gitignore` entries, Lean toolchain) idempotently.

## Versioning

Plugin versions are tracked in `.claude-plugin/marketplace.json` — one `version` field per plugin entry. This is what the plugin manager reads. When asked to "bump the version", update the relevant plugin's version in `.claude-plugin/marketplace.json`.

## License

Apache 2.0
