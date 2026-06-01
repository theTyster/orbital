// =============================================================================
// Digest fold — merge specialists' routing recommendations into the stage digest
// (D-3 ; C-2 ; separation of authority).
//
// foldDigest folds the specialists' AGENT-EMITTED routing recommendations
// (advance | gap | halt, plus gap/verdict fields) into the single routable STAGE
// DIGEST the proven loop branches on. It is PURE + DETERMINISTIC: no agent, no
// artifact-content inspection. It REPLACES the former assembler-AGENT — an extra
// LLM projection layer between the judges and the digest (the lossy-projection
// failure mode) — so folding in code keeps verdict authority with the specialists.
//
// C-2 BOUNDARY (locked by tests/digest_fold.c2_regression_guard.test.js — the
// pre-kimmy C-2 re-attack found two real violations in an earlier foldDigest):
//   - gapClass comes ONLY from the agent-emitted failureClass, else a fixed
//     CONSTANT — it is NEVER synthesized from substrate identity (__agentType /
//     stage). gapClass keys withinLoopLimit (a CONTROL decision); deriving it from
//     identity would make WHERE the run halts depend on which specialist the
//     substrate routed to rather than on agent judgement. (Violation A, fixed.)
//   - coreObligation=true is a hard-stop AXIS: it FORCES halt even on a gap-routed
//     result; it must never be demoted to a recoverable loopback. (Violation B.)
//   - the verdict word is carried verbatim or null; the substrate never derives it.
//
// MIRROR: realized/orbital-pipeline.realized.mjs inlines this function VERBATIM
// (the Workflow-tool host has no require); the two function bodies must stay
// byte-identical — only the module wiring (require vs inline) differs.
// =============================================================================

"use strict";

const { HARD_STOP_REASONS } = require("../schemas/stage-digest.schema.js");

/**
 * Fold the specialists' agent-emitted ROUTING recommendations into the routable
 * STAGE DIGEST. PURE + DETERMINISTIC — no agent, no artifact-content inspection.
 * Each specialist already emitted its own routing (advance|gap|halt) + gap/verdict
 * fields (it is the judge, in its own window); this merely MERGES them into the
 * shape the proven loop routes on (C-2: the substrate honors agent-emitted fields,
 * it never derives a verdict). This REPLACES the former assembler-AGENT, which was
 * an extra LLM projection layer between the judges and the digest (the lossy-
 * projection failure mode) — folding in code keeps verdict authority with the
 * specialists and removes a per-stage agent call.
 *
 * @param {string} stage    the stage producing this digest
 * @param {object} brief    the stage brief (reserved for caller-signature
 *                          symmetry with the realized runStage; not read here)
 * @param {Array}  results  specialist results, each carrying agent-emitted
 *                          routing/gap/verdict fields (plus substrate __agentType
 *                          identity tags that MUST NOT influence routable fields)
 * @returns {object} the routable stage digest
 */
function foldDigest(stage, brief, results) {
  // 1. HALT dominates: routing='halt' OR an agent-emitted coreObligation=true. A
  //    refuted core obligation is a hard-stop AXIS and must NEVER be demoted to a
  //    recoverable gap (the C-2 secondary violation the re-attack found: a gap-
  //    routed result carrying coreObligation=true silently dropped the hard-stop).
  const halt = results.find((r) => r && (r.routing === "halt" || r.coreObligation === true));
  if (halt) {
    return {
      stage,
      status: "halt",
      gaps: [],
      verdict: halt.verdictSignal || null,
      coreObligation: !!halt.coreObligation,
      reason: halt.coreObligation
        ? HARD_STOP_REASONS.CORE_OBLIGATION_REFUTED
        : halt.failureClass || "halt",
    };
  }
  // 2. GAPS: every specialist recommending a loopback contributes one gap, tagged
  //    with ITS OWN failureClass + upstreamStage (the loop's mergeGaps dedups by
  //    target). targetStage defaults to this stage (in-place repair) when unstated.
  const gaps = results
    .filter((r) => r && r.routing === "gap")
    .map((r) => ({
      targetStage: r.upstreamStage || stage,
      // gapClass = the agent-emitted failureClass, else a single fixed CONSTANT.
      // NEVER synthesize it from substrate identity (r.__agentType / stage): the
      // C-2 re-attack showed an identity-derived gapClass keys the loop-limit
      // control decision (withinLoopLimit) on which specialist the substrate
      // routed to rather than on agent judgement. A constant is content-agnostic.
      gapClass: r.failureClass || "unspecified_gap",
      params: {},
    }));
  // 3. VERDICT: carry the first agent-emitted verdict word (never derived here).
  const carried = results.find((r) => r && r.verdictSignal);
  return {
    stage,
    status: "ok",
    gaps,
    verdict: carried ? carried.verdictSignal : null,
    coreObligation: results.some((r) => r && r.coreObligation),
    reason: null,
  };
}

module.exports = { foldDigest };
