// =============================================================================
// Disprove reserve accounting (C-3/C-5 ; I-5/I-6/I-7).
//
// Disprove policy (D-6):
//   - >=1 attempt per run (mandatory floor; budget reserved up front)        I-6
//   - >=2 perspective-diverse adversaries per attempt, dispatched in parallel I-7 / C-5
//   - never spends below the reserve                                          I-5 / C-3
//   - never attacks its own output                                           I-5 / C-3
//
// This module plans a SINGLE attempt deterministically (no RNG, no clock).
// =============================================================================

"use strict";

const DEFAULT_OWN_OUTPUT = "disproof_results";
const DEFAULT_GATE_TARGET = "gate_target_descriptor";

/**
 * Plan one disprove attempt. Pure & deterministic.
 *
 * Reserve discipline (C-3/I-5): the MANDATORY attempt always spends at least the
 * reserve, regardless of opportunistic budget — even availableBudget 0 cannot
 * push spend below reserve. Spend = max(reserve, availableBudget?, 1).
 *
 * No-self-attack (C-3/I-5): the chosen target is never the attempt's own output.
 * If a candidate list is given, the own output is filtered out and the first
 * remaining candidate is selected; otherwise the gate-target descriptor is used.
 *
 * Fan-out (C-5/I-7): >=2 distinct adversaries, dispatched in parallel.
 *
 * @param {object} spec
 * @param {number} [spec.reserve=1]            reserved disprove budget floor
 * @param {number} [spec.availableBudget]      opportunistic budget (may be 0)
 * @param {string} [spec.ownOutput]            this attempt's own output surface
 * @param {string} [spec.gateTarget]           default attack target
 * @param {string[]} [spec.candidateTargets]   candidate targets to choose from
 * @param {Array<{id:string}>} [spec.adversaries] override adversary set
 * @returns {{target,ownOutput,spend,reserve,parallel,adversaries}}
 */
function planDisproveAttempt(spec = {}) {
  const reserve = spec.reserve == null ? 1 : spec.reserve;
  const ownOutput = spec.ownOutput || DEFAULT_OWN_OUTPUT;

  // Reserve discipline: spend never drops below the reserve (C-3/I-5). The
  // mandatory attempt protects the reserve even when opportunistic budget is 0.
  const opportunistic =
    spec.availableBudget == null ? reserve : spec.availableBudget;
  const spend = Math.max(reserve, opportunistic, 1);

  // No-self-attack: choose a target that is NOT the own output (C-3/I-5).
  const target = chooseTarget({
    ownOutput,
    gateTarget: spec.gateTarget || DEFAULT_GATE_TARGET,
    candidateTargets: spec.candidateTargets,
  });

  // Fan-out: >=2 distinct, perspective-diverse adversaries in parallel (C-5/I-7).
  const adversaries =
    spec.adversaries && spec.adversaries.length >= 2
      ? spec.adversaries
      : [{ id: "adv1", perspective: "structural" }, { id: "adv2", perspective: "semantic" }];

  return { target, ownOutput, spend, reserve, parallel: true, adversaries };
}

/** Select an attack target that never coincides with the own output. */
function chooseTarget({ ownOutput, gateTarget, candidateTargets }) {
  if (Array.isArray(candidateTargets) && candidateTargets.length > 0) {
    const allowed = candidateTargets.filter((t) => t !== ownOutput);
    if (allowed.length > 0) return allowed[0];
    // Every candidate coincides with own output -> re-route to the gate target.
    return gateTarget !== ownOutput ? gateTarget : `${ownOutput}__rerouted`;
  }
  return gateTarget !== ownOutput ? gateTarget : `${ownOutput}__rerouted`;
}

module.exports = { planDisproveAttempt };
