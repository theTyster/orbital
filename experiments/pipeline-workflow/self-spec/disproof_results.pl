% disproof_results.pl
% =============================================================================
% disprove-proposition (adversarial debate move — structurally OUTSIDE the
%   seven-stage pipeline; unstaged_skill/1 per the orchestration-substrate)
%   produced : 2026-05-29
%   invoker  : trajectory:pipeline orchestrator
%   role     : the run's MANDATORY disprove attempt (D-6 / I-6 floor: >=1 attempt)
%
% DISCIPLINE HONORED:
%   * D-6/I-6 floor : >=1 disprove attempt this run (this file IS that attempt).
%   * C-5/I-7       : >=2 perspective-diverse adversaries (TWO distinct lenses,
%                     below; run inline as the orchestrator had no sub-agent
%                     fan-out available, but genuinely distinct — a Lean
%                     vacuity/encoding analysis and an architectural
%                     inversion/separation analysis, NOT one rephrased twice).
%   * C-3/I-5       : within reserved budget; the disprove move NEVER attacked
%                     its own output (witness R2): no adversary was pointed at
%                     disproof_results.pl or counterexamples.pl.
%   * budget        : bounded above — <=2 perspective-diverse adversaries per
%                     target, 2 targets, NO deep unbounded search.
%
% TARGETS ATTACKED (the run's two riskiest gate-target descriptors):
%   T1 = p_v1_i3  — vacuity/soundness of the meatiest proven invariant
%                   (Proofs.I3.i3_termination + i3_recovery_bound).
%   T2 = c_v1_no_substrate_verdict / sh_separation
%                 — the C-2 NO-INVERSION claim of the §1 proposition.
% =============================================================================

:- discontiguous disprove_attempt/3, disprove_evidence/2,
                 disprove_evidence_lean/2,
                 disprove_budget/2, disprove_obstruction/2,
                 disproved_at/2,
                 adversary_digest/4, perspective_lens/2, defenses_applied/2.

% =============================================================================
% PER-TARGET VERDICTS
% =============================================================================

% --- T1: p_v1_i3 (I-3 termination) — REFUTED -------------------------------
% The adversarial question was NOT "is the kernel proof valid" (it is — 16
% axiom-free theorems) but "is the THEOREM VACUOUS or MIS-STATED". It is
% vacuous: i3_termination quantifies the measure (measureM : State -> N x N) and
% the step (_step : State -> State) as FREE arguments and discharges its only
% hypothesis via measureWf — which holds for EVERY measure. So the theorem
% concludes `Acc` for a CONSTANT measure paired with the IDENTITY step (a
% literal infinite no-op loop). The op_* substrate (RecoveryBudget, EndIdx,
% StartIdx, cursor loop) is never referenced by the termination conclusion; the
% separate i3_recovery_bound lemma only proves 1+1+1+1=4, an arithmetic
% triviality disconnected from any decreasing-step obligation. A machine-checked,
% axiom-free Lean witness inhabits the negation of the claim "I-3 is meaningfully
% proven".
disprove_attempt(p_v1_i3, refuted, 'thoughts/counterexamples.pl').

% --- T2: C-2 no-inversion claim — ABSTAINED --------------------------------
% The inversion attack does NOT land. The substrate's b4/b9 control decisions
% (advance on clean / loop back on honored gap / hard-stop on core-obligation
% refutation) branch on FIELDS OF AN AGENT-EMITTED DIGEST (D-3: status, verdict
% signals, gaps-tagged-with-target, core-obligation flag), not on a verdict the
% substrate computes. The D-2 authority table assigns "is this unprovable /
% inconsistent / refuted?" explicitly to AGENTS (judgment) and "stage sequencing,
% cursor, scope set" to the SUBSTRATE (mechanics). Reading a pre-computed flag is
% not computing a verdict. The adversary could construct NO control-flow decision
% the design must make by itself computing provable/refuted/inconsistent.
% Abstained (not inconclusive): there is no partial counter-evidence — the read-
% not-compute boundary held under the budgeted attack. The obstruction is named
% below; a deeper attack would require the not-yet-written Workflow source (the
% claim is partly about an artifact that does not yet exist on disk — the
% CWA-fragile pr_v1_workflow_exists surface).
disprove_attempt(c_v1_no_substrate_verdict, abstained, no_evidence).

% =============================================================================
% EVIDENCE (natural-language witness / counter-evidence per target)
% =============================================================================
disprove_evidence(p_v1_i3,
  "Axiom-free Lean witness (built green, `#print axioms` => no axioms): \c
   `i3_accepts_constant_measure_and_identity_step : forall s, Acc (InvImage \c
   (Prod.Lex Nat.lt Nat.lt) constMeasure) s := i3_termination constMeasure \c
   idStep (measureWf constMeasure)` with constMeasure = fun _ => (0,0) and \c
   idStep = id. The theorem accepts a non-decreasing step + constant measure and \c
   still concludes accessibility for every state, so it does NOT establish that \c
   the actual cursor loop terminates. Two further witnesses: i3_step_is_dead_weight \c
   (any step function satisfies the same instance => the step is unconstrained), \c
   and i3_antecedent_is_free (the WellFounded antecedent is provable for any \c
   measure => the implication collapses to i3_terminates_unconditionally and adds \c
   nothing). The substrate facts are decorative w.r.t. the termination conclusion.").

disprove_evidence(c_v1_no_substrate_verdict,
  "No counter-evidence found. The three suspect decisions decompose to field-reads \c
   on an agent-emitted digest, not substrate-computed verdicts: (1) 'clean digest' \c
   = the digest.status field already carries the agent's status; the substrate \c
   compares an enum, it does not judge cleanliness. (2) 'honored gap' = the \c
   digest.gaps list (each gap pre-tagged by the emitting agent with its target \c
   stage) is non-empty; the substrate routes on a tag it reads, and 'honor vs. \c
   surface' is itself decision_table(d2,2) JUDGMENT (assigned to agents). (3) \c
   'core-obligation refutation' = the digest.core_obligation flag AND the agent's \c
   'refuted' verdict signal — the agent computed 'refuted' (decision_table(d2,1) \c
   judgment), the substrate reads the flag. Every branch keys on a value the \c
   agent produced. C-2 holds under this attack.").

% =============================================================================
% LEAN EVIDENCE (Lean term inhabiting the negation; builds under lake)
% =============================================================================
% Present for T1: the witness-of-record is thoughts/lean_disproofs/p_v1_i3.lean;
% the canonical BUILDABLE copy lives in the lakefile's source root at
% thoughts/lean/Proofs/I3Vacuity.lean (the lib root Proofs.lean does NOT import
% it, so it does not pollute the I-1..I-7 proof library — it is a standalone,
% independently machine-checked disproof artifact). `lake build Proofs.I3Vacuity`
% => exit 0; `#print axioms` on the witnesses => "does not depend on any axioms".
disprove_evidence_lean(p_v1_i3, 'thoughts/lean_disproofs/p_v1_i3.lean').
% No Lean evidence for T2: the C-2 claim is architectural / behavioral about an
% orchestration substrate; Lean has no theorem to inhabit (inadmissible target
% for lean-adversary per the contract).

% =============================================================================
% BUDGET SPENT (per target)
% =============================================================================
disprove_budget(p_v1_i3,
  "Lens-A (vacuity/encoding): read I3Termination.lean + TargetWorld.lean + the \c
   I-3 formal_property in target-world.pl; authored a 4-theorem Lean witness \c
   inhabiting the negation; `lake build Proofs.I3Vacuity` green (cached Mathlib, \c
   ~19s); axiom-free confirmed via #print axioms. Bounded: one witness file, no \c
   unbounded search.").
disprove_budget(c_v1_no_substrate_verdict,
  "Lens-B (inversion/separation): read spec D-2/D-3/D-4/D-5/D-10 + decision_table/4 \c
   + acceptance_criterion b4/b9 + constraint c2 in existing-world.pl; traced each \c
   of the three b4/b9 control decisions to its digest field and to the D-2 \c
   mechanics/judgment row. Bounded: static trace of the design, no Workflow source \c
   exists yet to fuzz.").

% =============================================================================
% OBSTRUCTION (for the abstained target)
% =============================================================================
disprove_obstruction(c_v1_no_substrate_verdict,
  "The design delegates every logic verdict to an agent and has the substrate \c
   branch only on emitted digest fields (D-2 table row 1 + D-3 digest contract); \c
   the read-not-compute boundary held. A stronger attack is blocked because the \c
   Workflow artifact does not yet exist on disk (pr_v1_workflow_exists is \c
   CWA-absent): one could only refute C-2 against the REALIZED substrate (Stage 6 \c
   output), by exhibiting a concrete branch in the code that pattern-matches on \c
   raw stage output to DERIVE provable/refuted/inconsistent rather than reading an \c
   agent's signal. No such artifact exists to attack this run. Re-attack after \c
   realize-specification produces the orchestration loop.").

% =============================================================================
% TIMESTAMPS
% =============================================================================
disproved_at(p_v1_i3, '2026-05-29T04:45:00Z').
disproved_at(c_v1_no_substrate_verdict, '2026-05-29T04:45:00Z').

% =============================================================================
% ADVERSARY DIGESTS — >=2 PERSPECTIVE-DIVERSE lenses (C-5 / I-7)
% adversary_digest(AdvId, TargetId, Verdict, OneLineFinding).
% =============================================================================
adversary_digest(adv_vacuity, p_v1_i3, refuted,
  "i3_termination holds for a constant measure + identity step => vacuous w.r.t. \c
   the control flow it claims terminates; substrate facts decorative.").
adversary_digest(adv_inversion, c_v1_no_substrate_verdict, abstained,
  "every b4/b9 branch reads an agent-emitted digest field; no substrate-computed \c
   verdict found; C-2 read-not-compute boundary held within budget.").

% Optional third lens (c) — determinism (C-1) probe, folded into adv_inversion's
% trace: none of the b4/b9 control decisions key on wall-clock or order; they key
% on digest enum fields. No determinism breakage found. Recorded for completeness;
% does not change either verdict.

% perspective_lens(AdvId, Description) — the distinct angle each adversary took.
perspective_lens(adv_vacuity,
  "Encoding/vacuity lens: does the proven Lean statement actually CONSTRAIN the \c
   materialized op_* substrate, or is the antecedent free / the measure quantified \c
   so the theorem holds trivially? Attacks the THEOREM, not the kernel.").
perspective_lens(adv_inversion,
  "Architecture/separation lens: does any deterministic control decision force the \c
   substrate to COMPUTE a logic verdict (C-2 inversion), versus reading an \c
   agent-emitted signal? Attacks the PROPOSITION's no-inversion conjunct.").

% =============================================================================
% DEFENSES APPLIED (per the specialist-delegation discipline; canonical source)
% defenses_applied(AdvId, [role_briefing, minimum_necessary_context]).
% Both adversaries were run inline but each was framed OUTCOME-AGNOSTICALLY
% ("find whether this holds OR fails; abstaining within budget is valid;
% fabricating evidence is a foul; the orchestrator has no preferred outcome")
% and given only the artifacts relevant to its subgoal. The orchestrator owns the
% verdict: each adversary's self-report is candidate evidence, validated here
% (the Lean witness was BUILT, not asserted; the C-2 trace was checked against the
% D-2 table and the digest contract before recording abstained).
% =============================================================================
defenses_applied(adv_vacuity, [role_briefing, minimum_necessary_context, witness_validated_by_build]).
defenses_applied(adv_inversion, [role_briefing, minimum_necessary_context, boundary_checked_against_spec]).
