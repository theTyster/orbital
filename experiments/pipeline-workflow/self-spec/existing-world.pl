% existing-world.pl
% =============================================================================
% close-world (Stage 1 of trajectory:pipeline) over:
%   docs/superpowers/specs/2026-05-28-pipeline-as-workflow-design.md
%
% LOGICAL-SYSTEM close-world (NOT a codebase scan). The source is a design spec
% that deliberately encodes decisions / constraints / requirements / invariants
% (not code). The spec's structured declarations ARE the ground facts, rules,
% and constraint rules of this closed world.
%
% CWA: everything asserted below is true; everything absent is, by the Closed
% World Assumption, FALSE. Absence here means "not asserted in the source," not
% "proven false." negation_provenance is recorded where the spec EXPLICITLY
% negates something (contradicts) vs. merely omits it (absent).
% =============================================================================

:- discontiguous
     spec_meta/2,
     proposition/2,
     falsifier/1,
     requirement/3,
     decision/3,
     decision_rationale/2,
     decision_table/4,
     constraint/3,
     invariant/3,
     invariant_formalizes/2,
     acceptance_criterion/3,
     stage/2,
     stage_order/2,
     stage_parallelism/3,
     lean_bound/2,
     assumption/3,
     risk/3,
     scope/2,
     consumption_step/3,
     negation_provenance/2,
     formal_property_sketch/3,
     measure_component/3,
     loop_limit/1,
     disprove_floor/2.

% -----------------------------------------------------------------------------
% GROUND FACTS — spec metadata
% -----------------------------------------------------------------------------

spec_meta(date, '2026-05-28').
spec_meta(branch, 'experiment/pipeline-workflow').
spec_meta(status, design_pending_user_review).
spec_meta(trial_target, kimmy_feature).
spec_meta(dogfood_subject, this_spec).            % D-12
spec_meta(home, 'experiments/pipeline-workflow/').% D-13

% -----------------------------------------------------------------------------
% GROUND FACTS — §1 Proposition (decompose-proposition lifts this)
% -----------------------------------------------------------------------------

proposition(p1,
  'The orbital-shifting seven-stage pipeline can be realized as one deterministic, background-executable Workflow that preserves invariants I-1..I-7, parallelizes its provable and testable stages without losing determinism, and is verifiable by the same pipeline, without inverting the smart-orchestrator / dumb-executor separation.').

% Falsifiers of the proposition (each is, if it holds, a refutation witness).
falsifier(any_invariant_in_section7_failing).
falsifier(control_decision_depends_on_wallclock).
falsifier(control_decision_depends_on_randomness).
falsifier(orchestration_layer_makes_logic_judgment_itself). % a C-2 violation

% -----------------------------------------------------------------------------
% GROUND FACTS — §2 Goal / Definition-of-Done requirements (R-G1..R-G5)
% and §4 Requirements (R-1..R-6)
% requirement(Id, Class, Text).
% -----------------------------------------------------------------------------

requirement(rg1, dod, 'Rigorously specced - this document (decisions, not code).').
requirement(rg2, dod, 'Unit-tested via TDD - required behaviors (section 9) red-to-green.').
requirement(rg3, dod, 'Proven - I-1..I-7 (section 7) closed in Lean.').
requirement(rg4, dod, 'Fleshed out and wired into an E2E Workflow pointable at a real ticket.').
requirement(rg5, dod, 'A closing explain run on exactly what was produced, for human review BEFORE the Workflow is pointed at any real target.').

requirement(r1, functional, 'Full control-flow machinery is first-class, not deferred: disprove branches, automatic loopbacks, scope widening, gap batching.').
requirement(r2, functional, 'Lean proving is bounded and parallel.').
requirement(r3, functional, 'The design self-verifies: its own invariants are machine-checked.').
requirement(r4, functional, 'The result is pointable end-to-end at a real ticket.').
requirement(r5, functional, 'Each run ends with a plain-language account of what it did.').
requirement(r6, functional, 'Runs are deterministic, resumable, and budget-bounded.').

% -----------------------------------------------------------------------------
% GROUND FACTS — §5 Decisions (D-1..D-13), firm with rationale.
% decision(Id, ShortName, Text).
% decision_rationale(Id, WhyText).
% -----------------------------------------------------------------------------

decision(d1, workflow_not_skill,
  'Orchestration is a deterministic Workflow script.').
decision_rationale(d1,
  'Parallelism, budget, resume, and formal verifiability that an Opus skill cannot give.').

decision(d2, separation_of_authority,
  'The orchestration layer owns mechanics; agents own judgment.').
decision_rationale(d2,
  'Keeps the smart-orchestrator role in agents and the substrate deterministic - the structural-layer separation that survived refutation.').

decision(d3, state_via_files_control_via_digest,
  'Stage state flows through thoughts/*.pl (the existing artifact contract); control flows through a structured digest each stage returns, carrying: artifact reference, status, verdict signals, gaps (each tagged with a target stage), and a core-obligation flag.').
decision_rationale(d3,
  'Preserve the proven file contract; never serialize KBs.').

decision(d4, movable_cursor_control_flow,
  'Stages are visited by a cursor that advances by default and moves backward only to honor a routed gap.').
decision_rationale(d4,
  'Makes loopbacks real while bounding motion (feeds I-3).').

decision(d5, auto_recover_and_log,
  'Recoverable gaps are honored automatically (within the loop limit) and logged to a decision trail. Only loop-limit exceeded, budget exhausted, or a core obligation refuted terminate-and-report.').
decision_rationale(d5,
  'A background run cannot pause to ask; autonomy plus an auditable trail. One switch flips this to hard human gates between runs if ever wanted.').

decision(d6, disprove_policy,
  'Every run performs >=1 disprove attempt (budget reserved up front); every attempt fans out >=2 perspective-diverse adversaries in parallel; disprove is bounded above.').
decision_rationale(d6,
  'A guaranteed adversarial floor plus bias defense through diversity.').

decision(d7, loop_limit_one,
  'LOOP_LIMIT = 1 recovery per gap-class-per-stage.').
decision_rationale(d7,
  'Matches the substrate policy, guarantees termination, prevents oscillation. Tunable upward for the kimmy run.').

decision(d8, explain_always_runs,
  'Explain always runs, post-loop and unconditional, on every path.').
decision_rationale(d8,
  'Every run is reviewable; also stated as I-1.').

decision(d9, parallelism_map,
  'Parallel: prove-invariants (per theorem), instantiate-properties (per test), per-property model-obligations. Serial by necessity: realize-specification (shared mutable source plus inter-test dependencies; worktree isolation does not save it).').
decision_rationale(d9,
  'Match parallelism to data-independence; realize-specification mutates shared source so it cannot fan out.').

decision(d10, lean_bounding_deterministic,
  'Proof effort is bounded per theorem by maxHeartbeats (plus maxRecDepth) - deterministic work-units, not wall-clock; a wall-clock timeout exists only as an infra backstop. Mathlib is prebuilt once before any fan-out; Lean concurrency is sub-capped (~cores/4). Unprovable under budget emits the unprovable signal that drives the loopback AND a disprove attempt.').
decision_rationale(d10,
  'A wall-clock bound would make the same proof pass/fail by machine load - fatal for a deterministic workflow; the bound is also the trigger that powers R-1.').

decision(d11, verifiable_in_isolation,
  'The deterministic mechanics are separable and pure, and the orchestration loop receives its effectful collaborators by injection, so tests can substitute fakes.').
decision_rationale(d11,
  'TDD of the control flow without invoking real agents (satisfies R-G2).').

decision(d12, dogfood_subject_is_this_spec,
  'The declarations here (D / C / I / R) are close-worlded, and section 1 is decomposed and proven, so the design is verified from the spec - not from the code.').
decision_rationale(d12,
  'Spec-driven proof is durable; code-driven proof rots.').

decision(d13, experiment_not_canonical,
  'Lives self-contained under experiments/pipeline-workflow/, not wired into plugins/trajectory/.').
decision_rationale(d13,
  'Dogfood first; promotion to canonical is a separate, later decision.').

% D-2 authority-split table. decision_table(D, RowIndex, Mechanics, Judgment).
decision_table(d2, 1, 'stage sequencing, cursor, scope set', 'is this unprovable / inconsistent / refuted?').
decision_table(d2, 2, 'gap batching (merge by target)',     'honor this loopback or surface it?').
decision_table(d2, 3, 'loop-limit / termination guard',     'refute this claim (adversaries)').
decision_table(d2, 4, 'scope widening; artifact gating',    'plain-language narration').

% -----------------------------------------------------------------------------
% GROUND FACTS — §6 Constraints (C-1..C-6), hard rules the impl must not violate.
% constraint(Id, ShortName, Text).
% -----------------------------------------------------------------------------

constraint(c1, determinism,
  'No control decision may depend on wall-clock time or randomness.').
constraint(c2, no_logic_call_in_substrate,
  'The orchestration layer may branch only on agent-emitted signals; it must never compute a logic verdict (provable / refuted / inconsistent) itself.').
constraint(c3, disprove_discipline,
  'Disprove never attacks its own output and never spends below the reserved budget.').
constraint(c4, monotone_scope,
  'Scope may only widen; it never narrows mid-run.').
constraint(c5, adversary_cardinality,
  'Every disprove attempt runs >=2 adversaries in parallel.').
constraint(c6, background_autonomy,
  'No human prompt mid-run.').

% -----------------------------------------------------------------------------
% GROUND FACTS — §7 Invariants (I-1..I-7), the formal proof targets.
% invariant(Id, ShortName, Text).
% These are the formal_property sketches §10 hands to prove-invariants.
% -----------------------------------------------------------------------------

invariant(i1, explain_always_runs,
  'Every terminating path reaches the explanation step.').
invariant(i2, artifact_gating,
  'No stage runs before its required upstream artifact exists.').
invariant(i3, termination,
  'The control flow halts. Proof obligation: a well-founded measure M = (sum of remaining recovery budget over all keys, endIdx - cursor) under lexicographic order strictly decreases each iteration - a forward step decreases the second component; a loopback decreases the first (recovery is consumed and is finitely bounded by #keys * LOOP_LIMIT); a hard-stop exits.').
invariant(i4, scope_only_widens,
  'The scope start index is monotonically non-increasing; the end is fixed; scope never narrows mid-run.').
invariant(i5, disprove_bounded_above,
  'Disprove never spends below the reserve and never attacks its own output.').
invariant(i6, disprove_runs_at_least_once,
  'Every run performs >=1 disprove attempt.').
invariant(i7, disprove_fans_out,
  'Every disprove attempt spawns >=2 adversaries in parallel.').

% -----------------------------------------------------------------------------
% RELATIONSHIP RULES — invariant <-> constraint/decision it formalizes.
% (the structural links the success criteria require)
% invariant_formalizes(InvariantId, SourceId).
% -----------------------------------------------------------------------------

invariant_formalizes(i1, d8).   % explain-always-runs <- D-8
invariant_formalizes(i3, d4).   % termination measure feeds from movable-cursor D-4
invariant_formalizes(i3, d7).   % ... bounded by LOOP_LIMIT (D-7)
invariant_formalizes(i4, c4).   % scope-only-widens formalizes C-4
invariant_formalizes(i5, c3).   % disprove-bounded-above formalizes C-3
invariant_formalizes(i6, d6).   % disprove-runs-at-least-once formalizes D-6 floor
invariant_formalizes(i7, c5).   % disprove-fans-out formalizes C-5

% Derived: which invariants have an explicit upstream source declaration.
formalizes_some(I) :- invariant_formalizes(I, _).

% Constraint <-> invariant that machine-checks it (inverse view, for queries).
constraint_proven_by(C, I) :- constraint(C, _, _), invariant_formalizes(I, C).

% Decision <-> invariant that machine-checks (or is grounded in) it.
decision_proven_by(D, I) :- decision(D, _, _), invariant_formalizes(I, D).

% -----------------------------------------------------------------------------
% GROUND FACTS — formal-property sketches (§7 lifted for prove-invariants).
% formal_property_sketch(InvariantId, Kind, ObligationText).
% Kind in {liveness, safety, termination, cardinality_floor, monotonicity}.
% -----------------------------------------------------------------------------

formal_property_sketch(i1, liveness,
  'forall terminating path P, explain_step in P.').
formal_property_sketch(i2, safety,
  'forall stage S, run(S) implies exists(required_artifact(S)).').
formal_property_sketch(i3, termination,
  'M = <sum_k recovery_budget(k), endIdx - cursor> decreases lexicographically each iteration; M well-founded; hard-stop terminates.').
formal_property_sketch(i4, monotonicity,
  'startIdx non-increasing AND endIdx fixed across the run.').
formal_property_sketch(i5, safety,
  'forall disprove attempt A: spend(A) >= reserve AND target(A) =/= own_output(A).').
formal_property_sketch(i6, cardinality_floor,
  'count(disprove_attempt, run) >= 1.').
formal_property_sketch(i7, cardinality_floor,
  'forall disprove attempt A: count(adversary, A) >= 2 AND parallel(adversaries(A)).').

% Components of the well-founded termination measure M (I-3).
% measure_component(MeasureId, ComponentName, Description).
measure_component(m, recovery_budget_sum,
  'sum of remaining recovery budget over all gap-class-per-stage keys; bounded by #keys * LOOP_LIMIT; decreased by a loopback.').
measure_component(m, cursor_distance,
  'endIdx - cursor; decreased by a forward step.').
measure_component(m, order, 'lexicographic over (recovery_budget_sum, cursor_distance).').

loop_limit(1).                       % D-7
disprove_floor(attempts_per_run, 1). % D-6 / I-6
disprove_floor(adversaries_per_attempt, 2). % D-6 / C-5 / I-7

% -----------------------------------------------------------------------------
% GROUND FACTS + ORDER RULES — pipeline stages and stage order (D-9 map, §10).
% stage(Id, Name).  stage_order(EarlierId, LaterId)  -- immediate successor.
% -----------------------------------------------------------------------------

stage(s1, close_world).
stage(s2, decompose_proposition).
stage(s3, model_obligations).
stage(s4, prove_invariants).
stage(s5, instantiate_properties).
stage(s6, realize_specification).
stage(s7, measure_entailment).
stage(s_explain, explain).            % closer, post-loop (D-8 / I-1)

stage_order(s1, s2).
stage_order(s2, s3).
stage_order(s3, s4).
stage_order(s4, s5).
stage_order(s5, s6).
stage_order(s6, s7).
stage_order(s7, s_explain).

% Transitive precedence (relationship rule).
precedes(A, B) :- stage_order(A, B).
precedes(A, B) :- stage_order(A, X), precedes(X, B).

% Closer property: explain is reachable as the terminal stage from every stage.
is_closer(s_explain).

% -----------------------------------------------------------------------------
% GROUND FACTS — §5 D-9 parallelism map.
% stage_parallelism(StageId, Mode, Unit).
%   Mode in {parallel, serial}.  Unit = the fan-out grain (or none).
% -----------------------------------------------------------------------------

stage_parallelism(s1, serial, none).
stage_parallelism(s2, serial, none).
stage_parallelism(s3, parallel, per_property).
stage_parallelism(s4, parallel, per_theorem).
stage_parallelism(s5, parallel, per_test).
stage_parallelism(s6, serial, shared_mutable_source). % serial by necessity
stage_parallelism(s7, parallel, per_resource).
stage_parallelism(s_explain, serial, none).

% Relationship rule: a stage fans out iff its mode is parallel.
fans_out(S) :- stage_parallelism(S, parallel, _).
serial_by_necessity(s6).  % realize-specification (D-9 rationale)

% -----------------------------------------------------------------------------
% GROUND FACTS — §5 D-10 Lean bounding (deterministic).
% lean_bound(Mechanism, Detail).
% -----------------------------------------------------------------------------

lean_bound(per_theorem_limit, 'maxHeartbeats (plus maxRecDepth) - deterministic work-units').
lean_bound(wallclock_timeout, 'infra backstop only; never a control decision (would violate C-1)').
lean_bound(mathlib_prebuilt, 'Mathlib built once before any fan-out').
lean_bound(concurrency_subcap, 'Lean concurrency sub-capped at approximately cores/4').
lean_bound(unprovable_signal, 'unprovable under budget emits the unprovable signal that drives BOTH a loopback and a disprove attempt').

% -----------------------------------------------------------------------------
% GROUND FACTS — §9 acceptance criteria.
% acceptance_criterion(Id, Layer, Text).  Layer in {behavioral, formal}.
% -----------------------------------------------------------------------------

acceptance_criterion(b1, behavioral, 'Merge gaps that share a target stage (and merge their parameters); keep distinct targets apart.').
acceptance_criterion(b2, behavioral, 'Cap recovery at LOOP_LIMIT per gap-class-per-stage.').
acceptance_criterion(b3, behavioral, 'Widen - never narrow - scope when a loopback target precedes the current start.').
acceptance_criterion(b4, behavioral, 'Advance the cursor on a clean digest, loop back on an honored gap, halt on a halt status.').
acceptance_criterion(b5, behavioral, 'Run >=2 adversaries per disprove attempt.').
acceptance_criterion(b6, behavioral, 'Perform >=1 disprove attempt even on an all-clean run.').
acceptance_criterion(b7, behavioral, 'Protect the disprove reserve (suppress opportunistic disprove below it; still run the mandatory one).').
acceptance_criterion(b8, behavioral, 'Run explain exactly once, last, on the happy path AND every hard-stop path.').
acceptance_criterion(b9, behavioral, 'Hard-stop on a core-obligation refutation.').
acceptance_criterion(b10, behavioral, 'Hard-stop on loop-limit exhaustion.').
acceptance_criterion(b11, behavioral, 'Emit a complete, auditable decision trail.').

acceptance_criterion(f1, formal, 'I-1 machine-checked in Lean under the D-10 bounds.').
acceptance_criterion(f2, formal, 'I-2 machine-checked in Lean under the D-10 bounds.').
acceptance_criterion(f3, formal, 'I-3 machine-checked in Lean under the D-10 bounds.').
acceptance_criterion(f4, formal, 'I-4 machine-checked in Lean under the D-10 bounds.').
acceptance_criterion(f5, formal, 'I-5 machine-checked in Lean under the D-10 bounds.').
acceptance_criterion(f6, formal, 'I-6 machine-checked in Lean under the D-10 bounds.').
acceptance_criterion(f7, formal, 'I-7 machine-checked in Lean under the D-10 bounds.').

% Relationship rule: each formal criterion targets exactly one invariant.
formal_criterion_targets(f1, i1).
formal_criterion_targets(f2, i2).
formal_criterion_targets(f3, i3).
formal_criterion_targets(f4, i4).
formal_criterion_targets(f5, i5).
formal_criterion_targets(f6, i6).
formal_criterion_targets(f7, i7).

% Relationship rule: behavioral criteria seed the projection / behavioral tests.
% behavioral_criterion_seeds(CriterionId, RelatedDecisionOrConstraint).
behavioral_seeds(b1, d3).   % gap batching
behavioral_seeds(b2, d7).   % LOOP_LIMIT cap
behavioral_seeds(b3, c4).   % monotone widen
behavioral_seeds(b3, i4).
behavioral_seeds(b4, d4).   % movable cursor
behavioral_seeds(b5, c5).   % >=2 adversaries
behavioral_seeds(b5, i7).
behavioral_seeds(b6, d6).   % >=1 attempt
behavioral_seeds(b6, i6).
behavioral_seeds(b7, c3).   % reserve protection
behavioral_seeds(b7, i5).
behavioral_seeds(b8, d8).   % explain once last
behavioral_seeds(b8, i1).
behavioral_seeds(b9, d5).   % hard-stop on core-obligation refutation
behavioral_seeds(b10, d5).  % hard-stop on loop-limit exhaustion
behavioral_seeds(b10, d7).
behavioral_seeds(b11, d5).  % auditable decision trail

% -----------------------------------------------------------------------------
% GROUND FACTS — §8 assumptions and risks.
% assumption(Id, Text, IfFalseFallback).
% risk(Id, Text, Mitigation).
% -----------------------------------------------------------------------------

assumption(a1,
  'skill-from-subagent: a general-purpose workflow subagent can invoke a shifting: skill and let it drive.',
  'call each stage named sub-agents directly and reproduce the skill orchestration in the substrate (more work; recorded in FINDINGS.md).').
assumption(a2,
  'sandbox import: the Workflow sandbox can import a sibling module.',
  'inline the mechanics into the shim and add a sync-check that asserts the copy matches the source.').

risk(risk_lean_parallel_memory,
  'Concurrent lake builds may thrash even with cached Mathlib.',
  'the D-10 sub-cap, tuned down if needed.').
risk(risk_close_world_fidelity,
  'A proof is only as good as the close-world model of the design; an omitted transition yields a vacuous theorem.',
  'kb-validator plus cwa-fragility-auditor on the self-spec KB.').
risk(risk_inversion_smell,
  'Any new substrate branch on a computed verdict violates C-2.',
  'route it through an agent instead.').

% -----------------------------------------------------------------------------
% GROUND FACTS — §10 consumption bridge (how the spec is consumed).
% consumption_step(N, StageId, Output).
% -----------------------------------------------------------------------------

consumption_step(1, s1, 'extract D / C / I / R as facts -> existing-world.pl').
consumption_step(2, s2, 'section 1 proposition -> hypothesis.pl; the section 7 invariants become the formal-property sketches').
consumption_step(3, s3, 'target-world.pl').
consumption_step(4, s4, 'I-1..I-7 in Lean, bounded-parallel per D-10 (this run also validates D-10 for real)').
consumption_step(5, s6, 'TDD-build the Workflow to satisfy the proven design (section 9 behavioral) -> E2E -> closing explain (R-G5)').

% -----------------------------------------------------------------------------
% GROUND FACTS — §11 scope (what is in / explicitly out).
% scope(Bucket, Item).  Bucket in {today, tonight_tomorrow, out}.
% -----------------------------------------------------------------------------

scope(today, 'finalize this spec').
scope(today, 'run it through close-world ... prove-invariants').
scope(today, 'TDD-build the Workflow').
scope(today, 'E2E wiring').
scope(today, 'closing explain').
scope(tonight_tomorrow, 'point the Workflow at a new kimmy feature, end-to-end').
scope(out, 'promotion to the canonical trajectory pipeline').
scope(out, 'disprove-recursion guards beyond C-3').
scope(out, 'multi-ticket fan-out (one ticket per run)').
scope(out, 'the 120k context hard-stop (subsumed by the token budget)').

% -----------------------------------------------------------------------------
% NEGATION PROVENANCE — explicit negations the spec asserts (contradicts)
% vs. things merely not asserted (absent, the CWA default for everything else).
% negation_provenance(Fact, Provenance).  Provenance in {contradicts, absent}.
% These are the EXPLICIT negations; absence of any other fact defaults to absent.
% -----------------------------------------------------------------------------

negation_provenance(orchestration_is_a_skill, contradicts).            % D-1: Workflow, NOT skill
negation_provenance(orchestration_layer_computes_logic_verdict, contradicts). % C-2
negation_provenance(control_decision_on_wallclock_or_random, contradicts).    % C-1
negation_provenance(scope_narrows_mid_run, contradicts).               % C-4 / I-4
negation_provenance(disprove_attacks_own_output, contradicts).         % C-3 / I-5
negation_provenance(disprove_spends_below_reserve, contradicts).       % C-3 / I-5
negation_provenance(human_prompt_mid_run, contradicts).                % C-6
negation_provenance(realize_specification_runs_parallel, contradicts). % D-9 serial-by-necessity
negation_provenance(wired_into_canonical_trajectory, contradicts).     % D-13 / §11 out
negation_provenance(self_orchestration_framing, contradicts).          % §3: refuted; separation won
negation_provenance(disprove_recursion_guards_beyond_c3, absent).      % §11 out, noted-not-built
negation_provenance(multi_ticket_fanout, absent).                      % §11 out
negation_provenance(context_120k_hardstop, absent).                    % §11 out, subsumed by token budget

% -----------------------------------------------------------------------------
% CONSTRAINT RULES — domain invariants enforced as queryable validators.
% Each is a check that should hold over this closed world. They fail (succeed
% as a violation query) if the KB ever contradicts the spec's hard rules.
% -----------------------------------------------------------------------------

% V1: Every §6 constraint that an invariant formalizes is actually linked.
%     (structural completeness of invariant_formalizes for the named links)
violation(unlinked_named_constraint(C)) :-
    member(C, [c3, c4, c5]),
    \+ ( invariant_formalizes(_, C) ).

% V2: Every invariant must have a formal-property sketch (so decompose can lift).
violation(invariant_without_sketch(I)) :-
    invariant(I, _, _),
    \+ formal_property_sketch(I, _, _).

% V3: Determinism (C-1): no lean bound may be a wall-clock control decision.
%     The wallclock timeout must be flagged as backstop-only, never a control bound.
violation(wallclock_used_as_control) :-
    lean_bound(wallclock_timeout, Detail),
    \+ sub_atom(Detail, _, _, _, 'backstop').

% V4: Adversary cardinality floor (C-5 / I-7) must be >= 2.
violation(adversary_floor_too_low(N)) :-
    disprove_floor(adversaries_per_attempt, N),
    N < 2.

% V5: Disprove attempt floor (D-6 / I-6) must be >= 1.
violation(attempt_floor_too_low(N)) :-
    disprove_floor(attempts_per_run, N),
    N < 1.

% V6: Stage order must be a total chain from close_world to explain (no gaps).
violation(stage_not_reachable_from_close_world(S)) :-
    stage(S, _),
    S \== s1,
    \+ precedes(s1, S).

% V7: realize-specification must be serial (D-9): it must NOT fan out.
violation(realize_specification_fans_out) :-
    fans_out(s6).

% V8: explain must be the unique closer and the terminal stage.
violation(explain_not_terminal) :-
    is_closer(s_explain),
    stage_order(s_explain, _).   % closer must have no successor

% Aggregate: the KB is consistent iff there are no violations.
kb_consistent :- \+ violation(_).

% =============================================================================
% PATTERNS CAPTURED (documentation comments — recurring structures in the spec)
% =============================================================================
% PATTERN A — "decision -> rationale" pairing: every D-n carries a *Why*.
%   Modeled as decision/3 + decision_rationale/2 so the rationale is queryable
%   separately from the decision text.
%
% PATTERN B — "constraint hardened into invariant": C-3->I-5, C-4->I-4, C-5->I-7
%   form a recurring lift where a §6 hard rule is restated as a §7 proof target.
%   Modeled by invariant_formalizes/2; the inverse constraint_proven_by/2 view
%   recovers "which invariant machine-checks this constraint."
%
% PATTERN C — "floor + ceiling on disprove": D-6 states a guaranteed floor
%   (>=1 attempt, >=2 adversaries) AND an upper bound ("bounded above"); the
%   floors are I-6/I-7, the ceiling is I-5 (reserve discipline). Disprove is
%   thus pinned from both sides.
%
% PATTERN D — "deterministic substitute for wall-clock": D-10 replaces a
%   wall-clock proof bound with maxHeartbeats work-units precisely to satisfy
%   C-1. wall-clock survives only as a non-control infra backstop. This is the
%   determinism idiom: every potential time/randomness dependence is replaced
%   by a deterministic work-unit or an agent-emitted signal.
%
% PATTERN E — "two-layer separation" (D-2): mechanics (orchestration substrate)
%   vs. judgment (agents). Captured as decision_table/4. C-2 is the boundary
%   guard: the substrate branches only on agent-emitted signals, never computes
%   a verdict. This is the framing that survived refutation (§3).
%
% PATTERN F — "parallel where data-independent, serial where shared-mutable":
%   D-9. Per-theorem / per-test / per-property / per-resource stages fan out;
%   realize-specification is serial because it mutates shared source. Captured
%   as stage_parallelism/3 + fans_out/1.
%
% PATTERN G — "well-founded measure for termination": I-3 supplies a lexicographic
%   measure M whose components decrease on forward steps (cursor_distance) and on
%   loopbacks (recovery_budget_sum, bounded by #keys * LOOP_LIMIT). Captured as
%   measure_component/3.
%
% PATTERN H — "self-verification / dogfood": D-12 + §10 — the spec is its own
%   pipeline input. The §7 invariants are simultaneously design decisions and
%   formal_property sketches. Captured by formal_property_sketch/3 mirroring
%   invariant/3.
% =============================================================================
