# Pipeline-as-Workflow — Design Spec

**Date:** 2026-05-28
**Branch:** `experiment/pipeline-workflow`
**Status:** Design — pending user review.

> This spec encodes **decisions, constraints, requirements, and invariants — not code.**
> Code changes; decisions about the code should be firmer. It is written to be **consumed by the
> orbital-shifting pipeline**: `close-world` extracts the declarations below as facts,
> `decompose-proposition` takes §1, and `prove-invariants` targets §7. See §10.

---

## 1. Proposition

**To decompose (§10):** *The orbital-shifting seven-stage pipeline can be realized as one
deterministic, background-executable Workflow that preserves invariants I-1…I-7, parallelizes its
provable and testable stages without losing determinism, and is verifiable by the same pipeline —
without inverting the smart-orchestrator / dumb-executor separation.*

Falsified by: any invariant in §7 failing; any control decision that depends on wall-clock or
randomness; or the orchestration layer making a logic judgment itself (a C-2 violation).

---

## 2. Goal & Definition of Done

The day's contract:

- **R-G1** Rigorously specced — this document (decisions, not code).
- **R-G2** Unit-tested via TDD — required behaviors (§9) red→green.
- **R-G3** Proven — I-1…I-7 (§7) closed in Lean.
- **R-G4** Fleshed out + wired into an E2E Workflow pointable at a real ticket tonight/tomorrow.
- **R-G5** A closing `explain` run on exactly what was produced, for human review **before** the
  Workflow is pointed at any real target.

Trial target: a new `kimmy` feature.

---

## 3. Background & positioning

Orbital-shifting is **already** a deterministic orchestrator — the `trajectory:pipeline` skill
(Opus/max), with its contract in `plugins/trajectory/references/orchestration-substrate.md` and
the inter-stage file contract in `plugins/shifting/hooks/scripts/artifact-chain.json`. This work
**moves** that orchestration from a *skill* into a *Workflow script* to gain parallelism, a hard
token budget, journal-resume, and a control flow that can itself be formally verified.

A prior `prop_pipeline_rewrite_R1_self_orchestration.md` was **refuted**; the framing that won was
**structural-layer-separation**. The line we hold to stay on the winning side is **C-2** (the
orchestration layer makes no logic judgment). The deterministic substrate is a *contract layer*,
not a smart agent — separation, not self-orchestration.

---

## 4. Requirements

- **R-1** Full control-flow machinery is first-class, not deferred: disprove branches, automatic
  loopbacks, scope widening, gap batching.
- **R-2** Lean proving is bounded and parallel.
- **R-3** The design self-verifies: its own invariants are machine-checked.
- **R-4** The result is pointable end-to-end at a real ticket.
- **R-5** Each run ends with a plain-language account of what it did.
- **R-6** Runs are deterministic, resumable, and budget-bounded.

---

## 5. Decisions (firm; with rationale)

- **D-1 — Workflow, not skill.** Orchestration is a deterministic Workflow script.
  *Why:* parallelism, budget, resume, and formal verifiability that an Opus skill can't give.
- **D-2 — Separation of authority.** The orchestration layer owns *mechanics*; agents own
  *judgment*:

  | Mechanics (orchestration layer) | Judgment (agents) |
  |---|---|
  | stage sequencing, cursor, scope set | "is this unprovable / inconsistent / refuted?" |
  | gap batching (merge by target) | "honor this loopback or surface it?" |
  | loop-limit / termination guard | "refute this claim" (adversaries) |
  | scope widening; artifact gating | plain-language narration |

  *Why:* keeps the smart-orchestrator role in agents and the substrate deterministic — the
  structural-layer separation that survived refutation.
- **D-3 — State via files, control via digest.** Stage state flows through `thoughts/*.pl` (the
  existing artifact contract); control flows through a structured digest each stage returns,
  carrying: artifact reference, status, verdict signals, gaps (each tagged with a target stage),
  and a core-obligation flag. *Why:* preserve the proven file contract; never serialize KBs.
- **D-4 — Movable-cursor control flow.** Stages are visited by a cursor that advances by default
  and moves **backward only to honor a routed gap**. *Why:* makes loopbacks real while bounding
  motion (feeds I-3).
- **D-5 — Auto-recover-and-log; hard-stop only when forced.** Recoverable gaps are honored
  automatically (within the loop limit) and logged to a decision trail. Only **loop-limit
  exceeded**, **budget exhausted**, or a **core obligation refuted** terminate-and-report.
  *Why:* a background run can't pause to ask; autonomy + an auditable trail. (One switch flips
  this to hard human gates between runs if ever wanted.)
- **D-6 — Disprove policy.** Every run performs **≥1** disprove attempt (budget reserved up
  front); every attempt fans out **≥2** perspective-diverse adversaries in parallel; disprove is
  bounded above. *Why:* a guaranteed adversarial floor + bias defense through diversity.
- **D-7 — `LOOP_LIMIT = 1`** recovery per gap-class-per-stage. *Why:* matches the substrate
  policy, guarantees termination, prevents oscillation. Tunable upward for the kimmy run.
- **D-8 — Explain always runs**, post-loop and unconditional, on every path. *Why:* every run is
  reviewable; also stated as I-1.
- **D-9 — Parallelism map.** Parallel: `prove-invariants` (per theorem), `instantiate-properties`
  (per test), per-property `model-obligations`. **Serial by necessity:** `realize-specification`
  (shared mutable source + inter-test dependencies; worktree isolation doesn't save it).

  ```
  close-world → decompose → model-obligations → prove-invariants → instantiate → realize → measure → [explain]
     (1)           (1)        ⇉ per-property      ⇉ per-theorem      ⇉ per-test   ✗ serial   ⇉ per-resource
  ```
- **D-10 — Lean bounding is deterministic.** Proof effort is bounded **per theorem by
  `maxHeartbeats` (+ `maxRecDepth`)** — deterministic work-units, not wall-clock; a wall-clock
  `timeout` exists only as an infra backstop. Mathlib is prebuilt once before any fan-out; Lean
  concurrency is sub-capped (~cores/4). "Unprovable under budget" emits the `unprovable` signal
  that drives the loopback **and** a disprove attempt. *Why:* a wall-clock bound would make the
  same proof pass/fail by machine load — fatal for a deterministic workflow; the bound is also the
  trigger that powers R-1.
- **D-11 — Verifiable in isolation.** The deterministic mechanics are separable and pure, and the
  orchestration loop receives its effectful collaborators by injection, so tests can substitute
  fakes. *Why:* TDD of the control flow without invoking real agents (satisfies R-G2).
- **D-12 — The dogfood subject is *this spec*.** The declarations here (D / C / I / R) are
  close-worlded, and §1 is decomposed and proven, so the **design is verified from the spec —
  not from the code**. *Why:* spec-driven proof is durable; code-driven proof rots.
- **D-13 — Experiment, not canonical.** Lives self-contained under
  `experiments/pipeline-workflow/`, not wired into `plugins/trajectory/`. *Why:* dogfood first;
  promotion to canonical is a separate, later decision.

---

## 6. Constraints (hard rules the implementation must not violate)

- **C-1 — Determinism.** No control decision may depend on wall-clock time or randomness.
- **C-2 — No logic call in the substrate.** The orchestration layer may branch only on
  *agent-emitted* signals; it must never *compute* a logic verdict (provable / refuted /
  inconsistent) itself.
- **C-3 — Disprove discipline.** Disprove never attacks its own output and never spends below the
  reserved budget.
- **C-4 — Monotone scope.** Scope may only widen; it never narrows mid-run.
- **C-5 — Adversary cardinality.** Every disprove attempt runs ≥2 adversaries in parallel.
- **C-6 — Background autonomy.** No human prompt mid-run.

---

## 7. Invariants (the formal proof targets)

These are the `formal_property` sketches §10 hands to `prove-invariants`.

- **I-1 — explain-always-runs.** Every terminating path reaches the explanation step.
- **I-2 — artifact-gating.** No stage runs before its required upstream artifact exists.
- **I-3 — termination** *(the meaty one).* The control flow halts. Proof obligation: a
  well-founded measure **`M = (Σ remaining recovery budget over all keys, endIdx − cursor)`** under
  lexicographic order strictly decreases each iteration — a forward step decreases the second
  component; a loopback decreases the first (recovery is consumed and is finitely bounded by
  `#keys × LOOP_LIMIT`); a hard-stop exits.
- **I-4 — scope-only-widens.** The scope's start index is monotonically non-increasing; the end
  is fixed; scope never narrows mid-run. (Formalizes C-4.)
- **I-5 — disprove-bounded-above.** Disprove never spends below the reserve and never attacks its
  own output. (Formalizes C-3.)
- **I-6 — disprove-runs-at-least-once.** Every run performs ≥1 disprove attempt. (Formalizes the
  floor in D-6.)
- **I-7 — disprove-fans-out.** Every disprove attempt spawns ≥2 adversaries in parallel.
  (Formalizes C-5.)

---

## 8. Assumptions & risks

- **A-1 (de-risk first) — skill-from-subagent.** A `general-purpose` workflow subagent can invoke
  a `shifting:` skill and let it drive. *If false:* call each stage's named sub-agents directly and
  reproduce the skill's orchestration in the substrate (more work; recorded in `FINDINGS.md`).
- **A-2 (de-risk first) — sandbox import.** The Workflow sandbox can import a sibling module.
  *If false:* inline the mechanics into the shim and add a sync-check that asserts the copy matches
  the source.
- **Risk — Lean parallel memory.** Concurrent `lake build`s may thrash even with cached Mathlib.
  *Mitigation:* the D-10 sub-cap, tuned down if needed.
- **Risk — close-world fidelity.** A proof is only as good as the close-world model of the design;
  an omitted transition yields a vacuous theorem. *Mitigation:* `kb-validator` +
  `cwa-fragility-auditor` on the self-spec KB.
- **Risk — inversion smell.** Any new substrate branch on a *computed* verdict violates C-2.
  *Mitigation:* route it through an agent instead.

---

## 9. Acceptance criteria

Two non-overlapping layers.

**Behavioral (TDD, written first — these seed the projection / behavioral tests).** The
orchestrator MUST:
1. merge gaps that share a target stage (and merge their parameters); keep distinct targets apart;
2. cap recovery at `LOOP_LIMIT` per gap-class-per-stage;
3. widen — never narrow — scope when a loopback target precedes the current start;
4. advance the cursor on a clean digest, loop back on an honored gap, halt on a halt status;
5. run ≥2 adversaries per disprove attempt;
6. perform ≥1 disprove attempt even on an all-clean run;
7. protect the disprove reserve (suppress opportunistic disprove below it; still run the mandatory one);
8. run `explain` exactly once, last, on the happy path **and** every hard-stop path;
9. hard-stop on a core-obligation refutation;
10. hard-stop on loop-limit exhaustion;
11. emit a complete, auditable decision trail.

**Formal.** I-1…I-7 (§7) machine-checked in Lean under the D-10 bounds.

---

## 10. How this spec is consumed (orbital-shifting bridge)

The spec is the pipeline's input — this is the dogfood (D-12):

1. **close-world** → extract D / C / I / R as facts → `existing-world.pl`.
2. **decompose-proposition** → §1 proposition → `hypothesis.pl`; the §7 invariants become the
   formal-property sketches.
3. **model-obligations** → `target-world.pl`.
4. **prove-invariants** → I-1…I-7 in Lean, bounded-parallel per D-10 (this run *also* validates
   D-10 for real).
5. Then **TDD-build** the Workflow to satisfy the proven design (§9 behavioral) → **E2E** →
   closing **explain** (R-G5).

---

## 11. Scope

**Today:** finalize this spec → run it through `close-world → … → prove-invariants` → TDD-build the
Workflow → E2E wiring → closing `explain`.

**Tonight / tomorrow:** point the Workflow at a new `kimmy` feature, end-to-end.

**Explicitly out (noted, not built):** promotion to the canonical `trajectory` pipeline;
disprove-recursion guards beyond C-3; multi-ticket fan-out (one ticket per run); the 120k context
hard-stop (subsumed by the token budget).
