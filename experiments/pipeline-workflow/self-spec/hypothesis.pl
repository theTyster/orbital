% hypothesis.pl
% =============================================================================
% decompose-proposition (Stage 2 of trajectory:pipeline)
%   carrier in : thoughts/existing-world.pl  (close-world over the design spec)
%   proposition: §1 of docs/superpowers/specs/2026-05-28-pipeline-as-workflow-design.md
%
% This is a SELF-VERIFYING (dogfood, D-12) decomposition: the spec is its own
% pipeline input, so most of the proposition's content is ALREADY entailed by
% the existing-world KB as design decisions (descriptive). The interesting
% surface is the proposition's DECLARED FALSIFIERS — each names a fact that the
% target world must NOT contain. Because the spec EXPLICITLY negates each of
% those facts (negation_provenance(_, contradicts) in existing-world.pl), the
% counterfactual claims here carry provenance `contradicts`, NOT `absent`:
% they are structurally necessary, not CWA-fragile. The one CWA-fragile
% surface is the implementation-existence prescriptive claim (the Workflow
% does not yet exist on disk).
%
% Ontology labels (see ../plugins/shifting/references/ontology.md):
%   descriptive    — already entailed by existing-world.pl (the design says so)
%   counterfactual — a fact in the falsifier set that must be false in target-world
%   prescriptive   — must become provable / must come to exist; not yet entailed
% Negation provenance for every negated premise: absent | contradicts.
% =============================================================================

:- discontiguous claim/2, claim_label/2, claim_status/2,
                 claim_premise/2, claim_negation_provenance/3,
                 evidence/3, formal_property/3,
                 sub_hypothesis/2, coverage/2, assumption/2.

proposition("The orbital-shifting seven-stage pipeline can be realized as one deterministic, background-executable Workflow that preserves invariants I-1..I-7, parallelizes its provable and testable stages without losing determinism, and is verifiable by the same pipeline, without inverting the smart-orchestrator / dumb-executor separation.").

existing_world_file('thoughts/existing-world.pl').

counterfactual_question("What about the existing-world KB would need to be false — and what new facts would need to become provable — for the seven-stage pipeline to be realizable as one deterministic, invariant-preserving, self-verifying Workflow that does NOT invert the smart-orchestrator / dumb-executor separation?").

% -----------------------------------------------------------------------------
% SUB-HYPOTHESES — the proposition decomposes into five conjuncts.
% -----------------------------------------------------------------------------
sub_hypothesis(sh_realizable, "The pipeline is realizable as ONE deterministic background-executable Workflow (D-1 workflow-not-skill).").
sub_hypothesis(sh_invariants, "The Workflow PRESERVES invariants I-1..I-7 (the §7 proof targets must become provable over the target world).").
sub_hypothesis(sh_parallel,   "It PARALLELIZES its provable/testable stages WITHOUT losing determinism (D-9 parallelism map respects C-1).").
sub_hypothesis(sh_selfverify, "It is VERIFIABLE BY THE SAME PIPELINE (D-12 dogfood: this very run).").
sub_hypothesis(sh_separation, "It does NOT invert the smart-orchestrator / dumb-executor separation (D-2 / C-2; the framing refuted as the self-orchestration R1).").

% =============================================================================
% CLAIMS
% =============================================================================

% -----------------------------------------------------------------------------
% DESCRIPTIVE claims — already entailed by existing-world.pl. The design (D/C/I)
% says these are so; close-world recorded them as ground facts. No counterfactual
% delta: the proposition's CONSTRUCTIVE content is the existing design.
% -----------------------------------------------------------------------------

claim(cf_v1_d_workflow, "Orchestration is realized as a deterministic Workflow script, not an Opus skill (D-1).").
claim_label(cf_v1_d_workflow, descriptive).
claim_status(cf_v1_d_workflow, clear).

claim(cf_v1_d_separation, "Authority is split: the orchestration layer owns mechanics; agents own judgment (D-2, the structural separation that survived refutation §3).").
claim_label(cf_v1_d_separation, descriptive).
claim_status(cf_v1_d_separation, clear).

claim(cf_v1_d_det_substitute, "Lean proof effort is bounded by deterministic work-units (maxHeartbeats + maxRecDepth), with wall-clock surviving only as a non-control infra backstop (D-10).").
claim_label(cf_v1_d_det_substitute, descriptive).
claim_status(cf_v1_d_det_substitute, clear).

claim(cf_v1_d_parallel_map, "Provable/testable stages fan out (prove-invariants per-theorem, instantiate-properties per-test, model-obligations per-property, measure-entailment per-resource) while realize-specification stays serial (D-9).").
claim_label(cf_v1_d_parallel_map, descriptive).
claim_status(cf_v1_d_parallel_map, clear).

claim(cf_v1_d_explain_closer, "explain is the unique terminal closer with no successor stage (D-8 / I-1), and the stage chain is a total order from close_world to explain.").
claim_label(cf_v1_d_explain_closer, descriptive).
claim_status(cf_v1_d_explain_closer, clear).

claim(cf_v1_d_floors, "The disprove floors are pinned: >=1 attempt per run, >=2 adversaries per attempt, with LOOP_LIMIT = 1 recovery per gap-class-per-stage (D-6 / D-7 / C-5).").
claim_label(cf_v1_d_floors, descriptive).
claim_status(cf_v1_d_floors, clear).

claim(cf_v1_d_dogfood, "The spec is its own pipeline input: the §7 invariants are simultaneously design decisions AND formal_property sketches (D-12, self-verification).").
claim_label(cf_v1_d_dogfood, descriptive).
claim_status(cf_v1_d_dogfood, clear).

% -----------------------------------------------------------------------------
% COUNTERFACTUAL claims — the proposition's DECLARED FALSIFIERS. Each names a
% fact that must be FALSE in the target world. Provenance is `contradicts`
% (NOT `absent`): the spec explicitly negates each via negation_provenance/2,
% so the falseness is structurally necessary and survives KB incompleteness.
% These are the primary refutation surface for disprove-proposition.
% -----------------------------------------------------------------------------

% --- determinism breakage class (C-1) -----------------------------------------
claim(cf_v1_no_wallclock_control, "No control decision depends on wall-clock time (C-1); the deterministic maxHeartbeats work-unit bound (D-10) is the contrastive substitute.").
claim_label(cf_v1_no_wallclock_control, counterfactual).
claim_status(cf_v1_no_wallclock_control, clear).
claim_premise(cf_v1_no_wallclock_control, control_decision_on_wallclock_or_random).
claim_negation_provenance(cf_v1_no_wallclock_control, control_decision_on_wallclock_or_random, contradicts).

claim(cf_v1_no_randomness_control, "No control decision depends on randomness (C-1); branching is keyed only on deterministic state and agent-emitted signals.").
claim_label(cf_v1_no_randomness_control, counterfactual).
claim_status(cf_v1_no_randomness_control, clear).
claim_premise(cf_v1_no_randomness_control, control_decision_on_wallclock_or_random).
claim_negation_provenance(cf_v1_no_randomness_control, control_decision_on_wallclock_or_random, contradicts).

% --- inversion smell class (C-2) — the framing refuted as R1, must NOT recur ---
claim(cf_v1_no_substrate_verdict, "The orchestration layer never computes a logic verdict (provable / refuted / inconsistent) itself; it branches only on agent-emitted signals (C-2).").
claim_label(cf_v1_no_substrate_verdict, counterfactual).
claim_status(cf_v1_no_substrate_verdict, clear).
claim_premise(cf_v1_no_substrate_verdict, orchestration_layer_computes_logic_verdict).
claim_negation_provenance(cf_v1_no_substrate_verdict, orchestration_layer_computes_logic_verdict, contradicts).

claim(cf_v1_no_self_orchestration, "The smart-orchestrator / dumb-executor separation is NOT inverted; the self-orchestration framing (orchestration is a skill making judgments) stays refuted (§3 / D-1).").
claim_label(cf_v1_no_self_orchestration, counterfactual).
claim_status(cf_v1_no_self_orchestration, clear).
claim_premise(cf_v1_no_self_orchestration, self_orchestration_framing).
claim_negation_provenance(cf_v1_no_self_orchestration, self_orchestration_framing, contradicts).

claim(cf_v1_orchestration_not_skill, "Orchestration is not a skill that makes judgments (D-1); the orchestration-is-a-skill framing is contradicted.").
claim_label(cf_v1_orchestration_not_skill, counterfactual).
claim_status(cf_v1_orchestration_not_skill, clear).
claim_premise(cf_v1_orchestration_not_skill, orchestration_is_a_skill).
claim_negation_provenance(cf_v1_orchestration_not_skill, orchestration_is_a_skill, contradicts).

% --- scope non-monotonicity class (C-4 / I-4) ---------------------------------
claim(cf_v1_no_scope_narrowing, "Scope never narrows mid-run; the start index is monotonically non-increasing and the end is fixed (C-4 / I-4).").
claim_label(cf_v1_no_scope_narrowing, counterfactual).
claim_status(cf_v1_no_scope_narrowing, clear).
claim_premise(cf_v1_no_scope_narrowing, scope_narrows_mid_run).
claim_negation_provenance(cf_v1_no_scope_narrowing, scope_narrows_mid_run, contradicts).

% --- disprove discipline class (C-3 / I-5) ------------------------------------
claim(cf_v1_no_self_attack, "Disprove never attacks its own output (C-3 / I-5).").
claim_label(cf_v1_no_self_attack, counterfactual).
claim_status(cf_v1_no_self_attack, clear).
claim_premise(cf_v1_no_self_attack, disprove_attacks_own_output).
claim_negation_provenance(cf_v1_no_self_attack, disprove_attacks_own_output, contradicts).

claim(cf_v1_no_below_reserve, "Disprove never spends below its reserved budget (C-3 / I-5).").
claim_label(cf_v1_no_below_reserve, counterfactual).
claim_status(cf_v1_no_below_reserve, clear).
claim_premise(cf_v1_no_below_reserve, disprove_spends_below_reserve).
claim_negation_provenance(cf_v1_no_below_reserve, disprove_spends_below_reserve, contradicts).

% --- background autonomy class (C-6) ------------------------------------------
claim(cf_v1_no_human_prompt, "No human prompt occurs mid-run; the Workflow is background-executable (C-6).").
claim_label(cf_v1_no_human_prompt, counterfactual).
claim_status(cf_v1_no_human_prompt, clear).
claim_premise(cf_v1_no_human_prompt, human_prompt_mid_run).
claim_negation_provenance(cf_v1_no_human_prompt, human_prompt_mid_run, contradicts).

% --- parallelism-without-determinism-loss class (D-9) -------------------------
claim(cf_v1_realize_not_parallel, "realize-specification does NOT fan out; it is serial-by-necessity because it mutates shared source (D-9). Parallelizing it would lose determinism.").
claim_label(cf_v1_realize_not_parallel, counterfactual).
claim_status(cf_v1_realize_not_parallel, clear).
claim_premise(cf_v1_realize_not_parallel, realize_specification_runs_parallel).
claim_negation_provenance(cf_v1_realize_not_parallel, realize_specification_runs_parallel, contradicts).

% -----------------------------------------------------------------------------
% PRESCRIPTIVE claims — must become provable / must come to exist. These are NOT
% yet entailed by existing-world.pl: the §7 invariants are proof TARGETS (sketches,
% not theorems), and the Workflow artifact does not yet exist on disk. The
% implementation-existence claim is the one CWA-fragile (absent) negation surface.
% -----------------------------------------------------------------------------

claim(pr_v1_i1_liveness, "Every terminating path of the Workflow reaches the explain step (I-1 must be machine-checked, not merely declared).").
claim_label(pr_v1_i1_liveness, prescriptive).
claim_status(pr_v1_i1_liveness, conditional).

claim(pr_v1_i2_gating, "No stage runs before its required upstream artifact exists (I-2 must be machine-checked).").
claim_label(pr_v1_i2_gating, prescriptive).
claim_status(pr_v1_i2_gating, conditional).

claim(pr_v1_i3_termination, "The control-flow loop terminates: the lexicographic measure M = (sum of remaining recovery budget over all keys, endIdx - cursor) strictly decreases each iteration (I-3 must be machine-checked).").
claim_label(pr_v1_i3_termination, prescriptive).
claim_status(pr_v1_i3_termination, conditional).

claim(pr_v1_i4_monotone, "Scope monotonicity holds operationally: startIdx is non-increasing and endIdx fixed across the whole run (I-4 must be machine-checked).").
claim_label(pr_v1_i4_monotone, prescriptive).
claim_status(pr_v1_i4_monotone, conditional).

claim(pr_v1_i5_reserve, "Disprove reserve discipline holds: every attempt spends at or above the reserve and never targets its own output (I-5 must be machine-checked).").
claim_label(pr_v1_i5_reserve, prescriptive).
claim_status(pr_v1_i5_reserve, conditional).

claim(pr_v1_i6_floor, "Every run performs >=1 disprove attempt (I-6 cardinality floor must be machine-checked).").
claim_label(pr_v1_i6_floor, prescriptive).
claim_status(pr_v1_i6_floor, conditional).

claim(pr_v1_i7_fanout, "Every disprove attempt spawns >=2 adversaries in parallel (I-7 cardinality floor must be machine-checked).").
claim_label(pr_v1_i7_fanout, prescriptive).
claim_status(pr_v1_i7_fanout, conditional).

claim(pr_v1_workflow_exists, "A deterministic, background-executable Workflow artifact comes to exist (under experiments/pipeline-workflow/, D-13) that realizes the seven-stage pipeline. This fact is absent from the KB today.").
claim_label(pr_v1_workflow_exists, prescriptive).
claim_status(pr_v1_workflow_exists, open).
claim_premise(pr_v1_workflow_exists, workflow_artifact_exists_on_disk).
claim_negation_provenance(pr_v1_workflow_exists, workflow_artifact_exists_on_disk, absent).

claim(pr_v1_self_verified, "The design is verified BY THE SAME pipeline: this very run carries §1 through model-obligations / prove-invariants / instantiate-properties / measure-entailment (D-12). The verification-completed fact is not yet entailed.").
claim_label(pr_v1_self_verified, prescriptive).
claim_status(pr_v1_self_verified, open).
claim_premise(pr_v1_self_verified, self_verification_run_completed).
claim_negation_provenance(pr_v1_self_verified, self_verification_run_completed, absent).

% =============================================================================
% FORMAL PROPERTIES — §7 invariants lifted from existing-world.pl's
% formal_property_sketch/3 into Lean sketches for prove-invariants (stage 4).
% Real Mathlib names used where applicable (Prod.Lex / WellFounded / Monotone)
% so stage 4 has a head start; bodies left `sorry` for the prover.
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
% EVIDENCE — Prolog queries against existing-world.pl that back the claims.
% =============================================================================

evidence(cf_v1_no_wallclock_control,
    "negation_provenance(control_decision_on_wallclock_or_random, P).",
    "P = contradicts. The spec EXPLICITLY forbids wall-clock/random control (C-1); falseness is structurally necessary, not CWA-absent.").
evidence(cf_v1_no_substrate_verdict,
    "negation_provenance(orchestration_layer_computes_logic_verdict, P).",
    "P = contradicts (C-2). The substrate computing a verdict is the inversion smell refuted as R1; must not recur.").
evidence(cf_v1_no_self_orchestration,
    "negation_provenance(self_orchestration_framing, P).",
    "P = contradicts. §3 records the self-orchestration framing as refuted; the structural separation (D-2) survived.").
evidence(cf_v1_no_scope_narrowing,
    "negation_provenance(scope_narrows_mid_run, P).",
    "P = contradicts (C-4 / I-4).").
evidence(cf_v1_realize_not_parallel,
    "fans_out(s6), negation_provenance(realize_specification_runs_parallel, P).",
    "fans_out(s6) FAILS (s6 is serial shared_mutable_source); P = contradicts (D-9). Parallelizing realize-specification is forbidden.").
evidence(cf_v1_no_self_attack,
    "negation_provenance(disprove_attacks_own_output, P), negation_provenance(disprove_spends_below_reserve, P2).",
    "both contradicts (C-3 / I-5).").
evidence(cf_v1_no_human_prompt,
    "negation_provenance(human_prompt_mid_run, P).",
    "P = contradicts (C-6 background autonomy).").
evidence(cf_v1_d_parallel_map,
    "findall(S-M-U, stage_parallelism(S,M,U), L).",
    "s3 parallel per_property, s4 parallel per_theorem, s5 parallel per_test, s7 parallel per_resource; s1/s2/s6/s_explain serial. Provable/testable stages fan out; realize stays serial.").
evidence(cf_v1_d_explain_closer,
    "is_closer(s_explain), \\+ stage_order(s_explain, _), forall(stage(S,_), (S==s1 ; precedes(s1,S))).",
    "explain is the unique terminal closer (no successor); every stage is reachable from close_world. Total chain s1..s_explain holds.").
evidence(cf_v1_d_floors,
    "loop_limit(L), disprove_floor(attempts_per_run, A), disprove_floor(adversaries_per_attempt, V).",
    "L=1, A=1, V=2. Matches D-6/D-7/C-5; satisfies V4/V5 (no floor-too-low violation).").
evidence(cf_v1_d_dogfood,
    "forall(invariant(I,_,_), formal_property_sketch(I,_,_)).",
    "TRUE for I-1..I-7: every invariant already carries a formal_property_sketch/3, so the spec is liftable as its own proof input (V2 holds).").
evidence(pr_v1_i3_termination,
    "findall(C, measure_component(m,C,_), Cs).",
    "Cs = [recovery_budget_sum, cursor_distance, order]; the lexicographic measure M components are present in the KB and preserved in p_v1_i3's Lean sketch.").
evidence(pr_v1_workflow_exists,
    "current_predicate(workflow_artifact_exists_on_disk/0) ; \\+ clause(stage_parallelism(s_workflow,_,_), true).",
    "No fact asserts the Workflow artifact exists. Absent under CWA — this is the prescriptive delta the implementation must close.").

% =============================================================================
% COVERAGE
% =============================================================================
coverage(total_clauses, 535).
coverage(claims_emitted, 26).
coverage(predicates_exercised, [negation_provenance/2, stage_parallelism/3, formal_property_sketch/3, measure_component/3, invariant/3, invariant_formalizes/2, loop_limit/1, disprove_floor/2, is_closer/1, stage_order/2, precedes/2, fans_out/1]).
coverage(percentage, 78).
coverage(assessment, high).
coverage(unexercised_predicates, [decision_table/4, acceptance_criterion/3, behavioral_seeds/2, lean_bound/2, risk/3, consumption_step/3, scope/2]).

% =============================================================================
% ASSUMPTIONS / OPEN QUESTIONS
% =============================================================================
assumption(a_v1_impl_grain,
    "The prescriptive I-1..I-7 claims assume the target-world model exposes the operational predicates the §7 sketches name (Run, Stage, cursor, startIdx/endIdx, recoveryBudget, DisproveAttempt). model-obligations must materialize these from the decision-level KB facts; if it cannot, emit upstream_gap(schema_insufficient) toward close-world.").
assumption(a_v1_self_verify_circularity,
    "The self-verification claim (pr_v1_self_verified) is satisfied only when THIS pipeline run completes through measure-entailment. It is intentionally open at stage 2; do not score it entailed until stage 7.").
assumption(a_v1_workflow_runtime_behavioral,
    "background-executable / no-human-prompt-mid-run (C-6) is partly a runtime behavioral property that close-world cannot fully capture (CWA strips runtime behaviour). Expect instantiate-properties to emit it as a behavioral_claim test, not a pure projection.").

% =============================================================================
% GATE-TARGET / REFUTATION SHAPE (for the orchestrator + disprove-proposition)
% Primary refutation surface = every counterfactual premise + every prescriptive
% new-fact assertion. Disprove classes requested by the orchestrator:
%   - determinism breakage  : attack cf_v1_no_wallclock_control / cf_v1_no_randomness_control
%   - inversion smell (R1)  : attack cf_v1_no_substrate_verdict / cf_v1_no_self_orchestration
%   - scope non-monotonicity: attack cf_v1_no_scope_narrowing (C-4/I-4)
%   - disprove floor/fanout : attack pr_v1_i6_floor (0 attempts) / pr_v1_i7_fanout (<2 adversaries)
%   - liveness/gating       : attack pr_v1_i1_liveness (skip explain) / pr_v1_i2_gating / pr_v1_i3_termination
% =============================================================================
refutation_target(cf_v1_no_substrate_verdict, inversion_smell, "the R1-refuted framing; highest-value disprove target").
refutation_target(cf_v1_no_wallclock_control, determinism_breakage, "contrast with D-10 deterministic maxHeartbeats substitute").
refutation_target(cf_v1_no_scope_narrowing, scope_non_monotonicity, "C-4 / I-4").
refutation_target(pr_v1_i6_floor, disprove_floor_failure, "a run performing 0 disprove attempts").
refutation_target(pr_v1_i7_fanout, disprove_fanout_failure, "an attempt with <2 adversaries").
refutation_target(pr_v1_i1_liveness, liveness_failure, "a terminating path that skips explain").
refutation_target(pr_v1_i3_termination, termination_failure, "non-termination of the cursor loop").
