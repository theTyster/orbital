% counterexamples.pl
% =============================================================================
% disprove-proposition (adversarial debate move — NOT a pipeline stage)
%   produced : 2026-05-29
%   invoker  : trajectory:pipeline orchestrator (mandatory disprove gate, D-6/I-6)
%
% REFUTED verdicts only. Each counterexample/4 row is backed by a concrete,
% machine-checkable witness. Inconclusive/abstained verdicts live in
% disproof_results.pl, NOT here.
%
% This run produced ONE refutation: the I-3 termination theorem is VACUOUS with
% respect to the control flow whose termination it claims to establish. The
% witness is an axiom-free Lean term (Proofs/I3Vacuity.lean, witness-of-record
% thoughts/lean_disproofs/p_v1_i3.lean) that inhabits the theorem with a
% degenerate measure + non-decreasing step.
% =============================================================================

:- discontiguous counterexample/4, counterexample_shrunk/2,
                 counterexample_blocks_proof/2.

% counterexample(TargetId, WitnessPath, Source, RecordedAt).
%   Source in {clp_search, bounded_enum, source_grep, pbt_shrink, manual, sub_agent}.
%   manual: the witness is an authored Lean term, machine-checked by `lake build`.
counterexample(p_v1_i3, 'thoughts/lean_disproofs/p_v1_i3.lean', manual, '2026-05-29T04:45:00Z').

% counterexample_shrunk(TargetId, ShrunkValue) — the minimal degenerate witness.
%   The constant measure (fun _ => (0,0)) paired with the identity step (id) is
%   the smallest inhabitant: it makes the measure non-decreasing on every step
%   (a literal infinite no-op loop) yet i3_termination STILL concludes Acc for
%   every state. So "termination" reduces to "Prod.Lex Nat.lt Nat.lt is
%   well-founded" — a Mathlib fact independent of the op_* substrate.
counterexample_shrunk(p_v1_i3, "constMeasure := fun _ => (0,0); idStep := id").

% counterexample_blocks_proof(TargetId, ProofTargetId) — the witness establishes
%   that ProofTargetId, while kernel-valid, does NOT carry the claimed content.
%   It does not make the theorem unprovable (it is provable, trivially); it shows
%   the theorem is the wrong theorem — the substrate facts (RecoveryBudget,
%   EndIdx, StartIdx, the cursor loop) are decorative w.r.t. the conclusion.
counterexample_blocks_proof(p_v1_i3, theorem_i3_termination).
counterexample_blocks_proof(p_v1_i3, theorem_i3_terminates_unconditionally).
