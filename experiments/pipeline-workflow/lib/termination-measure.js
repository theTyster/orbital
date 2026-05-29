// =============================================================================
// Termination guard — the well-founded lexicographic measure (I-3).
//
// M = (Σ remaining recovery budget over keys, endIdx − cursor)
//   represented here as (recoveryBudgetSum, cursorDistance), ordered by
//   Prod.Lex Nat.lt Nat.lt (lexicographic, 1st component dominant).
//
//   - forward step  : (rb, d+1) -> (rb, d)   — 2nd component strictly decreases
//   - loopback step : (rb+1, d) -> (rb, d')  — 1st component strictly decreases,
//                                              dominating ANY change in d'
//   - no identity / measure-preserving step exists (non-vacuity guard).
//
// recoveryBudgetSum is finitely bounded by #keys × LOOP_LIMIT (= 4 here), so
// the 1st component can drop at most that many times -> the relation is
// well-founded and the loop terminates.
// =============================================================================

"use strict";

/**
 * The lexicographic measure as a [primary, secondary] tuple.
 * @param {{recoveryBudgetSum:number, cursorDistance:number}} s
 * @returns {[number, number]}
 */
function measureM(s) {
  return [s.recoveryBudgetSum, s.cursorDistance];
}

/**
 * Strict lexicographic less-than over the [primary, secondary] tuple.
 * @param {[number, number]} a
 * @param {[number, number]} b
 * @returns {boolean} a <_lex b
 */
function lexLt(a, b) {
  if (a[0] !== b[0]) return a[0] < b[0];
  return a[1] < b[1];
}

/**
 * A forward step: cursor advances, so cursorDistance (endIdx - cursor) drops by
 * one; recovery budget is untouched. Strictly decreases the 2nd lex component.
 */
function stepForward(s) {
  return {
    recoveryBudgetSum: s.recoveryBudgetSum,
    cursorDistance: s.cursorDistance - 1,
  };
}

/**
 * A loopback step: consumes exactly one recovery unit (1st component drops by
 * one — strictly decreasing M and dominating the cursor jump). The cursor jumps
 * backward, so cursorDistance grows to (endIdx - target).
 *
 * @param {{recoveryBudgetSum:number, cursorDistance:number}} s
 * @param {number} endIdx  the fixed terminal index (cursor jumps back; distance grows)
 */
function stepLoopback(s, endIdx) {
  return {
    recoveryBudgetSum: s.recoveryBudgetSum - 1,
    // cursor jumped backward; new distance grows toward endIdx. The exact jump
    // target distribution is unsampled; the dominant 1st component guarantees
    // strict decrease regardless.
    cursorDistance: endIdx,
  };
}

/**
 * The initial recovery budget sum = #keys × LOOP_LIMIT.
 * @param {string[]} keys      recovery keys ({model_obligations,...})
 * @param {number} loopLimit   LOOP_LIMIT (1)
 */
function initialRecoveryBudgetSum(keys, loopLimit) {
  return keys.length * loopLimit;
}

module.exports = {
  measureM,
  lexLt,
  stepForward,
  stepLoopback,
  initialRecoveryBudgetSum,
};
