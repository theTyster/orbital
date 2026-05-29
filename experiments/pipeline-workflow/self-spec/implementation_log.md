# Implementation log — realize-specification (Stage 6)

Target: `experiments/pipeline-workflow/` — the deterministic, background-executable
Workflow realizing the orbital-shifting pipeline orchestration, driven from
`thoughts/tests/orbital_pipeline.proof_properties.test.js` (the spec/contract).

Runner: `node --test "thoughts/tests/**/*.test.js"` (Node 26; the bare-directory
form `thoughts/tests/` fails with a module-resolution error on Node 26 — the glob
form is the equivalent invocation and is used throughout).

Baseline: 24 tests, 0 pass, 0 fail, 24 skipped.

Modules created (pure mechanics, injected effects per D-11):
- `schemas/stage-digest.schema.js` — D-3 digest shape (status / verdict / gaps-tagged-with-target / coreObligation), routable-field allowlist (C-2), hard-stop reasons.
- `lib/scope-set.js` — `widenScope` (C-4 / I-4 monotone).
- `lib/disprove-reserve.js` — `planDisproveAttempt` (C-3/C-5, I-5/I-6/I-7).
- `lib/termination-measure.js` — `measureM`/`lexLt`/`stepForward`/`stepLoopback`/`initialRecoveryBudgetSum` (I-3).
- `lib/stage-order.js` — `canRunStage`/`stageSuccessor`/`requiredUpstream` (I-1/I-2).
- `lib/gap-batching.js` — `mergeGaps` (D-3, crit 1).
- `lib/loop-limit.js` — `withinLoopLimit` (D-7, crit 2).
- `lib/digest-router.js` — `routeDigest` (D-4, C-2, crit 4) — branches ONLY on digest fields.
- `lib/decision-trail.js` — `createTrail` (D-5, crit 11).
- `orbital-pipeline.workflow.js` — `runPipeline` orchestration loop + the single import seam re-exporting every mechanic.

## Chronological per-test record

1. **scope_narrowing_fact_absent** — projection — `widenScope` returns `min(start, target)`, endIdx fixed. PASS.
2. **scope_narrowing_reintroduced_breaks_monotonicity** — projection — narrowing request (target > start) leaves startIdx unchanged; guard never raises it. PASS.
3. **self_attack_fact_absent** — projection — `planDisproveAttempt` selects gateTarget != ownOutput. PASS.
4. **below_reserve_fact_absent** — projection — `spend = max(reserve, opportunistic, 1) >= reserve`. PASS.
5. **below_reserve_reintroduced_breaks_reserve** — projection — availableBudget 0 still yields spend >= reserve (mandatory attempt protects reserve). PASS.
6. **self_attack_reintroduced_breaks_no_self_attack** — projection — candidateTargets filtered to exclude ownOutput; first remaining selected. PASS.
   (after Phase 0: 6 pass / 0 fail / 18 skip)
7. **artifact_gating** — projection — `canRunStage` requires immediate predecessor in produced-set. PASS.
8. **close_world_ungated** — projection — close_world has empty `requiredUpstream` -> runnable cold. PASS.
9. **disprove_floor** — projection — `runPipeline` records the mandatory disprove attempt before the stage loop; trail has >=1 `disprove_attempt`. PASS.
10. **disprove_fanout** — projection — `planDisproveAttempt` returns >=2 distinct adversaries, `parallel: true`. PASS.
    (after Phase 1: 10 pass / 0 fail / 14 skip)
11. **termination_forward_step_decreases_measure** — projection — `stepForward` drops cursorDistance, leaves recoveryBudgetSum; `lexLt` confirms. PASS.
12. **termination_loopback_step_decreases_measure** — projection — `stepLoopback` decrements recoveryBudgetSum by exactly 1 (1st lex component dominates). PASS.
13. **termination_no_measure_preserving_step** — projection — both steps change M (non-vacuity). PASS.
14. **recovery_budget_bound** — projection — `initialRecoveryBudgetSum(keys, 1) = #keys = 4`. PASS.
15. **explain_always_runs** — projection — trail records `stage:"explain"` post-loop unconditionally. PASS.
16. **explain_is_terminal** — projection — `stageSuccessor("explain") === null`. PASS.
    (after Phase 2: 16 pass / 0 fail / 8 skip)
17. **crit1_gaps_merged_by_target_stage** — behavioral_claim — `mergeGaps` keys on targetStage, shallow-merges params; distinct targets apart. PASS.
18. **crit2_recovery_capped_per_gap_class_per_stage** — behavioral_claim — `withinLoopLimit` counts loopbacks per (gapClass, stage); LOOP_LIMIT=1. PASS.
19. **crit4_digest_routing_advance_loopback_halt** — behavioral_claim — `routeDigest` reads status/gaps only; `artifactContent` deliberately ignored (C-2 no inversion). PASS.
20. **crit9_hard_stop_on_core_obligation_refutation** — behavioral_claim — halt digest -> outcome `hard_stop`, reason `core_obligation_refuted`. PASS.
21. **crit10_hard_stop_on_loop_limit_exhaustion** — behavioral_claim — repeated same-class gap exceeds LOOP_LIMIT -> `hard_stop` / `loop_limit_exhausted`. PASS.
22. **crit8_explain_runs_exactly_once_last_on_hard_stop_paths_too** — behavioral_claim — explain recorded once, post-loop, after a break -> last and exactly once. PASS.
23. **crit11_auditable_decision_trail_is_complete** — behavioral_claim — every trail entry carries a non-empty `kind`. PASS.
24. **crit_C1_determinism_no_wallclock_no_randomness_branch** — behavioral_claim — clock/rng threaded only to the agent surface, never to a control decision -> identical trail across different clock/rng. PASS.
    (after Phase B: 24 pass / 0 fail / 0 skip)

## Final

`node --test "thoughts/tests/**/*.test.js"`:
tests 24 · suites 0 · pass 24 · fail 0 · cancelled 0 · skipped 0 · todo 0

No tests weakened. No halt/blocked condition. C-1 (determinism), C-2 (no inversion —
substrate branches only on digest fields), C-4 (monotone scope), D-4/D-5/D-7/D-8
all embodied in the mechanics rather than computed.
