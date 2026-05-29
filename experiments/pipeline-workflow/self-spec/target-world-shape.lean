import Ontology.Prelude

/-!
# target-world-shape.lean — structural translation of `target-world.pl`

Emitted by `model-obligations` (Stage 3). Consumed directly by `prove-invariants`
(Stage 4) instead of re-transcribing Prolog facts into Lean `List` literals.

This file encodes the SAME world as `target-world.pl`; it differs only in
representation. It declares:

* one `inductive` enum per closed Prolog domain (Stage, RecoveryKey, …),
* one `inductive … : … → Prop` per operational relation, one constructor per
  *surviving* ground fact, and
* one parallel CF-augmented predicate per counterfactual whose absence a §7
  invariant relies on (here: scope-narrowing, for I-4's necessity lemma).

Open-string positions (file paths, free-form ids) stay in `target-world.pl`
only; nothing here is open-domain. The §7 sketches in `target-world.pl`'s
`formal_property/3` facts name `Stage`, `Run`, `cursor`, `startIdx/endIdx`,
`recoveryBudget`, `DisproveAttempt` — the declarations below give those names a
closed structural home so the theorems are NON-VACUOUS.

Provenance note (ontology): the operational facts are `provenance(_, prescriptive)`
in `target-world.pl` — they are the obligation the Workflow realizes, derived
from the decisions, not yet on disk. The two `negation_provenance(_, absent)`
premises (workflow_artifact_exists_on_disk, self_verification_run_completed) are
CWA-fragile and are NOT encoded as closed-domain disproofs here:
CWA-absent ≠ Lean-disproved.
-/

set_option autoImplicit false

namespace TargetWorld

/-! ## Closed domains -/

/-- The eight pipeline stages (closed: `stage/2` total chain s1..s_explain). -/
inductive Stage where
  | close_world | decompose_proposition | model_obligations | prove_invariants
  | instantiate_properties | realize_specification | measure_entailment | explain
  deriving DecidableEq, Repr

/-- Recovery keys — the gap-class-per-stage loopback targets (closed). -/
inductive RecoveryKey where
  | s3 | s4 | s5 | s6
  deriving DecidableEq, Repr

/-- Disprove attempt ids in the canonical run (closed; the floor instance). -/
inductive DisproveAttempt where
  | a0
  deriving DecidableEq, Repr

/-- Adversary ids (closed; the ≥2 floor instance). -/
inductive Adversary where
  | adv1 | adv2
  deriving DecidableEq, Repr

/-- Run ids (closed; the canonical full-pipeline run). -/
inductive Run where
  | r0
  deriving DecidableEq, Repr

/-! ## Stage index — total order over the chain (cursor domain) -/

/-- `StageIndex s n` ⟺ stage `s` sits at cursor position `n`. One constructor
    per `op_stage_index/2` fact; explain is the maximal index (7). -/
inductive StageIndex : Stage → Nat → Prop where
  | close_world             : StageIndex .close_world 0
  | decompose_proposition   : StageIndex .decompose_proposition 1
  | model_obligations       : StageIndex .model_obligations 2
  | prove_invariants        : StageIndex .prove_invariants 3
  | instantiate_properties  : StageIndex .instantiate_properties 4
  | realize_specification   : StageIndex .realize_specification 5
  | measure_entailment      : StageIndex .measure_entailment 6
  | explain                 : StageIndex .explain 7

/-- Immediate-successor relation over stages (`stage_order/2`). -/
inductive StageOrder : Stage → Stage → Prop where
  | s1_s2 : StageOrder .close_world .decompose_proposition
  | s2_s3 : StageOrder .decompose_proposition .model_obligations
  | s3_s4 : StageOrder .model_obligations .prove_invariants
  | s4_s5 : StageOrder .prove_invariants .instantiate_properties
  | s5_s6 : StageOrder .instantiate_properties .realize_specification
  | s6_s7 : StageOrder .realize_specification .measure_entailment
  | s7_se : StageOrder .measure_entailment .explain

/-! ## I-1 liveness — explain is the unique terminal stage -/

/-- `ReachesExplain r` ⟺ run `r` reaches the explain step. The canonical
    terminating run does. -/
inductive ReachesExplain : Run → Prop where
  | r0 : ReachesExplain .r0

/-- `Terminates r` for the canonical run. -/
inductive Terminates : Run → Prop where
  | r0 : Terminates .r0

/-! ## I-2 artifact gating — required upstream artifact precedes its consumer -/

/-- Artifact produced by a stage. `Artifact s` ≈ `art(s)` in target-world.pl. -/
abbrev Artifact := Stage

/-- `Requires s a` ⟺ stage `s` requires upstream artifact `a` (= predecessor's
    output). One constructor per `op_requires_artifact/2` fact; `close_world`
    has no required upstream artifact (stage-0 carrier). -/
inductive Requires : Stage → Artifact → Prop where
  | s2 : Requires .decompose_proposition .close_world
  | s3 : Requires .model_obligations .decompose_proposition
  | s4 : Requires .prove_invariants .model_obligations
  | s5 : Requires .instantiate_properties .prove_invariants
  | s6 : Requires .realize_specification .instantiate_properties
  | s7 : Requires .measure_entailment .realize_specification
  | se : Requires .explain .measure_entailment

/-! ## I-3 termination — recovery budget per key (lex measure first component) -/

/-- `RecoveryBudget k b` ⟺ key `k` carries per-key budget `b` (= LOOP_LIMIT = 1).
    The recovery sum is `#keys * LOOP_LIMIT = 4`; the second lex component is
    `endIdx - cursor`. Well-foundedness of `Prod.Lex Nat.lt Nat.lt` over two
    bounded naturals is the I-3 obligation. -/
inductive RecoveryBudget : RecoveryKey → Nat → Prop where
  | s3 : RecoveryBudget .s3 1
  | s4 : RecoveryBudget .s4 1
  | s5 : RecoveryBudget .s5 1
  | s6 : RecoveryBudget .s6 1

/-! ## I-4 monotone scope — startIdx non-increasing, endIdx fixed -/

/-- `StartIdx r step idx` ⟺ at `step` of run `r`, the scope start index is `idx`.
    Canonical instance: start stays at 0 (scope never narrows). -/
inductive StartIdx : Run → Nat → Nat → Prop where
  | r0_step0 : StartIdx .r0 0 0
  | r0_step1 : StartIdx .r0 1 0
  | r0_step2 : StartIdx .r0 2 0

/-- `EndIdx r e` ⟺ run `r`'s scope end index is the constant `e` (= 7, explain). -/
inductive EndIdx : Run → Nat → Prop where
  | r0 : EndIdx .r0 7

/-- **Counterfactual augmentation (CF1, scope-narrowing).** Re-introduces the
    counterfactually-removed `scope_narrows_mid_run` fact as a later step whose
    start index is strictly larger. The I-4 necessity lemma proves the property
    FAILS in this CF-extended world by direct constructor citation —
    `negation_provenance(scope_narrows_mid_run, contradicts)`, so the removal is
    structurally necessary, not CWA-fragile. -/
inductive StartIdxCF1 : Run → Nat → Nat → Prop where
  | r0_step0 : StartIdxCF1 .r0 0 0
  | r0_step1 : StartIdxCF1 .r0 1 0
  | r0_step2 : StartIdxCF1 .r0 2 0
  | r0_step3_narrowed : StartIdxCF1 .r0 3 5   -- scope narrowed: later start > earlier

/-! ## I-5 / I-6 / I-7 — disprove discipline, floors, and fan-out -/

/-- `RunAttempt r a` ⟺ run `r` performs disprove attempt `a` (I-6 floor: ≥1). -/
inductive RunAttempt : Run → DisproveAttempt → Prop where
  | r0_a0 : RunAttempt .r0 .a0

/-- `AttemptAdversary a adv` ⟺ attempt `a` fans out to adversary `adv`
    (I-7 floor: ≥2, run in parallel). -/
inductive AttemptAdversary : DisproveAttempt → Adversary → Prop where
  | a0_adv1 : AttemptAdversary .a0 .adv1
  | a0_adv2 : AttemptAdversary .a0 .adv2

/-- `AdversariesParallel a` ⟺ attempt `a`'s adversaries run in parallel (C-5). -/
inductive AdversariesParallel : DisproveAttempt → Prop where
  | a0 : AdversariesParallel .a0

/-- Disprove spend / reserve (I-5: spend ≥ reserve). -/
inductive Spend : DisproveAttempt → Nat → Prop where
  | a0 : Spend .a0 1
inductive Reserve : DisproveAttempt → Nat → Prop where
  | a0 : Reserve .a0 1

/-- Disprove target vs own-output (I-5: target ≠ own output). Closed two-element
    domain so the disequality closes by `cases`/`exhaust`. -/
inductive DisproveSurface where
  | gate_target_descriptor | disproof_results
  deriving DecidableEq, Repr

inductive Target : DisproveAttempt → DisproveSurface → Prop where
  | a0 : Target .a0 .gate_target_descriptor
inductive OwnOutput : DisproveAttempt → DisproveSurface → Prop where
  | a0 : OwnOutput .a0 .disproof_results

end TargetWorld
