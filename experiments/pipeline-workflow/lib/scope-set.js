// =============================================================================
// Scope set — monotone (C-4 / I-4: scope only widens, never narrows).
//
// The scope is { startIdx, endIdx }. endIdx is FIXED (the explain terminal).
// startIdx is monotonically NON-INCREASING: a loopback whose target precedes
// the current start widens the scope (lowers startIdx); a target at or after
// the current start is NOT a narrowing and leaves startIdx unchanged.
//
// I-4 (i4_startidx_antitone): forall steps i<=j, startIdx j <= startIdx i.
// =============================================================================

"use strict";

/**
 * Widen scope to admit a loopback target. Pure.
 *   - target < startIdx : widen (startIdx := target)   — scope grows earlier
 *   - target >= startIdx: unchanged                     — never narrows (I-4)
 * endIdx is always preserved (fixed terminal).
 *
 * @param {{startIdx:number, endIdx:number}} scope
 * @param {number} target  loopback target stage index
 * @returns {{startIdx:number, endIdx:number}} a new scope; startIdx never raised
 */
function widenScope(scope, target) {
  const startIdx = Math.min(scope.startIdx, target);
  return { startIdx, endIdx: scope.endIdx };
}

module.exports = { widenScope };
