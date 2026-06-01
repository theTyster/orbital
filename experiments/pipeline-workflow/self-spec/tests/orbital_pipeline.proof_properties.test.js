// =============================================================================
// TDD Test Plan: Pipeline-as-Workflow — invariant-preserving deterministic Workflow
//
// Proposition (hypothesis.pl): "The orbital-shifting seven-stage pipeline can be
//   realized as one deterministic, background-executable Workflow that preserves
//   invariants I-1..I-7, parallelizes its provable and testable stages without
//   losing determinism, and is verifiable by the same pipeline — without inverting
//   the smart-orchestrator / dumb-executor separation."
//
// Generated from (carrier): thoughts/lean_proof_results.pl
//   + cross-referenced thoughts/lean/Proofs/*.lean.
//   Transitively cites thoughts/hypothesis.pl (claim labels, negation provenance),
//   thoughts/target-world.pl (formal_property NL) via theorem_source/2 +
//   provenance_annotation/3.
//
// Proven properties covered: 7 / 7  (I-1..I-7, all `proven`, axiom-free)
// proof_mode: conditional  (hypothesis.pl carries claim_label(_, counterfactual))
//
// test_category breakdown: 16 projection, 8 behavioral_claim
// Loopback signals: 0  (see LOOPBACK SIGNALS block — none this run)
// Coverage gaps: see COVERAGE GAPS block.
//
// BOUNDARY REMINDER (lean -> tdd). A green `projection` test is a WITNESS of the
// universally-proved property at ONE fixture, NOT a re-proof of forall x. P(x);
// the Lean theorem remains the authority on universality. `behavioral_claim`
// tests have NO upstream proof — Lean cannot state I/O, state mutation,
// concurrency, timing, or the digest-routing control flow they assert.
//
// DETERMINISM / INJECTION (spec D-11, C-1, C-2). Every test exercises the PURE
// mechanics with INJECTED fakes — no real agents, no Lean, no wall-clock, no RNG.
// The orchestration loop receives effectful collaborators by injection; the
// substrate branches ONLY on agent-emitted digest fields (C-2), never computing a
// logic verdict itself.
//
// SKIP CONTRACT. Every test starts skipped (`{ skip: true }`). realize-specification
// un-skips one at a time. Open-assumption stubs carry a distinguishing skip reason.
//
// Runner: node:test (built-in; `node --test`). Zero-dependency — the target
// (orbital-pipeline.workflow.js + lib/) is a Node project with no package.json yet.
// =============================================================================

const { test } = require("node:test");
const assert = require("node:assert/strict");

// -----------------------------------------------------------------------------
// Fixtures & injected fakes (drawn from target-world.pl substrate constants).
// These are the concrete sampling points; each projection test names its
// fixture_set / unsampled_domain explicitly.
//
// Substrate constants (target-world.pl):
//   STAGES: close_world, decompose, model_obligations, prove_invariants,
//           instantiate, realize, measure, explain  (explain = terminal closer)
//   endIdx = 7 (explain index); LOOP_LIMIT = 1; recovery keys = {s3,s4,s5,s6},
//   recoveryBudgetSum = #keys * LOOP_LIMIT = 4.
// -----------------------------------------------------------------------------

const STAGES = [
  "close_world", "decompose", "model_obligations", "prove_invariants",
  "instantiate", "realize", "measure", "explain",
];
const EXPLAIN_IDX = 7;
const LOOP_LIMIT = 1;
const RECOVERY_KEYS = ["model_obligations", "prove_invariants", "instantiate", "realize"];

// A clean digest: stage produced its artifact, no gaps, not a core obligation.
function cleanDigest(stage) {
  return { stage, artifact: `thoughts/${stage}.pl`, status: "ok", verdict: null, gaps: [], coreObligation: false };
}
// A digest carrying a routed gap (loopback request) toward `target`.
function gapDigest(stage, target, gapClass, params = {}) {
  return {
    stage, artifact: `thoughts/${stage}.pl`, status: "ok", verdict: null,
    gaps: [{ targetStage: target, gapClass, params }], coreObligation: false,
  };
}
// A halt digest (agent-emitted hard-stop signal — substrate does NOT compute it).
function haltDigest(stage, reason, coreObligation = false) {
  return { stage, artifact: `thoughts/${stage}.pl`, status: "halt", reason, gaps: [], coreObligation };
}

// The implementation under test is expected to expose pure mechanics from lib/.
// Tests reference these via a single injection seam so realize-specification can
// wire the real modules without rewriting the tests.
//   - mergeGaps(gaps)            -> batched gaps (crit 1)
//   - withinLoopLimit(trail, gapClass, stage) -> bool (crit 2, D-7)
//   - widenScope(scope, target)  -> scope (crit 3, I-4)
//   - routeDigest(state, digest) -> { action: 'advance'|'loopback'|'halt', ... } (crit 4)
//   - runPipeline(deps)          -> { trail, ... } where deps injects fake agent + collaborators
// Resolved lazily so the file loads (all-skipped) before lib/ exists.
function lib() {
  // eslint-disable-next-line global-require
  return require("../../orbital-pipeline.workflow.js");
}

// =============================================================================
// Phase 0 — Removal  (conditional mode; counterfactual claims with NECESSARY
//   necessity lemmas). Comes first: forbidden-dependency deletion before any new
//   behaviour is written. Both negated premises are `contradicts` (structural,
//   NOT CWA-fragile) — re-introducing the forbidden fact must break the invariant.
// Implements: I-4 (cf_v1_no_scope_narrowing), I-5 (cf_v1_no_self_attack,
//   cf_v1_no_below_reserve). Depends on: nothing.
// =============================================================================

test("scope_narrowing_fact_absent: the implementation never narrows scope mid-run", { skip: false }, () => {
  // Property: I-4 — startIdx non-increasing, endIdx fixed; scope never narrows.
  // Proven in: thoughts/lean/Proofs/I4Monotone.lean (i4_startidx_antitone)
  // proof_strategy: monotone: sufficiency intro+cases on both StartIdx hyps (all starts=0) => Nat.le_refl 0; endIdx constant by cases on EndIdx + rfl. Necessity over StartIdxCF1 cites .r0_step0/.r0_step3_narrowed witness
  // test_category: projection
  // ontology_label: counterfactual
  // negation_provenance: contradicts   (structural — NOT CWA-fragile)
  // sampled_from: forall steps i<=j of a run, startIdx j <= startIdx i
  // fixture_set: a run whose scope starts at 0 and widens only; assert no widenScope call ever returns a larger startIdx
  // unsampled_domain: runs with non-zero initial startIdx; multi-loopback runs where several widenings compose
  const { widenScope } = lib();
  const scope = { startIdx: 3, endIdx: EXPLAIN_IDX };
  // Loopback target precedes start -> widen to target; otherwise unchanged.
  const widened = widenScope(scope, 1);
  assert.ok(widened.startIdx <= scope.startIdx, "startIdx must never increase (no narrowing)");
  assert.equal(widened.endIdx, EXPLAIN_IDX, "endIdx is fixed");
});

test("scope_narrowing_reintroduced_breaks_monotonicity: NECESSITY — re-adding a later larger startIdx falsifies I-4", { skip: false }, () => {
  // Property: I-4 necessity — with scope_narrows_mid_run re-introduced (a later
  //   step with startIdx 5 > step 0's 0), antitonicity FAILS. Proves the removal
  //   is load-bearing (necessity_lemma_status(p_v1_i4, scope_narrows_mid_run, proven)).
  // Proven in: thoughts/lean/Proofs/I4Monotone.lean (i4_needs_no_scope_narrowing)
  // proof_strategy: necessity over StartIdxCF1 (CF-augmented) cites .r0_step0/.r0_step3_narrowed witness
  // test_category: projection
  // ontology_label: counterfactual
  // negation_provenance: contradicts
  // sampled_from: exists i<=j with StartIdxCF1 j > StartIdxCF1 i (the CF-augmented run)
  // fixture_set: feed the loop a synthetic "narrowing" event (startIdx 0 then 5) and assert the monotone guard rejects it
  // unsampled_domain: other narrowing magnitudes/positions; the full CF-augmented step family
  const { widenScope } = lib();
  // A narrowing request (target AFTER current start) must be rejected/ignored —
  // the guard never produces a larger startIdx. If it ever did, I-4 would break.
  const scope = { startIdx: 0, endIdx: EXPLAIN_IDX };
  const afterNarrowAttempt = widenScope(scope, 5); // target 5 > start 0 => no narrowing
  assert.ok(afterNarrowAttempt.startIdx <= 0, "a narrowing request must not raise startIdx");
});

test("self_attack_fact_absent: disprove never targets its own output", { skip: false }, () => {
  // Property: I-5 — every disprove attempt's target != its own output.
  // Proven in: thoughts/lean/Proofs/I5Reserve.lean (i5_target_ne_own_output)
  // proof_strategy: target=/=ownOutput by constructor disjointness of DisproveSurface (cases)
  // test_category: projection
  // ontology_label: counterfactual
  // negation_provenance: contradicts
  // sampled_from: forall attempts a, target(a) != ownOutput(a)
  // fixture_set: attempt a0 whose ownOutput is the disproof_results surface; assert chosen target differs
  // unsampled_domain: attempts whose ownOutput surface differs from a0's; multi-attempt runs
  const { planDisproveAttempt } = lib();
  const attempt = planDisproveAttempt({ ownOutput: "disproof_results", gateTarget: "gate_target_descriptor" });
  assert.notEqual(attempt.target, attempt.ownOutput, "disprove must not attack its own output");
});

test("below_reserve_fact_absent: disprove never spends below the reserve", { skip: false }, () => {
  // Property: I-5 — every disprove attempt spends >= reserve.
  // Proven in: thoughts/lean/Proofs/I5Reserve.lean (i5_spend_ge_reserve)
  // proof_strategy: reserve: sufficiency spend>=reserve via Spend/Reserve .a0 + Nat.le_refl
  // test_category: projection
  // ontology_label: counterfactual
  // negation_provenance: contradicts
  // sampled_from: forall attempts a, exists s r. spend(a)=s, reserve(a)=r, r<=s
  // fixture_set: attempt a0 with reserve 1; assert planned spend >= 1
  // unsampled_domain: attempts with reserve != 1; budget-exhaustion edge where spend is clamped at reserve
  const { planDisproveAttempt } = lib();
  const attempt = planDisproveAttempt({ reserve: 1, ownOutput: "disproof_results" });
  assert.ok(attempt.spend >= attempt.reserve, "disprove spend must be >= reserve");
});

test("below_reserve_reintroduced_breaks_reserve: NECESSITY — spend below reserve falsifies I-5", { skip: false }, () => {
  // Property: I-5 necessity — with disprove_spends_below_reserve re-introduced
  //   (spend 0 < reserve 1), reserve discipline FAILS. Load-bearing removal.
  //   necessity_lemma_status(p_v1_i5, disprove_spends_below_reserve, proven).
  // Proven in: thoughts/lean/Proofs/I5Reserve.lean (i5_needs_no_below_reserve)
  // proof_strategy: necessity lemma over SpendCF restores the forbidden fact (spend below reserve)
  // test_category: projection
  // ontology_label: counterfactual
  // negation_provenance: contradicts
  // sampled_from: exists a. SpendCF a 0 /\ Reserve a 1 /\ 0 < 1
  // fixture_set: ask the planner to honor reserve while given budget 0; assert it refuses to drop below reserve (does NOT plan spend 0)
  // unsampled_domain: other below-reserve spend magnitudes
  const { planDisproveAttempt } = lib();
  // Even with insufficient opportunistic budget, the MANDATORY attempt protects
  // the reserve — it must not plan a spend of 0 below reserve 1.
  const attempt = planDisproveAttempt({ reserve: 1, availableBudget: 0, ownOutput: "disproof_results" });
  assert.ok(attempt.spend >= 1, "mandatory attempt must not underspend the reserve");
});

test("self_attack_reintroduced_breaks_no_self_attack: NECESSITY — target == own output falsifies I-5", { skip: false }, () => {
  // Property: I-5 necessity — with disprove_attacks_own_output re-introduced
  //   (target = ownOutput, both disproof_results), no-self-attack FAILS.
  //   necessity_lemma_status(p_v1_i5, disprove_attacks_own_output, proven).
  // Proven in: thoughts/lean/Proofs/I5Reserve.lean (i5_needs_no_self_attack)
  // proof_strategy: necessity lemma over TargetCF restores target = own output
  // test_category: projection
  // ontology_label: counterfactual
  // negation_provenance: contradicts
  // sampled_from: exists a t o. TargetCF a t /\ OwnOutput a o /\ t = o
  // fixture_set: ask the planner for a target equal to ownOutput; assert it refuses (re-routes the target)
  // unsampled_domain: other surfaces where target could coincide with output
  const { planDisproveAttempt } = lib();
  // If the only candidate target IS the own output, the planner must re-route,
  // never produce a self-attack. Reintroducing the self-attack must be impossible.
  const attempt = planDisproveAttempt({ ownOutput: "disproof_results", candidateTargets: ["disproof_results", "gate_target_descriptor"] });
  assert.notEqual(attempt.target, "disproof_results", "planner must not select its own output as target");
});

// =============================================================================
// Phase 1 — Foundations  (projection tests, no inter-test dependencies).
// Implements: I-2 (gating), I-6 (disprove floor), I-7 (fanout).
// Depends on: Phase 0 (forbidden facts removed).
// =============================================================================

test("artifact_gating: no stage runs before its required upstream artifact exists", { skip: false }, () => {
  // Property: I-2 — forall stage s, artifact a. Requires s a -> StageOrder a s
  //   (the required artifact is produced by a strictly-earlier stage).
  // Proven in: thoughts/lean/Proofs/I2Gating.lean (i2_artifact_gating)
  // proof_strategy: gating: intro+cases on Requires, each required artifact discharged by its StageOrder predecessor constructor (.s1_s2 .. .s7_se); close_world ungated by case-exhaust
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile — see COVERAGE GAPS)
  // sampled_from: forall (s,a). Requires s a -> a precedes s in StageOrder
  // fixture_set: the materialized 8-stage chain; sample the s4 (prove_invariants) gate requiring s3 (model_obligations) output
  // unsampled_domain: stages whose required artifact is a non-immediate predecessor; future stages not in this chain
  const { canRunStage } = lib();
  const produced = new Set(["close_world", "decompose", "model_obligations"]);
  assert.equal(canRunStage("prove_invariants", produced), true, "prove_invariants runs once model_obligations artifact exists");
  const missing = new Set(["close_world", "decompose"]);
  assert.equal(canRunStage("prove_invariants", missing), false, "prove_invariants must NOT run before its required upstream exists");
});

test("close_world_ungated: the entry stage requires no upstream artifact", { skip: false }, () => {
  // Property: I-2 base case — forall a. NOT Requires close_world a.
  // Proven in: thoughts/lean/Proofs/I2Gating.lean (i2_close_world_ungated)
  // proof_strategy: close_world ungated by case-exhaust on Requires .close_world _
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall a. NOT Requires close_world a
  // fixture_set: empty produced-set; assert close_world is runnable from cold start
  // unsampled_domain: n/a (close_world is the unique stage-0 base case)
  const { canRunStage } = lib();
  assert.equal(canRunStage("close_world", new Set()), true, "close_world runs from a cold start (ungated)");
});

test("disprove_floor: every run performs at least one disprove attempt", { skip: false }, () => {
  // Property: I-6 — forall run r, exists attempt a. RunAttempt r a (>=1 attempt).
  // Proven in: thoughts/lean/Proofs/I6Floor.lean (i6_disprove_runs)
  // proof_strategy: floor: intro+cases on single-constructor Run; exhibit RunAttempt .r0 .a0 witness for exists-attempt
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall runs r, >=1 disprove attempt occurs
  // fixture_set: an ALL-CLEAN run (no gaps, no halts) driven with injected fakes; assert the trail records >=1 disprove attempt
  // unsampled_domain: runs with gaps/halts; runs where opportunistic disprove also fires (>1 attempt)
  const fakeAgent = makeFakeAgent({ allClean: true });
  const { runPipeline } = lib();
  const result = runPipeline({ agent: fakeAgent, clock: frozenClock(), rng: () => 0 });
  const attempts = result.trail.filter((e) => e.kind === "disprove_attempt");
  assert.ok(attempts.length >= 1, "at least one disprove attempt even on an all-clean run");
});

test("disprove_fanout: every disprove attempt spawns >=2 distinct adversaries in parallel", { skip: false }, () => {
  // Property: I-7 — forall attempt a, exists x!=y. AttemptAdversary a x /\ AttemptAdversary a y /\ AdversariesParallel a.
  // Proven in: thoughts/lean/Proofs/I7Fanout.lean (i7_disprove_fans_out)
  // proof_strategy: fanout: intro+cases on DisproveAttempt; exhibit distinct adv1/adv2 via AttemptAdversary .a0_adv1/.a0_adv2 (disjoint by enum) + AdversariesParallel .a0
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall attempts a, >=2 distinct adversaries run in parallel
  // fixture_set: a single disprove attempt; assert its adversary set has >=2 distinct ids and is dispatched in parallel
  // unsampled_domain: attempts with >2 adversaries; the actual parallel scheduling semantics (asserted structurally here, not by timing)
  const { planDisproveAttempt } = lib();
  const attempt = planDisproveAttempt({ ownOutput: "disproof_results", reserve: 1 });
  const ids = new Set(attempt.adversaries.map((a) => a.id));
  assert.ok(ids.size >= 2, "attempt fans out to >=2 DISTINCT adversaries");
  assert.equal(attempt.parallel, true, "adversaries are dispatched in parallel");
});

// =============================================================================
// Phase 2 — Compositions  (projection tests depending on Phase-1 mechanics).
// Implements: I-3 (termination measure), I-1 (explain liveness + terminality).
// Depends on: Phase 1 (gating + disprove floor).
// =============================================================================

test("termination_forward_step_decreases_measure: a forward step strictly lowers cursorDistance", { skip: false }, () => {
  // Property: I-3 — every Step strictly decreases M=(recoveryBudgetSum, endIdx-cursor)
  //   under Prod.Lex Nat.lt Nat.lt. Forward: (rb,d+1)->(rb,d), 2nd component drops.
  // Proven in: thoughts/lean/Proofs/I3Termination.lean (step_strictDecreasing, forward case)
  // proof_strategy: termination (RE-STATED non-vacuously): concrete Step relation over State=(recoveryBudgetSum,cursorDistance); forward strictly decreases 2nd lex component (Nat.lt_succ_self); StepRev subrelation of well-founded InvImage => Acc => loop terminates. Identity/constant-measure witness REJECTED.
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall states s s'. Step s s' -> M s' <_lex M s  (forward instance)
  // fixture_set: state (rb=4, cursorDistance=3); take one forward step; assert measure strictly decreased lexicographically
  // unsampled_domain: all other (rb,d) states; the loopback case is sampled separately below
  const { measureM, stepForward, lexLt } = lib();
  const s = { recoveryBudgetSum: 4, cursorDistance: 3 };
  const s2 = stepForward(s);
  assert.ok(lexLt(measureM(s2), measureM(s)), "forward step strictly decreases M (2nd component)");
  assert.equal(s2.recoveryBudgetSum, s.recoveryBudgetSum, "forward leaves recovery budget unchanged");
});

test("termination_loopback_step_decreases_measure: a loopback consumes a recovery unit (1st component drops)", { skip: false }, () => {
  // Property: I-3 — loopback: (rb+1,d)->(rb,d'), 1st lex component strictly decreases,
  //   dominating any cursor change. Recovery sum bounded by #keys*LOOP_LIMIT=4.
  // Proven in: thoughts/lean/Proofs/I3Termination.lean (step_strictDecreasing, loopback case; i3_recovery_bound)
  // proof_strategy: loopback -> Prod.Lex.left with Nat.lt_succ_self; recovery bound RecoveryBudget s3..s6 each 1, sum=4 by rfl; at most 4 loopbacks.
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall states. loopback Step strictly decreases M (1st component)
  // fixture_set: state (rb=4, cursorDistance=0); loopback jumps cursor to distance 7; assert measure still strictly decreased (rb 4->3)
  // unsampled_domain: every (rb,d,d') triple; the exact cursor jump target distribution
  const { measureM, stepLoopback, lexLt } = lib();
  const s = { recoveryBudgetSum: 4, cursorDistance: 0 };
  const s2 = stepLoopback(s, EXPLAIN_IDX); // cursor jumps back; distance grows
  assert.ok(lexLt(measureM(s2), measureM(s)), "loopback strictly decreases M (1st component dominates)");
  assert.equal(s2.recoveryBudgetSum, s.recoveryBudgetSum - 1, "loopback consumes exactly one recovery unit");
});

test("termination_no_measure_preserving_step: a no-op / identity transition is rejected", { skip: false }, () => {
  // Property: I-3 regression check — NO Step leaves M fixed; the degenerate
  //   identity/constant-measure witness that made the prior proof VACUOUS is rejected.
  // Proven in: thoughts/lean/Proofs/I3Termination.lean (i3_identity_step_is_rejected, i3_no_measure_preserving_step)
  // proof_strategy: REGRESSION CHECKS: i3_identity_step_is_rejected (NOT Step s s) and i3_no_measure_preserving_step (Step s s' -> M s' =/= M s); no-op fails to type-check against Step's constructors.
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall s s'. Step s s' -> M s' != M s  (and NOT Step s s)
  // fixture_set: assert the step constructors never emit a state with an unchanged measure (probe forward & loopback at one state)
  // unsampled_domain: the full state space; this samples the non-vacuity guard at one point
  const { measureM, stepForward, stepLoopback } = lib();
  const s = { recoveryBudgetSum: 4, cursorDistance: 3 };
  assert.notDeepEqual(measureM(stepForward(s)), measureM(s), "forward must change M");
  assert.notDeepEqual(measureM(stepLoopback(s, EXPLAIN_IDX)), measureM(s), "loopback must change M");
});

test("recovery_budget_bound: total recovery budget is #keys * LOOP_LIMIT = 4", { skip: false }, () => {
  // Property: I-3 substrate grounding — recoveryBudgetSum over keys {s3,s4,s5,s6}
  //   is exactly 4 (each key budget 1, LOOP_LIMIT 1). Bounds the 1st lex component.
  // Proven in: thoughts/lean/Proofs/I3Termination.lean (i3_recovery_bound)
  // proof_strategy: RecoveryBudget s3..s6 each 1, sum = #keys*LOOP_LIMIT = 4 by rfl
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: exists b3..b6. RecoveryBudget s_i b_i /\ b3+b4+b5+b6 = 4
  // fixture_set: the four recovery keys with LOOP_LIMIT=1; assert initial recovery sum == 4
  // unsampled_domain: tuned LOOP_LIMIT values (>1 for the kimmy run); different key sets
  const { initialRecoveryBudgetSum } = lib();
  assert.equal(initialRecoveryBudgetSum(RECOVERY_KEYS, LOOP_LIMIT), 4, "recovery sum = #keys * LOOP_LIMIT = 4");
});

test("explain_always_runs: every terminating run reaches the explain step", { skip: false }, () => {
  // Property: I-1 — forall run r. Terminates r -> ReachesExplain r.
  // Proven in: thoughts/lean/Proofs/I1Liveness.lean (i1_explain_always_runs)
  // proof_strategy: liveness: intro+cases on single-constructor Run/Terminates -> ReachesExplain
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall terminating runs, the run reaches explain
  // fixture_set: an all-clean terminating run; assert the trail's last stage is explain
  // unsampled_domain: hard-stop terminating paths (sampled in Phase B crit 8), non-terminating inputs (excluded by I-3)
  const fakeAgent = makeFakeAgent({ allClean: true });
  const { runPipeline } = lib();
  const result = runPipeline({ agent: fakeAgent, clock: frozenClock(), rng: () => 0 });
  const explainRuns = result.trail.filter((e) => e.kind === "stage" && e.stage === "explain");
  assert.ok(explainRuns.length >= 1, "a terminating run reaches the explain step");
});

test("explain_is_terminal: explain has no successor stage", { skip: false }, () => {
  // Property: I-1 — forall stage s. NOT StageOrder explain s (explain is the unique terminal).
  // Proven in: thoughts/lean/Proofs/I1Liveness.lean (i1_explain_is_terminal)
  // proof_strategy: terminality: exhaust (cases) on StageOrder .explain _ (no successor constructor)
  // test_category: projection
  // ontology_label: prescriptive
  // negation_provenance: absent   (CWA-fragile)
  // sampled_from: forall s. NOT StageOrder explain s
  // fixture_set: query the stage-order successor of explain; assert none exists
  // unsampled_domain: n/a (explain is the unique terminal stage)
  const { stageSuccessor } = lib();
  assert.equal(stageSuccessor("explain"), null, "explain has no successor — it is terminal");
});

// =============================================================================
// Phase B — Behavioral Contracts.
// No upstream proof — Lean cannot state runtime I/O / state / control-flow
// routing / timing. A failing test here indicates a CONTRACT gap, not a broken
// invariant; loopback STOPS at the TDD layer (does not return to decompose/prove).
// These omit proof_strategy / ontology_label / sampled_from / fixture_set /
// unsampled_domain / negation_provenance by contract.
// Implements §9 crit 1, 2, 4 (digest routing), 9, 10, 11 + C-1 determinism.
// Last; may stay red longer.
// =============================================================================

test("crit1_gaps_merged_by_target_stage: gaps sharing a target stage merge (params merged); distinct targets stay apart", { skip: false }, () => {
  // test_category: behavioral_claim
  // Runtime control-flow behaviour (gap batching) — Lean has no representation
  // for the digest's gap list or its merge semantics (D-3, §9 crit 1).
  const { mergeGaps } = lib();
  const merged = mergeGaps([
    { targetStage: "model_obligations", gapClass: "schema_insufficient", params: { a: 1 } },
    { targetStage: "model_obligations", gapClass: "schema_insufficient", params: { b: 2 } },
    { targetStage: "decompose", gapClass: "unfixturable", params: { c: 3 } },
  ]);
  assert.equal(merged.length, 2, "two gaps with the same target stage merge into one; distinct target stays apart");
  const moGap = merged.find((g) => g.targetStage === "model_obligations");
  assert.deepEqual(moGap.params, { a: 1, b: 2 }, "merged gaps combine their parameters");
});

test("crit2_recovery_capped_per_gap_class_per_stage: LOOP_LIMIT recoveries, then no more", { skip: false }, () => {
  // test_category: behavioral_claim
  // Runtime loop-limit accounting against the decision trail (D-7, §9 crit 2).
  // Lean's I-3 bounds the MEASURE; the per-gap-class-per-stage CAP as observed
  // runtime behaviour is a TDD-layer contract.
  const { withinLoopLimit } = lib();
  const trail = [{ kind: "loopback", gapClass: "schema_insufficient", targetStage: "model_obligations" }];
  // LOOP_LIMIT=1 already consumed for this (class,stage) -> further recovery refused.
  assert.equal(withinLoopLimit(trail, "schema_insufficient", "model_obligations"), false, "recovery capped at LOOP_LIMIT per gap-class-per-stage");
  // A DIFFERENT (class,stage) pair still has budget.
  assert.equal(withinLoopLimit(trail, "unfixturable", "decompose"), true, "a distinct gap-class/stage retains its own budget");
});

test("crit4_digest_routing_advance_loopback_halt: substrate branches ONLY on agent-emitted digest fields (C-2)", { skip: false }, () => {
  // test_category: behavioral_claim
  // The C-2 inversion-smell guard. The disprove gate ABSTAINED on C-2 and flagged
  // it for re-attack against the realized substrate — so this asserts the substrate
  // READS the verdict/status/gaps from the digest and NEVER computes provable/
  // refuted/inconsistent itself. Lean cannot state "does not compute a verdict".
  const { routeDigest } = lib();
  const state = { cursor: 4, scope: { startIdx: 0, endIdx: EXPLAIN_IDX }, trail: [] };
  assert.equal(routeDigest(state, cleanDigest("prove_invariants")).action, "advance", "clean digest -> advance cursor");
  assert.equal(routeDigest(state, gapDigest("prove_invariants", "model_obligations", "unprovable")).action, "loopback", "honored gap -> loop back");
  assert.equal(routeDigest(state, haltDigest("prove_invariants", "core_obligation_refuted", true)).action, "halt", "halt status -> halt");
  // C-2: routeDigest must derive its action from digest fields, not from inspecting
  // artifact CONTENT. A digest with status 'ok' and no gaps cannot be re-judged as refuted.
  const ambiguous = { stage: "prove_invariants", status: "ok", verdict: null, gaps: [], coreObligation: false, artifactContent: "looks unprovable" };
  assert.equal(routeDigest(state, ambiguous).action, "advance", "substrate must NOT compute a verdict from artifact content (C-2)");
});

test("crit9_hard_stop_on_core_obligation_refutation", { skip: false }, () => {
  // test_category: behavioral_claim
  // Runtime termination behaviour on an agent-emitted core-obligation refutation
  // (D-5, §9 crit 9). The refutation VERDICT is agent-emitted; the substrate only
  // routes on the coreObligation flag.
  const fakeAgent = makeFakeAgent({ haltAt: "prove_invariants", reason: "core_obligation_refuted", coreObligation: true });
  const { runPipeline } = lib();
  const result = runPipeline({ agent: fakeAgent, clock: frozenClock(), rng: () => 0 });
  assert.equal(result.outcome, "hard_stop", "core-obligation refutation hard-stops the run");
  assert.equal(result.reason, "core_obligation_refuted");
});

test("crit10_hard_stop_on_loop_limit_exhaustion", { skip: false }, () => {
  // test_category: behavioral_claim
  // Runtime termination on loop-limit exhaustion (D-5/D-7, §9 crit 10). The
  // LOOP_LIMIT accounting is the substrate's; the gap signal is agent-emitted.
  const fakeAgent = makeFakeAgent({ repeatGap: { targetStage: "model_obligations", gapClass: "schema_insufficient" } });
  const { runPipeline } = lib();
  const result = runPipeline({ agent: fakeAgent, clock: frozenClock(), rng: () => 0 });
  assert.equal(result.outcome, "hard_stop", "exhausting LOOP_LIMIT hard-stops the run");
  assert.equal(result.reason, "loop_limit_exhausted");
});

test("crit8_explain_runs_exactly_once_last_on_hard_stop_paths_too", { skip: false }, () => {
  // test_category: behavioral_claim
  // Crit 8 has a PROJECTION half (I-1 liveness, sampled above on the happy path)
  // and this BEHAVIORAL half: explain runs EXACTLY ONCE, LAST, on every HARD-STOP
  // path as well — a runtime sequencing guarantee over the trail that Lean's I-1
  // (reachability) does not state (it asserts reaches-explain, not exactly-once-last-on-halt).
  const fakeAgent = makeFakeAgent({ haltAt: "prove_invariants", reason: "core_obligation_refuted", coreObligation: true });
  const { runPipeline } = lib();
  const result = runPipeline({ agent: fakeAgent, clock: frozenClock(), rng: () => 0 });
  const stages = result.trail.filter((e) => e.kind === "stage").map((e) => e.stage);
  const explainCount = stages.filter((s) => s === "explain").length;
  assert.equal(explainCount, 1, "explain runs exactly once, even on a hard-stop path");
  assert.equal(stages[stages.length - 1], "explain", "explain runs LAST");
});

test("crit11_auditable_decision_trail_is_complete", { skip: false }, () => {
  // test_category: behavioral_claim
  // The decision trail is an emitted side-effect (D-5, §9 crit 11) — every cursor
  // move, loopback, gap-merge, disprove attempt, and halt is logged. Lean cannot
  // state "a complete log was emitted".
  const fakeAgent = makeFakeAgent({ allClean: true });
  const { runPipeline } = lib();
  const result = runPipeline({ agent: fakeAgent, clock: frozenClock(), rng: () => 0 });
  assert.ok(Array.isArray(result.trail) && result.trail.length > 0, "a decision trail is emitted");
  for (const entry of result.trail) {
    assert.ok(typeof entry.kind === "string" && entry.kind.length > 0, "every trail entry is typed/auditable");
  }
});

test("crit_C1_determinism_no_wallclock_no_randomness_branch", { skip: false }, () => {
  // test_category: behavioral_claim
  // C-1 determinism guard from REFUTATION_SHAPE_BRIEFING: two runs with DIFFERENT
  // injected clocks and RNGs must produce the IDENTICAL decision trail — proving no
  // control decision branches on wall-clock or randomness. Lean cannot state
  // "ignores the wall clock"; this is a runtime determinism contract.
  const { runPipeline } = lib();
  const a = runPipeline({ agent: makeFakeAgent({ allClean: true }), clock: () => 1000, rng: () => 0.1 });
  const b = runPipeline({ agent: makeFakeAgent({ allClean: true }), clock: () => 9999, rng: () => 0.9 });
  assert.deepEqual(a.trail, b.trail, "trail is identical across different clock/rng — no wall-clock/randomness branch (C-1)");
});

// -----------------------------------------------------------------------------
// Injected fake collaborators (D-11). These substitute for real agents / Lean /
// effectful collaborators so the pure mechanics are exercised in isolation.
// Defined after the tests for readability; hoisted by `function` declarations.
// -----------------------------------------------------------------------------

function frozenClock() {
  // A clock the substrate must NEVER branch on (C-1). Returns a constant.
  return () => 0;
}

function makeFakeAgent(opts = {}) {
  // Returns a fake agent whose .runStage(stage, ctx) yields a deterministic digest.
  // - allClean: every stage returns a clean digest.
  // - haltAt/reason/coreObligation: the named stage returns a halt digest.
  // - repeatGap: the named stage always re-emits the same gap (drives loop-limit).
  let gapEmitted = 0;
  return {
    runStage(stage /*, ctx */) {
      if (opts.haltAt === stage) return haltDigest(stage, opts.reason || "halt", !!opts.coreObligation);
      if (opts.repeatGap && stage === opts.repeatGap.targetStage) {
        gapEmitted += 1;
        return gapDigest(stage, opts.repeatGap.targetStage, opts.repeatGap.gapClass);
      }
      return cleanDigest(stage);
    },
    // Disprove agent contract: returns an attempt with >=2 distinct adversaries.
    runDisprove(spec) {
      return {
        target: spec.gateTarget || "gate_target_descriptor",
        ownOutput: spec.ownOutput || "disproof_results",
        spend: Math.max(spec.reserve || 1, 1),
        reserve: spec.reserve || 1,
        parallel: true,
        adversaries: [{ id: "adv1" }, { id: "adv2" }],
      };
    },
  };
}

// =============================================================================
// LOOPBACK SIGNALS
// Each entry names the upstream skill to revisit and the trigger.
//
// (none this run)
//   All necessity lemmas are PROVEN (necessity_lemma_status(_, _, proven) for
//   p_v1_i4 and p_v1_i5 — no `extraneous`), so there is no extraneous-counterfactual
//   prune signal. No INSUFFICIENT conditional proof (all 7 theorems `proven`,
//   axiom-free). claim_negation_provenance (hypothesis.pl) and provenance_annotation
//   (lean_proof_results.pl) AGREE on every negated premise (I-4 scope_narrows_mid_run
//   = contradicts both sides; I-5 disprove_attacks_own_output / disprove_spends_below_reserve
//   = contradicts both sides) — no provenance_disagreement loopback to prove-invariants.
// =============================================================================

// =============================================================================
// COVERAGE GAPS
// Advisory only — these do NOT loop back. The implementor handles them manually.
//
// GAP: universality loss (lean -> tdd boundary, every projection test)
//   Reason: each projection samples a forall-property at ONE fixture. The unsampled
//     domain is recorded per-test in the `unsampled_domain:` tag. The Lean proof
//     remains the authority on universality; these tests are tripwires, not re-proofs.
//   Suggested approach: for the bounded enum domains (Stage, DisproveSurface,
//     Adversary) consider exhaustive parameterized tests; for the unbounded Nat
//     domains of I-3 (recoveryBudgetSum, cursorDistance) a property-based testing
//     library (e.g. fast-check) would sample more of the (rb,d) state space.
//
// GAP: CWA-fragile projections (negation_provenance: absent)
//   Affected: I-1 (explain liveness + terminality), I-2 (gating + ungated base),
//     I-3 (all termination/measure tests), I-6 (floor), I-7 (fanout) — every
//     prescriptive-obligation theorem (provenance_annotation(_, _, absent)).
//   Reason: these rest on closed-world COMPLETENESS of the spec model — the proof
//     holds only to the extent the close-world KB enumerated every stage/transition.
//     An omitted stage-order edge or disprove move would yield a vacuously-green test.
//   Suggested approach: pair with the kb-validator / cwa-fragility-auditor on the
//     self-spec KB (spec §8 close-world-fidelity risk) before trusting green.
//   NOTE: the I-4 and I-5 projections are NOT in this gap — they are
//     negation_provenance: contradicts (structurally necessary, KB-completeness-independent).
//
// GAP: I-3 well-foundedness is asserted structurally, not as an executed fixpoint
//   Reason: stepForward/stepLoopback witness ONE strict-decrease each; the tests do
//     not run an unbounded transition sequence to observe actual halting.
//   Suggested approach: an integration test driving runPipeline through the maximal
//     4 loopbacks (recovery budget) + the forward chain, asserting it halts.
//
// GAP: parallelism is asserted by an `parallel: true` flag, not real concurrency
//   Affected: I-7 fanout, D-9 parallel-map (prove/instantiate/model per-item).
//   Reason: node:test exercises pure mechanics with fakes (D-11); real parallel
//     dispatch + Lean concurrency sub-cap (D-10) is integration-level.
//   Suggested approach: an integration harness that dispatches real (or timed-fake)
//     adversaries and asserts overlap; out of scope for the pure-mechanics suite.
//
// GAP: behavioral_claim tests have NO upstream formal backing
//   Affected: crit 1, 2, 4 (digest routing/C-2), 8 (hard-stop half), 9, 10, 11, C-1.
//   Reason: these assert runtime I/O / state / control-flow that no Lean theorem
//     expresses (the GAIN crossing the lean->tdd boundary). A red one is a contract
//     gap, not an invariant violation — it does not loop back upstream.
//   Suggested approach: review with the spec author; crit-4/C-2 is the inversion-smell
//     re-attack surface the disprove gate ABSTAINED on — scrutinize that the realized
//     substrate truly branches only on digest fields.
// =============================================================================
