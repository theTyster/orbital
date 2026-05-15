# Orchestration Substrate — Plugin-side Interface

This document specifies the **plugin-side** of the typed boundary between the seven-stage `shifting` pipeline and whatever orchestrates a single ticket through it. It is the wire format: what each primitive skill **emits** as a gate-target descriptor, what each primitive **accepts** as orchestrator-supplied parameters, what enforcement rules every primitive cites.

It does **not** specify the orchestrator's behavior — that is downstream design (mind-map / external Opus session / future meta-skill). The plugin documents its boundary; the orchestrator documents its responsibilities. This split is load-bearing: anything beyond the wire format belongs in the mind-map's `philosophy/orchestration-substrate.md`, not here.

The contract is grounded in `~/Projects/mine/orbital/thoughts/target-world.pl` — the Prolog model that emerged from `ticket-pipeline-rewrite-primitive-with-orchestration-channel.md`'s Phase 2 run. Every predicate cited below is queryable in that file under strict-load.

## The two layers

```
┌─────────────────────────────────────────────────────────────────┐
│  ORCHESTRATION SUBSTRATE  (external — mind-map, meta-skill, …)  │
│  • holds bespoke domain context                                  │
│  • parameterises each primitive per run                          │
│  • reads gate-target descriptors                                 │
│  • invokes disprove-proposition against descriptors              │
│  • consumes disproof_results.pl / counterexamples.pl             │
│  • decides cross-stage non-adjacent loopback                     │
└─────────────────────────────────────────────────────────────────┘
                              ↕  typed boundary
┌─────────────────────────────────────────────────────────────────┐
│  PIPELINE  (the seven staged primitives in `shifting`)           │
│  close-world → decompose-proposition → model-obligations →       │
│  prove-invariants → instantiate-properties →                     │
│  realize-specification → measure-entailment                      │
│                                                                  │
│  • each is single-input / single-output over its declared carrier│
│  • emits gate-target descriptors; never self-invokes them        │
│  • accepts orchestrator parameters; never invents them           │
│  • loops back only to its immediate predecessor                  │
│  • role-briefs every specialist; passes minimum-necessary context│
└─────────────────────────────────────────────────────────────────┘
                              ↕  layer-separate
        ┌──────────────────────────────────────────┐
        │  disprove-proposition  (unstaged)        │
        │  • lives at the orchestration layer     │
        │  • is the gate realizer the orchestrator│
        │    invokes against descriptors          │
        │  • does not gate the pipeline's outputs │
        │    by self-invocation                   │
        └──────────────────────────────────────────┘
```

The seven-stage pipeline order is invariant (`ds_t2_003` in `hypothesis.pl`). `disprove-proposition` is **structurally outside** the pipeline (it is `unstaged_skill/1` in both `existing-world.pl` and `target-world.pl`) — this is the R2 resolution. Universal-gate closure over `produces/2` pairs does not reach `disprove-proposition` because `disprove-proposition` is not at the same layer; no in-pipeline exemption mechanism is required.

## Gate-target descriptor — the wire format

Every artifact-producing primitive emits one **gate-target descriptor** per output. The descriptor is the structured handle the orchestrator reads to decide whether to invoke `disprove-proposition` against this artifact, and (if so) what refutation shape to brief.

A descriptor has three components:

| Field | What it carries | Source |
|---|---|---|
| **Artifact identity** | The named output (`existing_world_pl`, `hypothesis_pl`, `target_world_pl`, …) | `produces/2` in the KB; concrete file path on disk |
| **Declared shape** | The predicate schema the artifact carries — at minimum the discontiguous declaration block at the top of the `.pl` file, or the canonical schema doc | `references/pipeline-schema/*.md` in `shifting` |
| **Refutation-shape suggestions** | Specific refutation classes that are *plausible* given the artifact's content — open-domain assumptions, recursive premises, novel prescriptive obligations, narrow-quantifier formal properties | Inherited from upstream context; augmented by the producing skill |

The descriptor is **capability-shaped**, not commitment-shaped. The primitive declares "this is what you would attack and how" — it does not invoke the attack. The R2-refuted `emits_disprove_gate/2` predicate (a universal closure asserting "every produced artifact is self-attacked") is rejected; the canonical predicate is `emits_gate_target_descriptor/2`.

## Emitted descriptors (the outbound channel)

The twelve `emits_gate_target_descriptor(Skill, Artifact)` facts in `target-world.pl`. Each row is a descriptor a primitive emits; the orchestrator decides whether to invoke `disprove-proposition` against it.

| # | Skill | Artifact emitted | Notes |
|---|---|---|---|
| 1 | `close-world` | `existing_world_pl` | The KB itself — primary refutation surface for open-domain CWA assumptions |
| 2 | `decompose-proposition` | `hypothesis_pl` | The claim list — primary refutation surface for new premises and labels |
| 3 | `model-obligations` | `target_world_pl` | The substrate Lean proves over |
| 4 | `model-obligations` | `target_world_shape_lean` | The Lean-side structural translation (omitted when no closed domains) |
| 5 | `model-obligations` | `model_results_pl` | Per-property verdicts |
| 6 | `prove-invariants` | `lean_proof_results_pl` | Per-theorem verdicts |
| 7 | `prove-invariants` | `lean_proofs_dir` | The proof files themselves |
| 8 | `instantiate-properties` | `tests_dir` | Skipped tests pending implementation |
| 9 | `realize-specification` | `modified_source_files` | The implementation edits |
| 10 | `realize-specification` | `implementation_log_md` | The trace of unskip → green |
| 11 | `measure-entailment` | `adherence_facts_pl` | The extracted claim set |
| 12 | `measure-entailment` | `adherence_report_md` | The verdict narrative |

**Open scoping question — gap-flagged in Phase 2.** `realize-specification` has 8 additional internal `produces/2` entries — `realize_scratch_dir`, `survey_md`, `counterfactual_locator_json`, `counterfactual_locator_md`, `baseline_json`, `briefings_dir`, `suite_run_logs_dir`, `implementation_blocked_md`. These were not listed in the T2 prescription. The property `p_t2_gate_target_descriptor_total` quantifies over "every staged producing skill emits a gate-target descriptor for every output." The 12-pair prescription implicitly restricted "every output" to *externally-visible* outputs. This narrowing needs to be made explicit before Phase 3b (`prove-invariants`).

Two acceptable resolutions:
- (a) Widen the prescription to 20 pairs and add the 8 internal artifacts as additional descriptor-emitters.
- (b) Refine `p_t2_gate_target_descriptor_total` to quantify over `produces/2` *minus* `scratch/1` or some `externally_visible/1` filter, and add the filter to `target-world.pl`.

Either is consistent with R1/R2; the choice is a Phase-3 design decision rather than a deeper unresolved counterfactual.

## Orchestrator parameters (the inbound channel)

The seventeen `accepts_orchestrator_parameter(Skill, ParamType)` facts in `target-world.pl`. Each row is a parameter shape a primitive accepts from the orchestrator — supplied per run, not hardcoded into the skill.

| Skill | Parameter types accepted |
|---|---|
| `close-world` | `predicate_schema_extension`, `success_criteria`, `halt_condition` |
| `decompose-proposition` | `refutation_shape_briefing`, `artifact_versioning`, `halt_condition` |
| `model-obligations` | `refutation_shape_briefing`, `halt_condition` |
| `prove-invariants` | `refutation_shape_briefing`, `halt_condition` |
| `instantiate-properties` | `refutation_shape_briefing`, `halt_condition` |
| `realize-specification` | `refutation_shape_briefing`, `halt_condition`, `success_criteria` |
| `measure-entailment` | `success_criteria`, `halt_condition` |

The five categories of orchestrator-supplied state covered:

- **`predicate_schema_extension`** — bespoke predicates the orchestrator wants added to `existing-world.pl` for this ticket (e.g., `csproj_content_directive/1`, `published_artifact/1` for fp_i07's R3 substrate)
- **`refutation_shape_briefing`** — refutation classes the orchestrator wants `disprove-proposition` to focus on when later invoked against this primitive's outputs
- **`success_criteria`** — what counts as completion of this primitive's work for this run (e.g., minimum coverage, target verdict counts)
- **`halt_condition`** — when this primitive should stop and surface a partial result rather than continue
- **`artifact_versioning`** — for `decompose-proposition`, the v1/v2/... namespace convention the orchestrator wants for hypothesis emissions when a re-decomposition is needed

The orchestrator passes these as structured terms (Prolog facts) the skill consults at startup. Skills MUST NOT default to ad-hoc values when a parameter is absent — they MUST surface that the parameter is missing.

## Bias-defense discipline — applies to every delegation

Every primitive that delegates to a specialist sub-agent applies a **two-layer bias defense** on every delegation point:

1. **Outcome-agnostic role-briefing** — the delegation opens with a role-frame that is neutral to the desired verdict ("you are looking for whether this property holds *or fails*"; not "prove this"). Forty `calls_specialist_with_role_brief(Skill, true)` facts in `target-world.pl` — the seven staged primitives plus `disprove-proposition`.
2. **Minimum-necessary context** — the delegation passes the smallest context that lets the specialist do its work; broader context is escalated only on demand. Nineteen `delegates_with_minimum_context(Skill, Agent)` facts in `target-world.pl`.

Both obligations are enforced via the `enforcement_rule_cited_by(bias_defense_uniform, Skill)` facts (eight of them — the seven staged plus `disprove-proposition`). The rule is total: there is no exempted delegation.

| Primitive | Specialist agents briefed under the rule |
|---|---|
| `close-world` | `agent-of-truth` |
| `decompose-proposition` | `agent-of-questions`, `agent-of-truth`, `lean-expert` |
| `model-obligations` | `prolog-prover`, `agent-of-questions` |
| `prove-invariants` | `lean-expert` |
| `instantiate-properties` | `agent-of-questions`, `Explore` |
| `realize-specification` | `Explore`, `realize-counterfactual-scanner`, `realize-suite-runner`, `realize-test-briefer`, `general-purpose` |
| `measure-entailment` | `agent-of-truth`, `agent-of-questions` |
| `disprove-proposition` | `lean-expert`, `agent-of-questions`, `prolog-prover` |

## Loopback signaling — adjacent only

After T2, every loopback inside the pipeline is to the **immediate stage-predecessor** (`gap = 1`). The orchestrator handles non-adjacent escalation; primitives do not loop across non-adjacent stages.

| From | To (adjacent predecessor) | Conditions |
|---|---|---|
| `model-obligations` | `decompose-proposition` | inconsistent verdict, extraneous counterfactual, gap verdict |
| `prove-invariants` | `model-obligations` | open-string position needing inductive shape, missing closure |
| `instantiate-properties` | `prove-invariants` | property has no theorem id, theorem verdict was vacuous |
| `realize-specification` | `instantiate-properties` | test has no test_category label, briefing template missing |

The ten non-adjacent loopbacks present in T1 (all `prove-invariants` / `instantiate-properties` / `realize-specification` → `decompose-proposition`) are CF-removed in T2. When a primitive's adjacent loopback alone is insufficient — when, say, `prove-invariants` cannot make progress against any nearby refinement of the model — the primitive escalates *upward to the orchestrator*, which decides whether to drive a non-adjacent loopback.

The orchestrator's escalation channel is *out of band* with respect to the pipeline; the pipeline records the escalation signal but does not act on it. The same channel that carries `halt_condition` parameters also carries escalation acknowledgements.

## Disproof artifacts — orchestrator-consumed only

Three artifacts produced by `disprove-proposition` flow into the orchestrator, **never back into the pipeline**:

| Artifact | Predicate in target-world | Read by |
|---|---|---|
| `disproof_results.pl` | `consumed_by_orchestrator(disproof_results_pl)` | orchestrator only |
| `counterexamples.pl` | `consumed_by_orchestrator(counterexamples_pl)` | orchestrator only |
| `lean_disproofs_dir` | `consumed_by_orchestrator(lean_disproofs_dir)` | orchestrator only |

The pipeline's primitives do not auto-consume these. If the orchestrator decides that a disproof verdict should drive a loopback or a halt, it parameterizes the next primitive run accordingly via the inbound channel (`refutation_shape_briefing`, `halt_condition`, etc.).

This decision is the R2 resolution: by typing disprove outputs as *inputs to orchestrator decision-making* (not artifacts the pipeline self-attacks), universal-gate closure terminates cleanly at the layer boundary.

## The four T2 enforcement rules

Every staged primitive cites all four rules; `disprove-proposition` cites only `bias_defense_uniform` (it lives at the orchestration layer, so the three pipeline-internal rules don't apply to it).

| Rule | What it requires | Cited by |
|---|---|---|
| `carrier_only_reads` | A staged primitive reads only the declared carrier from its immediate predecessor (or a stage-0 user-supplied carrier). No optional reads, no cross-skill reads. | 7 staged primitives |
| `gate_target_descriptor_total` | Every staged producing skill emits a gate-target descriptor for every (externally-visible) output. | 7 staged primitives |
| `bias_defense_uniform` | Every delegation applies role-briefing + minimum-necessary context. | 7 staged + `disprove-proposition` = 8 |
| `orchestration_outside_pipeline` | The orchestration substrate is external to the pipeline; primitives accept its parameters but do not invent them. | 7 staged primitives |

These are `enforcement_rule_cited_by/2` facts in `target-world.pl`. They feed Phase 3b — the `prove-invariants` stage proves each rule holds over `target-world.pl`'s ground facts.

## What the orchestrator MAY do

- Read any gate-target descriptor and invoke `disprove-proposition` against it with a refutation-shape briefing
- Supply any subset of accepted orchestrator parameters to any primitive at run-start
- Read `disproof_results.pl` / `counterexamples.pl` / `lean_disproofs_dir` and decide pipeline next moves
- Drive cross-stage non-adjacent loopback by re-invoking an upstream primitive with a refined parameter set
- Hold ticket lineage across runs (e.g., `prior_witness/2` from a previous T1 refutation)
- Extend the predicate schema of `existing-world.pl` per-run via `predicate_schema_extension`

## What the orchestrator MUST NOT do

- Re-introduce `emits_disprove_gate(_, _)` as a universal closure over `produces/2` pairs. That predicate shape was refuted by witness R2.
- Invoke `disprove-proposition` from inside any staged primitive. That shape was refuted by witness R1.
- Treat a `negation_provenance(_, absent)` marker as a Lean-disproved fact — CWA-absent ≠ Lean-disproved (`cwa_negation_neq_lean_proof` in shifting's ontology).
- Override a primitive's own delegation discipline. The orchestrator parameterizes; it does not bypass.
- Read pipeline-internal predicates that are not surfaced through the gate-target descriptors or the parameters in this doc.

## Cross-references

- T2 hypothesis: `~/Projects/mine/orbital/thoughts/hypothesis.pl`
- T2 target-world: `~/Projects/mine/orbital/thoughts/target-world.pl`
- T2 model results: `~/Projects/mine/orbital/thoughts/model_results.pl`
- Phase-1 refutation witnesses: `~/Projects/mine/orbital/thoughts/witnesses/prop_pipeline_rewrite_R{1,2,3}_*.md`
- Driving ticket: `~/Projects/mine/orbital/thoughts/ticket-pipeline-rewrite-primitive-with-orchestration-channel.md`
- Plugin-side ontology (origin labels, negation provenance, CWA-vs-Lean): `../../shifting/references/ontology.md`
- Pipeline-schema files (per-artifact wire format): `../../shifting/references/pipeline-schema/`
- Hilbert prior: mind-map `philosophy/smart-orchestrator-dumb-executor.md`
- Layer-boundary witness record: mind-map `philosophy/external-orchestration-boundary.md`
