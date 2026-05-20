# orbital

Intent-shaped skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code): a formal reasoning pipeline from logic translation through proof verification to test generation and implementation review, plus architectural analysis, parallel orchestration, and developer utilities.

> Formerly `orbital-shift` (and before that `logic-focused-claude`). See [MIGRATION.md](MIGRATION.md) if you have an existing install under an old name.

## Plugins

This repository contains 4 plugins, decomposed by concern domain:

### orbital-shifting

Formal logic reasoning pipeline — from Prolog translation through proof verification to TDD tests, implementation review, and terminal adherence scoring. Seven staged primitives plus an always-runs closer:

```
1. close-world             — Translate a codebase into a Prolog knowledge base
2. decompose-proposition   — Ingest a proposition and create a hypothesis based on the Prolog KB
3. model-obligations       — Build the target-world model substrate (counterfactuals + obligations)
4. prove-invariants        — Formally verify each property in Lean4 (adjacent loopback to stage 3 if unprovable)
5. instantiate-properties  — Combine proven logical patterns into TDD tests that verify those patterns
6. realize-specification   — Orchestrate sub-agents to drive the TDD suite to green, refactoring against the proofs as the spec
7. measure-entailment      — Score how well the implementation entails the original proposition (Pattern 3 detection, prescriptive fulfillment, gaps, contradictions, extensions)
   Closer: explain         — Always-runs plain-language narrator for whatever artifacts exist on disk, for non-technical review
```

Stage 4 (`prove-invariants`) uses Lean for mathematical/abstract proofs; stage 3 (`model-obligations`) handles model-based verification of relational/structural properties via Prolog. `measure-entailment` is also valid stand-alone for ad-hoc resource comparison (spec vs. impl, doc vs. code) with an optional `--prime` source-of-truth.

Additional skill outside the staged pipeline:
- **disprove-proposition** — Adversarial debate move against a specific claim (Prolog claim id, Lean theorem, failing test, or English proposition). Invoked by the orchestrator against gate-target descriptors, or by the user directly to challenge an artifact.

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

- **pipeline** — Run a single ticket through some contiguous slice of the seven-stage pipeline (close-world → decompose-proposition → model-obligations → prove-invariants → instantiate-properties → realize-specification → measure-entailment) and always finish with the `explain` closer. Defaults to the full sequence when no scope is given; supports partial runs (entry mid-pipeline, early exit, or both) when the user names entry/exit stages or when `thoughts/` already holds upstream artifacts from a prior run. Renamed from `single-ticket-pipeline`. The previous `multi-plan` parallel orchestrator was retired.

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
