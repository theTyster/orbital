// =============================================================================
// Digest router — movable cursor control flow (D-4 ; C-2 ; §9 crit 4).
//
// routeDigest decides the substrate's next action by reading ONLY the digest's
// agent-emitted fields (status / verdict / gaps / coreObligation / reason). It
// NEVER inspects artifact CONTENT and NEVER computes a logic verdict itself
// (C-2 / D-2 separation of authority). The inversion bug would be deriving
// 'refuted'/'unprovable'/'inconsistent' from raw stage output here.
//
// Action precedence (all driven by digest fields):
//   1. status === 'halt'        -> halt   (agent-emitted hard-stop)
//   2. gaps non-empty           -> loopback (honor a routed gap; D-4 backward)
//   3. otherwise                -> advance (clean digest -> cursor forward)
//
// The cursor moves backward ONLY to honor a routed gap (D-4).
// =============================================================================

"use strict";

const { DIGEST_STATUS } = require("../schemas/stage-digest.schema.js");
const { stageIndex } = require("./stage-order.js");

/**
 * Decide the next control action from agent-emitted digest fields only.
 *
 * @param {object} state   { cursor, scope, trail } (read-only here)
 * @param {object} digest  the stage digest (D-3)
 * @returns {{action:'advance'|'loopback'|'halt', reason?, gap?, targetIdx?}}
 */
function routeDigest(state, digest) {
  // 1. Agent-emitted halt status. The reason is agent-emitted; the substrate
  //    only routes on it (it does not decide WHY the agent halted).
  if (digest.status === DIGEST_STATUS.HALT) {
    return {
      action: "halt",
      reason: digest.reason || "halt",
      coreObligation: !!digest.coreObligation,
    };
  }

  // 2. A routed gap requests a loopback. Read the (already agent-tagged) target
  //    stage from the gap; the substrate does not compute whether to honor it
  //    beyond the loop-limit accounting performed by the loop (D-2/D-4).
  if (Array.isArray(digest.gaps) && digest.gaps.length > 0) {
    const gap = digest.gaps[0];
    return {
      action: "loopback",
      gap,
      targetIdx: stageIndex(gap.targetStage),
    };
  }

  // 3. Clean digest -> advance the cursor (default forward motion, D-4).
  //    NOTE: artifactContent (if present) is deliberately IGNORED — re-judging
  //    it here would be the C-2 inversion bug.
  return { action: "advance" };
}

module.exports = { routeDigest };
