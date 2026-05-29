# Adherence Report

**Date:** 2026-05-29
**Mode:** Prime-relative (prime: `thoughts/hypothesis.pl`) — pipeline-terminal (Stage 7 of 7)
**Hypothesis loaded:** yes (direct-load exception `measure_entailment_hypothesis_direct_load`)
**Implementation under review:** `experiments/pipeline-workflow/` (`orbital-pipeline.workflow.js` + `lib/*.js` + `schemas/stage-digest.schema.js`)
**Carrier:** `thoughts/implementation_log.md` (realize-specification)
**Test gate:** 24 proof-property tests — independently re-run: **24 pass / 0 fail / 0 skipped**

This is a **self-verifying (dogfood)** run: the spec is its own pipeline input. The §1 proposition was carried close-world → decompose → model-obligations → prove-invariants → instantiate-properties → realize-specification → (here) measure-entailment, with one disprove-driven I-3 loopback.

---

## Headline Verdicts

| Verdict | Count | Status |
|---------|-------|--------|
| Counterfactual claims honored | **10 / 10** | clean — every forbidden fact correctly absent from impl |
| Counterfactual violations (Pattern 3) | **0** | clean (success criterion met) |
| Prescriptive — invariant obligations machine-checked (I-1..I-7) | **7 / 7** | fulfilled (24/24 proof-property tests green) |
| Prescriptive — existence + dogfood (now-resolvable) | **2 / 2** | satisfied — transition from Stage-2 `absent` to present |
| Prescriptive unfulfilled | **0** | clean |
| Prescriptive negation violations | **0** | clean |
| Descriptive claims (7) entailed | **7 / 7** | entailed (design decisions realized in source) |
| Contradictions (real) | **0** | 8 flagged by `find_contradictions/1` are multi-valued-set false positives (see below) |
| Descriptive drift | skipped | `existing-world.pl` is not in `asserts/2` form — no fact-level drift surface |

**All success criteria met: zero Pattern 3 violations; all 9 prescriptive claims satisfied; all 7 descriptive claims entailed.** Absence of bad news across every category is itself the verdict.

### No blocking rows

Every "blocking" verdict (Pattern 3, prescriptive unfulfilled, prescriptive negation violations) is **0**. There is nothing for `disprove-proposition` to attack on the implementation side: no counterfactual forbidden fact survived into the code, and no required obligation is missing.

---

## Per-Label Verdicts

### Counterfactual claims honored (10 / 10) — Pattern 3 clean

Each counterfactual claim in `hypothesis.pl` named a fact that had to be **false** in the implemented world (all with provenance `contradicts` — structurally necessary, not CWA-fragile). The label-aware pass (`counterfactual_honored/2`) confirms every forbidden premise atom is **absent** from the `impl` claim set, independently corroborated by source inspection:

| Claim | Forbidden fact (absent) | Source evidence |
|-------|------------------------|-----------------|
| `cf_v1_no_wallclock_control` | `control_decision_on_wallclock_or_random` | `workflow.js:55-57` — clock/rng injected, threaded only to the agent surface; no `Date.now`/`new Date` anywhere in control |
| `cf_v1_no_randomness_control` | `control_decision_on_wallclock_or_random` | no `Math.random` in repo; test 24 proves identical trail across different clock/rng |
| `cf_v1_no_substrate_verdict` | `orchestration_layer_computes_logic_verdict` | `digest-router.js:30-57` — `routeDigest` reads `status`/`gaps`/`coreObligation`/`reason` only; `artifactContent` deliberately ignored (the C-2 inversion bug) |
| `cf_v1_no_self_orchestration` | `self_orchestration_framing` | orchestration is a `runPipeline` script, not a judging skill (D-1) |
| `cf_v1_orchestration_not_skill` | `orchestration_is_a_skill` | realized as a Workflow JS module, not a `.md` skill |
| `cf_v1_no_scope_narrowing` | `scope_narrows_mid_run` | `scope-set.js:24-27` — `widenScope = min(startIdx, target)`, `endIdx` preserved; startIdx can only lower |
| `cf_v1_no_self_attack` | `disprove_attacks_own_output` | `disprove-reserve.js:67-75` — `chooseTarget` filters out `ownOutput` |
| `cf_v1_no_below_reserve` | `disprove_spends_below_reserve` | `disprove-reserve.js:48` — `spend = max(reserve, opportunistic, 1)`; even budget 0 cannot drop below reserve |
| `cf_v1_no_human_prompt` | `human_prompt_mid_run` | no `readline`/`prompt`/stdin read in the loop; `runPipeline` is non-interactive |
| `cf_v1_realize_not_parallel` | `realize_specification_runs_parallel` | no fan-out construct around realize; single serial mutating loop body (D-9) |

The headline C-2 inversion check (the R1-refuted framing — substrate computing a logic verdict itself rather than branching on an agent-emitted digest field) is **honored**: `routeDigest` branches solely on agent-emitted digest fields and the schema pins a `ROUTABLE_FIELDS` allowlist (`status`, `verdict`, `gaps`, `coreObligation`, `reason`). The substrate never derives `provable`/`refuted`/`inconsistent`.

### Prescriptive — invariant obligations machine-checked (I-1..I-7: 7 / 7)

These seven prescriptive claims carry **no `claim_premise`** in `hypothesis.pl` — they are "must become machine-checked" obligations, not fact-presence checks. They are scored against the proof-property suite (Stage 5 instantiation of the Stage 4 Lean proofs), all green:

| Claim | Invariant | Proving tests (all PASS) | Mechanic |
|-------|-----------|--------------------------|----------|
| `pr_v1_i1_liveness` | I-1 every terminating path reaches `explain` | 15 `explain_always_runs`, 22 `crit8_explain_runs_exactly_once_last`, 16 `explain_is_terminal` | `workflow.js:155` post-loop unconditional record; `stage-order.js` `stageSuccessor("explain")===null` |
| `pr_v1_i2_gating` | I-2 no stage before its upstream artifact | 7 `artifact_gating`, 8 `close_world_ungated` | `stage-order.js:50-67` `canRunStage`/`requiredUpstream` |
| `pr_v1_i3_termination` | I-3 lexicographic M strictly decreases (non-vacuous) | 11, 12 (forward/loopback decrease), 13 `no_measure_preserving_step`, 14 `recovery_budget_bound` | `termination-measure.js` — `stepForward` drops `cursorDistance`, `stepLoopback` drops `recoveryBudgetSum` by 1 (dominant), no identity step |
| `pr_v1_i4_monotone` | I-4 startIdx non-increasing, endIdx fixed | 1, 2 (`scope_narrowing_*`) | `scope-set.js` `widenScope` |
| `pr_v1_i5_reserve` | I-5 spend ≥ reserve, target ≠ own output | 3, 4, 5, 6 (self-attack + below-reserve, both directions) | `disprove-reserve.js` |
| `pr_v1_i6_floor` | I-6 ≥1 disprove attempt per run | 9 `disprove_floor` | `workflow.js:73` `runMandatoryDisprove` before the loop, every path |
| `pr_v1_i7_fanout` | I-7 ≥2 adversaries in parallel | 10 `disprove_fanout` | `disprove-reserve.js:57-63` — 2 distinct adversaries, `parallel: true` |

**I-3 non-vacuity note.** `hypothesis.pl`'s I-3 `formal_property` was re-stated *non-vacuously* after the disprove gate refuted the original vacuous form (a free measure + an identity step that trivially satisfied any decrease). The re-stated property requires a concrete `Step` relation with strict lexicographic decrease and *no* measure-preserving step. The implementation's `termination-measure.js` realizes exactly that concrete relation, and test 13 (`termination_no_measure_preserving_step`) pins the non-vacuity: both the forward and loopback steps strictly change M.

### Prescriptive — existence + dogfood (2 / 2, now-resolvable)

These two premises carried `claim_negation_provenance(_, _, absent)` in `hypothesis.pl` — at Stage 2 they were modeled as *currently-absent, must-come-to-exist* facts (the Workflow did not yet exist; the self-verification run had not yet completed). **Both are now resolved by this run** and are scored **satisfied**, with the transition noted:

| Claim | Premise | Stage-2 state | Stage-7 state | Evidence |
|-------|---------|---------------|---------------|----------|
| `pr_v1_workflow_exists` | `workflow_artifact_exists_on_disk` | `absent` (D-13 fragile) | **present** | `experiments/pipeline-workflow/orbital-pipeline.workflow.js` exists (214 lines) + 8 `lib/*.js` + schema |
| `pr_v1_self_verified` | `self_verification_run_completed` | `absent` (open, per `a_v1_self_verify_circularity`) | **present** | this pipeline run carried §1 close-world → … → measure-entailment; one disprove-driven I-3 loopback recorded |

These were intentionally *not* asserted as `impl` facts in the label-aware pass, because doing so would trip `prescriptive_negation_violations` (the strict reading: any fact with a `negation_provenance` entry that appears in impl is a Pattern-3-shaped violation). That strict reading is wrong here: the spec *wanted* these facts to come true ("must come to exist"), so their arrival is **fulfillment, not violation**. Recording them as negated-premise violations would be a false alarm. They are therefore verdicted out-of-band as satisfied existence/dogfood obligations. (Stage-2 assumption `a_v1_self_verify_circularity` explicitly directed: "do not score it entailed until stage 7" — that gate is now passed.)

### Descriptive claims entailed (7 / 7)

The seven descriptive claims were already entailed by `existing-world.pl` as design decisions; the implementation realizes each in source:

- `cf_v1_d_workflow` (D-1, deterministic Workflow not skill) → `orbital-pipeline.workflow.js` is a JS Workflow module.
- `cf_v1_d_separation` (D-2, mechanics/judgment split) → substrate owns `lib/*` mechanics; agent surface owns judgment.
- `cf_v1_d_det_substitute` (D-10, work-unit-bounded effort) → deterministic step accounting; clock is a non-control backstop.
- `cf_v1_d_parallel_map` (D-9, fan-out map) → `STAGE_SEQUENCE` + serial realize; fan-out is a per-stage agent concern.
- `cf_v1_d_explain_closer` (D-8/I-1, unique terminal) → `stageSuccessor("explain")===null`; total order frozen.
- `cf_v1_d_floors` (D-6/D-7/C-5 floors) → `LOOP_LIMIT=1`, ≥1 attempt, ≥2 adversaries.
- `cf_v1_d_dogfood` (D-12, spec as its own input) → this run.

### Descriptive drift — skipped

`thoughts/existing-world.pl` exists but is not in `asserts/2` resource form (it is a close-world KB of ground facts/rules), so it offers no fact-level drift surface against `impl`. Per `references/adherence-verdicts.md`: **skipped — no existing-world resource (in asserts/2 form).** Descriptive claims have no fact-level encoding in `hypothesis.pl`, so there is no automated drift row; the entailment above is by source inspection.

---

## Resources

| ID | Path | Claims |
|----|------|--------|
| `hyp` | structural projection of `thoughts/hypothesis.pl`'s §1 target world | 35 |
| `impl` | `experiments/pipeline-workflow/` (source) | 35 |

(`hyp` is a structural mirror in shared predicate vocabulary so overlap is measurable; `hypothesis.pl` itself is the label carrier, loaded directly for the verdict pass.)

## Adherence Scores

| Resource | Score (vs prime `hyp`) | Shared | Gaps | Contradictions (real) | Extensions |
|----------|------------------------|--------|------|------------------------|------------|
| `impl` | **100.00%** | 35/35 | 0 | 0 | 0 |

## Shared Facts (all 35, impl ≡ hyp)

The implementation asserts every structural claim the target world asserts, and no more — exact structural coincidence. Representative rows: `orchestration_realized_as(workflow_script)`, `terminal_stage(explain)`, `stage_successor(explain, none)`, `gating_required(true)`, `termination_measure(lexicographic, [recovery_budget_sum, cursor_distance])`, `measure_non_vacuous(no_identity_step)`, `scope_monotone(start_idx, non_increasing)`, `scope_fixed(end_idx)`, `loop_limit(1)`, `disprove_adversaries_per_attempt_floor(2)`, `substrate_branches_on(digest_fields_only)`, `substrate_computes_logic_verdict(false)`, `control_decision_on(deterministic_state_and_digest_only)`, `background_executable(true)`, `workflow_artifact_present(true)`, `self_verification_completed(true)`.

## Gaps

None. Every claim in the prime is present in `impl`.

## Contradictions

`find_contradictions/1` flagged **8 pairs**, all of which are **false positives** from the predicate's single-valued assumption. Two predicates are intentionally *multi-valued sets*, and `impl` and `hyp` hold **identical** sets for both:

- `hard_stop_reason/1`: both resources = `{budget_exhausted, core_obligation_refuted, loop_limit_exhausted}` (verified identical).
- `measure_strictly_decreases/1`: both resources = `{forward_step, loopback_step}` (verified identical).

There are **zero real contradictions**: the implementation disagrees with the target world on no fact.

## Extensions

None. The implementation asserts nothing beyond the target world's structural surface. (The codebase has additional *internal* helpers — `loopbacksFor`, `measureM`, `lexLt`, etc. — but these are mechanism behind the asserted claims, not new claims.)

## Analysis

The implementation **fully entails** the §1 proposition. All 10 counterfactual obligations are honored (zero Pattern 3 violations — the substrate never computes a logic verdict, never narrows scope, never lets disprove attack itself or spend below reserve, and never branches on wall-clock or randomness), all 7 invariant obligations are machine-checked green, the 2 previously-absent existence/dogfood premises are now resolved by this very run, and all 7 descriptive design decisions are realized in source. The 100% structural score is *not* a misleading aggregate masking a hidden breach — there are no blocking verdicts beneath it; the score and the per-label verdicts agree. The only noise is 8 spurious "contradictions" from a single-valued-predicate assumption in `find_contradictions/1`, confirmed to be identical sets in both resources. The critical inversion smell (C-2 / R1) that this whole exercise was guarding against is decisively absent: `routeDigest` is a pure function of agent-emitted digest fields and explicitly discards `artifactContent`.

## Prolog Evidence

- Facts file: `thoughts/adherence_facts.pl` (35 `impl` + 35 `hyp` claims; 10 appended `result(counterfactual_honored, ...)` facts; 0 violation results)
- Hypothesis file: `thoughts/hypothesis.pl` (loaded directly; `hypothesis_loaded` = yes; 26 claims: 7 descriptive / 10 counterfactual / 9 prescriptive)
- Prime: `hyp` (structural) / `hypothesis.pl` (label carrier)
- Module: `plugins/shifting/skills/measure-entailment/prolog/adherence.pl` (loaded `except([claim/2, claim/3])`)
- Queries run: `counterfactual_violations/2`, `counterfactual_honored/2`, `prescriptive_unfulfilled/2`, `prescriptive_fulfilled/2`, `prescriptive_negation_violations/2`, `adherence_score/3`, `shared_claims/3`, `gap_claims/3`, `extension_claims/3`, `find_contradictions/1`, `label_aware_facts_out/2`
- Verdict counts: counterfactual_violations=0, counterfactual_honored=10, prescriptive_unfulfilled=0, prescriptive_fulfilled=0 (no positive-premise prescriptive claims under strict label semantics), prescriptive_negation_violations=0
