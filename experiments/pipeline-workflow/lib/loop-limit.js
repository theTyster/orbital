// =============================================================================
// Loop-limit / termination guard (D-7 ; §9 crit 2).
//
// LOOP_LIMIT = 1 recovery per gap-class-per-stage. The guard counts honored
// loopbacks already recorded in the decision trail for a given (gapClass,
// targetStage) pair; once LOOP_LIMIT is reached, further recovery is refused
// (the run hard-stops with loop_limit_exhausted, D-5/crit 10). A DISTINCT
// (gapClass, stage) pair retains its own independent budget.
//
// This is pure accounting over the trail — no clock, no RNG (C-1).
// =============================================================================

"use strict";

const LOOP_LIMIT = 1;

/** Count honored loopbacks for a (gapClass, targetStage) pair in the trail. */
function loopbacksFor(trail, gapClass, targetStage) {
  let n = 0;
  for (const entry of trail) {
    if (
      entry.kind === "loopback" &&
      entry.gapClass === gapClass &&
      entry.targetStage === targetStage
    ) {
      n += 1;
    }
  }
  return n;
}

/**
 * Is another recovery for this (gapClass, stage) within the loop limit?
 * @returns {boolean} true if a further recovery is still permitted.
 */
function withinLoopLimit(trail, gapClass, stage, loopLimit = LOOP_LIMIT) {
  return loopbacksFor(trail, gapClass, stage) < loopLimit;
}

module.exports = { LOOP_LIMIT, withinLoopLimit, loopbacksFor };
