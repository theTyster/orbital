# Dogfood Run — Handoff to an orbital-rooted session

**Why this file exists.** The dogfood (run orbital-shifting on this repo's *own*
pipeline-as-Workflow spec) was set up from a **mind-map-rooted** Claude Code session, which
cannot host the pipeline skills: they resolve `thoughts/`, `docs/`, and `.claude/` relative to
the session's project root. Run this from a session rooted at `/Users/ty/Projects/mine/orbital`.
Everything below is already prepped on the `experiment/pipeline-workflow` branch.

## Prep already done — do NOT redo

- Branch `experiment/pipeline-workflow` (off `origin/main`). Confirm you're on it: `git branch --show-current`.
- Spec committed: `docs/superpowers/specs/2026-05-28-pipeline-as-workflow-design.md` (decisions + invariants, no code — this is the close-world subject).
- Setup marker `.claude/orbital-setup.json` present; all prereqs verified (swipl 10.0.2, lean, elan, `~/.lean/mathlib4`, jq, python3, toon). Pipeline pre-flight + the stage-4 Lean check will pass without prompting.
- Fresh `thoughts/` workspace; Lean project restored at `thoughts/lean` (build cache intact), `Proofs/` cleared.
- Prior `thoughts/` contents preserved at `thoughts.predogfood-bak/` (git-excluded) — restore after the run (below).
- `experiments/pipeline-workflow/self-spec/` created for the persisted artifacts.

## Run it

Either paste the invocation in **§ The ticket** below, or just say:
*"Read `experiments/pipeline-workflow/HANDOFF.md` and run the dogfood."*

## After the run

1. **Persist** the dogfood artifacts into `experiments/pipeline-workflow/self-spec/`:
   `existing-world.pl`, `hypothesis.pl`, `target-world.pl`, `model_results.pl`,
   `lean/Proofs/*`, `lean_proof_results.pl`, `tests/`, `adherence_report.md`, `explanation.md`.
2. **Review** `thoughts/explanation.md` — this is the human-readable account of exactly what was
   produced, to read *before* the built Workflow is pointed at any real target (e.g. kimmy).
3. **Restore** the prior workspace (non-destructive):
   ```sh
   mv thoughts thoughts.dogfood-done     # keep the dogfood run
   mv thoughts.predogfood-bak thoughts   # restore the prior workspace
   ```
4. **Record the cwd-coupling finding** in `experiments/pipeline-workflow/FINDINGS.md`: the pipeline
   skills are cwd-coupled (resolve `thoughts/`/`docs/`/`.claude/` against the session root). The
   Workflow version should take an **explicit project-root argument** to decouple from cwd — fold
   this in as an additional requirement the Workflow satisfies.

## The ticket

```
/trajectory:pipeline Dogfood run — use orbital-shifting to build the pipeline-as-Workflow from its own spec.

SCOPE: Full end-to-end (option C): close-world → decompose-proposition → model-obligations → prove-invariants → instantiate-properties → realize-specification → measure-entailment, then explain.

CLOSE-WORLD SUBJECT (source_material): docs/superpowers/specs/2026-05-28-pipeline-as-workflow-design.md — a logical-system close-world (NOT a codebase scan). Treat the spec's Decisions (D-1..D-13), Constraints (C-1..C-6), Requirements (R-1..R-6, R-G1..R-G5), and Invariants (I-1..I-7) as the facts, rules, and constraints.

PROPOSITION (decompose): "The orbital-shifting seven-stage pipeline can be realized as one deterministic, background-executable Workflow that preserves invariants I-1..I-7, parallelizes its provable and testable stages without losing determinism, and is verifiable by the same pipeline — without inverting the smart-orchestrator / dumb-executor separation."

INVARIANTS TO PROVE (prove-invariants), spec §7: I-1 explain-always-runs; I-2 artifact-gating; I-3 termination via well-founded measure M = (Σ remaining recovery budget over keys, endIdx − cursor) lexicographic; I-4 scope-only-widens; I-5 disprove-bounded-above; I-6 disprove-runs-at-least-once; I-7 disprove-fans-out (≥2 adversaries). Apply spec D-10 bounds: per-theorem maxHeartbeats + maxRecDepth, outer wall-clock timeout backstop, prebuilt Mathlib (~/.lean/mathlib4), Lean concurrency sub-capped.

REALIZE TARGET (target codebase dir): experiments/pipeline-workflow/ — build the deterministic Workflow script (orbital-pipeline.workflow.js) + supporting lib/ modules + schemas, satisfying the instantiated §9 behavioral acceptance criteria.

BIAS DEFENSE: role-brief every sub-agent; minimal context. Per spec C-5/D-6, every disprove attempt fans out ≥2 parallel perspective-diverse adversaries, and ≥1 disprove attempt must run.

AT THE END: persist the dogfood artifacts into experiments/pipeline-workflow/self-spec/, then have explain narrate exactly what was produced.
```
