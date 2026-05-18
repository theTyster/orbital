---
name: pipeline
description: >
  Run a single ticket through the entire orbital-shifting pipeline end-to-end —
  "run the full pipeline on this ticket", "drive this ticket through close-world to explain",
  "single-ticket pipeline", "orchestrate the logic pipeline for one ticket",
  "take this ticket from KB to implementation". Sequences close-world →
  decompose-proposition → model-obligations → prove-invariants →
  instantiate-properties → realize-specification, then closes with `explain`
  to present what occurred. Orchestrator runs at Opus/max effort and
  delegates each stage to its dedicated skill so the artifact chain stays
  intact.
user-invocable: true
model: opus
effort: max
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList
argument-hint: "[ticket: a single sentence or paragraph describing the change, invariant, or proposition to drive end-to-end] [optional: target codebase directory, defaults to cwd]"
---

# pipeline

Run **one ticket** through the full orbital-shifting pipeline and finish with a
plain-language explanation. The orchestrator is thin: each stage is delegated
to its dedicated skill, which owns its own artifacts and sub-agents. The
orchestrator's job is to sequence stages, hand the right paths forward, gate
on artifact existence, parameterise each primitive at startup, read each
stage's gate-target descriptor, and stop early on hard failures with a partial
`explain` instead of crashing.

> **Scope.** Exactly one ticket. The parallel multi-enhancement orchestrator
> previously named `multi-plan` has been retired; this is now the canonical
> orchestration skill in this plugin.

**Read first:** `references/orchestration-substrate.md` is the canonical wire
format for this skill's contract with the seven `shifting` primitives. It
defines the gate-target descriptor shape, the inbound orchestrator parameters
each primitive accepts, the four enforcement rules
(`carrier_only_reads`, `gate_target_descriptor_total`, `bias_defense_uniform`,
`orchestration_outside_pipeline`), and what this skill MAY and MUST NOT do.
The body below *applies* that contract; the references doc *declares* it.

## Required inputs

1. **Ticket** — a sentence or short paragraph describing the change, invariant,
   feature, or proposition to drive through the pipeline. If absent, ask the
   user before proceeding.
2. **Target codebase directory** — defaults to the current working directory.
   `realize-specification` needs this explicitly; capture it up front.

If either is missing or ambiguous, halt and ask. Do not invent a ticket.

## Orchestration substrate role

This skill is the in-marketplace expression of the orchestration substrate
specified in `references/orchestration-substrate.md`. Five responsibilities,
applied across the body below:

- **Hold bespoke domain context** for the run — the ticket text, the target
  codebase path, any prior witnesses the user carries forward, any
  predicate-schema extensions to inject into close-world.
- **Parameterise each primitive** at startup with the
  `accepts_orchestrator_parameter` values appropriate for the run. Skills do
  not invent these; if a needed parameter is missing for a stage, halt and ask.
- **Read each gate-target descriptor** after a stage emits its output —
  artifact identity, declared shape (per `shifting:references/pipeline-schema/`),
  refutation-shape suggestions inherited from upstream context.
- **Decide disprove invocation** per run. The orchestrator (this skill) is the
  only legal invoker of `shifting:disprove-proposition`. See "Disprove gating"
  below for when and when not.
- **Decide non-adjacent loopback.** Primitives only loop to their immediate
  predecessor. Cross-stage refinement is this skill's call, surfaced to the
  user before re-invoking an earlier primitive.

## Artifact chain (read-only contract)

Each stage produces a known artifact at a known path. Treat these paths as the
hand-off contract — never rename, never relocate.

| Stage | Skill | Primary output |
|-------|-------|----------------|
| 1 | `shifting:close-world` | `thoughts/existing-world.pl` |
| 2 | `shifting:decompose-proposition` | `thoughts/hypothesis.pl` |
| 3a | `shifting:model-obligations` | `thoughts/target-world.pl`, `thoughts/model_results.pl` |
| 3b | `shifting:prove-invariants` | `thoughts/lean/Proofs/*.lean`, `thoughts/lean_proof_results.pl` |
| 4 | `shifting:instantiate-properties` | `thoughts/tests/*` |
| 5 | `shifting:realize-specification` | source edits + `thoughts/implementation_log.md` |
| 6 | `shifting:explain` | `thoughts/explanation.md` |

Before invoking each stage, verify the upstream artifact exists. After each
stage, verify its declared output exists before advancing.

Every primary output above is also a **gate-target descriptor** — the
orchestrator MAY invoke `shifting:disprove-proposition` against any of them
when the run's success criteria warrant it. The 12 emitted descriptors and
the orchestrator parameters each stage accepts are catalogued in
`references/orchestration-substrate.md`.

## Lean prerequisites

Stage 3b requires a Lean 4 project with Mathlib. Before stage 3b runs, check:

```sh
test -d thoughts/lean/.lake/build && test -d ~/.lean/mathlib4
```

If either is missing, invoke `shifting:setup-lean-mathlib` and/or
`shifting:setup-lean-project` once, then proceed. These setup skills are
infrastructure, not pipeline stages — running them is idempotent.

## Orchestration sequence

Maintain one task per pipeline stage via TaskCreate; mark each `in_progress`
when you enter it and `completed` when its output artifact is verified on
disk. Use TaskUpdate, not commentary.

### Stage 1 — close-world

Invoke `shifting:close-world` with the target codebase as source
material. This reads the codebase and emits `thoughts/existing-world.pl`.

Orchestrator parameters to pass (if the ticket calls for them):
`predicate_schema_extension` (bespoke predicates this ticket needs in the KB),
`success_criteria` (minimum coverage / required predicate families),
`halt_condition`.

Gate: `thoughts/existing-world.pl` must exist and be non-empty before
advancing. If empty or missing, stop and run `explain` against whatever was
produced. The emitted descriptor exposes the KB's open-domain assumptions —
prime candidates for a refutation-shape briefing on the next stage.

### Stage 2 — decompose-proposition

Invoke `shifting:decompose-proposition` with two arguments: the path
`thoughts/existing-world.pl` and the **ticket text verbatim** as the
proposition. Output: `thoughts/hypothesis.pl`.

Orchestrator parameters to pass: `refutation_shape_briefing` (the classes of
counterfactual the orchestrator wants surfaced), `artifact_versioning` (the
v1/v2/... namespace if a re-decomposition is anticipated), `halt_condition`.

Gate: `thoughts/hypothesis.pl` must exist and contain at least one `claim/2`
fact. If decomposition refuses (e.g., proposition already entailed by KB),
record that, skip stages 3–5, and run `explain`.

### Stage 3a — model-obligations

Invoke `shifting:model-obligations` with `thoughts/hypothesis.pl` and
`thoughts/existing-world.pl`. Output: `thoughts/target-world.pl` and
`thoughts/model_results.pl`.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`.

Gate: both files must exist. If `model_results.pl` reports refutation of a
required obligation, stop and run `explain` — the model has already shown the
ticket cannot be realized as written. A `gap` verdict is not the same as
`inconsistent`: surface the gap_reason and decide per run whether the gap
warrants a non-adjacent loopback to `decompose-proposition` (this skill's
call, user-gated) or proceeds to stage 3b on the consistent subset.

### Stage 3b — prove-invariants

Confirm Lean prerequisites (see above), then invoke
`shifting:prove-invariants` with `thoughts/target-world.pl`. Output:
`thoughts/lean/Proofs/*.lean` and `thoughts/lean_proof_results.pl`.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`.

Gate: `thoughts/lean_proof_results.pl` must exist. Inspect it: if every
`theorem_verdict/2` is `unprovable`, the ticket is logically blocked at the
Lean boundary. The adjacent loopback target is `model-obligations`. The
non-adjacent loopback to `decompose-proposition` is **this skill's call**,
not the primitive's — surface the unprovable verdicts to the user, propose
the non-adjacent loopback with a one-sentence rationale, and act only on
confirmation. Default on no answer: finish with `explain`.

### Stage 4 — instantiate-properties

Invoke `shifting:instantiate-properties` with the target codebase
directory. Output: skipped tests under `thoughts/tests/`.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`.

Gate: at least one test file must exist under `thoughts/tests/`. If empty,
record and proceed to `explain` (no tests means nothing for stage 5 to drive).

### Stage 5 — realize-specification

For each test file produced in stage 4, invoke
`shifting:realize-specification` with that test file path and the target
codebase directory. Run them sequentially — `realize-specification` already
manages its own sub-agents and is not safe to fan out.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`,
`success_criteria` (e.g., "all targeted tests pass; zero regressions").

Gate: after each invocation, check `thoughts/implementation_log.md` and the
suite-runner digest. If `thoughts/implementation_blocked.md` appears, stop the
loop and proceed to `explain` with the blocked state included.

### Stage 6 — explain

Invoke `shifting:explain` with the target codebase / `thoughts/`
directory. This stage **always runs**, even on partial pipelines — it is the
presentation layer for whatever artifacts exist. Output:
`thoughts/explanation.md`.

`explain` is unstaged with respect to the disprove-gate contract — it is the
narrator, not a primitive in the descriptor chain. Pass no orchestrator
parameters; it reads what is on disk.

After `explain` completes, summarize for the user in one short paragraph: the
ticket as understood, the furthest stage reached, and the path to
`thoughts/explanation.md`.

## Disprove gating

After any stage emits its primary artifact, this skill MAY invoke
`shifting:disprove-proposition` against the corresponding gate-target
descriptor — the artifact, its declared shape, and the refutation-shape
suggestions the orchestrator wants attacked. The decision is per-run:

- **Default: do not invoke.** A pipeline run is exploratory; disprove
  invocations cost time and only pay off when the run's success criteria
  specifically call for an adversarial check.
- **Invoke when** a stage's verdict carries `gap`, `inconsistent`, or
  `unprovable`, and the ticket (or a user-supplied refutation_shape_briefing)
  names what to attack.
- **Invoke when** the user explicitly asks for a second opinion on an
  artifact before advancing.

When invoking, brief `shifting:disprove-proposition` with: the gate-target
descriptor (artifact path + declared shape from the relevant
`shifting:references/pipeline-schema/` doc + the refutation-shape suggestions),
plus a budget (token / wall-clock / attempts). Read its verdict from
`thoughts/disproof_results.pl`. Three outcomes:

- `refuted` — a concrete witness exists under `thoughts/counterexamples.pl`
  or `thoughts/lean_disproofs/`. Halt the pipeline; surface the witness and
  ask the user whether to drive a non-adjacent loopback or finish.
- `inconclusive` — partial evidence. Record, decide whether to thread the
  evidence into the next stage's `refutation_shape_briefing`, and proceed.
- `abstained` — no progress within budget. Record the obstruction and
  proceed without halting.

Never invoke `disprove-proposition` recursively against its own outputs
(witness R2 — universal-gate closure breaks at the self-application
boundary). Primitives downstream never auto-consume disprove artifacts; the
orchestrator threads verdicts back via parameters or halts.

## Upstream gap handling

After each stage's primary artifact lands, scan it for `upstream_gap/3` facts
— the reverse-direction outbound channel. See
`references/orchestration-substrate.md` §"Upstream gaps" for the canonical
shape and per-primitive emission table. Each gap is the primitive's
machine-readable signal that its input was insufficient.

Per gap, in order:

1. **Validate directionality.** `recovery_hint(TargetSkill, _)` MUST name a
   stage upstream of the emitter. A downstream-pointing gap is malformed —
   surface it to the user, do not honor it.
2. **Honor, batch, or decline.** Three options per run:
   - **Honor** — re-invoke `TargetSkill` with the suggested `ParamSpec`
     merged into the run's parameters, then re-run affected downstream
     stages. Loop limit: one recovery per gap-class-per-stage per run, to
     prevent oscillation.
   - **Batch** — multiple gaps from the same stage with the same
     `TargetSkill` collapse to one recovery invocation with merged
     `ParamSpec` values.
   - **Decline** — log the gap, proceed to `explain` without recovery,
     surface the decision to the user.
3. **Default on no decision** — decline the recovery and proceed to
   `explain`. Never silently retry.

Gaps and disprove invocations are independent decisions per run. A stage
may emit zero gaps and still warrant a disprove; a stage may emit several
gaps and need no disprove. Do not couple them.

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
2. Invoke `shifting:explain` immediately against whatever artifacts
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
- **Adjacent loopback** (e.g., `prove-invariants` → `model-obligations`,
  `realize-specification` → `instantiate-properties`) belongs to the
  primitive; the looped-back skill records its own decision.
- **Non-adjacent loopback** (e.g., `prove-invariants` →
  `decompose-proposition`, `realize-specification` → `decompose-proposition`)
  is **this skill's call**. Surface the gap to the user with a one-sentence
  rationale, propose the loopback, and act only on confirmation. Never
  silently retry a non-adjacent stage.

## Hard rules

Five prohibitions hold for every run, sourced from the T2 R1/R2/R3 witnesses.
See `references/orchestration-substrate.md` §"What the orchestrator MUST NOT
do" for the canonical list. Treat any conflict between this skill's behavior
and that list as a bug in this skill, not in the references doc.

## What this skill is not

- Not a multi-ticket fan-out — the parallel multi-enhancement orchestrator (`multi-plan`) has been retired; revive it from `thoughts/archive/multi-plan-skill-design.md` if needed.
- Not a prover — proving is `prove-invariants`.
- Not a refactor planner — refactoring lives inside `realize-specification`.
- Not a substitute for human review of `thoughts/explanation.md`.
