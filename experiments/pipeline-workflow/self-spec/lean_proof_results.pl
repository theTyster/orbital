% lean_proof_results.pl
% =============================================================================
% prove-invariants (Stage 4 of trajectory:pipeline)
%   carrier in  : thoughts/target-world.pl   (SOLE input; 7 formal_property/3)
%   produced    : 2026-05-29
%   lean project: thoughts/lean/  (Proofs/*.lean, machine-checked via lake build)
%   toolchain   : leanprover/lean4:v4.29.0 + shared Mathlib (~/.lean/mathlib4)
%
% Schema: plugins/shifting/references/pipeline-schema/lean-proof-results.md
% Consumed by instantiate-properties (Stage 5), realize-specification (Stage 6),
% and the explain closer — as a STRUCTURED KB, not prose.
%
% MACHINE-CHECK STATUS (real elaboration, not asserted):
%   `cd thoughts/lean && LAKE_ARTIFACT_CACHE=true lake build` => exit 0, 0 errors,
%   0 warnings, 0 live `sorry`. `#print axioms` on all 22 theorems =>
%   "does not depend on any axioms" for every one (no sorryAx, no Classical).
%   These are constructive kernel-checked proofs across all 7 invariants.
%
% I-3 RE-STATEMENT (2026-05-29, adjacent loopback after the disprove gate):
%   The disprove gate REFUTED the original i3_termination as VACUOUS (a constant
%   measure + identity step inhabited it). I-3 was re-stated in place over a
%   CONCRETE step relation that strictly decreases the lex measure; the verdict
%   stays `proven` but the degenerate witness now fails to type-check. See
%   restatement_note(p_v1_i3, ...) and the rewritten proof_strategy(p_v1_i3, ...).
%   The obsolete Proofs/I3Vacuity.lean (which attacked the old form) was removed
%   from the build; its regression intent is folded into I3Termination.lean as
%   i3_identity_step_is_rejected + i3_no_measure_preserving_step.
%
% PROVENANCE DISCIPLINE (enforcement rule cwa_negation_neq_lean_proof):
%   every theorem carries a provenance_annotation/3 whose value is READ OFF the
%   corresponding fact's negation_provenance/2 in target-world.pl. The 2
%   CWA-absent premises (workflow_artifact_exists_on_disk,
%   self_verification_run_completed) are NOT formal properties and are NOT
%   treated as Lean-disproved — recorded as cwa_check(_, _, verified) +
%   lean_skipped(_, cwa_absence_verified_directly). absent =/= disproved.
%
% D-10 VALIDATION: each theorem bounded by `set_option maxHeartbeats 400000`
%   (deterministic work-units, not wall-clock). No theorem exhausted budget;
%   no `unprovable` verdict. The only infra wall-clock was a `timeout` backstop
%   on `lake build`, never a control signal. Mathlib was never rebuilt (oleans
%   cached). This run dogfoods D-10's heartbeat-bounded determinism for real.
% =============================================================================


:- discontiguous
     theorem_verdict/2,
     theorem_source/2,
     proof_strategy/2,
     provenance_annotation/3,
     necessity_lemma_status/3,
     cwa_check/3,
     lean_skipped/2,
     refutation_shape/2,
     restatement_note/3,
     run_summary/2.

% =============================================================================
% PER-THEOREM VERDICTS — all 7 invariants PROVEN (kernel-checked, axiom-free)
% =============================================================================
theorem_verdict(p_v1_i1, proven).
theorem_verdict(p_v1_i2, proven).
theorem_verdict(p_v1_i3, proven).  % RE-STATED non-vacuously after the disprove gate REFUTED the old vacuous form; see restatement_note(p_v1_i3, ...) below.
theorem_verdict(p_v1_i4, proven).
theorem_verdict(p_v1_i5, proven).
theorem_verdict(p_v1_i6, proven).
theorem_verdict(p_v1_i7, proven).

% =============================================================================
% SOURCE LOCATIONS
% =============================================================================
theorem_source(p_v1_i1, "thoughts/lean/Proofs/I1Liveness.lean").
theorem_source(p_v1_i2, "thoughts/lean/Proofs/I2Gating.lean").
theorem_source(p_v1_i3, "thoughts/lean/Proofs/I3Termination.lean").
theorem_source(p_v1_i4, "thoughts/lean/Proofs/I4Monotone.lean").
theorem_source(p_v1_i5, "thoughts/lean/Proofs/I5Reserve.lean").
theorem_source(p_v1_i6, "thoughts/lean/Proofs/I6Floor.lean").
theorem_source(p_v1_i7, "thoughts/lean/Proofs/I7Fanout.lean").

% The shared structural-translation module (lifted from target-world-shape.lean).
theorem_source(target_world_shape, "thoughts/lean/Proofs/TargetWorld.lean").

% =============================================================================
% PROOF STRATEGY — one per proven theorem
% =============================================================================
proof_strategy(p_v1_i1,
  "liveness: intro+cases on single-constructor Run/Terminates -> ReachesExplain; \c
   terminality: exhaust (cases) on StageOrder .explain _ (no successor constructor)").
proof_strategy(p_v1_i2,
  "gating: intro+cases on Requires, each required artifact discharged by its \c
   StageOrder predecessor constructor (.s1_s2 .. .s7_se); close_world ungated by \c
   case-exhaust on Requires .close_world _").
proof_strategy(p_v1_i3,
  "termination (RE-STATED non-vacuously after disprove-gate refutation): the \c
   prior i3_termination quantified the measure + step as FREE args and closed by \c
   hwf.apply (definitional WellFounded unfolding) -- VACUOUS: the identity step + \c
   constant measure inhabited it. NOW: define a CONCRETE Step relation over \c
   State=(recoveryBudgetSum, cursorDistance) with two moves (forward: (rb,d+1) -> \c
   (rb,d), 2nd lex component strictly decreases; loopback: (rb+1,d) -> (rb,d'), \c
   1st component strictly decreases, dominating the lex order). KEY lemma \c
   step_strictDecreasing: every Step s s' gives M s' <_lex M s under \c
   Prod.Lex Nat.lt Nat.lt (forward -> Prod.Lex.right with Nat.lt_succ_self; \c
   loopback -> Prod.Lex.left with Nat.lt_succ_self). StepRev (reverse step) is a \c
   Subrelation of InvImage (Prod.Lex Nat.lt Nat.lt) M, which is well-founded \c
   (lexWf = WellFounded.prod_lex Nat.lt_wfRel.wf Nat.lt_wfRel.wf, lifted by \c
   InvImage.wf); so Subrelation.wf gives WellFounded StepRev and i3_termination : \c
   forall s, Acc StepRev s -- no infinite FORWARD Step-chain = the cursor loop \c
   terminates. Recovery bound grounded + CONNECTED: RecoveryBudget s3..s6 each 1, \c
   sum = #keys*LOOP_LIMIT = 4 by rfl; each loopback decreases this bounded \c
   component, so <=4 loopbacks. REGRESSION CHECKS (folded in from the obsolete \c
   I3Vacuity probe): i3_identity_step_is_rejected (NOT Step s s) and \c
   i3_no_measure_preserving_step (Step s s' -> M s' =/= M s) -- the degenerate \c
   identity/constant-measure witness FAILS to type-check against Step's \c
   constructors (forward forces source 2nd component = d+1; loopback forces \c
   source 1st component = rb+1; neither unifies with a no-op). Axiom-free.").
proof_strategy(p_v1_i4,
  "monotone: sufficiency intro+cases on both StartIdx hyps (all starts = 0) => \c
   Nat.le_refl 0; endIdx constant by cases on EndIdx + rfl. Necessity over \c
   StartIdxCF1 (CF-augmented) cites .r0_step0/.r0_step3_narrowed witness").
proof_strategy(p_v1_i5,
  "reserve: sufficiency spend>=reserve via Spend/Reserve .a0 + Nat.le_refl; \c
   target=/=ownOutput by constructor disjointness of DisproveSurface (cases). \c
   Two necessity lemmas over SpendCF / TargetCF restore the forbidden facts").
proof_strategy(p_v1_i6,
  "floor: intro+cases on single-constructor Run; exhibit RunAttempt .r0 .a0 \c
   witness for exists-attempt").
proof_strategy(p_v1_i7,
  "fanout: intro+cases on DisproveAttempt; exhibit distinct adv1/adv2 via \c
   AttemptAdversary .a0_adv1/.a0_adv2 (disjoint by enum) + AdversariesParallel .a0").

% =============================================================================
% RE-STATEMENT NOTE — adjacent loopback after the disprove gate refuted I-3
% -----------------------------------------------------------------------------
% restatement_note(PropId, refuted_form, restated_form). Records that p_v1_i3
% was re-stated non-vacuously in place after disprove_attempt(p_v1_i3, refuted)
% (see thoughts/disproof_results.pl). The verdict stays `proven`, but it now
% binds a CONCRETE step relation that strictly decreases the lex measure, so the
% degenerate identity-step / constant-measure witness no longer type-checks.
% =============================================================================
restatement_note(p_v1_i3,
  "REFUTED form: theorem i3_termination (measureM : State -> Nat x Nat) \c
   (_step : State -> State) : WellFounded (InvImage (Prod.Lex Nat.lt Nat.lt) \c
   measureM) -> forall s, Acc (InvImage ...) s := by intro hwf s; exact hwf.apply \c
   s. Vacuous: measureM and _step are FREE, _step UNUSED, body = definitional \c
   WellFounded unfolding; the identity step + constant measure (fun _ => (0,0)) \c
   inhabit it (witnesses: thoughts/lean_disproofs/p_v1_i3.lean, ex-I3Vacuity).",
  "RE-STATED form: State = structure (recoveryBudgetSum, cursorDistance); a \c
   CONCRETE inductive Step with two constructors (forward (rb,d+1)->(rb,d); \c
   loopback (rb+1,d)->(rb,d')); KEY lemma step_strictDecreasing : Step s s' -> \c
   Prod.Lex Nat.lt Nat.lt (M s') (M s); StepRev Subrelation of InvImage \c
   (Prod.Lex Nat.lt Nat.lt) M (well-founded); i3_termination : forall s, \c
   Acc StepRev s by Subrelation.wf. Regression checks \c
   i3_identity_step_is_rejected / i3_no_measure_preserving_step machine-confirm \c
   the no-op step is rejected. Build green (lake build exit 0, no sorry); \c
   #print axioms => no axioms on i3_termination, i3_step_wellFounded, \c
   step_strictDecreasing, i3_recovery_bound, and both regression checks.").

% =============================================================================
% PROVENANCE ANNOTATIONS (MANDATORY — domain exactly [absent, contradicts])
% -----------------------------------------------------------------------------
% Value READ OFF the corresponding fact's negation_provenance/2 in
% target-world.pl. Each agrees with the @[ontology .X, .Y] attribute on the
% theorem in Proofs/*.lean.
%
% I-1/I-2/I-3/I-6/I-7 are prescriptive obligations with NO negated premise feeding
% the theorem; the @[ontology .prescriptive, .absent] attribute records the
% obligation-not-counterfactual-removal status. The fact id is the obligation's
% prescriptive claim id (pr_v1_iN_*). absent here = "obligation realized, no CF
% fact removed", NOT a CWA-fragile disproof.
%
% I-4/I-5 are counterfactual: their negated premises are negation_provenance(_,
% contradicts) in target-world.pl (structurally necessary removals). One
% annotation per negated-premise fact.
% =============================================================================

% --- prescriptive obligations (no negated premise) ---------------------------
provenance_annotation(p_v1_i1, pr_v1_i1_liveness, absent).
provenance_annotation(p_v1_i2, pr_v1_i2_gating, absent).
provenance_annotation(p_v1_i3, pr_v1_i3_termination, absent).
provenance_annotation(p_v1_i6, pr_v1_i6_floor, absent).
provenance_annotation(p_v1_i7, pr_v1_i7_fanout, absent).

% --- counterfactual: one per negated-premise fact (all contradicts) ----------
provenance_annotation(p_v1_i4, scope_narrows_mid_run, contradicts).
provenance_annotation(p_v1_i5, disprove_attacks_own_output, contradicts).
provenance_annotation(p_v1_i5, disprove_spends_below_reserve, contradicts).

% =============================================================================
% COUNTERFACTUAL NECESSITY LEMMAS — proven => the removed fact is load-bearing
% -----------------------------------------------------------------------------
% Each necessity lemma re-introduces the counterfactually-removed fact in a
% CF-augmented inductive predicate and shows the invariant FAILS there. A
% `proven` status means re-introduction falsifies the property (load-bearing);
% NONE reduced to False (none extraneous), so NO loopback to decompose-proposition
% is triggered on minimality grounds.
% =============================================================================
necessity_lemma_status(p_v1_i4, scope_narrows_mid_run, proven).        % i4_needs_no_scope_narrowing
necessity_lemma_status(p_v1_i5, disprove_spends_below_reserve, proven).% i5_needs_no_below_reserve
necessity_lemma_status(p_v1_i5, disprove_attacks_own_output, proven).  % i5_needs_no_self_attack

% =============================================================================
% CWA-ABSENT PREMISES — gated OUT of Lean (absent =/= disproved)
% -----------------------------------------------------------------------------
% The 2 negation_provenance(_, absent) facts in target-world.pl are NOT among
% the 7 formal properties; they are CWA-fragile prescriptive existence claims
% (the Workflow does not yet exist on disk / has not yet been self-verified).
% Per the gating table (counterfactual|absent -> skip Lean) and the boundary
% discipline, they are recorded as CWA checks, NOT as Lean disproofs. swipl
% confirmed both are underivable (zero clauses) in target-world.pl standalone.
% =============================================================================
cwa_check(pr_v1_workflow_exists, workflow_artifact_exists_on_disk, verified).
cwa_check(pr_v1_self_verified,   self_verification_run_completed,  verified).

lean_skipped(pr_v1_workflow_exists, cwa_absence_verified_directly).
lean_skipped(pr_v1_self_verified,   cwa_absence_verified_directly).

% provenance_annotation still required so the ontology label survives the gate.
provenance_annotation(pr_v1_workflow_exists, workflow_artifact_exists_on_disk, absent).
provenance_annotation(pr_v1_self_verified,   self_verification_run_completed,  absent).

% =============================================================================
% REFUTATION-SHAPE BRIEFING — carried forward for the downstream disprove gate
% -----------------------------------------------------------------------------
% Surfaces the orchestrator-supplied refutation_shape_briefing so the disprove
% gate (and any lean-adversary) knows which attack shapes are live against this
% stage's output. Format: refutation_shape(ShapeId, Descriptor).
% =============================================================================
refutation_shape(determinism_breakage,
  "branch keyed on wall-clock/randomness (C-1); contrast D-10 heartbeat bounds, \c
   which this run validated (maxHeartbeats per theorem, no wall-clock control signal)").
refutation_shape(inversion_smell,
  "substrate computing a logic verdict itself (C-2, the R1-refuted shape); the \c
   Lean kernel — not the orchestration substrate — produced the I-1..I-7 verdicts here").
refutation_shape(scope_non_monotonicity,
  "scope narrows mid-run (C-4/I-4); attack surface = i4_startidx_antitone and its \c
   necessity lemma i4_needs_no_scope_narrowing (scope_narrows_mid_run is load-bearing)").
refutation_shape(disprove_floor_fanout,
  "disprove floor / fan-out (I-6/C-5/I-7); attack surface = i6_disprove_runs (>=1 \c
   attempt) and i7_disprove_fans_out (>=2 parallel adversaries)").
refutation_shape(liveness_gating_termination,
  "liveness (I-1 explain-always), artifact-gating (I-2), termination of the cursor \c
   loop under lex measure M=(sum recovery budget over keys, endIdx-cursor) (I-3)").

% Primary refutation surface per the orchestrator contract: theorem_verdict(_,
% proven) rows whose premises include provenance_annotation(_, _, absent). Here
% the absent-annotated rows are the prescriptive-obligation theorems I-1/I-2/I-3/
% I-6/I-7 (no CF removal) plus the two gated-out cwa_check claims. NOTE: the
% prescriptive `absent` here is the obligation-not-CF-removal sense, not a
% CWA-fragile negated premise — these theorems hold over POSITIVE op_* facts, so
% they are NOT CWA-fragile in the disprove sense. The genuinely CWA-fragile
% surface is the two cwa_check rows (workflow exists / self-verified), which are
% NOT Lean proofs and remain attackable as not-yet-true existence claims.
refutation_shape(cwa_fragile_existence,
  "the two cwa_check existence claims (workflow_artifact_exists_on_disk, \c
   self_verification_run_completed) are CWA-absent, NOT Lean-disproved; they remain \c
   open obligations the Workflow must realize (Stage 6) and self-verify").

% =============================================================================
% AGGREGATE SUMMARY
% =============================================================================
run_summary(properties_attempted, 7).
run_summary(proven, 7).
run_summary(unprovable, 0).
run_summary(cwa_checks, 2).
run_summary(necessity_lemmas_proven, 3).
run_summary(necessity_lemmas_extraneous, 0).
run_summary(theorems_kernel_checked, 22).
run_summary(theorems_axiom_free, 22).
run_summary(loopback_required, none).
run_summary(i3_restated_non_vacuously, true).
