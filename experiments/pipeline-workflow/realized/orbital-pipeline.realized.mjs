// =============================================================================
// orbital-pipeline.realized.mjs
//
// The Workflow-TOOL realization of the orbital-shifting seven-stage pipeline
// (+ the always-runs `explain` closer and the mandatory `disprove` floor).
//
// THIS IS "DECISION 2 / OPTION B". A Workflow `agent()` leaf cannot spawn its
// own sub-agents (depth-1 nesting cap, confirmed false-for-nested-Agent in the
// dogfood — see experiments/pipeline-workflow/FINDINGS.md F-2 / spec A-1). So the
// deterministic Workflow body calls each stage's NAMED specialist sub-agents
// DIRECTLY (no `shifting:<skill>` indirection) and reproduces the per-stage
// orchestration logic that the skills would otherwise own.
//
// CANONICAL PROVEN REFERENCE. The authority for this realization is NOT this
// file — it is the proven substrate at:
//     experiments/pipeline-workflow/lib/            (24 passing tests)
//     experiments/pipeline-workflow/self-spec/      (7 Lean invariants, axiom-free)
//     experiments/pipeline-workflow/orbital-pipeline.workflow.js  (the loop)
// The pure mechanics below are INLINED VERBATIM from lib/ (a reviewer should be
// able to diff them line-for-line against lib/), and `runPipeline` /
// `runMandatoryDisprove` are the ASYNC PORT of orbital-pipeline.workflow.js with
// the injected `agent.runStage` / `agent.runDisprove` seam replaced by the real
// `runStage` / `runMandatoryDisprove` functions in this file.
//
// SEPARATION OF AUTHORITY (D-2 / C-2). This substrate owns MECHANICS ONLY. It
// branches ONLY on agent-emitted digest fields (status / verdict / gaps /
// coreObligation / reason). It NEVER inspects artifact CONTENT and NEVER computes
// a logic verdict itself. This is the C-2 no-inversion invariant; it will be
// adversarially re-attacked (FINDINGS F-5) — do not violate it.
//
// HOST-IMPOSED CONSEQUENCE (Workflow tool). The model knob is a TIER only
// ('opus' | 'sonnet' | 'haiku') — there is NO effort knob and NO timeout /
// maxHeartbeats knob. Therefore every proof-writer / vetter / adversary discipline
// (lean-expert's forbidden-`decide` rule, the 15-attempt bounded-tactics budget,
// the prolog-prover tabling rule, the suite-runner "digest-is-the-verdict" rule,
// etc.) is written into the BRIEF TEXT below, since it cannot ride on a knob.
//
// FORBIDDEN at runtime (Workflow tool): require, import (other than this meta),
// fs / Node APIs, Date.now(), argless new Date(), Math.random(). All mechanics are
// inlined as top-level declarations because there is no `require`.
// =============================================================================

export const meta = {
  name: "orbital-pipeline",
  description:
    "Deterministic Workflow realization of the orbital-shifting pipeline (Decision 2 / option B): mandatory disprove floor, then the movable-cursor 8-stage loop (close_world -> decompose -> model_obligations -> prove_invariants -> instantiate -> realize -> measure -> explain) calling each stage's named specialists directly. Branches only on agent-emitted digest fields (C-2); explain always runs last.",
  phases: [
    { title: "disprove", detail: "Mandatory disprove floor: >=1 attempt, >=2 perspective-diverse adversaries in parallel, never attacks own output (D-6/I-5/I-6/I-7)." },
    { title: "close_world", detail: "Stage 1 (ungated base case): translate the source into a Prolog KB; validate via the five-tier cascade." },
    { title: "decompose", detail: "Stage 2: sharpen the proposition, gather counterfactual evidence, decompose into labeled claims + formal_property sketches." },
    { title: "model_obligations", detail: "Stage 3: build the target-world substrate by counterexample search; per-property verdict/2." },
    { title: "prove_invariants", detail: "Stage 4: transcribe each formal_property to a Lean stub, then close each stub (fan-out, one lean-expert per stub)." },
    { title: "instantiate", detail: "Stage 5: project proven universals onto fixtures as TDD tests (boundary lean -> tdd)." },
    { title: "realize", detail: "Stage 6 (serial, shared mutable source D-9): drive the skipped TDD suite to green one test at a time." },
    { title: "measure", detail: "Stage 7 (terminal): score how well the implementation entails the original proposition (Pattern 3, prescriptive fulfillment, gaps)." },
    { title: "explain", detail: "Always-runs closer: plain-language narrative of whatever artifacts exist on disk, for non-technical review." },
  ],
};

// #############################################################################
// ## INLINED MECHANICS (VERBATIM from experiments/pipeline-workflow/lib/).     ##
// ## "use strict", require(...) and module.exports are stripped; the function ##
// ## bodies are byte-for-byte identical so a reviewer can diff against lib/.   ##
// #############################################################################

// -----------------------------------------------------------------------------
// lib/stage-order.js  (I-1 terminality ; I-2 gating).
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
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// lib/gap-batching.js  (D-3 ; §9 crit 1).
//
// Gaps that share a TARGET STAGE merge into one (their params are merged);
// distinct target stages stay apart. This batches loopback requests so the
// movable cursor honors one widening per target rather than oscillating.
//
// Merge identity is the targetStage. (gapClass travels with the merged gap;
// the loop-limit guard keys on (gapClass, targetStage) separately.)
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// lib/loop-limit.js  (D-7 ; §9 crit 2).
//
// LOOP_LIMIT = 1 recovery per gap-class-per-stage. The guard counts honored
// loopbacks already recorded in the decision trail for a given (gapClass,
// targetStage) pair; once LOOP_LIMIT is reached, further recovery is refused
// (the run hard-stops with loop_limit_exhausted, D-5/crit 10). A DISTINCT
// (gapClass, stage) pair retains its own independent budget.
//
// This is pure accounting over the trail — no clock, no RNG (C-1).
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// lib/scope-set.js  — monotone (C-4 / I-4: scope only widens, never narrows).
//
// The scope is { startIdx, endIdx }. endIdx is FIXED (the explain terminal).
// startIdx is monotonically NON-INCREASING: a loopback whose target precedes
// the current start widens the scope (lowers startIdx); a target at or after
// the current start is NOT a narrowing and leaves startIdx unchanged.
//
// I-4 (i4_startidx_antitone): forall steps i<=j, startIdx j <= startIdx i.
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// lib/disprove-reserve.js  (C-3/C-5 ; I-5/I-6/I-7).
//
// Disprove policy (D-6):
//   - >=1 attempt per run (mandatory floor; budget reserved up front)        I-6
//   - >=2 perspective-diverse adversaries per attempt, dispatched in parallel I-7 / C-5
//   - never spends below the reserve                                          I-5 / C-3
//   - never attacks its own output                                           I-5 / C-3
//
// This module plans a SINGLE attempt deterministically (no RNG, no clock).
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// lib/termination-measure.js  — the well-founded lexicographic measure (I-3).
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
// -----------------------------------------------------------------------------

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

// -----------------------------------------------------------------------------
// lib/decision-trail.js  (D-5 ; §9 crit 11).
//
// Every control event — stage visit, cursor move, loopback, gap merge, disprove
// attempt, and halt — is appended to an auditable, typed trail. The trail is the
// run's side-effect of record; it is deterministic (C-1) and ordered.
//
// Each entry carries a non-empty string `kind`. Entries are plain data so two
// runs with different injected clock/RNG produce IDENTICAL trails (C-1).
// -----------------------------------------------------------------------------

/** Construct a fresh trail recorder. */
function createTrail() {
  const entries = [];
  return {
    /** Append a typed entry; returns it for convenience. */
    record(kind, fields = {}) {
      const entry = { kind, ...fields };
      entries.push(entry);
      return entry;
    },
    /** The accumulated entries (live array; treat as append-only). */
    get entries() {
      return entries;
    },
  };
}

// -----------------------------------------------------------------------------
// schemas/stage-digest.schema.js  (D-3: state via files, control via digest).
//
// Each pipeline stage returns a structured DIGEST. The orchestration substrate
// branches ONLY on these fields (C-2 / D-2 separation of authority) — it never
// inspects artifact CONTENT and never computes a logic verdict itself.
//
// A gap is { targetStage, gapClass, params } — the loopback request descriptor
// (D-4: backward motion only to honor a routed gap).
// -----------------------------------------------------------------------------

/** The allowed digest status values (agent-emitted). */
const DIGEST_STATUS = Object.freeze({ OK: "ok", HALT: "halt" });

/** The fields the substrate is permitted to branch on (C-2 allowlist). */
const ROUTABLE_FIELDS = Object.freeze([
  "status",
  "verdict",
  "gaps",
  "coreObligation",
  "reason",
]);

/**
 * The agent-emitted hard-stop reasons that terminate-and-report (D-5).
 * The substrate NEVER computes these; it only routes on the matching field.
 */
const HARD_STOP_REASONS = Object.freeze({
  CORE_OBLIGATION_REFUTED: "core_obligation_refuted",
  LOOP_LIMIT_EXHAUSTED: "loop_limit_exhausted",
  BUDGET_EXHAUSTED: "budget_exhausted",
});

/**
 * Validate the shape of a digest enough for the substrate to route it.
 * Returns true if the digest carries the routable fields in a usable form.
 * (Deliberately structural — it does NOT judge the verdict.)
 */
function isRoutableDigest(d) {
  return (
    d != null &&
    typeof d === "object" &&
    typeof d.status === "string" &&
    Array.isArray(d.gaps)
  );
}

// -----------------------------------------------------------------------------
// lib/digest-router.js  — movable cursor control flow (D-4 ; C-2 ; §9 crit 4).
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
// -----------------------------------------------------------------------------

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

// Constants the loop derives from the inlined mechanics.
const EXPLAIN_IDX = STAGE_SEQUENCE.indexOf("explain"); // 7
// Recovery keys: the loopback-eligible interior stages (D-7 substrate policy).
const RECOVERY_KEYS = ["model_obligations", "prove_invariants", "instantiate", "realize"];

// #############################################################################
// ## THE STAGE DIGEST SCHEMA the loop branches on (structurally enforced).    ##
// #############################################################################

// A real JSON Schema for the stage digest. The FINAL assembling/judging agent
// call in each stage is forced to return an object matching this, so the digest
// the loop routes on (status / gaps / verdict / coreObligation / reason) is
// structurally guaranteed to carry the routable fields (C-2 / D-3).
const STAGE_DIGEST_JSONSCHEMA = {
  type: "object",
  required: ["stage", "status", "gaps"],
  additionalProperties: false,
  properties: {
    stage: { type: "string" },
    artifact: { type: ["string", "null"], description: "reference to the thoughts/*.pl|*.md|*.lean state file (state via files)" },
    status: { type: "string", enum: ["ok", "halt"] },
    verdict: {
      type: ["string", "null"],
      description: "agent-emitted logic verdict signal or null; the substrate READS it, never derives it",
    },
    gaps: {
      type: "array",
      items: {
        type: "object",
        required: ["targetStage", "gapClass"],
        additionalProperties: false,
        properties: {
          targetStage: { type: "string", description: "the stage this gap loops back to (agent-tagged)" },
          gapClass: { type: "string", description: "the failure class keying the loop-limit budget" },
          params: { type: "object", additionalProperties: true },
        },
      },
    },
    coreObligation: { type: "boolean", description: "this stage carries a core obligation (D-5 hard-stop axis)" },
    reason: { type: ["string", "null"], description: "agent-emitted hard-stop reason on halt, else null" },
  },
};

// A reusable per-specialist result schema. Each specialist reports its own
// finding plus any failure signal it detected; the stage assembler folds these
// into the STAGE_DIGEST. Kept permissive on the payload (specialist outputs
// vary) but explicit on the failure/gap signal the assembler needs.
const SPECIALIST_RESULT_JSONSCHEMA = {
  type: "object",
  required: ["status", "routing"],
  additionalProperties: true,
  properties: {
    status: { type: "string", enum: ["ok", "failed", "abstained", "blocked"], description: "this specialist's own outcome — NOT the stage verdict" },
    routing: { type: "string", enum: ["advance", "gap", "halt"], description: "THIS specialist's routing RECOMMENDATION (the judgment the substrate honors MECHANICALLY): advance = my work is sound, proceed; gap = I found a RECOVERABLE upstream deficiency, loop back to fix it (set failureClass + upstreamStage); halt = I refuted a CORE obligation and no loopback can fix it, the run is terminal (set coreObligation + failureClass as the hard-stop reason). The substrate merges these; it never derives one from artifact content (C-2)." },
    finding: { type: ["string", "null"], description: "the specialist's plain finding / digest summary" },
    artifact: { type: ["string", "null"], description: "path the specialist wrote, if any" },
    failureClass: { type: ["string", "null"], description: "when routing=gap: the gapClass keying the loop-limit budget; when routing=halt: the hard-stop reason string" },
    upstreamStage: { type: ["string", "null"], description: "when routing=gap: the stage to loop back to (this stage for in-place repair, or an upstream stage)" },
    verdictSignal: { type: ["string", "null"], description: "an agent-emitted verdict word (provable/refuted/consistent/inconsistent/gap/unprovable/...) carried into digest.verdict; never derived by the substrate" },
    coreObligation: { type: "boolean", description: "true when routing=halt and this stage carries a core obligation this specialist found refuted" },
    fanoutList: { type: ["array", "null"], items: { type: "string" }, description: "PRODUCER FIELD: if a later specialist in THIS stage must process discrete items one-per-item (e.g. the Lean stubs you transcribed, the sub-hypotheses you decomposed, the tests you projected), return them here as short item identifiers so the stage fans out one agent per item. Else null." },
  },
};

// #############################################################################
// ## STAGE_BRIEFS — built from the extracted self-specs.                       ##
// ##                                                                            ##
// ## Source: the extraction workflow's `.result.specs` (per-stage role_brief + ##
// ## discipline_notes + min_context + ordering + fan-out). Each `brief` weaves  ##
// ## the spec's role_brief and discipline_notes into ONE outcome-neutral string.##
// ## BIAS-NEUTRALITY is PRESERVED VERBATIM — no steering toward provable /      ##
// ## refuted / pass / fail. Because the host has no effort / timeout knob, every ##
// ## lean-expert anti-`decide` / bounded-tactics / heartbeat-style discipline is ##
// ## written into the brief TEXT here.                                          ##
// #############################################################################

const STAGE_BRIEFS = {
  // ---- Stage 1 (ungated base case). serial: shared mutable existing-world.pl.
  close_world: {
    serial: true,
    digestFields: ["status", "coreObligation"],
    specialists: [
      {
        agentType: "shifting:agent-of-truth",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are extracting facts that are asserted in the source material under the Closed World Assumption. Survey the domain (entities, relationships, constraints, recurring patterns), pick domain-fitting predicates, and emit a validated Prolog KB to the target output path. Record what the source declares; do not infer what the user 'probably means' or what a reasonable system 'usually has'. Everything the source does not assert is, by CWA, false. Mark gaps via comments rather than papering over them with speculative facts. Precision matters more than completeness: omit a fact you are unsure of rather than assert one that may be wrong. The orchestrator has no preferred predicate set — only what the source asserts and what was named in predicate_schema_extension. Preserve the negation_provenance(absent | contradicts) distinction; do not collapse 'absent' into 'false'. Build incrementally: read 2-3 most relevant files first to establish vocabulary, then one file at a time, appending facts/relationship-rules/constraint-rules and confirming a clean strict-load after each.\n\nDISCIPLINE (bake these in — the Workflow model knob is a TIER only, no effort/timeout/heartbeat knob): Bias-isolation is mandatory and load-bearing — close-world has NO checker for over-claiming, so a too-optimistic KB is invisible without this structural defense. The KB must pass the strict-loading contract: swipl --on-warning=status --on-error=status, exit 0, empty stderr. Discovery via Glob then Grep; fall back to Bash find/rg only when dedicated tools cannot express the query. Use tabling for transitive closure over cyclic graphs; DCGs for structured-text parsing. Your reported tier-5 coverage is candidate evidence, NOT the run's verdict — coverage judgment against success_criteria stays with the orchestrator. If a required orchestrator parameter is missing, halt and report missing_required_parameter rather than guessing (this is a fork — there is no user to ask mid-run).",
        minContext: [
          "source_material (file paths or domain description supplied by the orchestrator)",
          "target output path (thoughts/existing-world.pl)",
          "predicate_schema_extension entries the orchestrator supplied for this run (if any)",
          "absolute path to the SWI-Prolog wiki (references/prolog-wiki/) for extension recipes",
          "the five-tier validation cascade contract the KB must pass before reporting done",
        ],
      },
      {
        agentType: "shifting:kb-validator",
        order: 2,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are a validation-cascade specialist. Take the .pl artifact path and a digest output path, run the five gated tiers in strict order, and write a JSON digest at the requested path. Tier 1 strict-load -> tier 2 referential integrity -> tier 3 constraint firing -> tier 4 spot-check sample -> tier 5 uncovered-predicate report. Tier N runs only if tier N-1 passed; report the highest tier reached. You validate and report — you do not synthesize facts, repair the file, suggest fixes, or opine on whether the coverage is acceptable. A FALSIFIED constraint or a type mismatch is surfaced, not judged. Return a brief confirmation (digest path + highest_tier_reached) and stop.\n\nDISCIPLINE (bake into the brief TEXT — this is the close-world analogue of lean-expert tactic discipline, a bounded, mechanical leaf specialist; the Workflow model knob is tier-only): FORBIDDEN — editing the .pl file under validation (pl_path is read-only, no Edit); reading the .pl file as TEXT (all validation goes through swipl — reading as text bypasses the parser); skipping halt-on-tier-fail (a tier-1 fail yields empty arrays for tiers 2-5 and highest_tier_reached:1 — do NOT run later tiers 'to give more info', the diagnostics are noise on an unloadable file); fact repair or fix-suggestion in the digest; spawning sub-agents (you are a leaf); opining on coverage thresholds (tier 5 is a flat list; acceptability is the orchestrator's call). If briefing is incomplete (no pl_path or no digest_path), write the digest with the error field naming the missing field and stop. If any tier fails beyond a clean load, report status: failed with failureClass naming the failing tier and upstreamStage close_world so the orchestrator (not you) routes the repair.",
        minContext: [
          "pl_path — the existing-world.pl artifact agent-of-truth just wrote (typically thoughts/existing-world.pl)",
          "digest_path — orchestrator scratch path for the JSON digest (e.g. thoughts/validation-digest.json)",
          "top_predicates (optional) — predicate names surveyed in step 1 plus any predicate_schema_extension entries; drives tier-4 sampling and tier-5 uncovered-report scope",
        ],
      },
    ],
  },

  // ---- Stage 2. serial: sharpener gates the decomposer; one shared hypothesis.pl.
  decompose: {
    serial: true,
    digestFields: ["status", "gaps", "reason"],
    specialists: [
      {
        agentType: "shifting:proposition-sharpener",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "Take the user's proposition verbatim and produce exactly ONE of two outcomes against the supplied existing-world KB vocabulary: (a) one declarative sentence that is falsifiable, scoped, and contestable, naming only entities and relations the KB actually enumerates; or (b) an abstention naming why it cannot be sharpened and the specific disambiguation the user must supply. There is no preferred outcome — a sharpened sentence and an honest abstention are equally valid returns. Do not paraphrase or 'interpret what the user really meant' before processing; do not invent a predicate to bridge a vocabulary gap; do not hedge ('probably', 'usually'); do not emit two competing sharpenings or a multi-clause sentence (two independent clauses is two claims, which is the decomposer's job, not yours). If the KB already trivially entails the sharpening, still return the strongest defendable single sentence but flag the triviality in the note field. Return the two-shape result (sharpened | abstained) and nothing else — no file writes, no narrative.\n\nDISCIPLINE: Single pass, single verdict — no iterative draft v1/v2/v3. NEVER read existing-world.pl as text: all KB inspection goes through swipl introspection (Read is allowed only for briefing material cited by path). No Write tool, no Agent tool — this is a leaf that returns to the caller. The discipline this enforces is falsifiability-refusal: abstaining when evidence does not support a sharpening is the whole point; a guessed sharpening launders uncertainty into the downstream pipeline that has no checker for it. (lean-expert decide/bounded-tactics discipline is N/A here — no Lean work in this leaf.)",
        minContext: [
          "raw_proposition_text (the user's proposition, verbatim — never paraphrased)",
          "existing_world_path (thoughts/existing-world.pl — the stage-1 carrier; inspected via swipl only)",
          "prolog_introspect_path (the introspect module path, for kb_summary/kb_describe)",
        ],
      },
      {
        agentType: "shifting:agent-of-questions",
        order: 2,
        fanout: true,
        fanoutOver:
          "one sub-hypothesis at a time (the counterfactual surface of each sub-hypothesis the decomposition produces); also ad-hoc Mathlib type-name lookups for formal_property Lean sketches",
        brief:
          "You are enumerating the counterfactual surface of ONE sub-hypothesis against the KB. Report every fact the KB contains that contradicts the sub-hypothesis; report an exhaustive search that returns empty as a positive finding (not a failure). Do NOT infer or assert facts the KB does not enumerate in order to make the sub-hypothesis 'work' — fabricating evidence is a foul, abstention on a sub-hypothesis is a valid outcome. Query both directions (for any positive claim, also search its negation), bind the domain before negating, and run a coverage check after your query set. Return per-sub-hypothesis: the queries you ran, the raw results, and the specific KB facts (if any) that contradict it. (You are hoisted to a direct orchestrator leaf because, under the depth-1 nesting cap, the hypothesis-decomposer leaf cannot itself spawn this sub-agent; the decomposer's evidence-gathering logic is realized by calling you and feeding the results back in.)\n\nDISCIPLINE: Minimum-necessary context is load-bearing — you will NOT be given the decomposer's decomposition rationale, the orchestrator's framing of the proposition's significance, or any downstream model-obligations/prove-invariants targets; orchestrator hopes about 'how cleanly' the proposition decomposes must not reach you. If context is insufficient, return 'underspecified' with a precise question. NEVER read .pl files with Read/cat/head — discover via swipl; never guess predicates/arities (run kb_summary first); never assume argument order (run kb_describe); never write Prolog files. Use tabling for transitive closure over potentially-cyclic graphs or the query loops forever. (lean-expert decide-discipline N/A — Mathlib lookups here are name-resolution only, not proof closure.)",
        minContext: [
          "existing_world_pl_path (the KB; queried via swipl, never read as text)",
          "ONE sub-hypothesis phrased as a counterfactual question (not the full decomposition rationale)",
          "prolog_introspect_path (the introspect module)",
          "refutation_shape_briefing (ONLY if the orchestrator supplied one)",
          "prolog-wiki path (passed only when a query needs an advanced extension — tabling for cyclic-graph closure, CLP, DCG)",
        ],
      },
      {
        agentType: "shifting:hypothesis-decomposer",
        order: 3,
        fanout: false,
        fanoutOver: null,
        brief:
          "Take the pinned one-sentence proposition (verbatim from the sharpener — do not re-sharpen or paraphrase) and run a single outcome-agnostic synthesis pass: decompose into falsifiable counterfactual sub-hypotheses, gather evidence per sub-hypothesis (from the agent-of-questions evidence handed to you), assign each claim EXACTLY ONE ontology label (descriptive | counterfactual | prescriptive) and, for every negated premise, EXACTLY ONE negation-provenance value (absent | contradicts), sketch formal_property/3 facts where a structural formalization exists, and emit a schema-validated thoughts/hypothesis.pl. There is no preferred outcome — a validated emission and an honest halt are equally valid. If a candidate claim could plausibly carry two labels and the evidence does not distinguish them, HALT with label_ambiguous (emit no file) rather than guess or silently split into two single-label claims. If a sub-hypothesis needs a predicate the KB does not enumerate, emit an upstream_gap/3 fact (missing_predicate or schema_insufficient) into the file — never coin a predicate. Validate the file loads under swipl with zero errors AND passes the schema checks before returning; emit nothing if validation fails. Return the fixed-shape digest (emitted: claim_count/label_counts/status_counts/provenance_counts/formal_property_count/coverage_percentage/open_assumptions, OR halted: halt_reason/halt_detail/what_orchestrator_should_clarify) — no prose recap, no opinion on which claims are most important or whether to proceed.\n\nDISCIPLINE: Single pass, single digest — if synthesis fails, HALT; do not retry (the orchestrator decides re-invocation). Halt-on-ambiguity is the central discipline and the bias-defense this stage exists to preserve: a guessed label or silent split launders uncertainty into model-obligations (no checker) and ultimately into Lean (which treats negated premises as logical falsity regardless of provenance). NEVER invent a fourth label or a compound label; the claim_label/2 domain is fixed at three values. NEVER read existing-world.pl as text (Read allowed only for the schema ref, ontology ref, and cited briefing material). On re-decomposition under a refutation_shape_briefing: AMEND the previous hypothesis.pl, do not regenerate, unless the proposition itself changed. CRITICAL formal_property discipline (this is where the lean-expert decide-lesson rides into this stage): default every formal_property/3 Lean sketch to quantified-invariant shape (forall a b, P a b -> Q a b) over enumerated conjunctions of pair facts — the enumerated form degrades to `decide` over a list at the prove-invariants/Lean stage and trips the closer's forbidden-tactics rule (the 20-minute decide hot-run lesson). Sketches name real Mathlib types (route lookups through the agent-of-questions evidence); a sorry-bodied quantified sketch is the correct starting point, not a closed proof. Your OWN spawning of agent-of-questions is suppressed under the depth-1 cap — that work is realized by the order-2 leaf and fed in via context.",
        minContext: [
          "sharpened_proposition (the sharpener's pinned sentence, verbatim)",
          "existing_world_pl_path (the KB; swipl introspection only)",
          "output_path (thoughts/hypothesis.pl, or orchestrator-overridden)",
          "schema_reference_path (references/pipeline-schema/hypothesis.md — read once at start; it wins over the agent body)",
          "ontology_reference_path (references/ontology.md — the three labels + two provenance values)",
          "prolog_introspect_path",
          "refutation_shape_briefing (ONLY if orchestrator supplied)",
          "artifact_versioning (ONLY if orchestrator supplied — the cf_v2_*/pr_v2_* namespace suffix)",
          "evidence results returned by the agent-of-questions leaf (order 2)",
        ],
      },
    ],
  },

  // ---- Stage 3. serial:false — prolog-prover carries it; agent-of-questions is an optional read-only aide.
  model_obligations: {
    serial: false,
    digestFields: ["status", "verdict", "gaps", "coreObligation", "reason"],
    specialists: [
      {
        agentType: "shifting:prolog-prover",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are deriving target-world consistency verdicts via counterexample search. Read thoughts/hypothesis.pl by querying its claim structure with swipl (do NOT parse markdown), follow its metadata pointer to the existing-world.pl substrate, and construct thoughts/target-world.pl by composing four operations on existing-world: (1) load every existing-world fact as baseline; (2) for each claim_label(Id, counterfactual), remove the corresponding fact and emit the per-fact negation_provenance(Fact, absent) or negation_provenance(Fact, contradicts) marker matching what hypothesis.pl recorded (the per-claim 3-arg claim_negation_provenance becomes the per-fact 2-arg form here); (3) for each claim_label(Id, prescriptive), assert the obligation fact with provenance(Fact, prescriptive); (4) for each claim_label(Id, descriptive), carry over from existing-world tagged provenance(Fact, descriptive). Copy every formal_property(Id, NL, Sketch) verbatim into target-world.pl (do not rename to property/2, do not strip the Lean sketch). Also emit cf_fact/N facts for the counterfactual list. Alongside, emit thoughts/target-world-shape.lean (one inductive enum per closed Prolog domain, one inductive Prop per predicate with one constructor per surviving ground fact, one parallel CF-augmented predicate per counterfactual claim, importing Ontology.Prelude); if there are no closed-domain predicates this ticket, skip that file and instead record emission_note(target_world_shape, omitted_no_closed_domains) in model_results.pl. For each formal_property, write a verdict directive that runs a falsification query and asserts verdict/2 plus counterexample/2 or gap_reason/2. A `consistent` verdict is earned ONLY after a genuine falsification attempt fails. If a property is genuinely `inconsistent`, stop and surface the counterexample exactly as found — do NOT patch the encoding to pass. If target-world lacks the deciding facts, that is a `gap` verdict with a gap_reason, and abstaining with a gap is a fully valid outcome. For each counterfactual feeding a property, run the load_bearing-vs-extraneous minimality check (re-introducing the cf fact must re-violate at least one property; otherwise it is extraneous). Emit all per-property verdict/2, counterexample/2, gap_reason/2, cf_status/2 facts into thoughts/model_results.pl. The orchestrator has no preferred verdict — report what counterexample search actually finds.\n\nDISCIPLINE (bake into the brief TEXT — Workflow model knob is a TIER only, no effort/timeout/heartbeat knobs, so all discipline rides in prose): (1) MANDATORY tabling (:- table pred/arity.) on every transitive-closure / recursive-reach helper — without it a cyclic depends_on graph loops forever; this is the prolog-prover analog of the lean-expert forbid-`decide` hot-run lesson. (2) STRICT-LOADING gate is a hard gate: the proof file must exit 0 under swipl --on-warning=status --on-error=status; a singleton variable in a violates_property/1 rule means the rule matches nothing, yields an empty counterexample set, and produces a FALSE 'verified' — the worst failure mode you can produce; treat references/prolog-wiki/practices/strict-loading.md as binding. (3) Bound-before-negate: never use \\+ on unbound variables — collect the domain with findall first, then filter. (4) Namespace-isolate helper predicates by prefixing with the property id to avoid cross-property collisions; shared helpers go in one top section. (5) Bounded correction budget per property: 5 inner corrections (same approach), then 3 outer iterations (fundamentally different encoding strategy), 15 total max — then stop and surface a gap rather than thrash. (6) Coverage gate: measure coverage per verdict; <30% with relevant predicates at 0% means target-world is too sparse to decide — record `gap` with a gap_reason, never silently `consistent`. (7) Verify the encoding captures the intended meaning and is not a vacuously-true weakening before declaring any verdict. If a property is inconsistent or hits a gap or an extraneous counterfactual, surface it as a finding with the verdict word and an upstreamStage of decompose; the orchestrator routes the loopback, you never self-invoke decompose.",
        minContext: [
          "thoughts/hypothesis.pl (carrier; transitively points at existing-world.pl)",
          "existing-world.pl path (followed from hypothesis.pl metadata or argument hint)",
          "target output paths: thoughts/target-world.pl, thoughts/target-world-shape.lean, thoughts/model_results.pl",
          "per-property correction budget: 5 inner / 3 outer / 15 total",
          "orchestrator-supplied refutation_shape_briefing (only if present)",
          "negation_provenance propagation rule: absent vs contradicts; CWA-absent != Lean-disproved",
          "absolute path to the Prolog wiki references/prolog-wiki/ and the shared ${PROLOG} dir",
        ],
      },
      {
        agentType: "shifting:agent-of-questions",
        order: 2,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are running standalone intermediate introspection queries against the in-progress Prolog substrate — spot-checking a helper predicate's behavior, inspecting the existing-world or target-world KB schema mid-construction, or enumerating a predicate's facts in both directions. Discover structure only through swipl (kb_summary / kb_describe / kb_stats / kb_graph from the introspect module); never read .pl files as text, never guess predicate names or argument positions. For any positive finding also search its negation and report an exhaustive empty result as a positive finding. Return a small structured digest of fact tuples / counts, not raw stdout dumps. You are not deriving the stage's verdicts and you have no preferred answer — report exactly what the KB says, including 'no solutions' as a real result.\n\nDISCIPLINE (bake into the brief TEXT — model knob is a TIER only): same bias-isolation discipline as prolog-prover, outcome-neutral, no steering toward any verdict. Query-mechanism discipline (the agent-of-questions analog of bounded tactics): pick the right swipl mechanism ONCE at the top of the query rather than fighting depth-first search — use tabling for transitive closure over any potentially-cyclic graph (otherwise the query loops forever, the direct analog of an unbounded hot-run), bound-before-negate (\\+ on unbound vars gives wrong answers), and findall+sort for unique values (setof fails on no solutions). Read-only introspection role: never write .pl files. You are OPTIONAL — invoked only for mid-construction spot-checks; the prolog-prover (order 1) carries the stage.",
        minContext: [
          "the specific predicate name + arity or schema question to introspect",
          "the .pl file path(s) to consult (existing-world.pl and/or the in-progress target-world.pl)",
          "the shared ${PROLOG} introspect-module dir path",
          "absolute path to references/prolog-wiki/ for picking the right query mechanism",
        ],
      },
    ],
  },

  // ---- Stage 4. serial:false — producer/consumer (spec-writer THEN per-stub lean-expert fan-out).
  prove_invariants: {
    serial: false,
    digestFields: ["status", "verdict", "gaps", "reason"],
    specialists: [
      {
        agentType: "shifting:lean-spec-writer",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "Transcribe each formal_property/3 row in target-world.pl into exactly one Lean4 theorem stub whose proof body is `by sorry`, carrying the @[ontology <label>] attribute read off claim_label/2 and a /- provenance(absent | contradicts) -/ docstring read off negation_provenance/2 for any counterfactually-removed fact the theorem mentions. Read target-world-shape.lean for the inductive vocabulary the stubs may reference; do not invent inductive declarations. Per property, return exactly one of three outcomes: stub emitted (type-checks under lake build), open_domain_shape halt (the property's domain is String / List String / open identifier and no matching inductive enum exists upstream), or type_error (the stub does not type-check). Determine the stub-or-halt outcome on its own terms; do not bias toward emitting stubs. Read values off the facts; do not infer the ontology label or provenance from the statement shape. Return the partitioning digest (stubs_emitted / open_domain_halts / type_errors + counts, including each emitted stub's path) as the entire return surface.\n\nDISCIPLINE (reasoning is structural translation, not search; the model knob is tier-only so paste the hard rules): proof body is exactly `by sorry` — replacing sorry with decide/rfl/cases/intro/exact? is a forbidden closing move (closing belongs to lean-expert); NO string-typed approximations — if the inductive lift is missing, halt with open_domain_shape rather than ranging a theorem over String/List String; NO speculative imports (no `import Mathlib` umbrella, only Ontology.Prelude plus the module exposing target-world-shape.lean); one theorem per file, no helper lemmas; inspect target-world.pl only via swipl introspection, never as text; you are a leaf agent (no Agent tool, no delegation). Bias toward flagging the open-domain halt: a flagged legitimate use is recoverable, a missed open-domain stub burns an opus budget downstream. If you emit open_domain_halts or type_errors, report them as a finding with upstreamStage model_obligations — the orchestrator routes, you do not.",
        minContext: [
          "thoughts/target-world.pl",
          "thoughts/target-world-shape.lean",
          "output_dir = thoughts/lean/Proofs/",
          "lean_project_root = thoughts/lean/",
        ],
      },
      {
        agentType: "shifting:lean-expert",
        order: 2,
        fanout: true,
        fanoutOver: "each stub in the spec-writer digest's stubs_emitted list (one closing invocation per stub)",
        brief:
          "You are verifying or refuting one universal property against target-world.pl. The stub at the given path already carries its theorem statement, @[ontology ...] attribute, and `by sorry` placeholder — your job is the proof body, not the statement. A theorem proves only what the Lean kernel accepts. Treat lake build as your reasoning tool: write one tactic, build, read the goal state, choose the next tactic from the compiler output. Select the proof shape from the stub's ontology label (counterfactual becomes a sufficiency theorem plus one necessity lemma per negated-premise fact — do not collapse them; descriptive becomes a single cases-closed theorem; prescriptive becomes witnessed constructors). If you cannot close it within the correction budget, halt and emit theorem_verdict(Id, unprovable) with the diagnostic and whether the property appears genuinely false or merely hard. Do not weaken or rewrite the theorem statement to make it pass; if the statement itself looks malformed or vacuous, halt and report rather than editing it. Abstention is a valid verdict — a wrong claim of provability is worse than honest failure. Preserve partial results (proven sub-lemmas remain valuable). Emit results as Prolog facts to thoughts/lean_proof_results.pl with a provenance_annotation/3 for every theorem carrying a negated premise.\n\nDISCIPLINE (reasoning effort would be xhigh; on the Workflow tool this rides as a model TIER only — there is NO effort knob and NO maxHeartbeats/timeout knob — so the discipline is here in prose and the ONLY available bounds are the textual 15-attempt budget plus the forbidden-tactics halt; state BOTH explicitly to yourself before you start). FORBIDDEN-TACTICS RULE (the 20-minute decide hot-run lesson): in any theorem whose hypotheses or goal mention a target-world predicate, `decide` / `native_decide` / `generalize` (used to abstract concrete-string indices) are FORBIDDEN as the closing move — halt and report upstream-encoding-failure (escalate to model_obligations), do NOT hunt for a different tactic that gets the proof through. Carve-outs that stay legitimate: decide on plain Nat arithmetic, decide discharging a Decidable instance, decide on small literals with no target-world predicate, decide/native_decide as an INTERNAL step (cases h <;> decide) when the residual goal is genuinely decidable arithmetic. BOUNDED TACTICS / CORRECTION BUDGET: 5 inner corrections (fix-and-retry, same approach) x 3 outer iterations (fundamentally different approach) = 15 attempts max per property, then abstain. Prefer narrowest Mathlib imports (every import must justify itself with a named lemma/tactic; no `import Mathlib` umbrella). Run the post-emit grep self-check: grep -n -E '(decide|native_decide|generalize)' Proofs/*.lean and inspect each hit. Stop writing tactics after any error; fix in priority order syntax -> type -> unsolved-goals -> linter. You will NOT be given hypothesis prose, orchestrator commentary on what 'should' be provable, or downstream instantiate/realize targets — if context is insufficient, return 'underspecified' with a precise question. On unprovable, report the verdict word and an upstreamStage (model_obligations for an encoding fault, decompose for an unresolvable negation-provenance) as a finding — the orchestrator routes the loopback.",
        minContext: [
          "the single stub path thoughts/lean/Proofs/<claim_id>.lean (one per invocation)",
          "thoughts/target-world.pl (facts + ontology labels the proof reasons over)",
          "thoughts/target-world-shape.lean path (if emitted)",
          "lean_project_root = thoughts/lean/",
          "Mathlib clone ~/.lean/mathlib4",
          "Mathlib wiki path <plugin>/references/lean4-wiki/",
          "methodology pointer prove-invariants/references/lean-proof-method.md",
          "orchestrator-supplied refutation_shape_briefing if present",
        ],
      },
    ],
  },

  // ---- Stage 5 (boundary lean -> tdd). serial:false — both read-only Prolog query/projection helpers.
  instantiate: {
    serial: false,
    digestFields: ["status", "gaps"],
    specialists: [
      {
        agentType: "shifting:agent-of-questions",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are projecting universal proofs onto specific fixtures, or recording behavioral claims the proofs could not state. Discover the predicate surface of the supplied Prolog carrier through swipl introspection (kb_summary / kb_describe / kb_stats) — never by reading the .pl files as text — and return a structured digest of the predicates, arities, and the facts the extraction checklist names. A property that cannot be projected onto any fixture in the target codebase is an unfixturable_property upstream gap, not a malformed test — surface it as a finding and move on. Do not invent fixtures to make a property 'work.' Report what the carrier says, in both directions (what holds and what is absent); do not characterize any result as a success or failure of the run.\n\nDISCIPLINE (query-only Prolog specialist; the model knob is tier-only, no effort/timeout knob): forbid reading .pl files as text (Read/cat/head) — all discovery via `swipl -g`; forbid guessing predicates or arities (run kb_summary first); forbid assuming argument order (run kb_describe first); bound the domain before negating (\\+ with unbound vars gives wrong answers). Paste into your working rules: wrap any ad-hoc query in `timeout 30`, and pick the right swipl mechanism (tabling for transitive closure over cyclic graphs, bound-before-negate) ONCE at the top rather than fighting depth-first search. You will NOT be given hypothesis prose, downstream realize targets, or the orchestrator's framing of why a proof matters. Surface any unfixturable_property as a finding with upstreamStage prove_invariants.",
        minContext: [
          "thoughts/lean_proof_results.pl (the stage-5 carrier)",
          "thoughts/lean/Proofs/*.lean and any .pl paths transitively cited via the carrier's theorem_source/2 and provenance_annotation/3 records",
          "the Step-1 extraction checklist (predicates to surface: theorem_verdict/2, proof_strategy/2, formal_property/3, theorem_source/2, necessity_lemma_status/3, provenance_annotation/3, cwa_check/3, lean_skipped/2, claim_label/2)",
          "the orchestrator-supplied refutation_shape_briefing digest field, only if present",
        ],
      },
      {
        agentType: "shifting:pl-fact-extractor",
        order: 2,
        fanout: false,
        fanoutOver: null,
        brief:
          "Project, don't discover; project, don't synthesize. You are given a list of .pl paths and a pinned fact_spec (predicate/arity list) already known to the caller. Load each path via swipl, run one findall projection per fact_spec entry, and return the combined JSON digest {facts:[...], counts:{...}} of the matched tuples. Do not interpret, validate, repair, or suggest additional predicates. A predicate absent at the requested arity is reported missing:true / count:0 — do not search for a near-match arity and do not flag the file as malformed. 'No facts found' is a valid, complete answer; how the caller reads it is the caller's call, not yours.\n\nDISCIPLINE (read-only leaf projection agent; tools Bash, Read only — no Write, no Agent, cannot spawn sub-agents, which satisfies the depth-1 nesting cap; mechanical, low reasoning effort, a low/standard model TIER suffices): forbid reading the artifact .pl as text (all projection via swipl, Read is only for briefing material referenced by path); forbid fact-shape inference (return missing:true rather than projecting the wrong arity); forbid follow-up/iterative queries (single pass — the caller re-invokes with a new fact_spec if more is needed). You will be given only the pinned fact list and paths, not hypothesis text or orchestrator framing.",
        minContext: [
          "pl_paths = thoughts/lean_proof_results.pl plus the paths transitively cited via its theorem_source/2 and provenance_annotation/3 records",
          "fact_spec = the pinned predicate/arity entries from the Step-1 extraction checklist (theorem_verdict/2, proof_strategy/2, formal_property/3, theorem_source/2, necessity_lemma_status/3, provenance_annotation/3, cwa_check/3, lean_skipped/2, claim_label/2)",
          "output_format = json",
        ],
      },
    ],
  },

  // ---- Stage 6. serial:true MANDATORY — D-9 shared mutable source under target_codebase_dir.
  realize: {
    serial: true,
    digestFields: ["status", "reason"],
    specialists: [
      {
        agentType: "shifting:realize-counterfactual-scanner",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "Locate or recheck; report findings as facts. In `initial` mode, build the counterfactual locator table: one row per counterfactual claim, with the file:line locations where the forbidden fact currently materializes (or mark ALREADY_ABSENT if zero matches). In `recheck` mode (Stage 3d), re-grep the ENTIRE target tree (not just touched files) for each claim's signatures and report removed / reintroduced / unchanged deltas. Report locations as facts; do not decide whether any re-introduction is acceptable — that is the orchestrator's call. Skip entirely if hypothesis.pl does not exist (behavioral-only test file).\n\nDISCIPLINE (read-only detection agent; never edits source or Prolog): Query hypothesis.pl via swipl, never by reading the .pl directly. Use ripgrep with --hidden and --no-ignore; never trust a single grep run. Assume each claim has SEVERAL search signatures, not one (an `import logging` claim is also re-introduced by `from logging import warn` or a requirements.txt entry). Prefer over-reporting candidate locations to under-reporting. In recheck mode, never overwrite the initial locator — write a dated recheck file. No model-tier/effort/timeout knob applies to detection; bound the work by signature list, not by clock.",
        minContext: [
          "mode (initial|recheck)",
          "thoughts/hypothesis.pl",
          "target_codebase_dir",
          "thoughts/.realize_scratch/ (scratch_dir)",
          "prior_locator_path (recheck only): thoughts/.realize_scratch/counterfactual_locator.json",
          "touched_files (recheck only): list from the refactor pass",
        ],
      },
      {
        agentType: "general-purpose",
        order: 2,
        fanout: false,
        fanoutOver: null,
        // NOTE: there is no `Explore` agentType to select; the read-only survey-only
        // role is realized as a general-purpose agent with the read-only discipline
        // baked into the brief text (per the spec's option-B wiring note).
        brief:
          "Survey what exists; do not propose changes. (This is the Explore role, run as a read-only general-purpose survey.) Produce a structured survey.md covering code layout, existing modules, the EXACT project commands (test / type-check / lint invocations), adjacent constraints, test-runner notes, and any behavioral-contract infrastructure (test doubles, clock injection, integration harness, retry mocks). Read-only — report what is there; do not recommend edits. You will be reused later (Stage 3a) to find refactor smells, and (Stage 4) for read-only loopback failure classification, both under the same survey-only, no-edit framing.\n\nDISCIPLINE (Explore-equivalent; strictly read-only): you must NOT edit source or test files while surveying or while finding smells. Output is survey.md only. The survey-section header contract is fixed (reference: skill's references/stage0-survey.md). Pick the relevant slice; your product feeds the briefer's per-test codebase-map slice, so completeness of project commands and module map is load-bearing. No effort/timeout knob — scope the survey to the test file's surface, do not boil the ocean.",
        minContext: [
          "target_codebase_dir",
          "thoughts/.realize_scratch/ (scratch_dir; writes survey.md here)",
          "thoughts/tests/ (the test file + manifest, to scope the survey)",
        ],
      },
      {
        agentType: "shifting:realize-test-briefer",
        order: 3,
        fanout: false,
        fanoutOver: null,
        brief:
          "Assemble a self-contained briefing for ONE test; halt with status: blocked rather than guess at routing. Take exactly one skipped test, resolve which upstream .pl files it cites via the manifest's descends_from/2 rows, query those files for the verbatim property/claim text and the cited claim's claim_label (and negation_provenance if counterfactual), and write a single self-contained briefing markdown file. Determine briefing_shape from the routing table strictly: projection+descriptive/prescriptive -> addition; projection+counterfactual -> removal; behavioral_claim -> behavioral. Return briefing_path, briefing_shape, test_category, claim_label, negation_provenance, notes. Run in TWO passes: first before unskip (routing, failure block empty), second after the failing run (re-brief only the failure_output_path so the briefing carries the real failure verbatim).\n\nDISCIPLINE (read-only against the codebase; writes ONLY inside scratch_dir/briefings/): Never edit source, test files, or Prolog. Query the manifest and hypothesis.pl via swipl — if manifest_path is missing, fails to load, or has no descends_from/2 row for this test's basename, return status: blocked (a producer-side contract violation, a Stage-4 loopback signal — do NOT synthesize a manifest). NEVER paraphrase property or claim text — copy verbatim from swipl output (paraphrasing is how downstream proofs get silently weakened). NEVER guess a claim_label: if a projection test resolves no claim_label, halt and report — do not default to addition. Never write a behavioral briefing for a projection test or vice versa; the routing table is binding. Briefings MUST be fully self-contained (the implementation agent sees neither this conversation nor the survey/Prolog files) but must inline only the relevant slice, never the whole survey or whole .pl file. If you return blocked, set upstreamStage instantiate so the orchestrator routes.",
        minContext: [
          "test_file (path to the generated suite)",
          "test_name (exact name of the one target test)",
          "thoughts/tests/manifest.pl (manifest_path — authoritative descends_from/2 carrier)",
          "thoughts/.realize_scratch/survey.md (survey_path)",
          "thoughts/.realize_scratch/counterfactual_locator.json (counterfactual_locator_path)",
          "thoughts/.realize_scratch/ (scratch_dir; writes the briefing here)",
          "failure_output_path (second pass only): thoughts/.realize_scratch/runs/<run_id>.failure.txt",
          "target_codebase_dir",
        ],
      },
      {
        agentType: "shifting:realize-suite-runner",
        order: 4,
        fanout: false,
        fanoutOver: null,
        brief:
          "Run and digest; the digest is the verdict, not your summary. In `baseline` mode (Stage 1), record the green/red/skipped sets of the full suite before any unskip and persist baseline.json. In `verify` mode (Stages 2c pre-impl, 2e post-impl, 3c/3d refactor), re-run the full suite, then compute targeted_outcome (pass/fail/not_found for the targeted_test), regressions (baseline-green now red, excluding pre_existing_failures), and new_passes; emit a small structured digest JSON plus a capped targeted_failure_excerpt. Return only the small digest values; the orchestrator decides routing from them.\n\nDISCIPLINE (run-and-report only; never edits source or test files — skip-toggling is the orchestrator's job — and never edits a written baseline): A regression is the SINGLE definition: green-in-baseline AND red-now; tests red in both runs are not regressions. Never decide whether a regression is acceptable — report; the orchestrator routes. Never return the full test log inline (that is the context bloat you exist to prevent) — return the digest, the log path suffices. Never paraphrase a failure summary — copy the runner's own one-line summary verbatim; stack traces are log excerpts, not paraphrases. Cap targeted_failure_excerpt at 60 lines (first 30 + last 10 for long traces). No effort/timeout knob — but you OWN the verdict: the orchestrator must never trust the implementation agent's self-reported pass, only your digest.",
        minContext: [
          "mode (baseline|verify)",
          "test_command (the EXACT command from the survey)",
          "target_codebase_dir (cwd for test_command)",
          "thoughts/.realize_scratch/ (scratch_dir)",
          "thoughts/.realize_scratch/baseline.json (baseline_path; written in baseline, read in verify)",
          "targeted_test (verify only): the test expected to flip red->green",
          "run_id (verify only): e.g. 2c-NNN-slug / 2e-NNN-slug / 3c-refactor-group",
          "pre_existing_failures (verify only): list of baseline-red names that do NOT count as regressions",
        ],
      },
      {
        agentType: "general-purpose",
        order: 5,
        fanout: false,
        fanoutOver: null,
        // NOTE: the implementation/refactor agent maps to general-purpose; the
        // edit-vs-read-only distinction (this one EDITS; order-2 does not) is baked
        // into the brief text since there is no dedicated agentType for it.
        brief:
          "The briefing is the spec; halt if you cannot satisfy it without weakening a test. Read the handed-over briefing path (fully self-contained: property text, cited claim, verbatim failure output, relevant codebase-map slice, exact project commands, and the rules block for its shape — addition / removal / behavioral). Implement the change it describes. Run the full test suite and the type check yourself before returning, and report what you ran and what passed. On the retry brief, re-read the same briefing plus the prior attempt's digest, see the still-red test and any named regressions, and adjust — same rules, no looser assertions. You also serve the Stage 3b refactor-execution role: execute the smells Explore proposed (or a reasoned subset), holding the invariant that every generated and pre-existing test stays green and every proven property still holds; run the suite yourself and return.\n\nDISCIPLINE (the lean-expert discipline applied analogically — there is no Lean here, but the dominant failure modes are encoded as the analog of forbidden-`decide` / bounded-tactics; the model knob is tier-only so all of this is in prose): You will NOT receive hypothesis prose, downstream measure-entailment hopes, or any commentary on whether the test 'matters' to the user — only the briefing path + scratch paths + orchestrator parameters. You MUST NOT weaken tests, delete assertions, or loosen assertions on retry — halt instead. REMOVAL briefings are DELETION work — adding code in response to a removal briefing is a FAILED attempt even if the test passes (LLM implementors bias toward adding code; resist it). No shims / re-exports to fake a deletion. Any change bigger than one function's internals must go through an Explore (survey-only) pass first. Your self-reported 'it passed' is NEVER the verdict — the suite-runner digest is; expect independent re-verification. Two failed attempts on one test = stop (the orchestrator routes to a Stage 4 loopback), never a third looser attempt. Bound effort by the briefing scope; no clock/effort knob is available, so keep edits minimal and shape-faithful.",
        minContext: [
          "briefing_path (the self-contained per-test briefing from the briefer)",
          "digest_path (retry / Stage 2f only): the prior attempt's digest JSON",
          "Explore findings + touched-files list (Stage 3b refactor role only)",
          "the orchestrator-supplied parameters: refutation_shape_briefing, halt_condition, success_criteria",
        ],
      },
      {
        agentType: "shifting:regression-bisector",
        order: 6,
        fanout: false,
        fanoutOver: null,
        brief:
          "Attribute blame, never patch. When a verify pass reports regressions > 0, join the suite-runner's regression list to the supplied git diff window: for each regressed test, derive its traceable code surface and score each diff-window file as high (direct import/exercise), medium (one-hop transitive), or low (same package, no direct trace) confidence. Emit one NDJSON row per regression with ranked suspect files (or an explicit empty `suspects: []` with reason 'no traceable intersection'), then a structured summary. The orchestrator decides revert vs delete-hunk vs loopback; you only rank.\n\nDISCIPLINE (read-only; tools Bash, Read — no Write/Edit): never modify a file, never run the test suite (you consume the runner's existing digest — regenerating risks a divergent regression set), never apply a fix or revert a hunk, never spawn sub-agents (you are a leaf). Never infer the diff range — the orchestrator owns the window; halt if git_diff_range is missing. Confidence is MECHANICAL (intersection tightness), not a hunch about causality; use exactly the three bands {high, medium, low} — never a fourth. Never pad the suspect list: empty is a valid, honest answer (cause lies outside the diff). Cap suspects per regression at 10 with a truncated note. Copy the failure summary verbatim from the digest; never re-interpret it. Order rows lexicographically by regression name for stable repeat runs. No effort/timeout knob; bound by the diff window and regression count.",
        minContext: [
          "thoughts/.realize_scratch/baseline.json (baseline_digest_path)",
          "thoughts/.realize_scratch/runs/<run_id>.digest.json (current_digest_path; its regressions array must be non-empty)",
          "git_diff_range (orchestrator-chosen window, e.g. pre-refactor-ref..HEAD)",
          "target_codebase_dir (repo root where git diff runs)",
          "thoughts/.realize_scratch/ (scratch_dir; used only to locate digests — writes nothing)",
        ],
      },
    ],
  },

  // ---- Stage 7 (TERMINAL). serial:true — shared mutable adherence_facts.pl (D-9 analog).
  measure: {
    serial: true,
    digestFields: ["status", "verdict", "gaps", "reason"],
    specialists: [
      {
        agentType: "shifting:agent-of-truth",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are extracting what each resource asserts, as structured Prolog facts wrapped in asserts/2 (one claim per fact, ground terms only). Use the same predicate name across resources ONLY when the claims are structurally the same; do not paper over differences by collapsing distinct claims into one predicate, and do not force a shared predicate where the claims genuinely differ. Report asserts/2 rows as facts. A low adherence score is a valid result; the orchestrator has no preferred score and no checker for under-extraction or over-aligned predicate naming, so neither inflate nor suppress overlap. Be briefed on ALL resource paths at once so predicate names line up across resources where the claims warrant it. Write all extracted facts to thoughts/adherence_facts.pl, grouped by resource id with header comments, and validate that the file loads cleanly under swipl before returning.\n\nDISCIPLINE (bias-isolation; you are opus/high-effort and on the tier-only knob the highest tier is set): open with the verbatim role-frame above; you will be given minimum-necessary context only (resource paths, prime, success_criteria, hypothesis.pl path) and NO orchestrator commentary or framing of why the adherence check matters. Predicate-naming is the single biggest source of false gaps/contradictions: brief all resources together so you pick aligned predicates, but do NOT collapse genuinely distinct claims. Validation discipline: the asserts/2 facts file MUST pass a clean swipl load before you return.",
        minContext: [
          "all resource paths to compare (the implemented codebase under target_codebase_dir + thoughts/implementation_log.md in pipeline-terminal mode; the supplied resource files in stand-alone mode)",
          "the --prime designation (or 'none')",
          "orchestrator-supplied success_criteria if present",
          "thoughts/hypothesis.pl path (pipeline-terminal mode only — for cross-vocabulary alignment of the impl side against the hypothesis ontology)",
          "thoughts/existing-world.pl path if descriptive-drift checking is wanted (supplementary; emit its facts under a stable resource id such as 'existing')",
          "absolute path to the SWI-Prolog wiki (references/prolog-wiki/) for advanced-extension lookups",
          "output path thoughts/adherence_facts.pl",
        ],
      },
      {
        agentType: "shifting:agent-of-questions",
        order: 2,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are running adherence queries over a facts file someone else extracted; you query, you do not extract or interpret. Introspect thoughts/adherence_facts.pl, then run the structural adherence queries against it: adherence_report/1 when a prime is designated, symmetric_report/0 when there is no prime, plus find_contradictions/1 and universal_claim/1. Report the shared claims, gaps (claims in prime absent from a resource), contradictions, extensions, and per-resource claim counts as a structured digest — these are the inputs the scoring step needs. A low adherence score, many gaps, or several contradictions are all valid results; there is no preferred outcome. In pipeline-terminal mode (when thoughts/hypothesis.pl is supplied) also consult hypothesis.pl into the same swipl session and run the label-aware pass — call label_aware_report/ImplResource and label_aware_facts_out/2, and report the five counts (counterfactual_violations, counterfactual_honored, prescriptive_unfulfilled, prescriptive_fulfilled, prescriptive_negation_violations) plus the full lists for any non-empty violation/unfulfilled category.\n\nDISCIPLINE (bias-isolation; you are sonnet/high-effort, a read-only query leaf — no Agent tool, no sub-spawning): open with an outcome-neutral role-frame (you query, you report; a low score is a valid result; orchestrator has no preferred score) and you will be given minimum-necessary context only (facts-file path, resource IDs, prime, hypothesis.pl path) — no orchestrator commentary. swipl discipline: load the adherence module with use_module(adherence.pl, except([claim/2, claim/3])) when hypothesis.pl will be consulted in the same session, to avoid the 'Local definition overrides weak import' warning contaminating output; bound-before-negate on any \\+ query; findall+sort (not setof) for unique values; wrap ad-hoc queries with timeout. You DEPEND on order-1 output (the shared file thoughts/adherence_facts.pl) — you run after agent-of-truth.",
        minContext: [
          "thoughts/adherence_facts.pl path (the carrier produced by agent-of-truth at order 1)",
          "the list of resource IDs present in the facts file",
          "the --prime designation (or 'none')",
          "thoughts/hypothesis.pl path (pipeline-terminal mode only, for the label-aware verdict pass)",
          "absolute path to the bundled adherence module (PROLOG/adherence.pl) so use_module sees adherence_report/1, symmetric_report/0, find_contradictions/1, universal_claim/1, and the label-aware predicates",
          "absolute path to the SWI-Prolog wiki (references/prolog-wiki/) for advanced-extension lookups",
        ],
      },
      {
        agentType: "shifting:verdict-extractor",
        order: 3,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are a fixed-query verdict-row extraction specialist (pipeline-terminal mode only — skip entirely in stand-alone mode where no hypothesis.pl exists). Load the adherence module together with thoughts/adherence_facts.pl and thoughts/hypothesis.pl, then run exactly the FIVE fixed label-aware queries and return their rows as a JSON digest: counterfactual_violations/2 (Pattern 3), counterfactual_honored/2, prescriptive_unfulfilled/2, prescriptive_negation_violations/2, and descriptive_drift/3. You do not interpret, score, or opine on whether a non-zero count is acceptable — you extract. Every one of the five rows is present in the digest every time: an empty result is count:0, entries:[] (never omitted); a row whose optional input was not supplied is skipped:true with a reason; the count/entries fields still appear. Do not invent a sixth verdict, do not collapse rows, do not classify results as good or bad. Both KBs are read-only; you do not append result/N facts back into adherence_facts.pl.\n\nDISCIPLINE (fixed-query discipline — the analog of lean-expert's bounded-tactics rule; you are sonnet/low-effort, mechanical): the five queries are FIXED by contract — counterfactual_violations/2, counterfactual_honored/2, prescriptive_unfulfilled/2, prescriptive_negation_violations/2, descriptive_drift/3 — inventing a sixth verdict is forbidden and you must halt with error rather than run a 'bonus' query. Mandatory swipl detail: load the adherence module with use_module(adherence.pl, except([claim/2, claim/3])) or the user-module claim/2 from hypothesis.pl triggers a warning that contaminates the JSON. Run each query in its own swipl invocation against the same load preamble so one query's failure does not poison the others. Read-only leaf: tools Bash/Read/Write only (Write surface is the digest_path ONLY), no Agent tool, no sub-spawning, no result/N append (that side-effect belongs to the orchestrator's label_aware_facts_out/2 call, not you). You DEPEND on the order-1 facts file + order-2 having run.",
        minContext: [
          "adherence_facts_path = thoughts/adherence_facts.pl",
          "hypothesis_path = thoughts/hypothesis.pl",
          "existing_world_path = thoughts/existing-world.pl if present (else omit; descriptive-drift row is then skipped)",
          "impl_resource_id (the implementation-side resource id in the facts file, typically 'impl')",
          "existing_resource_id (the existing-world resource id, typically 'existing'; must match what agent-of-truth emitted)",
          "prolog_module_path = absolute path to PROLOG/adherence.pl",
          "digest_path = a chosen path under thoughts/ for the JSON verdict digest",
        ],
      },
      {
        agentType: "shifting:pl-fact-extractor",
        order: 4,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are a read-only Prolog projection specialist: project named facts into a JSON digest, do not discover, interpret, or synthesize. Pre-load the bundled adherence module (its absolute path is in the brief) and consult thoughts/adherence_facts.pl, then project the two named predicates the caller has specified — universal_claim/1 and find_contradictions/1 — returning {facts:[...], counts:{...}} via writeq-serialized rows. A predicate that does not exist at the requested arity is reported missing:true with count:0; do not search for a near-match arity, do not suggest other predicates, do not repair the file. One pass, no follow-ups.\n\nDISCIPLINE (projection-not-discovery — analog of the fixed-query lesson; you are sonnet/low-effort, mechanical): the predicates and arities are already known (universal_claim/1, find_contradictions/1) — project exactly these and report missing:true rather than fall back to discovery. swipl-only access: never read the .pl as text (atom-quoting/operator-precedence bug class); all projection via swipl findall + writeq. Read-only leaf: tools Bash/Read only, NO Write surface (digest returned inline), no Agent tool, no sub-spawning. You are a supplementary projection over order-1's facts file; you run after agent-of-truth. OPTIONAL — the orchestrator may drop you if the structural digest from agent-of-questions at order 2 already supplied the universal-claim and contradiction tuples.",
        minContext: [
          "pl_paths = [thoughts/adherence_facts.pl]",
          "absolute path to the bundled adherence module (PROLOG/adherence.pl) — passed in brief prose so the agent's consult/use_module sees universal_claim/1 and find_contradictions/1",
          "fact_spec = [{predicate: universal_claim, arity: 1}, {predicate: find_contradictions, arity: 1}]",
          "output_format = json",
        ],
      },
      {
        agentType: "general-purpose",
        order: 5,
        fanout: false,
        fanoutOver: null,
        // NOTE: this narrator/scorer is the orchestrator-owned judgment step the SKILL
        // forbids delegating to the extraction/query agents; it is realized here as a
        // general-purpose leaf invoked LAST in the stage (it reads the prior digests).
        brief:
          "You are the orchestrator-owned narrator for the terminal adherence check — this is judgment/synthesis work with no dedicated specialist (it must NOT be delegated to the extraction or query agents). Using the structural digest (agent-of-questions), the supplementary projections (pl-fact-extractor), and the label-aware verdict digest (verdict-extractor), compute adherence scores (prime-relative: shared/total-in-prime; symmetric: Jaccard) and write thoughts/adherence_report.md. In pipeline-terminal mode the report leads with a fixed Headline Verdicts section (Pattern 3 counterfactual violations, counterfactual honored, prescriptive fulfilled/unfulfilled, prescriptive negation violations, descriptive drift) BEFORE the structural scores — a reviewer must see broken obligations before Jaccard percentages — drawing counts/entries straight from the verdict-extractor JSON and looking up each violation's natural-language claim/2 string from hypothesis.pl. Render a skipped row as its reason line, not a zero. After the digest is in hand, append the machine-readable result/N facts back to adherence_facts.pl via label_aware_facts_out/2 (this writer side-effect stays with the orchestrator, not the read-only verdict-extractor). State outcomes faithfully — if zero violations across all categories, say so explicitly (absence of bad news is itself a verdict); if a Pattern 3 violation turns an apparently-high score misleading, say that too.\n\nDISCIPLINE (orchestrator-owned, never delegated; on the tier-only knob this narrator runs at the highest available tier — the skill is opus/max effort): Headline-verdicts-first ordering is mandatory in pipeline-terminal mode: Pattern 3 -> prescriptive unfulfilled / negation violations -> contradictions -> descriptive drift, ahead of the structural scores. The label_aware_facts_out/2 append is the ONLY writer side-effect of the verdict pass and stays here (the read-only verdict-extractor must not do it); use_module(adherence.pl, except([claim/2, claim/3])) on that swipl append call too. Measure-entailment is the TERMINAL stage and emits NO loopback gaps — report gaps as the human-readable structural gap list (claims in prime absent from impl), not as a loopback signal.",
        minContext: [
          "the agent-of-questions structural digest (shared/gaps/contradictions/extensions/counts) from order 2",
          "the verdict-extractor JSON digest (five label-aware rows) from order 3, pipeline-terminal mode only",
          "the pl-fact-extractor projection digest (universal_claim, find_contradictions) from order 4 if produced",
          "thoughts/hypothesis.pl (to resolve violation claim ids to human-readable claim/2 strings; 'not loaded' in stand-alone mode)",
          "thoughts/adherence_facts.pl path + impl resource id (for the label_aware_facts_out/2 append)",
          "absolute path to PROLOG/adherence.pl (for the append step's use_module, with except([claim/2, claim/3]))",
          "the --prime designation, the run mode (pipeline-terminal vs stand-alone), and orchestrator success_criteria for the one-sentence interpretation",
          "references/adherence-verdicts.md (verdict-row item formats + Headline ordering)",
        ],
      },
    ],
  },

  // ---- Closer. serial:false — exactly one general-purpose narrator leaf.
  explain: {
    serial: false,
    digestFields: ["status", "reason"],
    specialists: [
      {
        agentType: "general-purpose",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "Produce a plain-language narrative (thoughts/explanation.md) of whatever orbital-shifting artifacts currently exist on disk, written for an outsider who does not read Prolog or Lean. Scan thoughts/ in discovery mode (or focus on a single named .lean/.pl/.md file if one is given): read every artifact present, skip what is absent, and note which pipeline stages have not been reached. For each artifact that exists, cover three things in flowing prose — what it is in plain terms, what it found or established, and what decision it informed. Translate every formal concept (predicates -> 'relationships the model tracks', theorems -> 'verified guarantees', quantifiers -> 'for every'/'there exists'/'if...then'). The single load-bearing discipline is calibrated honesty about the STRENGTH of each claim: sort every finding into exactly one of five buckets — proven universally (prescriptive Lean theorem, no closed-world premise), model-verified (descriptive Prolog, exhaustive within the model), sampled-and-passed (test_category projection), asserted-behaviourally (test_category behavioral_claim), and assumed (negation_provenance absent, or otherwise unverified). Report whatever strength each artifact actually carries — neither inflate a weaker claim into 'proven' nor deflate a machine-checked theorem into 'assumed'; where a claim composes labels, combine the calibrated phrases rather than simplifying. Missing stages and unverified claims are information to surface plainly, not failures to paper over. This is read-only narration: do not re-run, re-judge, or alter any upstream verdict.\n\nDISCIPLINE (bake into the brief; tier high — opus/max-effort equivalent — since calibration and narrative synthesis are the whole job): (1) Ontology-strength calibration is mandatory and is THE bias-defense for this stage — never flatten distinct strengths into the undifferentiated word 'proven'/'verified'/'confirmed'; pick the calibrated phrase matching each claim's actual label (prescriptive-no-CWA / prescriptive-under-hypothesis / prescriptive-on-CWA-premise / descriptive / negation_provenance contradicts vs absent / counterfactual / projection / behavioral_claim / unlabeled-taken-as-given) and weave it in. (2) Outcome-neutral: report the strength that exists, with NO steering toward any pass/fail/provable/refuted disposition. (3) Ontology labels themselves (claim_label, test_category, negation_provenance) must never appear in the prose — the reader is an outsider; only the translated phrase appears. (4) Write flowing prose with section headings, not bullet lists (lists confined to the 'What We Know Now' five-bucket summary). (5) Read-only: Read/Glob/Grep/Write only — Write touches thoughts/explanation.md exclusively; do not edit source, proofs, or upstream artifacts. (6) Do not pad — if one artifact exists, a single page is correct. (7) Derive prose directly from the artifacts read; do NOT request upstream digest fields or unrelated context. No lean-expert decide/tactic/heartbeat discipline applies here — this stage runs no Lean and spawns no formal specialist.",
        minContext: [
          "thoughts/ directory contents — minimum-necessary = only the artifact files actually present on disk (existing-world.pl, hypothesis.pl, target-world.pl, model_results.pl, lean/Proofs/*.lean, lean_proof_results.pl, tests/*, implementation_log.md, adherence_report.md as available); NOT upstream digest fields and NOT 'everything'",
          "optionally a single named artifact file or codebase directory when invoked in single-file mode",
          "plugins/shifting/references/ontology.md (ontology-label -> calibrated-strength-phrase reference)",
        ],
      },
    ],
  },

  // ---- Unstaged adversarial move. serial:true — composition, not committee (run sequentially, never auto-merge).
  disprove: {
    serial: true,
    digestFields: ["verdict", "reason"],
    specialists: [
      {
        agentType: "shifting:prolog-adversary",
        order: 1,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are searching for refutations of a single pinned claim that has a Prolog shape (a claim/2 from hypothesis.pl with an attached formal_property/3, a property previously closed by prolog-prover, or a counterfactual claim whose forbidden fact has a grep-able shape). Record your result regardless of which way it falls. Run adversarial CLP-driven counterexample search: restate the pinned target_text as a Prolog goal in its strongest defendable form (do not weaken it to a strawman; if the pinned form looks weaker than the natural-language original, surface that and abstain rather than refute a strawman), name the witness shape before searching, discover the KB through swipl introspection (never invent predicates), encode the claim's negation as a goal, then validate any witness back through the original claim before reporting refuted. Return exactly one verdict in {refuted, inconclusive, abstained}: refuted requires a concrete validated witness and a self-contained refutation artifact written to ${output_dir}/${target_id}.pl that loads cleanly under swipl; inconclusive for a near-miss or unvalidated witness (no artifact written); abstained when the search produced no information (name the obstruction). Abstaining within budget is a valid, first-class outcome; fabricating a witness or declaring the claim 'unrefutable' is a foul. The orchestrator has no preferred outcome and will independently validate any reported witness; your self-reported verdict is candidate evidence, not the final answer.\n\nDISCIPLINE (paste into brief text — Workflow model knob is a TIER only, no effort/timeout knob): bound the search explicitly by the supplied budget (CLP(FD)/(B)/(Q) depth and labeling caps, bounded enumeration length cap) and treat budget exhaustion as abstained, never as proof the claim holds. The validation step (re-run the witness against the full constraint set and check argument types) is NON-skippable — a witness that does not falsify the pinned claim downgrades to inconclusive. The refutation artifact MUST load under `swipl -g halt -t halt -f <file>` with zero errors/warnings or the verdict drops to inconclusive. Forbidden: fabricating a witness, weakening the claim before refuting, declaring the claim 'unrefutable', reading or modifying disproof_results.pl / counterexamples.pl, spawning sub-agents (no Agent tool).",
        minContext: [
          "target_id (the pinned claim's identifier)",
          "target_text (claim pinned by the orchestrator in its strongest defendable form)",
          "provenance (absolute path to the file the claim lives in, e.g. thoughts/hypothesis.pl)",
          "refutation_shape (witness shape named by the orchestrator before search)",
          "budget (explicit token/depth/attempt cap; exhaustion without a witness is abstained)",
          "output_dir (defaults to thoughts/refutations/)",
          "prolog introspect dir absolute path (for swipl kb_summary/kb_describe/kb_graph)",
          "prolog-wiki references absolute path (for CLP extension API)",
          "CODEBASE_PATH (only for counterfactual targets whose forbidden fact is grepped against source)",
        ],
      },
      {
        agentType: "shifting:lean-adversary",
        order: 2,
        fanout: false,
        fanoutOver: null,
        brief:
          "You are searching for refutations of a single pinned claim that has a Lean shape (a theorem name from lean_proof_results.pl — especially one with theorem_verdict(_, unprovable) — or a Prolog claim with an attached formal_property/3 that translates cleanly into Lean). Record your result regardless of which way it falls. Construct a Lean term inhabiting the negation of the ORIGINAL theorem in its strongest non-trivial reading (if multiple readings exist, pick the strongest non-trivial one and state both in the digest); treat `lake build` as the deductive judge — a refutation that does not build is not a refutation. Build incrementally with the `done` discipline, write the negated statement to ${output_dir}/${target_id}.lean, and before reporting refuted confirm side-by-side that the file syntactically negates the original's outermost connective (not a re-scoped or vacuously-weakened restatement) and builds cleanly. Return exactly one verdict in {refuted, inconclusive, abstained}: refuted requires a buildable, self-contained refutation file; inconclusive when only a partial term exists (one sub-goal unclosed) or the witness fails a validation check — do NOT commit an unbuildable file; abstained when no productive negation candidate emerged (name the obstruction, e.g. theorem appears genuinely true within the formalism, or witness requires a Mathlib import the project lacks). Behavioral/runtime targets (HTTP traces, wall-clock timing, observed I/O) and open-domain Prolog claims with no formal_property/3 are INADMISSIBLE — return abstained with that obstruction rather than forcing a refutation. Abstaining within budget is a valid, first-class outcome; fabricating a witness, weakening the original theorem, or declaring it 'unrefutable' is a foul. The orchestrator has no preferred outcome and will independently validate any reported witness; your self-reported verdict is candidate evidence, not the final answer. A refuted verdict from the Prolog adversary is sufficient on its own — failing to also obtain a Lean refutation never downgrades a refuted verdict or blocks abstention.\n\nDISCIPLINE (paste into brief text — Workflow model knob is a TIER only; there is NO effort/timeout knob, so the 20-minute `decide` hot-run lesson rides here as prose, not a timeout): FORBIDDEN as the closing move — `sorry`, `axiom`, `native_decide`, and `decide` over any open-shape goal whose hypotheses or goal mention a predicate emitted from target-world.pl / declared in target-world-shape.lean (the decidability instance would do all the work instead of constructing the witness). Bound tactic search and refutation-strategy revisions by the supplied budget; on exhaustion report abstained, never claim the theorem holds. Prefer short structural witness-construction tactics; run the post-build grep self-check `grep -n -E '(sorry|axiom|native_decide)' ${output_dir}/${target_id}.lean` and treat any hit as a violation (halt, do not record refuted). Forbidden: fabricating a witness, weakening the original theorem before refuting, declaring it 'unrefutable', requiring Mathlib imports the project lacks (that is inconclusive — record the import gap), reading or modifying disproof_results.pl / counterexamples.pl / files under thoughts/lean/Proofs/, spawning sub-agents (no Agent tool).",
        minContext: [
          "target_id (the pinned theorem/claim identifier)",
          "target_text (claim/theorem pinned by the orchestrator in its strongest defendable form)",
          "provenance (absolute path to the file the claim lives in, e.g. thoughts/lean_proof_results.pl)",
          "refutation_shape (witness shape named by the orchestrator before search)",
          "budget (explicit cap; exhaustion without a buildable refutation is abstained)",
          "output_dir (path the project lakefile reaches as a source root — orchestrator ensures this before delegating)",
          "lean4-wiki references absolute path (for negation lemmas)",
          "lean-tactics references absolute path (forbidden-tactics carve-outs, inverted)",
        ],
      },
    ],
  },
};

// #############################################################################
// ## THE REALIZED SEAM — runStage / runMandatoryDisprove / explain.            ##
// ##                                                                            ##
// ## These replace the injected `agent.runStage` / `agent.runDisprove` seam     ##
// ## from orbital-pipeline.workflow.js. They call the injected `agent()` /      ##
// ## `parallel()` globals DIRECTLY (option B). They ASSEMBLE a STAGE DIGEST      ##
// ## that the proven loop routes on; they NEVER compute a logic verdict in the   ##
// ## substrate — every verdict word is read off an agent's emitted field (C-2). ##
// #############################################################################

// Appended to EVERY specialist brief so the routing recommendation — which the
// substrate folds MECHANICALLY into the stage digest (C-2) — is emitted uniformly,
// rather than the substrate re-deriving routing from artifact content.
const ROUTING_CONTRACT =
  "\n\nROUTING CONTRACT (you emit the recommendation; the deterministic substrate merely honors it — it does NOT read your artifacts to second-guess you):\n" +
  "- routing='advance' when your work is sound and the pipeline should proceed.\n" +
  "- routing='gap' when you found a RECOVERABLE deficiency an earlier stage must fix; you MUST set failureClass (a short, STABLE class name — it keys the loop-limit recovery budget; omit it and your gap is bucketed under a single shared 'unspecified_gap' budget) and upstreamStage (the stage to loop back to — may be this same stage for in-place repair). Abstaining WITH an obstruction is a gap, not something to hide.\n" +
  "- routing='halt' ONLY when a CORE obligation is refuted and no loopback can fix it; set coreObligation=true and failureClass to the hard-stop reason. coreObligation=true is a HARD-STOP axis that FORCES termination regardless of routing — NEVER set it on a recoverable gap. Prefer gap whenever a fix is conceivable; do not over-use halt.\n" +
  "- verdictSignal: carry your verdict WORD verbatim (provable/refuted/consistent/inconsistent/gap/unprovable/abstained/...); the substrate records it, never derives it.\n" +
  "- PRODUCER NOTE: if a later specialist in THIS stage must process discrete items one-at-a-time (stubs, sub-hypotheses, tests), return those items as fanoutList.\n" +
  "There is NO preferred routing — advance, gap, and halt are all valid; report what you actually found.";

/** Append the per-specialist min_context block + the uniform routing contract. */
function withContext(brief, minContext) {
  const ctx =
    Array.isArray(minContext) && minContext.length > 0
      ? "\n\nMINIMUM-NECESSARY CONTEXT (you receive ONLY this — no orchestrator hopes, no downstream targets):\n- " +
        minContext.join("\n- ")
      : "";
  return brief + ctx + ROUTING_CONTRACT;
}

/** Specialize a fan-out specialist's brief to one concrete item. */
function briefWith(spec, item) {
  return (
    withContext(spec.brief, spec.minContext) +
    "\n\nTHIS INVOCATION'S ITEM (one of the fan-out set): " +
    item
  );
}

/**
 * Fallback fan-out item when NO producer specialist in this stage emitted a
 * fanoutList. runStage PREFERS the upstream producer's agent-emitted fanoutList
 * (real N-wide fan-out, e.g. lean-spec-writer's stub list -> one lean-expert per
 * stub); this sentinel only keeps the stage running 1-wide when no list exists.
 *
 * NOTE (decompose, DEFERRED): decompose's fan-out (agent-of-questions per
 * sub-hypothesis) needs a producer->fanout->consumer SANDWICH — the decomposer
 * proposes the sub-hypotheses, agent-of-questions fans out over them, then the
 * decomposer finalizes with the evidence. The current linear ordering cannot emit
 * that list before the fan-out, so decompose runs 1-wide on this sentinel until
 * the bespoke sandwich is added (before the kimmy spike; the pre-kimmy checklist
 * does not exercise decompose fan-out).
 */
function fanoutSentinel(stage) {
  if (stage === "prove_invariants") return ["all formal_property stubs emitted by lean-spec-writer for this run"];
  if (stage === "decompose") return ["each counterfactual sub-hypothesis the decomposition produces"];
  return ["the single item in scope for this stage"];
}

// -----------------------------------------------------------------------------
// lib/digest-fold.js  — fold specialists' routing recommendations into the stage
// digest (D-3 ; C-2). PURE; replaces the former assembler-AGENT (the lossy-
// projection failure mode). Canonical tested copy: lib/digest-fold.js + the C-2
// regression guard tests/digest_fold.c2_regression_guard.test.js. This is the
// VERBATIM inline (the Workflow-tool host has no require) — keep it in sync.
// -----------------------------------------------------------------------------

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

/**
 * runStage — the realized stage executor (replaces the injected agent.runStage).
 *
 * Runs STAGE_BRIEFS[stage]'s specialists in `order`. A FAN-OUT specialist is
 * dispatched one-agent-per-item via parallel(), over the item list a PRODUCER
 * specialist earlier in the stage emitted as `fanoutList` (agent-emitted, C-2) —
 * e.g. lean-spec-writer emits its stub list and one lean-expert runs per stub.
 * When no producer list exists, a single sentinel keeps the stage 1-wide. Serial
 * stages never overlap (each `await` precedes the next). The digest is then folded
 * by foldDigest (PURE — no assembler agent).
 *
 * NOTE (LOOP_LIMIT=1 consequence): the intra-stage write->validate->repair loop a
 * native skill drove (e.g. close_world: agent-of-truth then kb-validator) is
 * realized as a GAP a specialist emits (routing='gap'), so the proven OUTER loop
 * performs the loop-limited recovery — capped at ONE per (gapClass, targetStage).
 * No unbounded inner loop is introduced.
 */
async function runStage(stage, ctx) {
  const brief = STAGE_BRIEFS[stage];
  if (!brief) {
    return { stage, status: "ok", gaps: [], verdict: null, coreObligation: false, reason: null };
  }

  phase(stage);
  log("stage " + stage + ": dispatching " + brief.specialists.length + " specialist(s)" + (brief.serial ? " (serial)" : ""));

  const ordered = brief.specialists.slice().sort((a, b) => a.order - b.order);
  const results = [];
  // The most recent producer-emitted fan-out list (real N-wide fan-out, agent-
  // emitted — C-2, not substrate content-inspection). A non-fanout specialist that
  // returns fanoutList feeds the NEXT fanout specialist its true item set.
  let producerFanoutList = null;

  for (const spec of ordered) {
    if (spec.fanout) {
      const hasList = Array.isArray(producerFanoutList) && producerFanoutList.length > 0;
      const items = hasList ? producerFanoutList : fanoutSentinel(stage);
      if (!hasList) {
        log("stage " + stage + ": no producer fanoutList for " + spec.agentType + " — running 1-wide on a sentinel.");
      }
      const fanned = await parallel(
        items.map((it) => () =>
          agent(briefWith(spec, it), {
            label: stage + ":" + spec.agentType + ":item",
            phase: stage,
            agentType: spec.agentType,
            schema: SPECIALIST_RESULT_JSONSCHEMA,
          })
        )
      );
      for (const r of fanned.filter(Boolean)) {
        results.push({ ...r, __agentType: spec.agentType, __order: spec.order });
      }
    } else {
      const r = await agent(withContext(spec.brief, spec.minContext), {
        label: stage + ":" + spec.agentType,
        phase: stage,
        agentType: spec.agentType,
        schema: SPECIALIST_RESULT_JSONSCHEMA,
      });
      if (r) {
        results.push({ ...r, __agentType: spec.agentType, __order: spec.order });
        if (Array.isArray(r.fanoutList) && r.fanoutList.length > 0) {
          producerFanoutList = r.fanoutList;
        }
      }
    }
  }

  // PURE deterministic fold (no assembler agent) — merges the specialists'
  // agent-emitted routing recommendations into the routable digest (C-2).
  return foldDigest(stage, brief, results);
}

/**
 * runMandatoryDisprove — the realized disprove floor (replaces agent.runDisprove).
 *
 * Realizes the mandatory floor (D-6/I-5/I-6/I-7): >=1 attempt, >=2 perspective-
 * diverse adversaries dispatched in PARALLEL, never attacks its own output. The
 * deterministic PLAN comes from planDisproveAttempt (the inlined pure mechanic);
 * the adversaries are the disprove stage's specialists (prolog-adversary +
 * lean-adversary). The trail entry is recorded exactly as the proven loop does.
 *
 * The SKILL's "composition, not committee" rule (run adversaries serially when
 * both formalisms apply to one target) is a per-target ROUTING concern the
 * orchestrator owns; the MANDATORY FLOOR here dispatches >=2 perspective-diverse
 * adversaries in parallel to satisfy I-7 (fan-out) on at least one attempt. The
 * orchestrator-only responsibilities the leaves must NOT perform — pinning the
 * claim in its strongest form, naming the refutation shape, setting the budget,
 * independently validating any reported witness, and owning the verdict + writing
 * disproof_results.pl / counterexamples.pl — are reflected in the plan + brief and
 * stay out of the leaf agents.
 */
async function runMandatoryDisprove(trail) {
  const spec = { ownOutput: "disproof_results", reserve: 1, gateTarget: "gate_target_descriptor" };
  // Deterministic plan (pure mechanic): target (never own output), spend
  // (>= reserve), parallel:true, >=2 perspective-diverse adversaries.
  const attempt = planDisproveAttempt(spec);

  const disBrief = STAGE_BRIEFS.disprove;
  const adversarySpecs = disBrief.specialists.slice().sort((a, b) => a.order - b.order);

  const targetLine =
    "\n\nPINNED TARGET (orchestrator-pinned, strongest defendable form): " +
    attempt.target +
    "\nYou must NOT attack the disprove move's own output (" +
    attempt.ownOutput +
    "). Budget: bounded; on exhaustion report abstained, never 'unrefutable'. Your self-reported verdict is candidate evidence; the orchestrator independently validates any witness and owns disproof_results.pl / counterexamples.pl.";

  // I-7 fan-out: dispatch the >=2 perspective-diverse adversaries in PARALLEL.
  await parallel(
    adversarySpecs.map((spec2) => () =>
      agent(withContext(spec2.brief, spec2.minContext) + targetLine, {
        label: "disprove:" + spec2.agentType,
        phase: "disprove",
        agentType: spec2.agentType,
        schema: {
          type: "object",
          required: ["verdict"],
          additionalProperties: true,
          properties: {
            verdict: { type: "string", enum: ["refuted", "inconclusive", "abstained"], description: "this adversary's self-reported verdict — candidate evidence, the orchestrator validates it" },
            reason: { type: ["string", "null"], description: "the obstruction / witness-evidence narrative" },
            artifact: { type: ["string", "null"], description: "the self-contained refutation artifact path under thoughts/refutations/ (refuted only)" },
          },
        },
      })
    )
  );

  // Record the disprove_attempt trail entry EXACTLY as the proven loop does.
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

/**
 * explain — the always-runs closer. It has NO dedicated specialist agent; the
 * explain spec is a single general-purpose narrator leaf. After the loop, this
 * runs exactly once with the outcome-neutral narrator brief, then the proven
 * terminal trail entry is recorded.
 */
async function runExplainCloser() {
  const spec = STAGE_BRIEFS.explain.specialists[0];
  await agent(withContext(spec.brief, spec.minContext), {
    label: "explain:" + spec.agentType,
    phase: "explain",
    agentType: spec.agentType,
  });
}

// #############################################################################
// ## THE LOOP — async port of orbital-pipeline.workflow.js's runPipeline.      ##
// ##                                                                            ##
// ## Control flow IDENTICAL to the proven reference, except: async, the seam    ##
// ## is the real runStage / runMandatoryDisprove above (no `deps` injection),   ##
// ## and explain ALWAYS runs post-loop via runExplainCloser(). Every invariant- ##
// ## bearing line is preserved: movable cursor, canRunStage gating, routeDigest  ##
// ## branching, mergeGaps, withinLoopLimit hard-stop, widenScope, produced set,  ##
// ## decision trail, explain-always-runs (happy path AND every hard-stop path).  ##
// #############################################################################

async function runPipeline(opts = {}) {
  const loopLimit = opts.loopLimit == null ? LOOP_LIMIT : opts.loopLimit;
  const trail = createTrail();

  // Scope is monotone (C-4/I-4): startIdx only widens (lowers), endIdx fixed.
  let scope = { startIdx: 0, endIdx: EXPLAIN_IDX };
  // The movable cursor (D-4): advances by default, backward only for a gap.
  let cursor = 0;
  const produced = new Set();

  // Disprove floor (D-6/I-6): reserve >=1 attempt up front, run it (>=2
  // adversaries in parallel, I-7). Recorded before the stage loop so EVERY run
  // — even all-clean — carries the mandatory attempt.
  await runMandatoryDisprove(trail);

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
    const digest = await runStage(stage, { scope, cursor });
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
  // AND every hard-stop path. Exactly once, last (crit 8). The realized closer is
  // an agent() call; the terminal trail entry is recorded exactly as the proven
  // loop does.
  phase("explain");
  await runExplainCloser();
  trail.record("stage", { stage: "explain", terminal: true });

  return { outcome, reason, trail: trail.entries, scope };
}

// #############################################################################
// ## TOP-LEVEL BODY.                                                            ##
// ## phase('disprove') -> run the pipeline -> return { outcome, reason,        ##
// ## scope, trail }.                                                            ##
// #############################################################################

phase("disprove");
log("orbital-pipeline (realized Workflow, Decision 2 / option B): mandatory disprove floor, then the movable-cursor 8-stage loop. Control branches ONLY on agent-emitted digest fields (C-2).");

const result = await runPipeline();

log(
  "pipeline finished: outcome=" +
    result.outcome +
    (result.reason ? " reason=" + result.reason : "") +
    " scope=[" + result.scope.startIdx + "," + result.scope.endIdx + "]" +
    " trail_entries=" + result.trail.length
);

return {
  outcome: result.outcome,
  reason: result.reason,
  scope: result.scope,
  trail: result.trail,
};
