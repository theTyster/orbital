% model_results.pl
% =============================================================================
% model-obligations (Stage 3 of trajectory:pipeline) — per-property verdicts
%   carrier in : thoughts/hypothesis.pl  (26 claims, 7 formal properties)
%   substrate  : thoughts/target-world.pl (+ thoughts/existing-world.pl)
%   constructed: 2026-05-28
%
% Downstream (instantiate-properties) queries this file with swipl, not prose.
% Schema: ../plugins/shifting/references/pipeline-schema/model-results.md
%
% HEADLINE: all 7 §7 invariants (I-1..I-7) are CONSISTENT in target-world.
% The proposition CAN be realized as written — no core obligation is forced
% inconsistent. No halt. The operational substrate the §7 sketches name was
% DERIVED from decision-level facts (not fabricated); each verdict is
% NON-VACUOUS (every violation rule fires on a deliberately-broken witness).
%
% SELF-CONTAINMENT (2026-05-28 referential-integrity repair): every verdict and
% non-vacuity result below was RE-VALIDATED against target-world.pl loaded
% STANDALONE — no existing-world.pl, no other file co-loaded — because that is
% exactly what prove-invariants (Stage 4) sees: target-world.pl is its SOLE
% carrier. The five decision-level operational predicates the verdict directives
% branch on (stage/2, stage_order/2, is_closer/1, loop_limit/1, disprove_floor/2)
% are now MATERIALIZED verbatim inside target-world.pl. `list_undefined`
% (library(check)) on a standalone consult reports ZERO undefined procedures.
% =============================================================================

:- discontiguous verdict/2, counterexample/2, gap_reason/2, cf_status/2,
                 summary/2, emission_note/2, upstream_gap/3,
                 refutation_shape/2, negation_provenance_carry/2,
                 nonvacuity/2.

% ----- per-property verdicts (source order from hypothesis.pl) -----
verdict(p_v1_i1,consistent).
verdict(p_v1_i2,consistent).
verdict(p_v1_i3,consistent).
verdict(p_v1_i4,consistent).
verdict(p_v1_i5,consistent).
verdict(p_v1_i6,consistent).
verdict(p_v1_i7,consistent).

% ----- counterexamples (present iff inconsistent) -----
% (none — no inconsistent verdicts)

% ----- gap reasons (present iff gap) -----
% (none — no gap verdicts)

% ----- counterfactual minimality (all 9 cf_facts load-bearing) -----
cf_status(cf_fact(control_dep,wallclock_or_random),load_bearing).
cf_status(cf_fact(substrate,computes_logic_verdict),load_bearing).
cf_status(cf_fact(framing,self_orchestration),load_bearing).
cf_status(cf_fact(orchestration,is_a_skill),load_bearing).
cf_status(cf_fact(scope,narrows_mid_run),load_bearing).
cf_status(cf_fact(disprove,attacks_own_output),load_bearing).
cf_status(cf_fact(disprove,spends_below_reserve),load_bearing).
cf_status(cf_fact(human,prompt_mid_run),load_bearing).
cf_status(cf_fact(realize_specification,runs_parallel),load_bearing).

% ----- summary counts -----
summary(verdicts_total, 7).
summary(consistent, 7).
summary(inconsistent, 0).
summary(gap, 0).
summary(extraneous_counterfactuals, 0).
summary(counterfactuals_applied, 9).      % 9 distinct cf_facts (10 cf premises; 2 share control_decision_on_wallclock_or_random)
summary(prescriptive_obligations, 9).     % 7 invariant obligations + 2 CWA-fragile existence/completion claims
summary(operational_predicates_materialized, 7). % Run, Stage(index), cursor, startIdx/endIdx, recoveryBudget, DisproveAttempt, adversaries

% ----- non-vacuity attestation -----
% Each verdict is structural consistency in target-world only
% (lean_universal_neq_test_verified): NOT a universal proof, NOT a test pass.
% Anti-vacuity check: each per-property violation rule was probed with a
% deliberately-broken witness and CONFIRMED to fire — so a `consistent` verdict
% means "no counterexample found in a world where one COULD be found," not
% "the rule was empty." This probe was RE-RUN with target-world.pl loaded
% STANDALONE (the prove-invariants carrier view); all 7 rules still fire, so the
% grounding does not depend on existing-world.pl being co-loaded. Witness that
% fired each rule:
nonvacuity(p_v1_i1, fires_on(run_does_not_reach_explain(rbad))).
nonvacuity(p_v1_i2, fires_on(gates_on_future_artifact(s2, art(s7)))).
nonvacuity(p_v1_i3, fires_on(recovery_sum_exceeds_bound(103, 4))).
nonvacuity(p_v1_i4, fires_on(scope_narrowed(r0, 0, 3, 0, 5))).
nonvacuity(p_v1_i5, fires_on(spends_below_reserve(abad, 0, 1))).
nonvacuity(p_v1_i6, fires_on(run_below_attempt_floor(rzero, 0, 1))).
nonvacuity(p_v1_i7, fires_on(attempt_below_adversary_floor(alone, 1, 2))).

% ----- negation-provenance carry-forward (for prove-invariants @ Prolog->Lean) -----
% The provenance distinction MUST be preserved into Lean. `contradicts` premises
% are structurally necessary (the spec explicitly negates them); `absent`
% premises are CWA-fragile — Lean MUST NOT lift them to a proven negation.
% CWA-absent != Lean-disproved (cwa_negation_neq_lean_proof).
negation_provenance_carry(control_decision_on_wallclock_or_random, contradicts).
negation_provenance_carry(orchestration_layer_computes_logic_verdict, contradicts).
negation_provenance_carry(self_orchestration_framing, contradicts).
negation_provenance_carry(orchestration_is_a_skill, contradicts).
negation_provenance_carry(scope_narrows_mid_run, contradicts).
negation_provenance_carry(disprove_attacks_own_output, contradicts).
negation_provenance_carry(disprove_spends_below_reserve, contradicts).
negation_provenance_carry(human_prompt_mid_run, contradicts).
negation_provenance_carry(realize_specification_runs_parallel, contradicts).
negation_provenance_carry(workflow_artifact_exists_on_disk, absent).        % CWA-FRAGILE
negation_provenance_carry(self_verification_run_completed, absent).         % CWA-FRAGILE

% ----- refutation-shape briefing (carry-forward for downstream disprove) -----
% The orchestrator's refutation_shape_briefing, threaded forward so the
% disprove gate / measure-entailment can attack the right surfaces.
refutation_shape(determinism_breakage,
    "any branch keyed on wall-clock/randomness (C-1); contrast D-10's deterministic maxHeartbeats. Surface: p_v1_i3 substrate, op_measure_* must not read a clock.").
refutation_shape(inversion_smell,
    "substrate computing a logic verdict itself (C-2, the R1-refuted shape). Surface: any op_* fact that encodes a verdict the substrate would compute rather than receive from an agent.").
refutation_shape(scope_non_monotonicity,
    "C-4 / I-4. Surface: p_v1_i4 / StartIdxCF1 — a later step with a strictly larger startIdx re-violates; the cf removal is contradicts (structurally necessary).").
refutation_shape(disprove_floor_fanout_failure,
    "I-6 / C-5 / I-7. Surface: p_v1_i6 (a run with 0 attempts) / p_v1_i7 (an attempt with <2 adversaries or non-parallel).").
refutation_shape(liveness_gating_failure,
    "I-1 explain liveness, I-2 artifact-gating, I-3 termination of the cursor loop under measure M. Surface: p_v1_i1 / p_v1_i2 / p_v1_i3.").

% ----- Pattern-3 watch (primary refutation surface for these descriptors) -----
% A counterfactually-removed fact that the IMPLEMENTATION still asserts is a
% Pattern-3 violation. The 9 load-bearing cf_facts above are the watch list;
% measure-entailment (Stage 7) checks each against the realized Workflow.

% ----- emission note (dual emission) -----
% target-world-shape.lean WAS emitted (closed domains present: Stage,
% RecoveryKey, DisproveAttempt, Adversary, Run, DisproveSurface). prove-invariants
% consumes it directly; the StartIdxCF1 CF-augmented predicate carries I-4's
% necessity lemma. No open-string-only ticket condition, so no omission note.
emission_note(target_world_shape, emitted_closed_domains_present).

% ----- emission note (self-containment) -----
% target-world.pl is now SELF-CONTAINED: it is the sole carrier prove-invariants
% reads, and a standalone consult (no existing-world.pl) resolves every
% operational procedure with zero `Unknown procedure` errors. The five
% decision-level predicates the verdict directives branch on — stage/2,
% stage_order/2, is_closer/1, loop_limit/1, disprove_floor/2 — were materialized
% verbatim into target-world.pl (copied, same args/values, tagged
% provenance(_, descriptive)). Validation: list_undefined reports none; all 7
% verdict(p_v1_iN, consistent) facts assert from the in-file directives; all 7
% non-vacuity probes fire — all under a STANDALONE consult.
emission_note(target_world_self_contained, standalone_consult_zero_undefined).

% ----- upstream gaps -----
% NONE. assumption(a_v1_impl_grain) from hypothesis.pl flagged that the §7
% sketches name operational predicates absent from the decision-level KB and
% directed: materialize them, or emit upstream_gap(schema_insufficient) toward
% close-world rather than fabricate. RESOLUTION: every operational predicate
% (Run, Stage index, cursor, startIdx/endIdx, recoveryBudget, DisproveAttempt,
% adversaries) was DERIVED from decision-level facts the spec fixes
% (stage_order/2, loop_limit/1, disprove_floor/2, measure_component/3). No
% predicate required fabrication, so NO schema_insufficient gap is emitted.
% (If a future ticket needs a concrete cursor STEP-TRACE — runtime behavior the
%  decision KB cannot pin — that surfaces at instantiate-properties as a
%  behavioral_claim test, per assumption(a_v1_workflow_runtime_behavioral); it
%  is not a stage-3 gap.)
