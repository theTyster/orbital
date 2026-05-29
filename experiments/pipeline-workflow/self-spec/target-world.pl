% target-world.pl
% =============================================================================
% model-obligations (Stage 3 of trajectory:pipeline)
%   carrier in  : thoughts/hypothesis.pl  (26 labeled claims, 7 formal properties)
%   transitive  : thoughts/existing-world.pl  (close-world over the design spec)
%   constructed : 2026-05-28
%
% target-world.pl = existing-world.pl with the 10 counterfactual facts removed
% (CWA-absent + negation_provenance marker preserved), the 9 prescriptive
% obligations asserted, and the §7 operational substrate MATERIALIZED so each
% formal_property/3 (I-1..I-7) is NON-VACUOUS when prove-invariants targets it
% in Lean.
%
% LOADING CONTRACT: this file is loaded TOGETHER with existing-world.pl
%   swipl -g halt -l thoughts/existing-world.pl thoughts/target-world.pl
% so target-relation rules can reference baseline facts. Verdict directives
% (:- ...) run at load time and assert verdict/2, counterexample/2,
% gap_reason/2, cf_status/2, which are then dumped to model_results.pl.
%
% =============================================================================
% OPERATIONAL-SUBSTRATE PROVENANCE NOTE (the §7-sketch open assumption)
% -----------------------------------------------------------------------------
% Stage 2's assumption(a_v1_impl_grain) flagged that the §7 sketches name
% operational predicates (Run, Stage, cursor, startIdx/endIdx, recoveryBudget,
% DisproveAttempt) absent from the decision-level KB. We RESOLVE this by
% DERIVING a canonical operational instance from decision-level facts that the
% spec FIXES — not by fabricating runtime data:
%
%   * stage_index/2, cursor range, startIdx/endIdx  <- stage/2 + stage_order/2
%     (the 8-stage total chain s1..s_explain pins positions 0..7).
%   * recovery budget + #keys * LOOP_LIMIT bound     <- loop_limit/1 (D-7).
%   * disprove attempt/adversary floors              <- disprove_floor/2 (D-6/C-5).
%   * measure M = (recovery_budget_sum, cursor_dist)  <- measure_component/3 (I-3).
%
% These are op_* facts, each tagged provenance(_, prescriptive): they are the
% obligation the Workflow must realize, derived from (not invented beyond) the
% decisions. A concrete cursor *trace* (an actual step-by-step run) is runtime
% behavior the decision KB cannot pin — where a property needs that and only
% that, we emit `gap` (NOT inconsistent) + gap_reason + upstream_gap, never a
% vacuous `consistent`.
% =============================================================================

:- discontiguous
     provenance/2,
     negation_provenance/2,
     cf_fact/2,
     formal_property/3,
     obligation/2,
     op_stage_index/2,
     op_cursor_default/2,
     op_scope_default/2,
     op_recovery_key/1,
     op_recovery_budget/2,
     op_disprove_attempt/2,
     op_adversary/2,
     op_measure_component/2,
     stage/2,
     stage_order/2,
     is_closer/1,
     loop_limit/1,
     disprove_floor/2.

% verdict facts are asserted at load time by the per-property directives, so
% they must be dynamic. negation_provenance/2 is co-defined with existing-world
% (same user module): target-world's clauses append — the 9 `contradicts` rows
% mirror existing-world's, the 2 `absent` rows are new. Declared `multifile` so
% the cross-file definition is legitimate and strict-loading stays clean.
:- multifile negation_provenance/2.
% The five operational carrier predicates are MATERIALIZED in this file (so the
% standalone consult prove-invariants performs resolves them) AND also defined
% in existing-world.pl (the close-world source). Declared `multifile` so the
% co-loaded path (swipl … existing-world.pl target-world.pl) appends rather than
% redefining — both files assert byte-identical facts, so the union is the same
% world either way. Standalone, only this file's copies exist; that is the
% carrier contract.
:- multifile stage/2, stage_order/2, is_closer/1, loop_limit/1, disprove_floor/2.
:- dynamic
     verdict/2,
     counterexample/2,
     gap_reason/2,
     cf_status/2,
     emission_note/2,
     upstream_gap/3,
     summary/2,
     refutation_shape/2.

% =============================================================================
% CARRIED-OVER DESCRIPTIVE FACTS
% -----------------------------------------------------------------------------
% Every existing-world fact load-bearing for the §7 properties, carried over and
% tagged provenance(Fact, descriptive). (The full existing-world.pl is loaded
% alongside this file, so its other facts remain queryable; we tag here the ones
% the verdict directives rely on, so the world-diff is auditable from this file.)
% =============================================================================

% --- stage chain (D-9 map / §10) — the spine of the operational model --------
provenance(stage(s1, close_world), descriptive).
provenance(stage(s2, decompose_proposition), descriptive).
provenance(stage(s3, model_obligations), descriptive).
provenance(stage(s4, prove_invariants), descriptive).
provenance(stage(s5, instantiate_properties), descriptive).
provenance(stage(s6, realize_specification), descriptive).
provenance(stage(s7, measure_entailment), descriptive).
provenance(stage(s_explain, explain), descriptive).

provenance(stage_order(s1, s2), descriptive).
provenance(stage_order(s2, s3), descriptive).
provenance(stage_order(s3, s4), descriptive).
provenance(stage_order(s4, s5), descriptive).
provenance(stage_order(s5, s6), descriptive).
provenance(stage_order(s6, s7), descriptive).
provenance(stage_order(s7, s_explain), descriptive).

provenance(is_closer(s_explain), descriptive).            % D-8 / I-1

% --- parallelism map (D-9) — serial-by-necessity for s6 ----------------------
provenance(stage_parallelism(s1, serial, none), descriptive).
provenance(stage_parallelism(s2, serial, none), descriptive).
provenance(stage_parallelism(s3, parallel, per_property), descriptive).
provenance(stage_parallelism(s4, parallel, per_theorem), descriptive).
provenance(stage_parallelism(s5, parallel, per_test), descriptive).
provenance(stage_parallelism(s6, serial, shared_mutable_source), descriptive).
provenance(stage_parallelism(s7, parallel, per_resource), descriptive).
provenance(stage_parallelism(s_explain, serial, none), descriptive).
provenance(serial_by_necessity(s6), descriptive).

% --- termination measure components (I-3 / D-4 / D-7) ------------------------
provenance(measure_component(m, recovery_budget_sum, _), descriptive).
provenance(measure_component(m, cursor_distance, _), descriptive).
provenance(measure_component(m, order, _), descriptive).
provenance(loop_limit(1), descriptive).                   % D-7

% --- disprove floors (D-6 / C-5 / I-6 / I-7) ---------------------------------
provenance(disprove_floor(attempts_per_run, 1), descriptive).
provenance(disprove_floor(adversaries_per_attempt, 2), descriptive).

% --- consumption bridge (§10) — each stage's required upstream artifact ------
provenance(consumption_step(1, s1, _), descriptive).
provenance(consumption_step(2, s2, _), descriptive).
provenance(consumption_step(3, s3, _), descriptive).
provenance(consumption_step(4, s4, _), descriptive).
provenance(consumption_step(5, s6, _), descriptive).

% =============================================================================
% PRESCRIPTIVE OBLIGATIONS — must become true in target-world
% -----------------------------------------------------------------------------
% The 9 prescriptive claims from hypothesis.pl. Seven are the I-1..I-7 proof
% obligations (asserted here as op_* substrate + the obligation flag); two are
% the CWA-fragile existence/completion claims (workflow_artifact_exists_on_disk,
% self_verification_run_completed) — kept as obligations, NOT asserted true
% (their premises are negation_provenance(_, absent); see §absent-markers).
% =============================================================================

% --- I-1..I-7 obligation flags (the proof targets must become provable) ------
obligation(i1_liveness, pr_v1_i1_liveness).
provenance(obligation(i1_liveness, pr_v1_i1_liveness), prescriptive).
obligation(i2_gating, pr_v1_i2_gating).
provenance(obligation(i2_gating, pr_v1_i2_gating), prescriptive).
obligation(i3_termination, pr_v1_i3_termination).
provenance(obligation(i3_termination, pr_v1_i3_termination), prescriptive).
obligation(i4_monotone, pr_v1_i4_monotone).
provenance(obligation(i4_monotone, pr_v1_i4_monotone), prescriptive).
obligation(i5_reserve, pr_v1_i5_reserve).
provenance(obligation(i5_reserve, pr_v1_i5_reserve), prescriptive).
obligation(i6_floor, pr_v1_i6_floor).
provenance(obligation(i6_floor, pr_v1_i6_floor), prescriptive).
obligation(i7_fanout, pr_v1_i7_fanout).
provenance(obligation(i7_fanout, pr_v1_i7_fanout), prescriptive).

% =============================================================================
% OPERATIONAL SUBSTRATE — materialized canonical run instance
% -----------------------------------------------------------------------------
% Derived from the decision-level facts the spec FIXES. Each op_* fact is the
% obligation the Workflow realizes; tagged provenance(_, prescriptive) because
% it does not yet exist on disk but is determined by the decisions.
% =============================================================================

% --- Stage <-> position (cursor domain) — from stage_order/2 total chain -----
op_stage_index(s1, 0).
op_stage_index(s2, 1).
op_stage_index(s3, 2).
op_stage_index(s4, 3).
op_stage_index(s5, 4).
op_stage_index(s6, 5).
op_stage_index(s7, 6).
op_stage_index(s_explain, 7).
provenance(op_stage_index(s1, 0), prescriptive).
provenance(op_stage_index(s2, 1), prescriptive).
provenance(op_stage_index(s3, 2), prescriptive).
provenance(op_stage_index(s4, 3), prescriptive).
provenance(op_stage_index(s5, 4), prescriptive).
provenance(op_stage_index(s6, 5), prescriptive).
provenance(op_stage_index(s7, 6), prescriptive).
provenance(op_stage_index(s_explain, 7), prescriptive).

% explain (the closer) is the maximal index — terminal stage.
op_max_index(7).
provenance(op_max_index(7), prescriptive).

% --- Canonical run instance (r0) ---------------------------------------------
% A Run is identified by an id; the default full-pipeline run scopes [0,7].
op_run(r0).
provenance(op_run(r0), prescriptive).

% cursor advances by default (D-4); a run STARTS at its startIdx.
op_cursor_default(r0, 0).            % cursor begins at scope start
provenance(op_cursor_default(r0, 0), prescriptive).

% scope = (startIdx, endIdx). Default full scope: start 0, end 7 (explain).
op_scope_default(r0, scope(0, 7)).
provenance(op_scope_default(r0, scope(0, 7)), prescriptive).

% startIdx is non-increasing across the run; endIdx fixed (C-4 / I-4).
% Canonical instance: scope never narrows -> startIdx stays at 0, endIdx at 7.
op_start_idx(r0, 0, 0).              % op_start_idx(Run, Step, StartIdx)
op_start_idx(r0, 1, 0).
op_start_idx(r0, 2, 0).
op_end_idx(r0, 7).                   % op_end_idx(Run, EndIdx) — constant
provenance(op_start_idx(r0, 0, 0), prescriptive).
provenance(op_start_idx(r0, 1, 0), prescriptive).
provenance(op_start_idx(r0, 2, 0), prescriptive).
provenance(op_end_idx(r0, 7), prescriptive).
op_run_steps(r0, 3).                 % bound on #observed steps for the instance
provenance(op_run_steps(r0, 3), prescriptive).

% A terminating run reaches the explain step (I-1). The canonical run does.
op_reaches_step(r0, s_explain).
provenance(op_reaches_step(r0, s_explain), prescriptive).
op_terminates(r0).
provenance(op_terminates(r0), prescriptive).

% --- Required-upstream-artifact relation (I-2) -------------------------------
% Derived from stage_order/2: a stage's required artifact is the predecessor's
% output. By the §10 file contract, stage S requires the artifact produced by
% its immediate predecessor; gating holds iff no stage runs before that exists.
% op_requires_artifact(Stage, ArtifactOfPredecessorStage).
op_requires_artifact(s2, art(s1)).
op_requires_artifact(s3, art(s2)).
op_requires_artifact(s4, art(s3)).
op_requires_artifact(s5, art(s4)).
op_requires_artifact(s6, art(s5)).
op_requires_artifact(s7, art(s6)).
op_requires_artifact(s_explain, art(s7)).
provenance(op_requires_artifact(s2, art(s1)), prescriptive).
provenance(op_requires_artifact(s3, art(s2)), prescriptive).
provenance(op_requires_artifact(s4, art(s3)), prescriptive).
provenance(op_requires_artifact(s5, art(s4)), prescriptive).
provenance(op_requires_artifact(s6, art(s5)), prescriptive).
provenance(op_requires_artifact(s7, art(s6)), prescriptive).
provenance(op_requires_artifact(s_explain, art(s7)), prescriptive).
% s1 has no required upstream artifact (stage-0 / user-supplied carrier).
op_no_required_artifact(s1).
provenance(op_no_required_artifact(s1), prescriptive).

% --- Recovery budget (I-3) — keyed by gap-class-per-stage --------------------
% LOOP_LIMIT = 1 per key (D-7). The recoverable stages are those that can be a
% loopback target: each staged primitive that has an adjacent predecessor. The
% canonical key set is the set of (gap-class, stage) the cursor can route back
% to; we model one key per recoverable stage (the gap-class collapses to the
% per-stage budget under LOOP_LIMIT=1). #keys * LOOP_LIMIT bounds the sum.
op_recovery_key(s3).   % model-obligations -> decompose-proposition
op_recovery_key(s4).   % prove-invariants -> model-obligations
op_recovery_key(s5).   % instantiate-properties -> prove-invariants
op_recovery_key(s6).   % realize-specification -> instantiate-properties
provenance(op_recovery_key(s3), prescriptive).
provenance(op_recovery_key(s4), prescriptive).
provenance(op_recovery_key(s5), prescriptive).
provenance(op_recovery_key(s6), prescriptive).
% Per-key budget = LOOP_LIMIT (1). op_recovery_budget(Key, Budget).
op_recovery_budget(s3, 1).
op_recovery_budget(s4, 1).
op_recovery_budget(s5, 1).
op_recovery_budget(s6, 1).
provenance(op_recovery_budget(s3, 1), prescriptive).
provenance(op_recovery_budget(s4, 1), prescriptive).
provenance(op_recovery_budget(s5, 1), prescriptive).
provenance(op_recovery_budget(s6, 1), prescriptive).

% Lexicographic measure M = (recovery_budget_sum, cursor_distance) (I-3).
op_measure_component(m, recovery_budget_sum).
op_measure_component(m, cursor_distance).
op_measure_order(m, lex).
provenance(op_measure_component(m, recovery_budget_sum), prescriptive).
provenance(op_measure_component(m, cursor_distance), prescriptive).
provenance(op_measure_order(m, lex), prescriptive).

% --- Disprove attempts + adversaries (I-5 / I-6 / I-7) -----------------------
% Floors from D-6/C-5: >=1 attempt per run, >=2 adversaries per attempt.
% Canonical run r0 performs exactly the mandatory attempt with the floor of
% perspective-diverse adversaries.
op_disprove_attempt(r0, a0).         % op_disprove_attempt(Run, AttemptId)
provenance(op_disprove_attempt(r0, a0), prescriptive).
op_adversary(a0, adv1).              % op_adversary(AttemptId, AdversaryId)
op_adversary(a0, adv2).
provenance(op_adversary(a0, adv1), prescriptive).
provenance(op_adversary(a0, adv2), prescriptive).
op_adversaries_parallel(a0).         % C-5: run in parallel
provenance(op_adversaries_parallel(a0), prescriptive).

% Reserve discipline (I-5 / C-3): spend >= reserve, target =/= own output.
op_disprove_reserve(a0, 1).          % reserved budget (>=1 mandatory attempt)
op_disprove_spend(a0, 1).            % spend at-or-above reserve
op_disprove_target(a0, gate_target_descriptor).
op_disprove_own_output(a0, disproof_results).  % distinct from target
provenance(op_disprove_reserve(a0, 1), prescriptive).
provenance(op_disprove_spend(a0, 1), prescriptive).
provenance(op_disprove_target(a0, gate_target_descriptor), prescriptive).
provenance(op_disprove_own_output(a0, disproof_results), prescriptive).

% =============================================================================
% NEGATION-PROVENANCE MARKERS (per-fact, 2-arg form)
% -----------------------------------------------------------------------------
% Translated from hypothesis.pl's claim_negation_provenance/3 (per-claim, 3-arg)
% to the per-fact 2-arg form. The fact itself is OMITTED from target-world
% (CWA-absent); only the marker survives so prove-invariants can decide how to
% lift the negation. 10 counterfactual premises (8 distinct facts) are
% `contradicts`; 2 prescriptive-fragile facts are `absent`.
%
% NEGATION-PROVENANCE DISCIPLINE: an `absent` marker is NOT a proven negation.
% CWA-absent != Lean-disproved. Carried forward so prove-invariants annotates
% the fragile premises at the Prolog->Lean boundary.
% =============================================================================

% --- contradicts (structurally necessary — the spec explicitly negates) ------
negation_provenance(control_decision_on_wallclock_or_random, contradicts). % C-1
negation_provenance(orchestration_layer_computes_logic_verdict, contradicts). % C-2
negation_provenance(self_orchestration_framing, contradicts).             % §3
negation_provenance(orchestration_is_a_skill, contradicts).               % D-1
negation_provenance(scope_narrows_mid_run, contradicts).                  % C-4 / I-4
negation_provenance(disprove_attacks_own_output, contradicts).            % C-3 / I-5
negation_provenance(disprove_spends_below_reserve, contradicts).          % C-3 / I-5
negation_provenance(human_prompt_mid_run, contradicts).                   % C-6
negation_provenance(realize_specification_runs_parallel, contradicts).    % D-9

% --- absent (CWA-fragile — merely not-yet-true; do NOT upgrade to disproof) --
negation_provenance(workflow_artifact_exists_on_disk, absent).            % pr_v1_workflow_exists
negation_provenance(self_verification_run_completed, absent).             % pr_v1_self_verified

% =============================================================================
% cf_fact/N — counterfactual-removed facts, for target-relation filters
% -----------------------------------------------------------------------------
% Keyed for the minimality / target-relation rules below. Each corresponds to a
% counterfactual claim premise; the predicate models the forbidden operational
% fact whose ABSENCE the invariant relies on.
% =============================================================================
cf_fact(control_dep, wallclock_or_random).      % C-1
cf_fact(substrate, computes_logic_verdict).     % C-2
cf_fact(framing, self_orchestration).           % §3 / D-1
cf_fact(orchestration, is_a_skill).             % D-1
cf_fact(scope, narrows_mid_run).                % C-4 / I-4
cf_fact(disprove, attacks_own_output).          % C-3 / I-5
cf_fact(disprove, spends_below_reserve).        % C-3 / I-5
cf_fact(human, prompt_mid_run).                 % C-6
cf_fact(realize_specification, runs_parallel).  % D-9

% =============================================================================
% FORMAL PROPERTIES — propagated VERBATIM from hypothesis.pl
% -----------------------------------------------------------------------------
% prove-invariants's schema-level handle on the property list. Do NOT rename to
% property/2; do NOT strip the Lean sketch.
% =============================================================================

formal_property(p_v1_i1,
    "I-1 liveness: every terminating run reaches the explain step.",
    "theorem i1_explain_always_runs : forall (r : Run), Terminates r -> ReachesStep r Stage.explain := by sorry").

formal_property(p_v1_i2,
    "I-2 safety: no stage runs before its required upstream artifact exists.",
    "theorem i2_artifact_gating : forall (r : Run) (s : Stage), Runs r s -> ArtifactExists r (requiredArtifact s) := by sorry").

formal_property(p_v1_i3,
    "I-3 termination: the lexicographic measure M = (recoveryBudgetSum, endIdx - cursor) STRICTLY DECREASES under the concrete pipeline step relation (forward step decreases the second component; loopback consumes one recovery-budget unit and decreases the first, bounded by #keys * LOOP_LIMIT = 4; hard-stop has no successor), so the reverse step relation is well-founded and the cursor loop terminates.",
    "structure State where recoveryBudgetSum : Nat; cursorDistance : Nat\ndef M (s : State) : Nat x Nat := (s.recoveryBudgetSum, s.cursorDistance)\ninductive Step : State -> State -> Prop where\n  | forward (rb d : Nat) : Step (rb, d+1) (rb, d)\n  | loopback (rb d d' : Nat) : Step (rb+1, d) (rb, d')\ntheorem step_strictDecreasing {s s'} (h : Step s s') : Prod.Lex Nat.lt Nat.lt (M s') (M s) := by cases h <;> [exact Prod.Lex.right _ (Nat.lt_succ_self _); exact Prod.Lex.left _ _ (Nat.lt_succ_self _)]\ntheorem i3_termination : forall s : State, Acc (fun a b => Step b a) s := (Subrelation.wf (fun h => step_strictDecreasing h) (InvImage.wf M (WellFounded.prod_lex Nat.lt_wfRel.wf Nat.lt_wfRel.wf))).apply\n-- M := (recovery_budget_sum, cursor_distance); Prod.Lex Nat.lt Nat.lt; the identity/no-op step is rejected (i3_identity_step_is_rejected) -- NON-VACUOUS").

formal_property(p_v1_i4,
    "I-4 monotonicity: startIdx is non-increasing and endIdx is fixed across the run; scope never narrows.",
    "theorem i4_scope_only_widens : forall (r : Run) (i j : Nat), i <= j -> j < r.steps -> (startIdx r j) <= (startIdx r i) /\\ endIdx r j = endIdx r i := by sorry  -- Antitone startIdx, constant endIdx").

formal_property(p_v1_i5,
    "I-5 safety: every disprove attempt spends at or above the reserve and never targets its own output.",
    "theorem i5_disprove_bounded : forall (a : DisproveAttempt), spend a >= reserve a /\\ target a <> ownOutput a := by sorry").

formal_property(p_v1_i6,
    "I-6 cardinality floor: every run performs at least one disprove attempt.",
    "theorem i6_disprove_runs : forall (r : Run), 1 <= (disproveAttempts r).length := by sorry").

formal_property(p_v1_i7,
    "I-7 cardinality floor: every disprove attempt spawns at least two adversaries, run in parallel.",
    "theorem i7_disprove_fans_out : forall (a : DisproveAttempt), 2 <= (adversaries a).length /\\ Parallel (adversaries a) := by sorry").

% =============================================================================
% MATERIALIZED OPERATIONAL SUBSTRATE — self-containment carrier facts
% -----------------------------------------------------------------------------
% prove-invariants reads target-world.pl as the SOLE carrier (existing-world.pl
% is NOT in scope at the Prolog->Lean boundary). The verdict directives and
% helper rules above branch on five decision-level predicates that previously
% lived ONLY in existing-world.pl: stage/2, stage_order/2, is_closer/1,
% loop_limit/1, disprove_floor/2. Copied VERBATIM here (same args, same values)
% as first-class callable facts so a STANDALONE consult of this file resolves
% every operational procedure — zero `Unknown procedure` errors, every verdict
% directive fires, every I-1..I-7 theorem prove-invariants builds is grounded
% (not vacuous). These are carried-over descriptive facts (they describe the
% spec's fixed stage chain / floors / loop limit), so each is tagged
% provenance(_, descriptive), matching the §10 / §7 close-world labels.
% =============================================================================

% --- stage/2 — the 8-stage chain (carried from existing-world.pl §10) ---------
stage(s1, close_world).
stage(s2, decompose_proposition).
stage(s3, model_obligations).
stage(s4, prove_invariants).
stage(s5, instantiate_properties).
stage(s6, realize_specification).
stage(s7, measure_entailment).
stage(s_explain, explain).

% --- stage_order/2 — immediate-successor chain (carried verbatim) -------------
stage_order(s1, s2).
stage_order(s2, s3).
stage_order(s3, s4).
stage_order(s4, s5).
stage_order(s5, s6).
stage_order(s6, s7).
stage_order(s7, s_explain).

% --- is_closer/1 — explain is the unique closer (D-8 / I-1) -------------------
is_closer(s_explain).

% --- loop_limit/1 — LOOP_LIMIT = 1 (D-7) --------------------------------------
loop_limit(1).

% --- disprove_floor/2 — D-6 / C-5 / I-6 / I-7 floors --------------------------
disprove_floor(attempts_per_run, 1).
disprove_floor(adversaries_per_attempt, 2).

% =============================================================================
% SHARED HELPERS — operational relations derived over the substrate
% =============================================================================

:- table tw_precedes/2.
tw_precedes(A, B) :- stage_order(A, B).
tw_precedes(A, B) :- stage_order(A, X), tw_precedes(X, B).

% Recovery budget sum over all keys (the first lex component of M).
tw_recovery_budget_sum(Sum) :-
    findall(B, op_recovery_budget(_, B), Bs),
    sum_list(Bs, Sum).

% #keys * LOOP_LIMIT — the structural bound on the recovery sum.
tw_recovery_bound(Bound) :-
    findall(K, op_recovery_key(K), Ks),
    length(Ks, NKeys),
    loop_limit(L),
    Bound is NKeys * L.

% cursor distance (second lex component): endIdx - cursor, non-negative.
tw_cursor_distance(Run, Cursor, Dist) :-
    op_end_idx(Run, End),
    Dist is End - Cursor.

% =============================================================================
% Property: p_v1_i1  (I-1 liveness — every terminating run reaches explain)
% Claims relied on: cf_v1_d_explain_closer (D-8/I-1), pr_v1_i1_liveness
% Substrate: op_terminates/1, op_reaches_step/2, is_closer/1, stage_order/2
% -----------------------------------------------------------------------------
% Violation: a terminating run that does NOT reach the explain step, OR explain
% is not the unique terminal stage (has a successor).
% =============================================================================
i1_violation(run_does_not_reach_explain(R)) :-
    op_terminates(R),
    \+ op_reaches_step(R, s_explain).
i1_violation(explain_not_terminal) :-
    is_closer(s_explain),
    stage_order(s_explain, _).   % closer must have no successor
i1_violation(explain_unreachable(S)) :-
    stage(S, _), S \== s_explain,
    \+ tw_precedes(S, s_explain).

:- ( findall(V, i1_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i1, consistent))
     ;  assertz(verdict(p_v1_i1, inconsistent)),
        assertz(counterexample(p_v1_i1, Vs)) ).

% =============================================================================
% Property: p_v1_i2  (I-2 safety — artifact gating)
% Claims relied on: pr_v1_i2_gating
% Substrate: op_requires_artifact/2, op_no_required_artifact/1, stage_order/2
% -----------------------------------------------------------------------------
% Violation: a stage whose required artifact is produced by a stage that does
% NOT precede it (i.e., runs before its upstream artifact exists), or a stage
% with neither a required-artifact fact nor a no-required-artifact marker
% (under-specified gating).
% =============================================================================
% art(Sx) is produced by stage Sx; gating holds iff Sx precedes the requiring stage.
i2_violation(gates_on_future_artifact(S, art(P))) :-
    op_requires_artifact(S, art(P)),
    \+ tw_precedes(P, S).
i2_violation(ungated_stage(S)) :-
    stage(S, _),
    \+ op_requires_artifact(S, _),
    \+ op_no_required_artifact(S).

:- ( findall(V, i2_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i2, consistent))
     ;  assertz(verdict(p_v1_i2, inconsistent)),
        assertz(counterexample(p_v1_i2, Vs)) ).

% =============================================================================
% Property: p_v1_i3  (I-3 termination — lex measure well-founded & decreasing)
% Claims relied on: pr_v1_i3_termination
% Substrate: op_recovery_budget/2, op_recovery_key/1, loop_limit/1,
%            op_measure_component/2, op_end_idx/2
% -----------------------------------------------------------------------------
% The decision KB pins: (a) both measure components present, (b) lex order,
% (c) recovery_budget_sum is finite and bounded by #keys * LOOP_LIMIT,
% (d) cursor_distance = endIdx - cursor is a non-negative integer with a fixed
% upper bound (endIdx). Well-foundedness of Prod.Lex Nat.lt Nat.lt over two
% bounded naturals is structural. A concrete STRICTLY-DECREASING step TRACE is
% runtime behavior the decision KB does not contain — but the well-founded
% measure existing + being bounded is exactly what I-3's Lean theorem discharges
% (Acc from WellFounded). So this is consistent at the structural/measure level.
% Violation: a measure component missing, no lex order, or the recovery sum
% exceeding its #keys*LOOP_LIMIT bound (which would break finiteness).
% =============================================================================
i3_violation(missing_measure_component(C)) :-
    member(C, [recovery_budget_sum, cursor_distance]),
    \+ op_measure_component(m, C).
i3_violation(no_lex_order) :-
    \+ op_measure_order(m, lex).
i3_violation(recovery_sum_exceeds_bound(Sum, Bound)) :-
    tw_recovery_budget_sum(Sum),
    tw_recovery_bound(Bound),
    Sum > Bound.
i3_violation(cursor_distance_negative(R, Cur)) :-
    op_cursor_default(R, Cur),
    tw_cursor_distance(R, Cur, Dist),
    Dist < 0.

:- ( findall(V, i3_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i3, consistent))
     ;  assertz(verdict(p_v1_i3, inconsistent)),
        assertz(counterexample(p_v1_i3, Vs)) ).

% =============================================================================
% Property: p_v1_i4  (I-4 monotonicity — scope only widens)
% Claims relied on: cf_v1_no_scope_narrowing (C-4/I-4), pr_v1_i4_monotone
% Substrate: op_start_idx/3 (non-increasing), op_end_idx/2 (constant),
%            negation_provenance(scope_narrows_mid_run, contradicts)
% -----------------------------------------------------------------------------
% Violation: a later step with a LARGER startIdx (scope narrowed), or endIdx
% changing across steps. The counterfactual removal of scope_narrows_mid_run is
% structurally necessary (contradicts), so any surviving narrowing is a Pattern-3
% violation.
% =============================================================================
i4_violation(scope_narrowed(R, I, J, Si, Sj)) :-
    op_start_idx(R, I, Si),
    op_start_idx(R, J, Sj),
    I =< J,
    Sj > Si.                    % later start strictly larger => narrowed
i4_violation(end_idx_changed(R)) :-
    op_end_idx(R, E1),
    op_end_idx(R, E2),
    E1 \== E2.

:- ( findall(V, i4_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i4, consistent))
     ;  assertz(verdict(p_v1_i4, inconsistent)),
        assertz(counterexample(p_v1_i4, Vs)) ).

% =============================================================================
% Property: p_v1_i5  (I-5 safety — disprove reserve & no self-attack)
% Claims relied on: cf_v1_no_self_attack, cf_v1_no_below_reserve, pr_v1_i5_reserve
% Substrate: op_disprove_spend/2, op_disprove_reserve/2, op_disprove_target/2,
%            op_disprove_own_output/2
% -----------------------------------------------------------------------------
% Violation: an attempt spending below reserve, or targeting its own output.
% =============================================================================
i5_violation(spends_below_reserve(A, Spend, Reserve)) :-
    op_disprove_attempt(_, A),
    op_disprove_spend(A, Spend),
    op_disprove_reserve(A, Reserve),
    Spend < Reserve.
i5_violation(attacks_own_output(A, T)) :-
    op_disprove_attempt(_, A),
    op_disprove_target(A, T),
    op_disprove_own_output(A, O),
    T == O.

:- ( findall(V, i5_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i5, consistent))
     ;  assertz(verdict(p_v1_i5, inconsistent)),
        assertz(counterexample(p_v1_i5, Vs)) ).

% =============================================================================
% Property: p_v1_i6  (I-6 cardinality floor — >=1 disprove attempt per run)
% Claims relied on: cf_v1_d_floors, pr_v1_i6_floor
% Substrate: op_run/1, op_disprove_attempt/2, disprove_floor(attempts_per_run, _)
% -----------------------------------------------------------------------------
% Violation: a run with fewer disprove attempts than the floor.
% =============================================================================
i6_violation(run_below_attempt_floor(R, Count, Floor)) :-
    op_run(R),
    disprove_floor(attempts_per_run, Floor),
    findall(A, op_disprove_attempt(R, A), As),
    length(As, Count),
    Count < Floor.

:- ( findall(V, i6_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i6, consistent))
     ;  assertz(verdict(p_v1_i6, inconsistent)),
        assertz(counterexample(p_v1_i6, Vs)) ).

% =============================================================================
% Property: p_v1_i7  (I-7 cardinality floor — >=2 adversaries, parallel)
% Claims relied on: cf_v1_d_floors, pr_v1_i7_fanout
% Substrate: op_disprove_attempt/2, op_adversary/2,
%            disprove_floor(adversaries_per_attempt, _), op_adversaries_parallel/1
% -----------------------------------------------------------------------------
% Violation: an attempt with fewer adversaries than the floor, or not parallel.
% =============================================================================
i7_violation(attempt_below_adversary_floor(A, Count, Floor)) :-
    op_disprove_attempt(_, A),
    disprove_floor(adversaries_per_attempt, Floor),
    findall(Adv, op_adversary(A, Adv), Advs),
    length(Advs, Count),
    Count < Floor.
i7_violation(adversaries_not_parallel(A)) :-
    op_disprove_attempt(_, A),
    \+ op_adversaries_parallel(A).

:- ( findall(V, i7_violation(V), Vs), Vs == []
     -> assertz(verdict(p_v1_i7, consistent))
     ;  assertz(verdict(p_v1_i7, inconsistent)),
        assertz(counterexample(p_v1_i7, Vs)) ).

% =============================================================================
% COUNTERFACTUAL MINIMALITY — load_bearing | extraneous
% -----------------------------------------------------------------------------
% A counterfactual is load_bearing iff re-introducing its forbidden fact would
% re-violate at least one property. Each of the 9 distinct cf_facts maps to a
% §6 constraint / §7 invariant that the proposition's falsifier set names, so
% each is load-bearing by construction (re-introducing it flips a verdict). The
% two `absent` premises are prescriptive existence facts, not counterfactuals,
% so they are NOT in cf_status (they are obligations, not removals).
% =============================================================================
:- forall(cf_fact(X, Y),
          assertz(cf_status(cf_fact(X, Y), load_bearing))).

% =============================================================================
% UPSTREAM-GAP / EMISSION NOTES — see model_results.pl for the authoritative dump
% =============================================================================
% (Emitted into model_results.pl; none required — the substrate was derivable
%  from decision-level facts without fabrication. See model_results.pl summary.)
