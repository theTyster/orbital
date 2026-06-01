import Ontology.Prelude

/-!
# Proofs/TargetWorld.lean — structural translation of `target-world.pl`

Lifted from `thoughts/target-world-shape.lean` (emitted by `model-obligations`,
Stage 3) into the `Proofs/` Lean library so the I-1..I-7 invariant proofs can
`import Proofs.TargetWorld`. The shape file itself lives outside this lib's
source tree and is not importable as a module; this is its in-lib home.

This file encodes the SAME world as `target-world.pl`; it differs only in
representation. It declares:

* one `inductive` enum per closed Prolog domain (Stage, RecoveryKey, …),
* one `inductive … : … → Prop` per operational relation, one constructor per
  *surviving* ground fact, and
* one parallel CF-augmented predicate per counterfactual whose absence a §7
  invariant relies on (explain-skipped-on-hard-stop for I-1, scope-narrowing for
  I-4, below-reserve / self-attack for I-5, zero-attempt-run for I-6).

## NON-DEGENERACY CONTRACT (why this model is shaped the way it is)

An earlier cut of this file was *degenerate by construction*: one-point
inductives (`Run` = `r0` only, `DisproveAttempt` = `a0` only) and
constant-valued relations (`StartIdx _ _ 0`, `Spend _ 1`, `Reserve _ 1`)
collapsed the §7 universals into `True → True` and made the proof hypotheses
dead weight. Five of seven invariant proofs (I-1, I-3, I-4, I-5, I-6) were
vacuous as a result.

The substrate below makes every invariant's hypothesis LOAD-BEARING:

* `Run` has **two** inhabitants with **distinct outcomes** — `r0` (complete) and
  `r1` (hard_stop mid-pipeline) — so a `∀ r` ranges over >1 and an `RunOutcome`
  relation discriminates them. Per D-8 BOTH reach explain (`ReachesExplain` is
  total); I-1's non-vacuity is the `ReachesExplainCF` necessity lemma (drop
  explain-on-hard-stop ⇒ liveness fails for `r1`) + the structural terminal half. (I-1.)
* `DisproveAttempt` has **two** inhabitants (`a0`, `a1`) so I-5's `∀ attempt` and
  I-6's `∃ attempt` range over >1. (I-5 / I-6.)
* `StartIdx` carries **distinct, strictly-decreasing** start indices per run
  (r0: 3 → 1 → 0; r1: 2 → 0). Antitonicity is now load-bearing: `i ≤ j` must be
  USED (cross-step cases are discharged only by `omega`), and the REVERSE
  direction is unprovable (`3 ≤ 1` is false). (I-4.)
* `Spend` / `Reserve` carry **per-attempt, above-reserve** values that genuinely
  vary (`a0`: spend 5 ≥ reserve 2; `a1`: spend 3 ≥ reserve 3) so a coexisting
  below-reserve spend would falsify a universal `∀ a s r, Spend a s → Reserve a r
  → r ≤ s`. (I-5.)
* `Target` / `OwnOutput` are **attempt-dependent**: the (target, own-output)
  surface pair differs across `a0` and `a1`, so the disequality is not a single
  constructor-fiat fact. (I-5.)
* `RunAttempt` attests **≥1 attempt for BOTH runs** (r0 fans to a0+a1, r1 to a1),
  so the I-6 floor `∀ r, ∃ a, RunAttempt r a` discriminates ≥1 from 0. (I-6.)

Each invariant additionally gets a CF-augmented predicate carrying the forbidden
fact, so the re-proof can add a NECESSITY lemma showing the property FAILS once
the counterfactually-removed fact is restored (the I-3 / I-4 regression pattern):

* `ReachesExplainCF` — explain skipped on the hard-stop path (no `r1` ctor). (I-1.)
* `StartIdxCF1` — scope narrows mid-run (later start > earlier).        (I-4.)
* `SpendCF`     — an attempt spends below its reserve.                   (I-5.)
* `TargetCF`    — an attempt targets its own output (target = ownOutput). (I-5.)
* `RunAttemptCF`— a run performs ZERO attempts (no constructor for `r1`). (I-6.)

Provenance note (ontology): the operational facts are `provenance(_, prescriptive)`
in `target-world.pl` — the obligation the Workflow realizes, derived from the
decisions, not yet on disk. The two `negation_provenance(_, absent)` premises
(workflow_artifact_exists_on_disk, self_verification_run_completed) are
CWA-fragile and are NOT encoded as closed-domain disproofs here:
CWA-absent ≠ Lean-disproved.
-/

set_option autoImplicit false

namespace TargetWorld

/-! ## Closed domains -/

/-- The eight pipeline stages (closed: `stage/2` total chain s1..s_explain).
    PRESERVED — the genuine 8-stage chain I-2 gating + I-1 terminality rely on. -/
inductive Stage where
  | close_world | decompose_proposition | model_obligations | prove_invariants
  | instantiate_properties | realize_specification | measure_entailment | explain
  deriving DecidableEq, Repr

/-- Recovery keys — the gap-class-per-stage loopback targets (closed).
    PRESERVED — I-3's bounded first lex component. -/
inductive RecoveryKey where
  | s3 | s4 | s5 | s6
  deriving DecidableEq, Repr

/-- Disprove attempt ids in the canonical run (closed). TWO inhabitants so I-5's
    `∀ attempt` and I-6's `∃ attempt` range over more than one point. -/
inductive DisproveAttempt where
  | a0 | a1
  deriving DecidableEq, Repr

/-- Adversary ids (closed; the ≥2 floor instance).
    PRESERVED — I-7's ≥2 fan-out floor. -/
inductive Adversary where
  | adv1 | adv2
  deriving DecidableEq, Repr

/-- Run ids (closed). TWO inhabitants with DISTINCT outcomes: `r0` is the
    happy-path full-pipeline run that completes; `r1` hard-stops mid-pipeline.
    A `∀ r` / `∃ r` now ranges over more than one point, and `RunOutcome`
    discriminates the two. -/
inductive Run where
  | r0 | r1
  deriving DecidableEq, Repr

/-- Run termination outcome (closed). `complete` — the run reached the explain
    closer; `hard_stop` — the run halted mid-pipeline (e.g. an unrecoverable
    gate). This is the discriminator the degenerate one-point `Run` could not
    express. -/
inductive Outcome where
  | complete | hard_stop
  deriving DecidableEq, Repr

/-- `RunOutcome r o` ⟺ run `r` terminates with outcome `o`. `r0` completes; `r1`
    hard-stops. Two constructors over two distinct outcomes — non-degenerate. -/
inductive RunOutcome : Run → Outcome → Prop where
  | r0 : RunOutcome .r0 .complete
  | r1 : RunOutcome .r1 .hard_stop

/-! ## Stage index — total order over the chain (cursor domain)

    PRESERVED EXACTLY — the genuine 8-stage positions 0..7. -/

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

/-- Immediate-successor relation over stages (`stage_order/2`).
    PRESERVED EXACTLY — the real 7-edge chain. -/
inductive StageOrder : Stage → Stage → Prop where
  | s1_s2 : StageOrder .close_world .decompose_proposition
  | s2_s3 : StageOrder .decompose_proposition .model_obligations
  | s3_s4 : StageOrder .model_obligations .prove_invariants
  | s4_s5 : StageOrder .prove_invariants .instantiate_properties
  | s5_s6 : StageOrder .instantiate_properties .realize_specification
  | s6_s7 : StageOrder .realize_specification .measure_entailment
  | s7_se : StageOrder .measure_entailment .explain

/-! ## I-1 liveness — explain is the unique terminal stage -/

/-- `ReachesExplain r` ⟺ run `r` reaches the explain step. Per **D-8**, explain is
    the unconditional post-loop closer that runs on EVERY path — the happy path
    AND every hard-stop path. This is exactly what the behavioral `crit8` test
    pins ("explain runs exactly once last on hard-stop paths too") and what the
    implementation does (records explain unconditionally after the loop). So BOTH
    the `complete` run `r0` and the `hard_stop` run `r1` reach explain;
    `ReachesExplain` is TOTAL.

    The I-1 liveness sufficiency `∀ r, Terminates r → ReachesExplain r` therefore
    holds for both runs. Its NON-VACUITY is carried NOT by the antecedent (which
    is inherently unconditional — D-8 makes explain run regardless), but by the
    NECESSITY lemma over `ReachesExplainCF` below (removing explain-on-hard-stop
    breaks liveness for `r1`) plus the genuinely-structural terminal half
    (`∀ s, ¬ StageOrder .explain s`, which the I-1 adversary already conceded is
    non-vacuous over the real 7-edge `StageOrder`). -/
inductive ReachesExplain : Run → Prop where
  | r0 : ReachesExplain .r0
  | r1 : ReachesExplain .r1

/-- `Terminates r` ⟺ run `r` terminates (reaches a terminal state — either the
    explain closer or a hard stop). BOTH runs terminate: `r0` by completing, `r1`
    by hard-stopping. Both also reach explain (D-8; see `ReachesExplain`), so the
    sufficiency implication `Terminates r → ReachesExplain r` holds for both runs.
    The non-vacuity of I-1 lives in the `ReachesExplainCF` necessity lemma + the
    structural terminal half, NOT in this (unconditional-by-D-8) antecedent. -/
inductive Terminates : Run → Prop where
  | r0 : Terminates .r0
  | r1 : Terminates .r1

/-- **Counterfactual augmentation (explain skipped on the hard-stop path).** The
    I-1 liveness necessity witness: a CF world where explain is NOT reached on the
    hard-stop path — `r0` still reaches explain but there is NO constructor for
    `r1`. Under this relation a terminating run (`r1`) fails to reach explain, so
    `∃ r, Terminates r ∧ ¬ ReachesExplainCF r` (witness `r1`). The I-1 necessity
    lemma cites this to show the "explain runs on every (incl. hard-stop) path"
    fact (D-8) is LOAD-BEARING —
    `negation_provenance(explain_skipped_on_hard_stop, contradicts)` — rather than
    holding by CWA fiat. Mirrors `RunAttemptCF` (I-6) and `StartIdxCF1` (I-4). -/
inductive ReachesExplainCF : Run → Prop where
  | r0 : ReachesExplainCF .r0
  -- NB: no constructor for `r1` — under CF, explain is skipped on the hard-stop path.

/-! ## I-2 artifact gating — required upstream artifact precedes its consumer

    PRESERVED EXACTLY — the real 7-edge requires chain. -/

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

/-! ## I-3 termination — recovery budget per key (lex measure first component)

    PRESERVED EXACTLY — the four keys, budget 1 each. The concrete-Step
    machinery lives in `Proofs/I3Termination.lean`. -/

/-- `RecoveryBudget k b` ⟺ key `k` carries per-key budget `b` (= LOOP_LIMIT = 1).
    The recovery sum is `#keys * LOOP_LIMIT = 4`; the second lex component is
    `endIdx - cursor`. Well-foundedness of `Prod.Lex Nat.lt Nat.lt` over two
    bounded naturals is the I-3 obligation. -/
inductive RecoveryBudget : RecoveryKey → Nat → Prop where
  | s3 : RecoveryBudget .s3 1
  | s4 : RecoveryBudget .s4 1
  | s5 : RecoveryBudget .s5 1
  | s6 : RecoveryBudget .s6 1

/-! ## I-4 monotone scope — startIdx strictly decreasing, endIdx fixed -/

/-- `StartIdx r step idx` ⟺ at `step` of run `r`, the scope start index is `idx`.

    NON-DEGENERATE: the start index DECREASES across steps (scope only widens),
    with genuinely DISTINCT values per run:

    * `r0`: step0 → 3, step1 → 1, step2 → 0.
    * `r1`: step0 → 2, step1 → 0.

    Antitonicity (`i ≤ j → startIdx j ≤ startIdx i`) is now load-bearing: the
    earlier-step value is strictly larger, so the re-proof must USE `i ≤ j` to
    discharge cross-step cases (e.g. `i=0, j=2` needs `startIdx 2 = 0 ≤ 3 =
    startIdx 0`), and the REVERSE direction (`startIdx i ≤ startIdx j`) is FALSE
    (`3 ≤ 0` does not hold) — so the adversary's reverse / no-ordering probes
    cannot type-check. -/
inductive StartIdx : Run → Nat → Nat → Prop where
  | r0_step0 : StartIdx .r0 0 3
  | r0_step1 : StartIdx .r0 1 1
  | r0_step2 : StartIdx .r0 2 0
  | r1_step0 : StartIdx .r1 0 2
  | r1_step1 : StartIdx .r1 1 0

/-- `EndIdx r e` ⟺ run `r`'s scope end index is the constant `e` (= 7, explain).
    Fixed per run; the second I-4 conjunct (endIdx never changes). -/
inductive EndIdx : Run → Nat → Prop where
  | r0 : EndIdx .r0 7
  | r1 : EndIdx .r1 7

/-- **Counterfactual augmentation (CF1, scope-narrowing).** Re-introduces the
    counterfactually-removed `scope_narrows_mid_run` fact as a later step whose
    start index is strictly LARGER than an earlier step's. The I-4 necessity
    lemma proves the property FAILS in this CF-extended world by direct
    constructor citation — `negation_provenance(scope_narrows_mid_run,
    contradicts)`, so the removal is structurally necessary, not CWA-fragile.

    PRESERVED (per spec) — and kept genuinely non-monotone: the real prefix
    decreases (3 → 1 → 0) and step3 jumps back UP to 5, so a later start exceeds
    an earlier one. -/
inductive StartIdxCF1 : Run → Nat → Nat → Prop where
  | r0_step0 : StartIdxCF1 .r0 0 3
  | r0_step1 : StartIdxCF1 .r0 1 1
  | r0_step2 : StartIdxCF1 .r0 2 0
  | r0_step3_narrowed : StartIdxCF1 .r0 3 5   -- scope narrowed: later start > earlier

/-! ## I-5 / I-6 / I-7 — disprove discipline, floors, and fan-out -/

/-- `RunAttempt r a` ⟺ run `r` performs disprove attempt `a` (I-6 floor: ≥1).

    NON-DEGENERATE: BOTH runs attest at least one attempt, and the counts vary —
    `r0` fans out to `a0` AND `a1`, `r1` performs `a1`. So the I-6 floor
    `∀ r, ∃ a, RunAttempt r a` ranges over two runs and genuinely discriminates
    ≥1 from 0 (see `RunAttemptCF` for the 0-attempt regression). -/
inductive RunAttempt : Run → DisproveAttempt → Prop where
  | r0_a0 : RunAttempt .r0 .a0
  | r0_a1 : RunAttempt .r0 .a1
  | r1_a1 : RunAttempt .r1 .a1

/-- **Counterfactual augmentation (zero-attempt run).** The I-6 floor's
    necessity witness: a run that performs NO disprove attempt. Mirrors the
    real `RunAttempt` for `r0` but provides NO constructor for `r1` — under this
    CF relation `r1` performs zero attempts, so `¬ ∃ a, RunAttemptCF .r1 a`. The
    I-6 necessity lemma cites this to show the floor FAILS for a 0-attempt run,
    making the `1 ≤ count` floor the operative (discriminating) clause rather
    than a CWA fiat. -/
inductive RunAttemptCF : Run → DisproveAttempt → Prop where
  | r0_a0 : RunAttemptCF .r0 .a0
  -- NB: no constructor for `r1` — it is the zero-attempt run under CF.

/-- `AttemptAdversary a adv` ⟺ attempt `a` fans out to adversary `adv`
    (I-7 floor: ≥2, run in parallel). PRESERVED — both attempts fan out to the
    two distinct adversaries, so I-7's `x ≠ y` biting clause holds for each. -/
inductive AttemptAdversary : DisproveAttempt → Adversary → Prop where
  | a0_adv1 : AttemptAdversary .a0 .adv1
  | a0_adv2 : AttemptAdversary .a0 .adv2
  | a1_adv1 : AttemptAdversary .a1 .adv1
  | a1_adv2 : AttemptAdversary .a1 .adv2

/-- `AdversariesParallel a` ⟺ attempt `a`'s adversaries run in parallel (C-5).
    PRESERVED — holds for every attempt. -/
inductive AdversariesParallel : DisproveAttempt → Prop where
  | a0 : AdversariesParallel .a0
  | a1 : AdversariesParallel .a1

/-- Disprove spend (I-5: spend ≥ reserve). NON-DEGENERATE / single-valued per
    attempt, with values that genuinely VARY and sit strictly/loosely above the
    reserve: `a0` spends 5, `a1` spends 3. -/
inductive Spend : DisproveAttempt → Nat → Prop where
  | a0 : Spend .a0 5
  | a1 : Spend .a1 3

/-- Disprove reserve (I-5: spend ≥ reserve). Single-valued per attempt; `a0`
    reserves 2 (so 2 ≤ 5), `a1` reserves 3 (so 3 ≤ 3). The universal
    `∀ a s r, Spend a s → Reserve a r → r ≤ s` is therefore load-bearing:
    a coexisting below-reserve spend (see `SpendCF`) would falsify it. -/
inductive Reserve : DisproveAttempt → Nat → Prop where
  | a0 : Reserve .a0 2
  | a1 : Reserve .a1 3

/-- **Counterfactual augmentation for `disprove_spends_below_reserve`** (C-3 /
    I-5). Restores an attempt whose spend is strictly BELOW its reserve (`a0`
    spends 0 against reserve 2). The I-5 necessity lemma cites this to show the
    reserve discipline FAILS once the forbidden fact is restored —
    `negation_provenance(disprove_spends_below_reserve, contradicts)`. -/
inductive SpendCF : DisproveAttempt → Nat → Prop where
  | a0_below : SpendCF .a0 0          -- restored: spend (0) below reserve (2)

/-- Disprove target vs own-output (I-5: target ≠ own output). Three-element
    surface domain so the disequality is genuinely ATTEMPT-DEPENDENT (the
    (target, own) pair differs across attempts), not a single constructor-fiat
    fact. Closed enum so each disequality still closes by constructor
    disjointness (`exhaust`), NOT by `decide`. -/
inductive DisproveSurface where
  | gate_target_descriptor | disproof_results | counterexamples
  deriving DecidableEq, Repr

/-- `Target a s` ⟺ attempt `a` attacks surface `s`. ATTEMPT-DEPENDENT: `a0`
    targets the gate descriptor, `a1` targets the disproof_results surface. -/
inductive Target : DisproveAttempt → DisproveSurface → Prop where
  | a0 : Target .a0 .gate_target_descriptor
  | a1 : Target .a1 .disproof_results

/-- `OwnOutput a s` ⟺ attempt `a`'s own output is surface `s`. ATTEMPT-DEPENDENT:
    `a0`'s own output is `disproof_results`, `a1`'s is `counterexamples`. For
    EACH attempt the target differs from the own output (`gate_target_descriptor
    ≠ disproof_results`; `disproof_results ≠ counterexamples`), but the surfaces
    vary by attempt — so the no-self-attack disequality is not a constant. -/
inductive OwnOutput : DisproveAttempt → DisproveSurface → Prop where
  | a0 : OwnOutput .a0 .disproof_results
  | a1 : OwnOutput .a1 .counterexamples

/-- **Counterfactual augmentation for `disprove_attacks_own_output`** (C-3 /
    I-5). Restores an attempt whose target COINCIDES with its own output (`a0`
    targets `disproof_results`, which is also `a0`'s own output). The I-5
    necessity lemma cites this to show the no-self-attack discipline FAILS once
    the forbidden fact is restored —
    `negation_provenance(disprove_attacks_own_output, contradicts)`. -/
inductive TargetCF : DisproveAttempt → DisproveSurface → Prop where
  | a0_self : TargetCF .a0 .disproof_results   -- restored: target = own output (a0)

end TargetWorld
