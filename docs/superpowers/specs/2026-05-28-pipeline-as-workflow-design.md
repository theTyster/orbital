# Pipeline-as-Workflow — Design Spec

**Date:** 2026-05-28
**Branch:** `experiment/pipeline-workflow`
**Status:** Design — pending user review before `writing-plans`.

---

## 1. Goal & Definition of Done

Build a solid, **deterministic Workflow script** that drives the orbital-shifting seven-stage
pipeline with its full control-flow machinery (disprove branches, auto-loopbacks, scope
widening, gap batching, bounded-parallel Lean), and **self-verify it** by running
orbital-shifting on the workflow's own control flow to prove a set of invariants in Lean.

Definition of done for today:

- [ ] **Rigorously specced** — this document, committed.
- [ ] **Unit-tested via TDD** — the deterministic mechanics, tests written first.
- [ ] **Proven** — the 7 invariants (§9) closed in Lean (the dogfood).
- [ ] **Fleshed out + wired into an E2E workflow** pointable at a real ticket tonight/tomorrow.
- [ ] **Closing `explain` run on exactly what was produced**, for human review *before* the
      workflow is ever pointed at a real target.

Trial run: a new `kimmy` feature, tomorrow (or late tonight).

---

## 2. Background & prior art

The orbital-shifting pipeline is **already** a deterministic orchestrator — implemented as the
`trajectory:pipeline` skill (~500-line `SKILL.md`, Opus/max). Its primitive↔orchestrator
contract lives in `plugins/trajectory/references/orchestration-substrate.md`; the inter-stage
file contract is `plugins/shifting/hooks/scripts/artifact-chain.json`. So this work is **not**
"add orchestration" — it is "move orchestration from an Opus *skill* into a JS *Workflow
script*," and exploit what that buys us: parallelism, a hard token budget, journal-resume, and
a control flow that can itself be formally verified.

**Why this is not the refuted design.** A prior proposal,
`prop_pipeline_rewrite_R1_self_orchestration.md`, was *refuted*; the framing that won was
**structural-layer-separation** (smart orchestrator + dumb executor, separated by a clean
contract). The risk here is inverting that pairing — making the orchestrator "dumb" by
hard-coding judgment into JS `if`s. We avoid it with one rule (see §3): **the JS makes no logic
call.** All judgment stays in agents; the JS executes the calls they return. The deterministic
substrate is the *contract layer*, not a smart agent — which is exactly structural-layer
separation, not self-orchestration.

---

## 3. Architecture — deterministic substrate + smart agents

One load-bearing rule: **the JS owns mechanics; agents own judgment.** The JS never decides
whether something is provable, refuted, inconsistent, or worth looping back on — it only
batches, counts, gates, sequences, and executes the structured decisions agents return.

| Concern | Owner | Why |
|---|---|---|
| Stage sequencing, cursor, scope set | JS (deterministic) | Mechanical, must be reproducible |
| Gap batching (merge by target) | JS | Arithmetic on emitted facts |
| Loop-limit / termination guard | JS | Policy enforcement |
| Scope widening | JS | Set operation |
| "Is this unprovable / inconsistent / refuted?" | **Agent** (stage / adversary) | Genuine logic |
| "Honor this loopback or surface it?" | **Agent** (`routeGaps`) | Genuine judgment |
| "Refute this claim" | **Agents** (≥2 adversaries) | Genuine search |
| Plain-language narration | **Agent** (`explain`) | Generative |

**Testability consequence (this is why TDD works here):** every mechanics function is **pure**
and lives in a Node-importable module (`lib/`). The orchestration loop is a single function,
`runPipeline(deps)`, with its effectful collaborators **dependency-injected**
(`{ agent, parallel, phase, log, budget, stages }`). The Workflow script is a thin shim that
injects the *real* workflow globals; the unit tests inject *fakes*. Nothing in the loop's logic
is reachable only inside the Workflow sandbox.

---

## 4. Control-flow contract

The spine is sequential (each stage reads the prior's `thoughts/*.pl`); parallelism lives
*inside* stages (§5). The loop is **movable-cursor**, which is what makes loopbacks, scope
widening, and gap batching real rather than decorative.

```js
// lib/pipeline.mjs  (pure logic; deps injected)
export async function runPipeline(deps) {
  const { agent, parallel, phase, log, budget, stages } = deps
  let startIdx = deps.startIdx, endIdx = deps.endIdx
  let cursor = startIdx, halted = null
  const recovery = new Map()           // `${stage}:${gapClass}` -> count, capped at LOOP_LIMIT
  const decisions = []
  const art = { ...deps.seed }
  let disproofCount = 0

  while (cursor <= endIdx) {
    const stage = stages[cursor]; phase(stage.title)
    const d = await stage.run(art, deps)          // SMART: stage agents (may parallel-fan-out)
    art[stage.key] = d

    // --- disprove (opportunistic): non-clean verdict + budget above the reserve ---
    if (shouldDisprove(d) && budget.remaining() > DISPROVE_RESERVE) {
      const v = await runDisprove(d, art, deps)   // SMART: >=2 adversaries in parallel
      decisions.push({ kind: 'disprove', ...v }); disproofCount++
      if (v.outcome === 'refuted' && d.is_core) { halted = { kind: 'refuted', stage: stage.name }; break }
      if (v.outcome === 'refuted') d.upstream_gaps.push(gapFromRefutation(v))
    }

    // --- gaps: mechanics in JS, honor-decision in an agent ---
    const gaps = batchGaps(d.upstream_gaps)       // MECHANICS: merge by target stage
    if (gaps.length) {
      const r = await routeGaps(gaps, { startIdx, recovery, scope: [startIdx, endIdx] }, deps)
      decisions.push({ kind: 'route', ...r })
      if (r.honor) {
        const tIdx = stages.findIndex(s => s.name === r.target_stage)
        if (tIdx < startIdx) { startIdx = tIdx; decisions.push({ kind: 'widen', to: tIdx }) } // scope only widens
        const key = `${stage.name}:${r.gap_class}`
        if ((recovery.get(key) || 0) >= LOOP_LIMIT) { halted = { kind: 'loop_limit', key }; break }
        recovery.set(key, (recovery.get(key) || 0) + 1)
        cursor = tIdx; continue                    // LOOP BACK
      }
    }

    if (d.status === 'halt') { halted = { kind: 'halt', stage: stage.name, reason: d.reason }; break }
    cursor++
  }

  // --- mandatory adversarial floor: guarantee >=1 disprove (budget reserved up front) ---
  if (disproofCount === 0) {
    const v = await runDisprove(coreTarget(art), art, deps)  // uses the reserved budget
    decisions.push({ kind: 'disprove', mandatory: true, ...v }); disproofCount++
  }

  phase('Explain')
  const explanation = await runExplain(art, halted, decisions, deps)   // ALWAYS RUNS
  return { halted, scope: { startIdx, endIdx }, artifacts: art, decisions, explanation }
}
```

Constants: `LOOP_LIMIT = 1` (one recovery per gap-class-per-stage, matching the substrate's
policy); `DISPROVE_RESERVE` = the token cost of one ≥2-adversary attempt, reserved up front so
invariant 6 always holds even if the run is otherwise budget-starved.

Semantics:

- **Auto-recover-and-log vs terminate-and-report.** A background workflow cannot pause to ask
  the user. Recoverable gaps are **honored automatically within the loop limit and logged** to
  `decisions` (autonomy + an auditable trail). Only **hard stops** terminate-and-report:
  loop-limit exceeded, token budget exhausted, or a **core** obligation refuted. (If you later
  want hard human gates between runs instead, this is the one switch to flip.)
- **Disprove triad.** (5) bounded above — never spends below `DISPROVE_RESERVE`, never attacks
  its own output; (6) at-least-once — the post-loop block guarantees ≥1 attempt using the
  reserved budget; (7) fans-out — `runDisprove` is structurally `parallel([...≥2])` with
  perspective-diverse adversaries (`lean-adversary` + `prolog-adversary`, or ≥2 skeptics with
  distinct lenses).
- **Explain always runs** — it is post-loop and unconditional, on every path including breaks.

---

## 5. Stage spine & parallelism map

```
close-world → decompose → model-obligations → prove-invariants → instantiate → realize → measure → [explain]
   (1)           (1)        ⇉ per-property      ⇉ per-theorem      ⇉ per-test   ✗ serial   ⇉ per-resource
```

- **Parallel-clean:** `prove-invariants` (independent theorems, one `.lean` file each),
  `instantiate-properties` (one test per proved property), per-property `model-obligations`.
- **Stays serial — honest finding:** `realize-specification` unskips one test at a time against
  *shared mutable source* with inter-test dependencies; worktree isolation doesn't save it
  (merge conflicts + ordering). Serial by necessity.
- `close-world` *may* fan out over source modules; default single-shot for the dogfood subject.

---

## 6. Bounded-parallel Lean

The deterministic structural box is **heartbeats, not wall-clock** (wall-clock would make the
same proof pass/fail by machine load — poison for a deterministic workflow):

- **Primary box, per theorem:** `set_option maxHeartbeats 400000 in` (+ `set_option
  maxRecDepth 1024 in`). A non-converging proof fails *loudly* instead of hanging. (400000 is a
  tunable starting point = 2× Lean default.)
- **Outer backstop:** each `lean-expert` runs `timeout 300 lake build Proofs.<Name>` — catches
  infra/pathological hangs only.
- **Mathlib prebuilt once:** `lake exe cache get` in a provisioning step *before* the fan-out;
  parallel agents then compile only their own small file against the cache.
- **Lean concurrency sub-cap:** prove-invariants batches its `parallel()` fan-out in chunks of
  ≈`cores/4` to bound memory (below the global `min(16, cores-2)` cap).
- **Failure feeds control flow:** "unprovable under budget" → `verdict.unprovable` +
  `upstream_gap(prove-invariants, unprovable, target: model-obligations)` → drives the adjacent
  loopback **and** triggers a disprove attempt on that theorem. The bound is the trigger.

---

## 7. Stage execution model + the assumption to de-risk first

Pipeline stages are **skills** (multi-agent orchestrations); a Workflow's unit of delegation is
a single **agent**. So `stage.run` mapping to one `agent()` is a simplification we must make
faithful for a real run.

**Load-bearing assumption (verify before building the spine):** a workflow subagent invoked as
`agent(prompt, { agentType: 'general-purpose' })` carries the `Skill` tool and can therefore
invoke `shifting:close-world` etc. and let the skill drive. Smoke-test one stage first.

- **If true:** each `stage.run` is `agent("invoke shifting:<stage> with <inputs>", { agentType:
  'general-purpose', schema: StageDigest })`. Clean.
- **If false (fallback):** call the stage's named sub-agents directly via `agentType`
  (`shifting:agent-of-truth`, `shifting:lean-expert`, …) and reproduce the skill's internal
  orchestration in JS. More work; flagged loudly; recorded in `FINDINGS.md`.

A second assumption to verify: **can the Workflow sandbox `import` a sibling `.mjs`?** If yes,
the shim imports `lib/pipeline.mjs`. If no, the shim inlines `runPipeline` and a `sync-check`
test asserts the inlined copy matches the module source.

---

## 8. Inter-stage artifacts & schemas

State is threaded **through files** (`thoughts/*.pl`, mirroring the existing artifact chain);
each `stage.run` writes its artifact and **returns a small structured digest** validated by the
Workflow `agent({schema})` layer. We do not serialize Prolog KBs through JSON.

```
StageDigest = {
  stage:         string,
  artifact_path: string,                     // the thoughts/*.pl it wrote
  status:        'ok' | 'halt',
  reason?:       string,
  verdict?:      { unprovable?: bool, inconsistent?: bool, refuted_candidate?: bool },
  counts:        object,                     // e.g. { claims, theorems, proved }
  is_core:       bool,                       // carries a core obligation (disprove hard-stop)
  upstream_gaps: [ { gap_class, detail, target_stage, param_spec } ]
}

DisproofVerdict = {
  target:   string,
  outcome:  'refuted' | 'inconclusive' | 'abstained',
  adversaries: [ { lens, outcome } ],        // length >= 2
  counterexample_path?: string
}

RouteDecision = { honor: bool, target_stage: string, gap_class: string, rationale: string }
```

---

## 9. Dogfood self-verification — the invariant set

Close-world the **control flow of `runPipeline`** (states = cursor positions + post-loop;
transitions = advance / loopback / break; guards = recovery limit, scope monotonicity, budget
reserve) into `existing-world.pl`; decompose the proposition *"this control flow terminates and
always explains, runs disprove ≥1 with ≥2 adversaries, and never narrows scope"*; prove:

1. **explain-always-runs** — every terminating path reaches `runExplain` (it is post-loop,
   unconditional).
2. **artifact-gating** — no stage runs before its required upstream artifact exists in `art`.
3. **termination** *(the meaty one)* — the loop halts. Well-founded measure
   `M = (Σ remaining recovery budget over all keys, endIdx − cursor)` under lexicographic order:
   a forward step keeps the first component and decreases the second; a loopback decreases the
   first (recovery consumed, finitely bounded by `#keys × LOOP_LIMIT`); a break exits. `M`
   strictly decreases each iteration ⇒ termination.
4. **scope-only-widens** — `startIdx` is monotonically non-increasing; `endIdx` fixed; scope
   never narrows mid-run.
5. **disprove-bounded-above** — disprove never spends below `DISPROVE_RESERVE` and never attacks
   its own output.
6. **disprove-runs-at-least-once** — every run performs ≥1 disprove attempt (post-loop block
   uses the reserved budget; like explain-always-runs).
7. **disprove-fans-out** — every disprove attempt spawns ≥2 adversaries in parallel (cardinality
   property of `runDisprove`).

---

## 10. Verification strategy — two non-overlapping layers

**Layer 1 — unit tests (behavior), TDD, written first.** Pure mechanics + the injected loop,
exercised with `mock-runner.mjs` stubbing `agent / parallel / phase / log / budget`. Failing
tests first, then implementation. Test list:

1. `batchGaps` merges gaps with the same `target_stage` (and merges `param_spec`); distinct
   targets stay separate.
2. `recoveryGuard` allows up to `LOOP_LIMIT` per key, blocks the next.
3. Honoring a gap with `target < startIdx` lowers `startIdx`; never raises it.
4. Cursor: advances on a clean digest; loops back on an honored gap; breaks on `halt`.
5. `runDisprove` invokes ≥2 adversaries in parallel (assert `parallel` called with ≥2 thunks).
6. **Mandatory disprove:** an all-clean run still performs ≥1 disprove attempt.
7. **Disprove budget:** opportunistic disprove suppressed when below reserve; the mandatory
   post-loop pass still runs (reserve protected).
8. `explain` runs exactly once, last, on the happy path **and** on every break path.
9. Core-refuted ⇒ break, then explain.
10. Loop-limit hit ⇒ `halted.kind === 'loop_limit'`, then explain.
11. Scripted E2E (mocked): one loopback + one disprove + completion ⇒ asserts the full
    `decisions` trail.

**Layer 2 — Lean proofs (invariants).** The 7 theorems of §9, closed against the close-worlded
model, under the heartbeat box of §6. These *are* the dogfood, and they are the real Lean
workload that validates bounded-parallel today.

---

## 11. Repo layout, branch, artifacts

- Branch: `experiment/pipeline-workflow` off `origin/main`.
- Not wired into `plugins/trajectory/` — dogfood, not canonical. Self-contained experiment:

```
experiments/pipeline-workflow/
  orbital-pipeline.workflow.js     # thin shim: meta + stage runners + runPipeline(deps)
  lib/
    pipeline.mjs                   # runPipeline(deps) + pure mechanics (batchGaps, guards, …)
    schemas.mjs                    # StageDigest / DisproofVerdict / RouteDecision
  mock-runner.mjs                  # stubs agent/parallel/phase/log/budget
  pipeline.test.mjs                # Layer-1 unit tests (node --test)
  self-spec/                       # dogfood artifacts, persisted from the run
    existing-world.pl  hypothesis.pl  target-world.pl  lean/Proofs/*.lean
  FINDINGS.md                      # fit assessment + the two de-risk results (§7)
```

- Brainstorming spec (this file): `docs/superpowers/specs/2026-05-28-pipeline-as-workflow-design.md`.

---

## 12. Scope

**Today:** spec → TDD unit tests → implementation → dogfood proof (7 invariants) → E2E wiring →
closing `explain` run on what was produced.

**Tomorrow / late tonight:** point the workflow at a new `kimmy` feature, end-to-end.

**Explicitly out (noted, not built):** making it the canonical `trajectory` pipeline; the
`disprove`-recursion guard beyond "never attacks own output"; multi-ticket `pipeline()`
fan-out (we orchestrate one ticket); the 120k context hard-stop (maps to `budget.remaining()`,
noted only).

---

## 13. Risks & open questions

- **R1 — skill-from-subagent (§7).** Whole faithful-execution story depends on it. *Verify
  first.* Fallback defined.
- **R2 — sandbox import (§7).** Determines shim shape (import vs inline+sync-check). Verify
  early.
- **R3 — Lean parallel memory.** Even with cached Mathlib, N concurrent `lake build`s may
  thrash. Mitigation: `cores/4` sub-cap, tune down if needed.
- **R4 — termination measure fidelity.** The Lean proof is only as good as the close-world model
  of the loop; if the model omits a transition the proof is vacuous. Mitigation: `kb-validator`
  + a `cwa-fragility-auditor` pass on the self-spec KB.
- **R5 — inverting smart/dumb.** Guarded by the §3 rule. Branching on an *agent-emitted* signal
  (`d.status`, `d.verdict`, `d.is_core`) is fine — that is *executing* an agent's decision. The
  smell is a JS `if` that *computes* a verdict itself; route that through an agent instead.
```
