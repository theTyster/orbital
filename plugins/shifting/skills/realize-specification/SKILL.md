---
name: realize-specification
description: >
  Stage 6 of `trajectory:pipeline` (the seven-stage pipeline). Unskips one test at a time from `thoughts/tests/` and orchestrates sub-agents to realize the specification, routing each test by its `test_category` (projection vs behavioral_claim) and the ontology label (`claim_label/2`) of its cited claim in `thoughts/hypothesis.pl`. Modifies source under the target codebase directory and emits `thoughts/implementation_log.md`. The canonical entry point is `trajectory:pipeline`, which dispatches here when stage 6 is in scope. Invoke this skill directly when the user wants to drive an existing skipped test suite to green without re-running upstream stages — "drive the TDD suite to green", "implement the skipped tests", "implement from proof", "make these tests pass".
user-invocable: true
model: opus
effort: high
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent
argument-hint: "[test file path] [target codebase directory — REQUIRED] (optionally reads thoughts/hypothesis.pl, thoughts/lean_proof_results.pl)"
---

# realize-specification

Logical operation: **realize-specification** — implement code so that every `projection` test goes green and every `behavioral_claim` test reflects deliberate engineering judgment.

Take the skipped test file produced by `instantiate-properties` and drive it to green. Every `projection` test samples a machine-verified invariant at one fixture; every `behavioral_claim` test encodes a TDD-layer contract with no upstream proof. The implementation must satisfy all of them without weakening any.

This skill is a **thin orchestrator**. The real work — reading code, reading Prolog facts, writing code, running tests, scanning for re-introduced counterfactuals — is delegated to dedicated sub-agents. The orchestrator decides what to do next, hands paths around, and keeps the implementation log.

**The lean→tdd boundary is lossy.** Per the `lean_universal_neq_test_verified` enforcement rule, a passing `projection` test is a *witness* of a universal property at one fixture — it is not a re-proof of ∀x.P(x). The Lean theorem `∀x.P(x)` is the proof; the test that exercises `P(specific_fixture)` is a sample. Treat green projection tests as witnesses, not as verifications, and surface that distinction in the log.

The tests and proofs are the specification. Refactoring existing code to satisfy them is not only permitted — it is encouraged, because tests and proofs outrank prior structure.

## Inputs

**Carrier-only contract.** The sole carrier from the predecessor (`instantiate-properties`) is `thoughts/tests/` — the test file plus the `manifest.pl` that accompanies it. Each test carries `test_category(projection | behavioral_claim)` plus a carried-forward ontology label and (for projections) negation-provenance annotation. Predicates from `hypothesis.pl`, `lean_proof_results.pl`, and `model_results.pl` are *transitively cited* via the test-comment tags and the manifest's `cites_artifact/2` records — the `realize-test-briefer` sub-agent follows those references when assembling each per-test briefing. The orchestrator does not read upstream `.pl` files directly.

- **Carrier**: `thoughts/tests/{file}` + `thoughts/tests/manifest.pl` — the skipped TDD suite from `instantiate-properties`.
- **Stage-0 env**: `target_codebase_dir` (orchestrator-supplied) — the directory whose source files will be modified. There is no default; if the caller did not provide it, halt and ask.

The test file's tags use **`test_category(projection | behavioral_claim)`** — exactly two values. Reference: `../../references/ontology.md`.

## Orchestrator contract

Stage 6. Orchestration-substrate wire format: `plugins/trajectory/references/orchestration-substrate.md`.

**Orchestrator parameters accepted:** `refutation_shape_briefing` (refutation classes the orchestrator wants attacked on the implementation outputs); `halt_condition`; `success_criteria` (e.g., "all targeted tests pass; zero regressions").

**Gate-target descriptors emitted on completion** — two outputs:
- `modified_source_files` — the implementation edits. Primary refutation surface: any modified file that re-introduces a counterfactual fact (the Stage 3d watchdog catches obvious cases, but `disprove-proposition` can attack the implementation more broadly).
- `implementation_log_md` — the trace of unskip → green. Refutation surface: every entry tagged `property_verified` (a green projection test that is a sample, not a proof) is a candidate for adversarial sampling under different fixtures.

**Adjacent loopback target:** `instantiate-properties` (gaps: `wrong_test`, `tests_conflict`, `missing_context`). These are this skill's own adjacent move and run without orchestrator gating.

**Non-adjacent loopbacks** are now orchestrator-routed via `upstream_gap/3` emissions in `implementation_log.md`'s machine-readable header block, not the auto-routed prose blockers of the previous design:

- `upstream_gap(realize_specification, gap_descriptor(untestable_category, test(TestId, category_mismatch(Expected, Actual))), recovery_hint(instantiate_properties, refutation_shape_briefing([retag_category])))` — adjacent.
- `upstream_gap(realize_specification, gap_descriptor(schema_insufficient, claim(ClaimId, wrong_property)), recovery_hint(decompose_proposition, refutation_shape_briefing([resharpen_claim])))` — non-adjacent.
- `upstream_gap(realize_specification, gap_descriptor(schema_insufficient, claim(ClaimId, fragile_counterfactual)), recovery_hint(decompose_proposition, refutation_shape_briefing([sharpen_cwa_absent_to_contradicts])))` — non-adjacent, CWA-fragility-specific.
- `upstream_gap(realize_specification, gap_descriptor(schema_insufficient, claim(ClaimId, inaccurate_counterfactual_list)), recovery_hint(decompose_proposition, refutation_shape_briefing([reenumerate_counterfactuals])))` — non-adjacent.

When two implementation attempts on the same test fail, Stage 4 still emits `thoughts/implementation_blocked.md`; the orchestrator pattern-matches on the gap entries in the implementation log and decides whether to honor the recovery_hint.

If no language was detected when tests were generated (pseudotest format), halt and ask the user which language to implement in. Do not guess.

**Routing summary:**

| Test tag | Cited claim's `claim_label` | Briefing shape |
|---|---|---|
| `test_category(projection)` | `counterfactual` | **Removal** — delete the named fact's source location |
| `test_category(projection)` | `descriptive` or `prescriptive` | **Addition** — write code to satisfy the proven property at the sample fixture |
| `test_category(behavioral_claim)` | (no upstream claim) | **Behavioral** — engineering judgment governs |

Routing is decided by the `realize-test-briefer` agent, not the orchestrator. The orchestrator just reads the briefer's returned `briefing_shape` and routes the implementation agent's work accordingly.

## Scratch directory

This skill maintains state across stages in a scratch directory under the user's working tree:

```
thoughts/.realize_scratch/
├── survey.md                       # Stage 0 codebase survey (one-shot)
├── counterfactual_locator.json     # Stage 0 initial locator table
├── counterfactual_locator.md       # Human-readable companion
├── counterfactual_locator.recheck.<run_id>.json  # Stage 3d rechecks
├── baseline.json                   # Stage 1 baseline test result sets
├── briefings/
│   └── NNN-<test-slug>.md          # Per-test briefings (Stage 2a)
└── runs/
    ├── baseline.log                # Verbatim Stage 1 log
    ├── <run_id>.log                # Verbatim per-iteration logs
    └── <run_id>.digest.json        # Per-iteration structured digest
```

The orchestrator never inlines the contents of these files into its own context. It hands paths to sub-agents and reads only the small digests they return.

## What this skill does NOT do

- **Does not commit.** Git is the user's. The implementation log is the handoff.
- **Does not weaken tests or delete assertions.** Assumption-stub tests and `COVERAGE GAPS` items stay skipped by design.
- **Does not touch `thoughts/`** except to write inside `thoughts/.realize_scratch/`, toggle skip annotations in the test file, write `thoughts/implementation_log.md`, and (on loopback) write `thoughts/implementation_blocked.md`.
- **Does not make large architectural decisions alone.** Any change bigger than one function's internals goes through `Agent(Explore)` first.
- **Does not trust sub-agent summaries about test results.** Verification flows through `realize-suite-runner`, which compares to a persisted baseline.
- **Does not re-verify universal properties.** A green `projection` test samples one point in `∀x.P(x)`; the proof is what verifies the universal.

## Bias-isolation discipline

Every sub-agent delegation in this skill — to Explore, the realize-* trio, or general-purpose — applies the canonical role-brief + minimum-context discipline. The orchestrator's hopes about which test "should" be easy MUST NOT reach the implementation agent.

**Role-brief, applied per-invocation:** outcome-agnostic framing. For Explore: *"survey what exists; do not propose changes."* For the realize-counterfactual-scanner: *"locate or recheck; report findings as facts."* For the realize-suite-runner: *"run and digest; the digest is the verdict, not your summary."* For the briefer: *"assemble a self-contained briefing; halt with `status: blocked` rather than guess at routing."* For general-purpose (implementation): *"the briefing is the spec; halt if you cannot satisfy it without weakening a test."*

**Minimum-necessary context, applied per-invocation:** every brief sends only the briefing path, scratch paths, and the orchestrator-supplied parameters (`refutation_shape_briefing`, `halt_condition`, `success_criteria`). Do not paste hypothesis prose, downstream measure-entailment hopes, or commentary on whether the test "matters" to the user.

**Orchestrator responsibilities (never delegated):** decide the per-test routing only after the briefer returns; validate every digest against the implementation agent's claim before recording; own the upstream_gap emission decision; keep the implementation log structurally consistent.

## Process

### Stage 0 — Codebase survey + counterfactual locator

Two read-only sub-agents run in parallel — `Agent(Explore)` writes a structured `survey.md` (code layout, existing modules, exact project commands, adjacent constraints, test-runner notes, behavioral-contract infrastructure if any) and `Agent(realize-counterfactual-scanner)` in `initial` mode emits the `counterfactual_locator.json` / `.md` table.

Verbatim sub-agent briefs and the survey-section header contract live in **`references/stage0-survey.md`**. Skip 0b if `hypothesis.pl` does not exist (a behavioral-only test file). The orchestrator records only the paths and counts; the contents stay in the scratch dir.

### Stage 1 — Baseline (`Agent(realize-suite-runner)` in `baseline` mode)

Brief the suite runner:

> mode: baseline
> test_command: {exact command from survey}
> target_codebase_dir: {dir}
> scratch_dir: `thoughts/.realize_scratch/`
> baseline_path: `thoughts/.realize_scratch/baseline.json`

It writes `baseline.json` (green/red/skipped sets) and the verbatim log. Returns totals only.

The orchestrator keeps the path and the totals. It does NOT read the verbatim log unless something later forces it to.

If the runner reports many pre-existing failures, decide whether they are unrelated to this work (proceed) or whether the suite is too broken to baseline against (halt, ask the user).

### Stage 2 — Main TDD loop

For each skipped test in the generated file, top-to-bottom (order is load-bearing — never jump ahead):

**Skip the assumption-stub tests and any `COVERAGE GAPS` items.** They stay skipped.

**2a. Brief `Agent(realize-test-briefer)`** with the next real test:

> test_file: {path}
> test_name: {exact name}
> scratch_dir: `thoughts/.realize_scratch/`
> survey_path: `thoughts/.realize_scratch/survey.md`
> counterfactual_locator_path: `thoughts/.realize_scratch/counterfactual_locator.json`
> prolog_paths:
>   - `thoughts/lean_proof_results.pl` (or `thoughts/model_results.pl`)
>   - `thoughts/hypothesis.pl`
>   - any domain `.pl` files
> failure_output_path: (filled in after 2c — see below)
> target_codebase_dir: {dir}

The briefer returns `briefing_path`, `briefing_shape`, `test_category`, `claim_label`, `negation_provenance`, `notes`. If it returns `status: blocked`, treat as Stage 4 loopback.

Note: 2a is run in TWO passes. First pass before 2b/2c, with `failure_output_path` empty, to establish routing. Second pass after 2c, re-briefing only the `failure_output_path` field, so the briefing carries the real failure verbatim. (The briefer overwrites the same briefing file.)

**2b. Unskip the test.** This is one of the few edits the orchestrator makes directly — toggle the skip annotation in the test file.

**2c. Run the suite (`Agent(realize-suite-runner)` in `verify` mode).**

> mode: verify
> test_command: {exact command}
> target_codebase_dir: {dir}
> scratch_dir: `thoughts/.realize_scratch/`
> baseline_path: `thoughts/.realize_scratch/baseline.json`
> targeted_test: {test name}
> run_id: `2c-NNN-<slug>`
> pre_existing_failures: {list from baseline}

Confirm `targeted_outcome == fail` and the failure shape is "missing implementation / missing module / assertion mismatch" — not a compile error or fixture error that needs its own fix. The runner returns a short `targeted_failure_excerpt`; write it to `thoughts/.realize_scratch/runs/2c-NNN-<slug>.failure.txt` and pass that path back to the briefer for the second pass of 2a.

**2d. Delegate implementation to `Agent(general-purpose)`** with a one-line brief that just hands over the briefing path:

> Read `{briefing_path}`. Implement the change it describes. The briefing is fully self-contained — it includes the property text, the cited claim, the failure output, the relevant codebase map slice, the exact project commands, and the rules. Run the full test suite and type check yourself before returning. Report what you ran and what passed.

Three briefing shapes — addition, removal, behavioral — are produced by the briefer per the routing table. The shape is encoded in the briefing file; the implementation agent does not need separate orchestrator instructions.

**2e. Verify independently (`Agent(realize-suite-runner)` in `verify` mode)** with `run_id: 2e-NNN-<slug>`. Two pass criteria, both required:

1. `targeted_outcome: pass`
2. `regressions: 0` (relative to baseline, excluding pre-existing failures)

If `regressions > 0` even when `targeted_outcome == pass`, treat as failure for routing purposes.

**2f. On failure or regression.** Brief a second `Agent(general-purpose)` with the same briefing path AND the new digest path:

> Re-read `{briefing_path}`. Your previous attempt produced this digest: `{digest_path}`. Read it. The targeted test is still red and/or {N} regressions appeared: {first 3 names}. Adjust the implementation. Same rules as the original briefing. Run the suite yourself before returning.

Re-run 2e. If two implementation iterations cannot resolve it, go to Stage 4.

**2g. Append to `thoughts/implementation_log.md`** — property name, test name, `test_category`, `claim_label` (if applicable), summary of what changed (sourced from the implementation agent's return, not from the diff), whether a refactor occurred, which agents ran, and the digest paths for forensic traceability. Outcome field uses `property_verified` for projection tests (acknowledging it as a sample witness of the proof) and `behavioral_witness` for `behavioral_claim` tests. One entry per unskipped test.

**2h. Advance to the next test.**

### Stage 3 — Refactor pass (at logical boundaries)

After finishing a coherent group of related tests, run a dedicated refactor pass.

**3a. `Agent(Explore)`** — briefed with the list of files touched during this group and the full property set (paths to `lean_proof_results.pl`, `hypothesis.pl`, the briefings dir). Ask it to find: duplication introduced across tests, naming drift from the Prolog vocabulary, unclear boundaries, dead intermediate state. Read-only — it proposes, it does not edit.

**3b. `Agent(general-purpose)`** — briefed with the Explore findings and the invariant: every generated test and every pre-existing test must remain green; every proven property must still hold. The refactor agent executes the changes the Explore agent proposed (or a reasoned subset), runs the suite itself, and returns.

**3c. Verify (`Agent(realize-suite-runner)` in `verify` mode)** with `run_id: 3c-refactor-<group>` and no `targeted_test`. Pass criteria: `regressions: 0`. On regression, delegate blame attribution to `Agent(regression-bisector)`:

> baseline_digest_path: `thoughts/.realize_scratch/baseline.json`
> current_digest_path: `thoughts/.realize_scratch/runs/3c-refactor-<group>.digest.json`
> git_diff_range: `<the range spanning the refactor pass — orchestrator picks; usually HEAD~N..HEAD where N is the refactor's commit count, or the pre-refactor ref..HEAD if uncommitted>`
> target_codebase_dir: {dir}
> scratch_dir: `thoughts/.realize_scratch/`

The bisector returns `{regression_test → suspect_files[] → confidence}` rows (NDJSON on stdout) plus a structured summary. The orchestrator uses the suspect mapping to decide between three routes: (a) brief the refactor agent to revert specific files when one or more `high`-confidence suspects map cleanly to the regression set, (b) revert the entire refactor pass when suspects are diffuse or all `low`-confidence, (c) escalate to Stage 4 loopback when bisection produces empty suspect lists (regression cause lies outside the diff window). The bisector produces blame, never a patch; the fix/revert decision stays with the orchestrator.

**3d. Counterfactual re-introduction check (`Agent(realize-counterfactual-scanner)` in `recheck` mode):**

> mode: recheck
> hypothesis_path: `thoughts/hypothesis.pl`
> target_codebase_dir: {dir}
> scratch_dir: `thoughts/.realize_scratch/`
> prior_locator_path: `thoughts/.realize_scratch/counterfactual_locator.json`
> touched_files: {list from refactor}

If `reintroduced_count > 0`, treat as a regression: brief the refactor agent with the scanner's `reintroduced` list and instruct deletion. Re-run 3c and 3d. A refactor that satisfies new invariants but silently re-introduces a previously-removed counterfactual is the exact failure mode the counterfactual lens exists to prevent.

**Behavioral regression check.** Re-run all `test_category(behavioral_claim)` tests via the suite-runner with `targeted_test` rotated through each one (or via the runner's totals if behavioral tests are tagged in the runner). A refactor that satisfies a projection test but breaks a behavioral one is NOT a formally-valid trade-off — the refactor silently weakened a contract the proof layer never knew about. Treat as regression.

Log the refactor pass in `thoughts/implementation_log.md` as its own entry.

### Stage 4 — Loopback (when a test cannot be made green)

If two implementation attempts on the same test fail, do not keep grinding. Delegate a read-only diagnosis to `Agent(Explore)` using the seven-class failure taxonomy and routing rules in **`references/loopback-classifications.md`** — wrong test / wrong property / tests conflict / missing context / fragile counterfactual (CWA-absent) / inaccurate counterfactual list / behavioral test with no upstream property.

Write the classification and recommended pipeline stage to `thoughts/implementation_blocked.md`, halt, leave the offending test unskipped with its failure intact. **This skill does not auto-restart any upstream stage** — the human decides what to re-run.

## Agent delegation reference

| Task | Agent | Why |
|---|---|---|
| Initial codebase survey | `Agent(Explore)` | Read-only, broad, scoped; writes survey.md |
| Initial counterfactual locator table | `Agent(realize-counterfactual-scanner)` mode `initial` | Queries hypothesis.pl + greps codebase; writes locator JSON/MD |
| Per-test briefing assembly | `Agent(realize-test-briefer)` | Reads test + Prolog facts; emits self-contained briefing file |
| Test-suite execution + delta vs baseline | `Agent(realize-suite-runner)` | Owns all suite invocations and returns small digests instead of verbatim logs |
| Single-test implementation (any briefing shape) | `Agent(general-purpose)` | Reads briefing path; the briefing carries shape-specific rules |
| Refactor discovery | `Agent(Explore)` | Must not edit while finding smells |
| Refactor execution | `Agent(general-purpose)` | Briefed from Explore findings |
| Counterfactual re-introduction check | `Agent(realize-counterfactual-scanner)` mode `recheck` | Re-greps for forbidden signatures; reports drift vs prior locator |
| Regression blame attribution (Stage 3c) | `Agent(regression-bisector)` | Intersects each regressed test's surface with the diff window; emits ranked suspect files per regression |
| Loopback diagnosis | `Agent(Explore)` | Read-only classification |
| Toggling one skip annotation | **Orchestrator (Edit)** | Single-line edit; the only direct test-file edit |
| Appending to implementation log | **Orchestrator (Edit)** | Structured one-row append |

The orchestrator's own edits are limited to: toggling skip annotations in the test file, appending to the implementation log, and writing the blocked report. Every substantive code edit, every substantive code read, every test-suite invocation, and every Prolog query happens in a sub-agent.

## Output

- **Primary**: modified source files inside `target_codebase_dir` (produced by sub-agents).
- **Always**: `thoughts/implementation_log.md` — chronological per-test record. Human-reviewed; also feeds `explain`.
- **Loopback only**: `thoughts/implementation_blocked.md` — written when Stage 4 halts.
- **Scratch artifacts**: everything under `thoughts/.realize_scratch/`. These are forensic — durable enough to resume an interrupted run, ephemeral enough that the user can `rm -rf` them between runs without breaking the pipeline.
- Skip annotations in the test file updated in place (the progress ledger; re-running the skill resumes at the first still-skipped real test).

## Final report

- Tests unskipped and passing: N / M (of the implementable real tests)
- Tests intentionally left skipped: K (assumption stubs, coverage gaps — list them)
- Refactor passes run: list, with one-line summary of each
- Baseline regressions encountered and their resolution
- Loopback status: none, or blocked at test {name} with classification {...}
- Test category breakdown of tests completed: N `test_category(projection)` (broken down further by `claim_label`: descriptive / prescriptive / counterfactual), M `test_category(behavioral_claim)`.
- For projection tests: count how many cited claims had `negation_provenance(_, absent)` vs `negation_provenance(_, contradicts)` — relevant for assessing CWA-fragility risk.
- Behavioral_claim tests remaining red (if any) with their classification from Stage 4.
- Path to `thoughts/implementation_log.md` and to `thoughts/.realize_scratch/`
- Next steps

## Guidance

- **`lean_universal_neq_test_verified`** — projection tests witness a sample, not a proof. Implement the property generally; do not let a passing fixture deceive you into thinking the universal is established by the test.
- **Behavioral_claim tests have no upstream proof** — log their outcomes as `behavioral_witness`, not `property_verified`. Persistent failures surface to the user; no formal-pipeline loopback.
- **CWA-absent ≠ Lean-disproved** — counterfactual claims with `negation_provenance(absent)` are fragile against KB completeness; treat persistent failures as candidates for `decompose-proposition` loopback.
- **The suite-runner's digest is the judge** — never the implementation agent's summary or the orchestrator's reading of the diff. After every implementation attempt, run verify-mode and trust the digest.
- **Run the whole suite, not just the generated file** — pre-existing tests are part of the specification; `regressions` is computed against the baseline's full green set.
- **Tests and proofs outrank existing structure** — briefings explicitly permit refactoring adjacent code. Refactoring goes through Explore first (test-scoped during Stage 2, structure-scoped during Stage 3).
- **Use domain names from the Prolog facts** — `explain` and `measure-entailment` depend on the code and the facts sharing vocabulary.
- **Assumption stubs stay skipped** — `skip(reason="assumption not proven — verify manually")` is a deliberate gap; the skill does not unskip them.
- **Halt loudly, don't drift quietly** — two failed implementation attempts → loopback (Stage 4), not a third attempt with looser assertions.
- **Briefings are self-contained** — the briefer agent assembles them; if one is missing a section, fix the briefer or `references/realize-briefing-rules.md`, not the briefing.
- **Removal briefings are deletion work** — LLM implementors prefer adding code; an agent that adds code in response to a removal briefing is a failed attempt regardless of whether the test passed.
- **A silently re-introduced counterfactual is worse than a failing test** — Stage 3d's `recheck` mode greps the entire codebase, not just touched files.

## Additional resources

- **`../../agents/realize-test-briefer.md`** — per-test briefing agent
- **`../../agents/realize-suite-runner.md`** — test-suite runner with baseline-delta digests
- **`../../agents/realize-counterfactual-scanner.md`** — counterfactual locator + re-introduction watchdog
- **`../../agents/regression-bisector.md`** — regression blame attribution agent for Stage 3c
- **`../../references/realize-briefing-rules.md`** — canonical addition / removal / behavioral rule blocks copied into every briefing
- **`../../references/ontology.md`** — definitions of `claim_label` and `negation_provenance`
