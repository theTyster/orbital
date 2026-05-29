// =============================================================================
// Gap batching / merge (D-3 ; §9 crit 1).
//
// Gaps that share a TARGET STAGE merge into one (their params are merged);
// distinct target stages stay apart. This batches loopback requests so the
// movable cursor honors one widening per target rather than oscillating.
//
// Merge identity is the targetStage. (gapClass travels with the merged gap;
// the loop-limit guard keys on (gapClass, targetStage) separately.)
// =============================================================================

"use strict";

/**
 * Merge gaps sharing a target stage; keep distinct targets apart. Pure.
 * Param objects are shallow-merged in encounter order (later keys win on clash).
 *
 * @param {Array<{targetStage:string, gapClass:string, params?:object}>} gaps
 * @returns {Array<{targetStage:string, gapClass:string, params:object}>}
 */
function mergeGaps(gaps) {
  const byTarget = new Map();
  for (const gap of gaps) {
    const key = gap.targetStage;
    if (byTarget.has(key)) {
      const existing = byTarget.get(key);
      existing.params = { ...existing.params, ...(gap.params || {}) };
      // Preserve the set of gap classes that routed to this target.
      if (!existing.gapClasses.includes(gap.gapClass)) {
        existing.gapClasses.push(gap.gapClass);
      }
    } else {
      byTarget.set(key, {
        targetStage: gap.targetStage,
        gapClass: gap.gapClass,
        gapClasses: [gap.gapClass],
        params: { ...(gap.params || {}) },
      });
    }
  }
  return Array.from(byTarget.values());
}

module.exports = { mergeGaps };
