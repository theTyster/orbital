---
name: pipeline
description: >
  Run a single ticket through the entire logic-focused pipeline end-to-end —
  "run the full pipeline on this ticket", "drive this ticket through close-world to explain",
  "single-ticket pipeline", "orchestrate the logic pipeline for one ticket",
  "take this ticket from KB to implementation". Sequences close-world →
  decompose-proposition → model-obligations → prove-invariants →
  instantiate-properties → realize-specification, then closes with `explain`
  to present what occurred. Orchestrator runs at Sonnet/medium effort and
  delegates each stage to its dedicated skill so the artifact chain stays
  intact.
user-invocable: true
model: sonnet
effort: medium
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList
argument-hint: "[ticket: a single sentence or paragraph describing the change, invariant, or proposition to drive end-to-end] [optional: target codebase directory, defaults to cwd]"
---

# pipeline

Run **one ticket** through the full logic-focused pipeline and finish with a
plain-language explanation. The orchestrator is thin: each stage is delegated
to its dedicated skill, which owns its own artifacts and sub-agents. The
orchestrator's job is to sequence stages, hand the right paths forward, gate
on artifact existence, and stop early on hard failures with a partial
`explain` instead of crashing.

> **Scope.** Exactly one ticket. The parallel multi-enhancement orchestrator
> previously named `multi-plan` has been retired; this is now the canonical
> orchestration skill in this plugin.

## Required inputs

1. **Ticket** — a sentence or short paragraph describing the change, invariant,
   feature, or proposition to drive through the pipeline. If absent, ask the
   user before proceeding.
2. **Target codebase directory** — defaults to the current working directory.
   `realize-specification` needs this explicitly; capture it up front.

If either is missing or ambiguous, halt and ask. Do not invent a ticket.

## Artifact chain (read-only contract)

Each stage produces a known artifact at a known path. Treat these paths as the
hand-off contract — never rename, never relocate.

| Stage | Skill | Primary output |
|-------|-------|----------------|
| 1 | `logic-focused:close-world` | `thoughts/existing-world.pl` |
| 2 | `logic-focused:decompose-proposition` | `thoughts/hypothesis.pl` |
| 3a | `logic-focused:model-obligations` | `thoughts/target-world.pl`, `thoughts/model_results.pl` |
| 3b | `logic-focused:prove-invariants` | `thoughts/lean/Proofs/*.lean`, `thoughts/lean_proof_results.pl` |
| 4 | `logic-focused:instantiate-properties` | `thoughts/tests/*` |
| 5 | `logic-focused:realize-specification` | source edits + `thoughts/implementation_log.md` |
| 6 | `logic-focused:explain` | `thoughts/explanation.md` |

Before invoking each stage, verify the upstream artifact exists. After each
stage, verify its declared output exists before advancing.

## Lean prerequisites

Stage 3b requires a Lean 4 project with Mathlib. Before stage 3b runs, check:

```sh
test -d thoughts/lean/.lake/build && test -d ~/.lean/mathlib4
```

If either is missing, invoke `logic-focused:setup-lean-mathlib` and/or
`logic-focused:setup-lean-project` once, then proceed. These setup skills are
infrastructure, not pipeline stages — running them is idempotent.

## Orchestration sequence

Maintain one task per pipeline stage via TaskCreate; mark each `in_progress`
when you enter it and `completed` when its output artifact is verified on
disk. Use TaskUpdate, not commentary.

### Stage 1 — close-world

Invoke `logic-focused:close-world` with the target codebase as source
material. This reads the codebase and emits `thoughts/existing-world.pl`.

Gate: `thoughts/existing-world.pl` must exist and be non-empty before
advancing. If empty or missing, stop and run `explain` against whatever was
produced.

### Stage 2 — decompose-proposition

Invoke `logic-focused:decompose-proposition` with two arguments: the path
`thoughts/existing-world.pl` and the **ticket text verbatim** as the
proposition. Output: `thoughts/hypothesis.pl`.

Gate: `thoughts/hypothesis.pl` must exist and contain at least one `claim/2`
fact. If decomposition refuses (e.g., proposition already entailed by KB),
record that, skip stages 3–5, and run `explain`.

### Stage 3a — model-obligations

Invoke `logic-focused:model-obligations` with `thoughts/hypothesis.pl` and
`thoughts/existing-world.pl`. Output: `thoughts/target-world.pl` and
`thoughts/model_results.pl`.

Gate: both files must exist. If `model_results.pl` reports refutation of a
required obligation, stop and run `explain` — the model has already shown the
ticket cannot be realized as written.

### Stage 3b — prove-invariants

Confirm Lean prerequisites (see above), then invoke
`logic-focused:prove-invariants` with `thoughts/target-world.pl`. Output:
`thoughts/lean/Proofs/*.lean` and `thoughts/lean_proof_results.pl`.

Gate: `thoughts/lean_proof_results.pl` must exist. Inspect it: if every
`theorem_verdict/2` is `unprovable`, the ticket is logically blocked at the
Lean boundary. Per `prove-invariants`, the documented loop-back is to
`decompose-proposition`. **The orchestrator does not loop automatically.**
Surface the unprovable verdicts to the user, ask whether to refine the
hypothesis (one round) or finish with `explain`. Default on no answer: finish
with `explain`.

### Stage 4 — instantiate-properties

Invoke `logic-focused:instantiate-properties` with the target codebase
directory. Output: skipped tests under `thoughts/tests/`.

Gate: at least one test file must exist under `thoughts/tests/`. If empty,
record and proceed to `explain` (no tests means nothing for stage 5 to drive).

### Stage 5 — realize-specification

For each test file produced in stage 4, invoke
`logic-focused:realize-specification` with that test file path and the target
codebase directory. Run them sequentially — `realize-specification` already
manages its own sub-agents and is not safe to fan out.

Gate: after each invocation, check `thoughts/implementation_log.md` and the
suite-runner digest. If `thoughts/implementation_blocked.md` appears, stop the
loop and proceed to `explain` with the blocked state included.

### Stage 6 — explain

Invoke `logic-focused:explain` with the target codebase / `thoughts/`
directory. This stage **always runs**, even on partial pipelines — it is the
presentation layer for whatever artifacts exist. Output:
`thoughts/explanation.md`.

After `explain` completes, summarize for the user in one short paragraph: the
ticket as understood, the furthest stage reached, and the path to
`thoughts/explanation.md`.

## Effort and model

Orchestrator runs at `model: sonnet`, `effort: medium`. The heavy reasoning
(Lean tactics, claim decomposition, sub-agent fan-out) lives inside each
delegated skill, where the appropriate models and efforts are already
declared. Do not override sub-skill models from here.

When this skill itself spawns Agent calls (e.g., to inspect Prolog gates),
pass `model: "sonnet"` and `effort: "medium"` explicitly per repository
convention.

## Context budget (hard stop at 120k tokens)

Managing context is part of the orchestrator's job. Before invoking each
stage skill, check the running context size. If it has crossed **120,000
tokens**, do not start the next stage. Instead:

1. Mark the current task as halted (TaskUpdate with a status note that the
   budget was hit).
2. Invoke `logic-focused:explain` immediately against whatever artifacts
   exist on disk.
3. Report to the user: the stage that was about to run, the budget breach,
   and the path to `thoughts/explanation.md`.

This is a **hard stop**, not a soft warning. Do not attempt to compress,
summarize, or push past the threshold — the partial pipeline is more
valuable when its narrative is captured cleanly than when it crashes
mid-stage with a corrupted artifact chain. The downstream stages can be
resumed in a fresh session against the same `thoughts/` directory.

The 120k threshold is below the model's window deliberately, leaving
headroom for `explain` to read the artifacts it needs and write its
report.

## Failure handling

- **Missing upstream artifact** → stop, run `explain`, report the gap.
- **Hard refutation** at stage 3a or 3b → stop, run `explain`, surface the
  refuted obligations / unprovable verdicts to the user as the headline.
- **Sub-agent or skill error** → record the stage and error, run `explain`
  against partial state, then surface the error.
- **Never** silently retry a failed stage. Refinement loops (e.g.,
  `prove-invariants` → `decompose-proposition`) are user-gated.

## What this skill is not

- Not a multi-ticket fan-out — the parallel multi-enhancement orchestrator (`multi-plan`) has been retired; revive it from `thoughts/archive/multi-plan-skill-design.md` if needed.
- Not a prover — proving is `prove-invariants`.
- Not a refactor planner — refactoring lives inside `realize-specification`.
- Not a substitute for human review of `thoughts/explanation.md`.
