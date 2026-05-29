// =============================================================================
// Stage order & artifact gating (I-1 terminality ; I-2 gating).
//
// The 8-stage chain (target-world.pl substrate):
//   close_world -> decompose -> model_obligations -> prove_invariants
//     -> instantiate -> realize -> measure -> explain (terminal closer)
//
// I-1 terminality : explain has no successor (unique terminal).
// I-2 gating      : no stage runs before its required upstream artifact exists;
//                   close_world is ungated (the unique stage-0 base case).
//
// The required-artifact relation is the immediate predecessor's output.
// This is MECHANICS (D-2) — it reads what artifacts are produced; it computes
// no logic verdict.
// =============================================================================

"use strict";

const STAGE_SEQUENCE = Object.freeze([
  "close_world",
  "decompose",
  "model_obligations",
  "prove_invariants",
  "instantiate",
  "realize",
  "measure",
  "explain",
]);

/** Index of a stage in the canonical sequence, or -1. */
function stageIndex(stage) {
  return STAGE_SEQUENCE.indexOf(stage);
}

/**
 * The stage that immediately follows `stage`, or null if it is terminal.
 * I-1: stageSuccessor("explain") === null (explain is the unique terminal).
 */
function stageSuccessor(stage) {
  const i = stageIndex(stage);
  if (i < 0 || i >= STAGE_SEQUENCE.length - 1) return null;
  return STAGE_SEQUENCE[i + 1];
}

/**
 * The stage(s) whose artifact `stage` requires upstream. close_world requires
 * none (ungated base case). Every other stage requires its immediate predecessor.
 * @returns {string[]}
 */
function requiredUpstream(stage) {
  const i = stageIndex(stage);
  if (i <= 0) return []; // close_world (i=0) or unknown -> ungated
  return [STAGE_SEQUENCE[i - 1]];
}

/**
 * I-2: a stage may run iff every required upstream artifact has been produced.
 * close_world runs from a cold (empty) produced set.
 *
 * @param {string} stage
 * @param {Set<string>} produced  set of stages whose artifact exists
 * @returns {boolean}
 */
function canRunStage(stage, produced) {
  const required = requiredUpstream(stage);
  return required.every((r) => produced.has(r));
}

module.exports = {
  STAGE_SEQUENCE,
  stageIndex,
  stageSuccessor,
  requiredUpstream,
  canRunStage,
};
