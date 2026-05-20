---
name: pipeline
description: >
  Run a single ticket through some contiguous slice of the orbital-shifting
  pipeline's seven staged primitives, finishing with `explain` as the
  always-runs closer. Defaults to the full end-to-end sequence (close-world →
  decompose-proposition → model-obligations → prove-invariants →
  instantiate-properties → realize-specification → measure-entailment, then
  `explain`) when no scope is given. When the user names an entry or exit
  stage — or when `thoughts/` already holds upstream artifacts from a prior
  run — runs only the in-scope stages and still closes with `explain`.
  Triggers: "run the full pipeline on this ticket", "drive this ticket from
  close-world through decompose-proposition", "pick up from
  model-obligations", "just run prove-invariants forward", "continue the
  pipeline where we left off", "take this ticket from KB to implementation",
  "stop after decompose-proposition", "only run through prove-invariants",
  "close-world and decompose only", "run through measure-entailment", "score
  adherence after realize-specification", "single-ticket pipeline".
  Orchestrator runs at Opus/max effort and delegates each in-scope stage to
  its dedicated skill so the artifact chain stays intact.
user-invocable: true
model: opus
effort: max
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill, Agent, TaskCreate, TaskUpdate, TaskList
argument-hint: "[ticket: a single sentence or paragraph describing the change, invariant, or proposition to drive] [optional: target codebase dir, defaults to cwd] [optional: start_stage and/or end_stage if running a partial slice]"
---

# pipeline

Run **one ticket** through some contiguous slice of the orbital-shifting
pipeline's seven staged primitives and finish with the always-runs `explain`
closer. The default slice is the entire pipeline (stages 1 → 7), but the
orchestrator supports partial runs in either direction — starting
mid-pipeline when upstream artifacts already exist, stopping early when the
ticket only calls for the first few stages, or both. The orchestrator is
thin: each in-scope stage is delegated to its dedicated skill, which owns
its own artifacts and sub-agents. The orchestrator's job is to **determine
the scope**, sequence the in-scope stages, hand the right paths forward,
gate on artifact existence, parameterise each primitive at startup, read
each stage's gate-target descriptor, and stop early on hard failures with a
partial `explain` instead of crashing.

> **Scope.** Exactly one ticket. The slice of the pipeline run on that ticket
> can be any contiguous subrange of stages 1 → 7. `explain` is the unstaged
> closer — it always runs after the in-scope stages, regardless of scope,
> producing the human-readable narrative for whatever artifacts exist on
> disk. The parallel multi-enhancement orchestrator previously named
> `multi-plan` has been retired; this is now the canonical orchestration
> skill in this plugin.

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

If either of the above is missing or ambiguous, halt and ask. Do not invent a
ticket.

### Optional inputs (scope)

3. **`start_stage`** — the first stage to run (default: auto-detected, see
   "Pipeline scope" below). Accepts a stage id (`close-world`,
   `decompose-proposition`, `model-obligations`, `prove-invariants`,
   `instantiate-properties`, `realize-specification`, `measure-entailment`).
4. **`end_stage`** — the last in-scope stage before the `explain` closer
   (default: `measure-entailment`). Same id set as `start_stage`; must be ≥
   `start_stage` in pipeline order. `explain` is not a valid `end_stage` —
   it is the always-runs closer, not a scope-bounded stage.

If only one of `start_stage` / `end_stage` is given, the other takes its
default. If neither is given **and** no upstream artifacts exist in
`thoughts/`, the orchestrator runs the full pipeline (stages 1 → 7) and
finishes with the `explain` closer.

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
| 3 | `shifting:model-obligations` | `thoughts/target-world.pl`, `thoughts/model_results.pl` |
| 4 | `shifting:prove-invariants` | `thoughts/lean/Proofs/*.lean`, `thoughts/lean_proof_results.pl` |
| 5 | `shifting:instantiate-properties` | `thoughts/tests/*` |
| 6 | `shifting:realize-specification` | source edits + `thoughts/implementation_log.md` |
| 7 | `shifting:measure-entailment` | `thoughts/adherence_facts.pl`, `thoughts/adherence_report.md` |
| Closer | `shifting:explain` | `thoughts/explanation.md` |

Before invoking each stage, verify the upstream artifact exists. After each
stage, verify its declared output exists before advancing.

Every primary output above is also a **gate-target descriptor** — the
orchestrator MAY invoke `shifting:disprove-proposition` against any of them
when the run's success criteria warrant it. The 12 emitted descriptors and
the orchestrator parameters each stage accepts are catalogued in
`references/orchestration-substrate.md`.

## Pipeline scope

Before any stage runs, the orchestrator picks a contiguous subrange
`[start_stage … end_stage]` of stages 1 → 7 to execute. The `explain` closer
**always** runs at the end, regardless of scope — it is the presentation
layer for whatever artifacts exist on disk and is structurally outside the
seven-stage prescription (see substrate §"The two layers").

### Resolution order

The orchestrator resolves `start_stage` / `end_stage` in this priority order
(first match wins):

1. **Explicit user signal.** The ticket text, the invocation arguments, or a
   prior turn names entry or exit stages — e.g., "pick up from
   model-obligations", "just run prove-invariants forward", "stop after
   decompose-proposition", "from close-world through prove-invariants",
   "continue where we left off". Honour the named stages verbatim.
2. **Resumable artifact state.** Scan `thoughts/` for the artifacts in the
   chain table above. If a contiguous prefix of stages already has its
   primary output on disk and matches the ticket's intent, default
   `start_stage` to the stage **immediately after** the last present
   artifact. Surface this inference to the user in one sentence before
   running ("`thoughts/existing-world.pl` and `thoughts/hypothesis.pl`
   already exist; resuming from model-obligations") and proceed unless the
   user objects.
3. **Default — full pipeline.** No user signal, no resumable artifacts in
   `thoughts/`: run stages 1 → 7 in order, then the `explain` closer. This
   is the assumption when nothing else is specified.

If the user signal and the on-disk state conflict (e.g., user says "start at
prove-invariants" but `thoughts/target-world.pl` is missing), halt and ask
whether to fill the gap from an earlier stage or supply the missing artifact
manually. Do not silently start with a missing upstream.

### Entry-point gating

When `start_stage` is not stage 1, the orchestrator must verify the upstream
artifact exists **and is non-empty** before invoking the entry stage:

| Entry stage | Required upstream artifact(s) |
|-------------|--------------------------------|
| `decompose-proposition` | `thoughts/existing-world.pl` |
| `model-obligations` | `thoughts/existing-world.pl`, `thoughts/hypothesis.pl` |
| `prove-invariants` | `thoughts/target-world.pl` (and `thoughts/model_results.pl` if it was produced) |
| `instantiate-properties` | `thoughts/lean_proof_results.pl` (and `thoughts/lean/Proofs/`) |
| `realize-specification` | At least one test file under `thoughts/tests/` |
| `measure-entailment` | `thoughts/implementation_log.md` + target codebase directory (and `thoughts/hypothesis.pl` for pipeline-terminal mode's label-aware verdicts) |

If a required upstream artifact is missing at entry, halt and ask. The
orchestrator does not back-fill an earlier stage unless the user confirms.

### Exit-point semantics

`end_stage` caps the last in-scope staged primitive before the `explain`
closer runs. After `end_stage` completes (or is skipped because its gate
fails), control passes directly to `shifting:explain` against whatever
artifacts exist on disk. No stages between `end_stage` and
`measure-entailment` run, even if their inputs happen to be present.
`explain` itself cannot be named as `end_stage` — it is the always-runs
closer, not a scope-bounded stage.

### Non-adjacent loopback within a partial scope

If a stage emits an `upstream_gap/3` whose `recovery_hint(TargetSkill, _)`
names a stage **earlier than the current `start_stage`**, the orchestrator
must surface the gap to the user before honouring it — honouring would
expand the scope beyond the user's declared entry point. The user decides
whether to widen the scope, decline the recovery, or override the suggested
`TargetSkill` with an in-scope stage.

## Setup prerequisites

The pipeline assumes `scaffolding:setup` has been run for this project. That
single bootstrap writes `.claude/orbital-setup.json`, which records whether
the Prolog and Lean dependencies are provisioned. Before stage 1, check:

```sh
test -f .claude/orbital-setup.json
```

If absent, invoke `scaffolding:setup` once and let it interview the user about
which backends are needed. The pipeline can run with just the Prolog backend
(skipping stage 4); the marker records what was provisioned.

Stage 4 specifically requires the Lean toolchain. Before stage 4 runs,
consult the marker:

```sh
"${CLAUDE_PLUGIN_ROOT}/../scaffolding/skills/setup/scripts/check-setup.sh" mathlib_clone \
  && "${CLAUDE_PLUGIN_ROOT}/../scaffolding/skills/setup/scripts/check-setup.sh" lean_project
```

If either is missing, invoke `scaffolding:setup-lean-mathlib` and/or
`scaffolding:setup-lean-project` once, then proceed. These setup skills are
infrastructure, not pipeline stages — running them is idempotent and they
update the marker on completion.

## Orchestration sequence

Each numbered stage below runs **only if it falls within the resolved
`[start_stage … end_stage]` scope** (see "Pipeline scope" above). Stages
outside the scope are skipped without invocation; their gate checks are
still consulted at entry to confirm upstream artifacts exist on disk. The
`explain` closer always runs after the in-scope stages — it is structurally
outside the seven-stage chain.

Maintain one task per in-scope pipeline stage via TaskCreate; mark each
`in_progress` when you enter it and `completed` when its output artifact is
verified on disk. Use TaskUpdate, not commentary. Do not create tasks for
out-of-scope stages.

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
record that, skip stages 3–7, and run the `explain` closer.

### Stage 3 — model-obligations

Invoke `shifting:model-obligations` with `thoughts/hypothesis.pl` and
`thoughts/existing-world.pl`. Output: `thoughts/target-world.pl` and
`thoughts/model_results.pl`.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`.

Gate: both files must exist. If `model_results.pl` reports refutation of a
required obligation, stop and run `explain` — the model has already shown the
ticket cannot be realized as written. A `gap` verdict is not the same as
`inconsistent`: surface the gap_reason and decide per run whether the gap
warrants a non-adjacent loopback to `decompose-proposition` (this skill's
call, user-gated) or proceeds to stage 4 on the consistent subset.

### Stage 4 — prove-invariants

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

### Stage 5 — instantiate-properties

Invoke `shifting:instantiate-properties` with the target codebase
directory. Output: skipped tests under `thoughts/tests/`.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`.

Gate: at least one test file must exist under `thoughts/tests/`. If empty,
record and proceed to `explain` (no tests means nothing for stage 5 to drive).

### Stage 6 — realize-specification

For each test file produced in stage 5, invoke
`shifting:realize-specification` with that test file path and the target
codebase directory. Run them sequentially — `realize-specification` already
manages its own sub-agents and is not safe to fan out.

Orchestrator parameters to pass: `refutation_shape_briefing`, `halt_condition`,
`success_criteria` (e.g., "all targeted tests pass; zero regressions").

Gate: after each invocation, check `thoughts/implementation_log.md` and the
suite-runner digest. If `thoughts/implementation_blocked.md` appears, stop the
loop and proceed to the `explain` closer with the blocked state included.

### Stage 7 — measure-entailment

Invoke `shifting:measure-entailment` against the implemented codebase using
`thoughts/implementation_log.md` (from `realize-specification`) as the
carrier, with `thoughts/hypothesis.pl` directly loaded for label-aware
verdicts (Pattern 3 detection, prescriptive fulfillment / negation
violations). Output: `thoughts/adherence_facts.pl` and
`thoughts/adherence_report.md`.

Orchestrator parameters to pass: `success_criteria` (e.g., "zero Pattern 3
violations; all prescriptive claims fulfilled"), `halt_condition`.

Gate: `thoughts/adherence_report.md` must exist. The verdict is data, not a
hard halt — even a report showing many violations is a successful Stage 7
output; the orchestrator passes the report forward to the `explain` closer
without re-interpreting the verdicts. measure-entailment is terminal: it
has no adjacent loopback target (gaps surface as report verdicts, not
recovery signals).

### Closer — explain

Invoke `shifting:explain` with the target codebase / `thoughts/`
directory. The closer **always runs**, even on partial pipelines and even
when staged primitives errored out — it is the presentation layer for
whatever artifacts exist. Output: `thoughts/explanation.md`.

`explain` is unstaged with respect to the disprove-gate contract — it is
the narrator, not a primitive in the descriptor chain. Pass no orchestrator
parameters; it reads what is on disk.

After `explain` completes, summarize for the user in one short paragraph: the
ticket as understood, the furthest stage reached, the headline adherence
verdict if Stage 7 ran, and the path to `thoughts/explanation.md`.

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

Orchestrator runs at `model: opus`, `effort: max` (per the 2026-05 audit that
reserved opus/max for orchestrators and audit skills). The heavy reasoning
(Lean tactics, claim decomposition, sub-agent fan-out) lives inside each
delegated skill, where the appropriate models and efforts are already
declared. Do not override sub-skill models from here.

When this skill itself spawns Agent calls (e.g., to inspect Prolog gates),
pass `model: "sonnet"` and `effort: "medium"` explicitly per repository
convention — sub-agent inspections are tactical, not orchestrative.

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

- **Missing upstream artifact at entry** → see "Pipeline scope → Entry-point
  gating" above. Short version: halt and ask; never silently back-fill.
- **Missing upstream artifact mid-run** → stop, run `explain`, report the gap.
- **Hard refutation** at stage 3 or 4 → stop, run the `explain` closer,
  surface the refuted obligations / unprovable verdicts to the user as the
  headline.
- **Sub-agent or skill error** → record the stage and error, run `explain`
  against partial state, then surface the error.
- **Adjacent loopback** (e.g., `prove-invariants` → `model-obligations`,
  `realize-specification` → `instantiate-properties`) belongs to the
  primitive; the looped-back skill records its own decision. If the
  adjacent predecessor is **outside the current scope**, the primitive's
  loopback request is escalated to the orchestrator and surfaced to the
  user as a scope-widening proposal.
- **Non-adjacent loopback** (e.g., `prove-invariants` →
  `decompose-proposition`, `realize-specification` → `decompose-proposition`)
  is **this skill's call**. Surface the gap to the user with a one-sentence
  rationale, propose the loopback (and any scope widening it implies), and
  act only on confirmation. Never silently retry a non-adjacent stage and
  never silently widen the user-declared scope.

## Hard rules

Five prohibitions hold for every run, sourced from the T2 R1/R2/R3 witnesses.
See `references/orchestration-substrate.md` §"What the orchestrator MUST NOT
do" for the canonical list. Treat any conflict between this skill's behavior
and that list as a bug in this skill, not in the references doc.

## What this skill is not

- Not a multi-ticket fan-out — the parallel multi-enhancement orchestrator (`multi-plan`) was retired.
- Not a prover — proving is `prove-invariants`.
- Not a refactor planner — refactoring lives inside `realize-specification`.
- Not start-to-finish-only — partial slices (entry mid-pipeline, early exit, or both) are first-class. Full pipeline is the default when no scope signal is given.
- Not a substitute for human review of `thoughts/explanation.md`.
