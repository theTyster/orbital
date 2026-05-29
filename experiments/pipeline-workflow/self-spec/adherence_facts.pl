% =============================================================================
% adherence_facts.pl  — measure-entailment (Stage 7 of 7), pipeline-terminal mode
%
% Prime: thoughts/hypothesis.pl (loaded DIRECTLY into the swipl session for the
% label-aware verdict pass; the documented measure_entailment_hypothesis_direct_load
% exception to the carrier-only rule).
%
% Resource ids:
%   impl  — the implemented Workflow under experiments/pipeline-workflow/
%           (orbital-pipeline.workflow.js + lib/*.js + schemas/*.js), the thing
%           being scored. Claims are what the SOURCE actually asserts.
%   hyp   — the structural target the §1 proposition asserts (the descriptive +
%           prescriptive-invariant surface), expressed in the SAME predicate
%           vocabulary as impl so structural overlap is measurable. This mirrors
%           hypothesis.pl's intended target world; it is NOT the label carrier.
%
% Extraction stance (bias-isolation): these rows record what each resource
% ASSERTS. A low adherence score would be a valid result. Predicate names are
% shared across impl/hyp ONLY where the claim is structurally the same.
%
% Pattern 3 surface (label-aware): the impl resource MUST NOT assert any of the
% ten forbidden counterfactual premise atoms (control_decision_on_wallclock_or_random,
% orchestration_layer_computes_logic_verdict, self_orchestration_framing,
% orchestration_is_a_skill, scope_narrows_mid_run, disprove_attacks_own_output,
% disprove_spends_below_reserve, human_prompt_mid_run,
% realize_specification_runs_parallel). It asserts none — confirmed against source.
% =============================================================================

% ---- Resource: hyp  (the §1 target world, structural surface) ----------------
% D-1 / D-2: orchestration is a deterministic Workflow script; authority split.
asserts(hyp, orchestration_realized_as(workflow_script)).
asserts(hyp, authority_split(mechanics, substrate)).
asserts(hyp, authority_split(judgment, agents)).
% D-8 / I-1: explain is the unique terminal closer; total order close_world..explain.
asserts(hyp, terminal_stage(explain)).
asserts(hyp, stage_successor(explain, none)).
asserts(hyp, total_stage_order(close_world, explain)).
% I-2: gating — no stage runs before its upstream artifact exists; close_world ungated.
asserts(hyp, gating_required(true)).
asserts(hyp, ungated_base_stage(close_world)).
% I-3: termination via lexicographic measure M = (recoveryBudgetSum, cursorDistance).
asserts(hyp, termination_measure(lexicographic, [recovery_budget_sum, cursor_distance])).
asserts(hyp, measure_strictly_decreases(forward_step)).
asserts(hyp, measure_strictly_decreases(loopback_step)).
asserts(hyp, measure_non_vacuous(no_identity_step)).
asserts(hyp, recovery_budget_bound(keys_times_loop_limit)).
% I-4 / C-4: monotone scope — startIdx non-increasing, endIdx fixed.
asserts(hyp, scope_monotone(start_idx, non_increasing)).
asserts(hyp, scope_fixed(end_idx)).
% I-5 / C-3: disprove reserve discipline.
asserts(hyp, disprove_spend_at_or_above_reserve(true)).
asserts(hyp, disprove_target_never_own_output(true)).
% I-6: >=1 disprove attempt per run.
asserts(hyp, disprove_attempts_per_run_floor(1)).
% I-7 / C-5: >=2 adversaries in parallel per attempt.
asserts(hyp, disprove_adversaries_per_attempt_floor(2)).
asserts(hyp, disprove_adversaries_parallel(true)).
% D-7 / C-5: LOOP_LIMIT = 1 recovery per gap-class-per-stage.
asserts(hyp, loop_limit(1)).
asserts(hyp, loop_limit_keyed_on(gap_class, stage)).
% crit 1 / D-3: gaps merge by target stage.
asserts(hyp, gap_merge_by(target_stage)).
% D-9: parallel map — provable/testable stages fan out; realize stays serial.
asserts(hyp, realize_specification_serial(true)).
% D-5 / crit 9 / crit 10: hard-stops on core-obligation refutation, loop-limit, budget.
asserts(hyp, hard_stop_reason(core_obligation_refuted)).
asserts(hyp, hard_stop_reason(loop_limit_exhausted)).
asserts(hyp, hard_stop_reason(budget_exhausted)).
% crit 11 / D-5: auditable decision trail.
asserts(hyp, auditable_decision_trail(true)).
% C-2 / D-2: substrate branches only on agent-emitted digest fields, never a verdict.
asserts(hyp, substrate_branches_on(digest_fields_only)).
asserts(hyp, substrate_computes_logic_verdict(false)).
% C-1 / D-11: no control decision on wall-clock or randomness; effects injected.
asserts(hyp, control_decision_on(deterministic_state_and_digest_only)).
asserts(hyp, effects_injected([agent, clock, rng, fs])).
% C-6: background-executable; no human prompt mid-run.
asserts(hyp, background_executable(true)).
% D-13 / existence + D-12 / dogfood: the Workflow must come to exist & be self-verified.
asserts(hyp, workflow_artifact_present(true)).
asserts(hyp, self_verification_completed(true)).

% ---- Resource: impl  (experiments/pipeline-workflow/, what the SOURCE asserts) -
% D-1 / D-2: deterministic Workflow script; mechanics in substrate, judgment in agents.
%   orbital-pipeline.workflow.js header + module split lib/*.js (mechanics only).
asserts(impl, orchestration_realized_as(workflow_script)).
asserts(impl, authority_split(mechanics, substrate)).
asserts(impl, authority_split(judgment, agents)).
% D-8 / I-1: explain recorded post-loop, unconditional; stageSuccessor("explain")===null.
%   orbital-pipeline.workflow.js:155 (trail.record stage explain terminal); stage-order.js:39-43.
asserts(impl, terminal_stage(explain)).
asserts(impl, stage_successor(explain, none)).
asserts(impl, total_stage_order(close_world, explain)).   % STAGE_SEQUENCE frozen 8-chain
% I-2: gating — canRunStage requires immediate predecessor produced; close_world ungated.
%   stage-order.js:50-67; workflow loop guard :83-90.
asserts(impl, gating_required(true)).
asserts(impl, ungated_base_stage(close_world)).
% I-3: termination measure realized concretely. termination-measure.js.
asserts(impl, termination_measure(lexicographic, [recovery_budget_sum, cursor_distance])).
asserts(impl, measure_strictly_decreases(forward_step)).   % stepForward drops cursorDistance
asserts(impl, measure_strictly_decreases(loopback_step)).  % stepLoopback drops recoveryBudgetSum by 1
asserts(impl, measure_non_vacuous(no_identity_step)).      % test 13 both steps change M
asserts(impl, recovery_budget_bound(keys_times_loop_limit)). % initialRecoveryBudgetSum = #keys*LOOP_LIMIT = 4
% I-4 / C-4: monotone scope. scope-set.js widenScope = min(start,target), endIdx preserved.
asserts(impl, scope_monotone(start_idx, non_increasing)).
asserts(impl, scope_fixed(end_idx)).
% I-5 / C-3: disprove reserve discipline. disprove-reserve.js.
asserts(impl, disprove_spend_at_or_above_reserve(true)).   % spend = max(reserve, opportunistic, 1)
asserts(impl, disprove_target_never_own_output(true)).     % chooseTarget filters ownOutput
% I-6: mandatory disprove before the loop. workflow.js:73 runMandatoryDisprove.
asserts(impl, disprove_attempts_per_run_floor(1)).
% I-7 / C-5: >=2 distinct adversaries, parallel:true. disprove-reserve.js:57-63.
asserts(impl, disprove_adversaries_per_attempt_floor(2)).
asserts(impl, disprove_adversaries_parallel(true)).
% D-7 / C-5: LOOP_LIMIT = 1, keyed on (gapClass, targetStage). loop-limit.js.
asserts(impl, loop_limit(1)).
asserts(impl, loop_limit_keyed_on(gap_class, stage)).
% crit 1 / D-3: mergeGaps keys on targetStage. gap-batching.js.
asserts(impl, gap_merge_by(target_stage)).
% D-9: realize-specification serial — no fan-out construct; single mutating loop body.
asserts(impl, realize_specification_serial(true)).
% D-5 / crit 9 / crit 10: hard-stop reasons. stage-digest.schema.js HARD_STOP_REASONS + loop.
asserts(impl, hard_stop_reason(core_obligation_refuted)).
asserts(impl, hard_stop_reason(loop_limit_exhausted)).
asserts(impl, hard_stop_reason(budget_exhausted)).
% crit 11 / D-5: auditable trail; every entry carries non-empty kind. decision-trail.js.
asserts(impl, auditable_decision_trail(true)).
% C-2 / D-2: routeDigest branches only on status/gaps/coreObligation/reason; ignores artifactContent.
%   digest-router.js:30-57; ROUTABLE_FIELDS allowlist schema:28-34.
asserts(impl, substrate_branches_on(digest_fields_only)).
asserts(impl, substrate_computes_logic_verdict(false)).
% C-1 / D-11: clock/rng injected but never threaded into a control decision. workflow.js:55-57.
asserts(impl, control_decision_on(deterministic_state_and_digest_only)).
asserts(impl, effects_injected([agent, clock, rng, fs])).
% C-6: background-executable; no readline / prompt / stdin in the loop.
asserts(impl, background_executable(true)).
% D-13 existence: the Workflow artifact EXISTS on disk (transition from Stage-2 absent).
asserts(impl, workflow_artifact_present(true)).
% D-12 dogfood: this very pipeline run is the self-verification, now completed.
asserts(impl, self_verification_completed(true)).

% NOTE — deliberately NOT asserted for impl (the ten forbidden counterfactual
% premise atoms). Their ABSENCE is what counterfactual_honored/2 detects:
%   control_decision_on_wallclock_or_random   — no Date.now / Math.random in any control path
%   orchestration_layer_computes_logic_verdict — routeDigest reads digest fields only
%   self_orchestration_framing                 — orchestration is a script, not a judging skill
%   orchestration_is_a_skill                   — D-1 honored: it is a Workflow
%   scope_narrows_mid_run                       — widenScope can only lower startIdx
%   disprove_attacks_own_output                 — chooseTarget excludes ownOutput
%   disprove_spends_below_reserve               — spend >= reserve always
%   human_prompt_mid_run                        — no interactive I/O in the loop
%   realize_specification_runs_parallel         — realize stays serial (asserted serial above)

% ---- label-aware result/N facts (appended by label_aware_facts_out/2) ----
result(counterfactual_honored,impl,cf_v1_no_below_reserve,disprove_spends_below_reserve,contradicts).
result(counterfactual_honored,impl,cf_v1_no_human_prompt,human_prompt_mid_run,contradicts).
result(counterfactual_honored,impl,cf_v1_no_randomness_control,control_decision_on_wallclock_or_random,contradicts).
result(counterfactual_honored,impl,cf_v1_no_scope_narrowing,scope_narrows_mid_run,contradicts).
result(counterfactual_honored,impl,cf_v1_no_self_attack,disprove_attacks_own_output,contradicts).
result(counterfactual_honored,impl,cf_v1_no_self_orchestration,self_orchestration_framing,contradicts).
result(counterfactual_honored,impl,cf_v1_no_substrate_verdict,orchestration_layer_computes_logic_verdict,contradicts).
result(counterfactual_honored,impl,cf_v1_no_wallclock_control,control_decision_on_wallclock_or_random,contradicts).
result(counterfactual_honored,impl,cf_v1_orchestration_not_skill,orchestration_is_a_skill,contradicts).
result(counterfactual_honored,impl,cf_v1_realize_not_parallel,realize_specification_runs_parallel,contradicts).
