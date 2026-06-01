// =============================================================================
// C-2 REGRESSION GUARD — foldDigest (lib/digest-fold.js).
//
// foldDigest folds the specialists' agent-emitted routing recommendations into
// the single routable STAGE DIGEST. It is PURE and must honor C-2 (separation of
// authority): the substrate routes on AGENT-EMITTED fields, NEVER on substrate
// identity, and NEVER demotes an agent-emitted hard-stop.
//
// The pre-kimmy C-2 re-attack found two real, silent violations in an earlier
// foldDigest. These tests LOCK the fix so neither can regress unnoticed:
//   (A) gapClass was synthesized from substrate identity ((r.__agentType||stage)
//       + "_gap") when failureClass was omitted. gapClass keys withinLoopLimit (a
//       CONTROL decision), so WHERE the run halts depended on which specialist the
//       substrate routed to, not on agent judgement. -> C-2 inversion.
//   (B) a gap-routed result carrying coreObligation=true silently dropped the
//       hard-stop — a refuted core obligation demoted to a recoverable loopback.
//
// These import the tested mechanic DIRECTLY (no workflow.js seam), so they run
// independent of the rest of the suite.
//
// Runner: node:test (`node --test`).
// =============================================================================

const { test } = require("node:test");
const assert = require("node:assert/strict");

const { foldDigest } = require("../../lib/digest-fold.js");
const { HARD_STOP_REASONS } = require("../../schemas/stage-digest.schema.js");

// A specialist result the way runStage pushes it: the agent-emitted routing
// fields, plus the substrate-attached identity tag (__agentType). The identity
// tag MUST NOT influence any routable digest field.
function result(routing, extra = {}) {
  return { routing, ...extra };
}

// ---- Guard A: gapClass is content-agnostic; NEVER derived from __agentType ----

test("C2-A1: gap with no failureClass yields the CONSTANT gapClass, regardless of __agentType", () => {
  const d1 = foldDigest("close_world", null, [result("gap", { __agentType: "agent-of-truth", upstreamStage: "close_world" })]);
  const d2 = foldDigest("close_world", null, [result("gap", { __agentType: "lean-expert", upstreamStage: "close_world" })]);
  // Same omission, different substrate identity -> IDENTICAL gapClass.
  assert.equal(d1.gaps[0].gapClass, "unspecified_gap", "missing failureClass must fall back to the fixed constant");
  assert.equal(d2.gaps[0].gapClass, "unspecified_gap");
  assert.equal(d1.gaps[0].gapClass, d2.gaps[0].gapClass, "gapClass must NOT vary with __agentType (C-2 identity-inversion guard)");
  // And it must not embed the agent type at all.
  assert.ok(!d1.gaps[0].gapClass.includes("agent-of-truth"), "gapClass must not embed substrate identity");
  assert.ok(!d2.gaps[0].gapClass.includes("lean-expert"));
});

test("C2-A2: the constant fallback is also independent of the stage", () => {
  const dA = foldDigest("close_world", null, [result("gap", { __agentType: "x" })]);
  const dB = foldDigest("prove_invariants", null, [result("gap", { __agentType: "y" })]);
  assert.equal(dA.gaps[0].gapClass, dB.gaps[0].gapClass, "constant fallback must not be stage-derived");
  assert.equal(dA.gaps[0].gapClass, "unspecified_gap");
});

test("C2-A3: an agent-emitted failureClass IS carried verbatim (the only legitimate source)", () => {
  const d = foldDigest("model_obligations", null, [
    result("gap", { failureClass: "obligation_unsatisfiable", __agentType: "prolog-prover", upstreamStage: "decompose" }),
  ]);
  assert.equal(d.gaps[0].gapClass, "obligation_unsatisfiable", "failureClass must be carried verbatim");
  assert.equal(d.gaps[0].targetStage, "decompose", "upstreamStage routes the loopback target");
});

// ---- Guard B: coreObligation=true is a hard-stop AXIS; never demoted to a gap ----

test("C2-B1: a gap-routed result carrying coreObligation=true FORCES halt (not a loopback)", () => {
  const d = foldDigest("measure", null, [
    result("gap", { coreObligation: true, failureClass: "core_thing", __agentType: "verdict-extractor", upstreamStage: "decompose" }),
  ]);
  assert.equal(d.status, "halt", "coreObligation=true must force halt even on routing='gap' (hard-stop axis)");
  assert.equal(d.reason, HARD_STOP_REASONS.CORE_OBLIGATION_REFUTED, "halt reason must be the canonical core-obligation-refuted");
  assert.equal(d.coreObligation, true);
  assert.deepEqual(d.gaps, [], "a hard-stop carries no recoverable gaps");
});

test("C2-B2: explicit routing='halt' produces a halt digest carrying the verdict word", () => {
  const d = foldDigest("prove_invariants", null, [result("halt", { verdictSignal: "refuted", failureClass: "unprovable_core" })]);
  assert.equal(d.status, "halt");
  assert.equal(d.verdict, "refuted", "verdict word carried verbatim");
});

// ---- Guard C: the fold NEVER invents a verdict (carries verbatim or null) ----

test("C2-C1: verdict is carried verbatim from the first agent that emitted one", () => {
  const d = foldDigest("prove_invariants", null, [result("advance", {}), result("advance", { verdictSignal: "provable" })]);
  assert.equal(d.verdict, "provable");
});

test("C2-C2: no agent-emitted verdict -> verdict is null (never derived)", () => {
  const d = foldDigest("close_world", null, [result("advance", {})]);
  assert.equal(d.verdict, null, "the substrate must not synthesize a verdict");
  assert.equal(d.status, "ok");
  assert.deepEqual(d.gaps, []);
});

// ---- Sanity: a clean advance-only fold is a clean 'ok' digest ----

test("C2-D1: all-advance results fold to a clean ok digest", () => {
  const d = foldDigest("instantiate", null, [result("advance", {}), result("advance", {})]);
  assert.equal(d.status, "ok");
  assert.equal(d.coreObligation, false);
  assert.deepEqual(d.gaps, []);
  assert.equal(d.reason, null);
});
