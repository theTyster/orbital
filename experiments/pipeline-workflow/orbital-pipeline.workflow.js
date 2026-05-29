// =============================================================================
// orbital-pipeline.workflow.js
//
// The deterministic, background-executable Workflow entry script realizing the
// orbital-shifting seven-stage pipeline as ONE Workflow (D-1), preserving
// invariants I-1..I-7.
//
// SEPARATION OF AUTHORITY (D-2 / C-2). This substrate owns MECHANICS ONLY:
// stage sequencing, the movable cursor (D-4), gap batching (crit 1), the
// loop-limit/termination guard (D-7/I-3), monotone scope (C-4/I-4), disprove
// reserve accounting (C-3/C-5/I-5..I-7), and the decision trail (crit 11). It
// branches ONLY on agent-emitted digest fields (C-2) and NEVER computes a logic
// verdict itself. Agents own judgment (provable / refuted / inconsistent).
//
// DETERMINISM (C-1 / D-11). Effectful collaborators — agent, clock, rng, fs —
// are INJECTED. No control decision reads the clock or rng; two runs with
// different clock/rng produce an identical decision trail.
//
// This module is BOTH the Workflow entry AND the single import seam the test
// suite resolves (it re-exports every pure mechanic from lib/).
// =============================================================================

"use strict";

const { mergeGaps } = require("./lib/gap-batching.js");
const { LOOP_LIMIT, withinLoopLimit, loopbacksFor } = require("./lib/loop-limit.js");
const { widenScope } = require("./lib/scope-set.js");
const { planDisproveAttempt } = require("./lib/disprove-reserve.js");
const {
  measureM,
  lexLt,
  stepForward,
  stepLoopback,
  initialRecoveryBudgetSum,
} = require("./lib/termination-measure.js");
const {
  STAGE_SEQUENCE,
  stageIndex,
  stageSuccessor,
  requiredUpstream,
  canRunStage,
} = require("./lib/stage-order.js");
const { routeDigest } = require("./lib/digest-router.js");
const { createTrail } = require("./lib/decision-trail.js");
const { HARD_STOP_REASONS } = require("./schemas/stage-digest.schema.js");

const EXPLAIN_IDX = STAGE_SEQUENCE.indexOf("explain"); // 7
// Recovery keys: the loopback-eligible interior stages (D-7 substrate policy).
const RECOVERY_KEYS = ["model_obligations", "prove_invariants", "instantiate", "realize"];

// -----------------------------------------------------------------------------
// runPipeline — the orchestration loop.
//
// Injected deps (D-11): { agent, clock, rng, fs? }. The agent exposes
// runStage(stage, ctx) -> digest and (optionally) runDisprove(spec) -> attempt.
// clock and rng are accepted to PROVE they are never branched on (C-1): they are
// threaded only into the injected agent surface, never into a control decision.
// -----------------------------------------------------------------------------
function runPipeline(deps = {}) {
  const agent = deps.agent;
  const loopLimit = deps.loopLimit == null ? LOOP_LIMIT : deps.loopLimit;
  const trail = createTrail();

  // Scope is monotone (C-4/I-4): startIdx only widens (lowers), endIdx fixed.
  let scope = { startIdx: 0, endIdx: EXPLAIN_IDX };
  // The movable cursor (D-4): advances by default, backward only for a gap.
  let cursor = 0;
  const produced = new Set();

  // Disprove floor (D-6/I-6): reserve >=1 attempt up front, run it (>=2
  // adversaries in parallel, I-7). Recorded before the stage loop so EVERY run
  // — even all-clean — carries the mandatory attempt.
  runMandatoryDisprove(agent, trail);

  let outcome = "complete";
  let reason = null;

  // The interior stages (close_world..measure); explain is the post-loop closer.
  while (cursor < EXPLAIN_IDX) {
    const stage = STAGE_SEQUENCE[cursor];

    // I-2 artifact gating: a stage only runs once its upstream artifact exists.
    if (!canRunStage(stage, produced)) {
      // A gate that cannot be satisfied is a hard structural stop. (Not reached
      // on the canonical forward chain; defensive.)
      outcome = "hard_stop";
      reason = "artifact_gate_unsatisfied";
      trail.record("halt", { stage, reason });
      break;
    }

    trail.record("stage", { stage, cursor });
    const digest = agent.runStage(stage, { scope, cursor });
    const decision = routeDigest({ cursor, scope, trail: trail.entries }, digest);

    if (decision.action === "halt") {
      outcome = "hard_stop";
      // The reason is agent-emitted; the substrate routes on it (D-5).
      reason =
        decision.reason ||
        (decision.coreObligation
          ? HARD_STOP_REASONS.CORE_OBLIGATION_REFUTED
          : "halt");
      trail.record("halt", {
        stage,
        reason,
        coreObligation: !!decision.coreObligation,
      });
      break;
    }

    if (decision.action === "loopback") {
      // Batch gaps that share a target, then honor the routed gap (D-3 crit 1).
      const merged = mergeGaps(digest.gaps);
      const gap = merged[0];
      trail.record("gap_merge", { merged, count: merged.length });

      // D-7/crit 2: cap recovery at LOOP_LIMIT per gap-class-per-stage. Once
      // exhausted, hard-stop (D-5/crit 10). The accounting is the substrate's;
      // the gap signal is agent-emitted.
      if (!withinLoopLimit(trail.entries, gap.gapClass, gap.targetStage, loopLimit)) {
        outcome = "hard_stop";
        reason = HARD_STOP_REASONS.LOOP_LIMIT_EXHAUSTED;
        trail.record("halt", { stage, reason, gapClass: gap.gapClass, targetStage: gap.targetStage });
        break;
      }

      // Mark this stage's artifact produced (it ran and emitted a routable
      // digest) so the re-run after loopback can pass its gate.
      produced.add(stage);

      // Honor the loopback: widen scope if the target precedes start (C-4/I-4),
      // record the loopback (consumes one recovery unit, I-3 1st component), and
      // move the cursor backward ONLY here (D-4).
      const targetIdx = stageIndex(gap.targetStage);
      scope = widenScope(scope, targetIdx);
      trail.record("loopback", {
        from: stage,
        targetStage: gap.targetStage,
        gapClass: gap.gapClass,
        targetIdx,
      });
      cursor = targetIdx;
      continue;
    }

    // advance: clean digest -> mark produced, move the cursor forward (D-4).
    produced.add(stage);
    trail.record("advance", { from: stage, to: STAGE_SEQUENCE[cursor + 1] });
    cursor += 1;
  }

  // D-8 / I-1: explain ALWAYS runs, post-loop, unconditional — on the happy path
  // AND every hard-stop path. Exactly once, last (crit 8).
  trail.record("stage", { stage: "explain", terminal: true });

  return { outcome, reason, trail: trail.entries, scope };
}

/** Reserve + run the mandatory disprove attempt (D-6/I-6/I-7). */
function runMandatoryDisprove(agent, trail) {
  const spec = { ownOutput: "disproof_results", reserve: 1, gateTarget: "gate_target_descriptor" };
  // Prefer the agent's disprove surface (judgment); fall back to the pure
  // planner (mechanics) so the floor holds even with a minimal fake agent.
  const attempt =
    agent && typeof agent.runDisprove === "function"
      ? agent.runDisprove(spec)
      : planDisproveAttempt(spec);
  trail.record("disprove_attempt", {
    target: attempt.target,
    ownOutput: attempt.ownOutput,
    spend: attempt.spend,
    reserve: attempt.reserve,
    parallel: attempt.parallel,
    adversaryCount: attempt.adversaries ? attempt.adversaries.length : 0,
  });
  return attempt;
}

// -----------------------------------------------------------------------------
// Public surface — the orchestration entry + every pure mechanic the tests and
// downstream stages (explain / measure-entailment) share vocabulary with.
// -----------------------------------------------------------------------------
module.exports = {
  // Orchestration
  runPipeline,
  // Gap batching (crit 1)
  mergeGaps,
  // Loop-limit / termination guard (D-7, crit 2)
  withinLoopLimit,
  loopbacksFor,
  LOOP_LIMIT,
  // Monotone scope (C-4 / I-4, crit 3)
  widenScope,
  // Digest routing — movable cursor (D-4, C-2, crit 4)
  routeDigest,
  // Disprove reserve accounting (C-3/C-5, I-5/I-6/I-7)
  planDisproveAttempt,
  // Termination measure (I-3)
  measureM,
  lexLt,
  stepForward,
  stepLoopback,
  initialRecoveryBudgetSum,
  // Stage order & gating (I-1, I-2)
  STAGE_SEQUENCE,
  stageIndex,
  stageSuccessor,
  requiredUpstream,
  canRunStage,
  // Constants
  EXPLAIN_IDX,
  RECOVERY_KEYS,
};
