---
name: translate-to-implementation
description: >
  Use this skill whenever the user wants to implement code from proven formal properties — "drive the TDD suite to green", "implement the skipped tests", "implement from proof", or "make these tests pass". Unskips one test at a time and orchestrates sub-agents to realize the specification, routing each test by its `test_category` (projection vs behavioral_claim) and the `epistemic_label` of its cited claim in `hypothesis.pl`.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent
argument-hint: "[test file path] [target codebase directory — REQUIRED] (optionally reads thoughts/hypothesis.pl, thoughts/lean_proof_results.pl)"
---

# Translate to Implementation

Logical operation: **realize_specification** — implement code so that every `projection` test goes green and every `behavioral_claim` test reflects deliberate engineering judgment.

Take the skipped test file produced by `translate-to-tests` and drive it to green. Every `projection` test samples a machine-verified invariant at one fixture; every `behavioral_claim` test encodes a TDD-layer contract with no upstream proof. The implementation must satisfy all of them without weakening any.

This skill is a **thin orchestrator** — the real work of reading code, writing code, and refactoring is delegated to sub-agents. The orchestrator decides what to do next, runs the test suite as the source of truth, and keeps the implementation log.

**The lean→tdd boundary is lossy.** Per the `lean_universal_neq_test_verified` enforcement rule, a passing `projection` test is a *witness* of a universal property at one fixture — it is not a re-proof of ∀x.P(x). The Lean theorem `∀x.P(x)` is the proof; the test that exercises `P(specific_fixture)` is a sample. Treat green projection tests as witnesses, not as verifications, and surface that distinction in the log.

The tests and proofs are the specification. Refactoring existing code to satisfy them is not only permitted — it is encouraged, because tests and proofs outrank prior structure.

## Inputs

- **Required**: `thoughts/tests/{file}` — the skipped TDD suite from `translate-to-tests`. Each test in this file carries `test_category(projection | behavioral_claim)` plus carried-forward `epistemic_label` and (for projections) `negation_provenance` annotations.
- **Required environment**: `target_codebase_dir` — the directory whose source files will be modified. There is no default; if the caller did not provide it, halt and ask.
- **Optional**: `thoughts/hypothesis.pl` — Prolog facts for claims, with `claim/2`, `claim_label(_, descriptive | counterfactual | prescriptive)`, `negation_provenance(_, absent | contradicts)`, sub-hypothesis decomposition, and edge predicates. When present, the orchestrator routes briefing shape by reading `claim_label` here.
- **Optional**: `thoughts/lean_proof_results.pl` — Prolog facts file containing `theorem_verdict/2` and accompanying facts. Each `projection` test cites a theorem here; when present, the proof is the ground truth for ambiguous tests.
- **Optional**: `thoughts/*.pl` — any additional Prolog facts files (e.g. domain vocabulary, model results) the test file or hypothesis cite.

The test file's tags use **`test_category(projection | behavioral_claim)`** — exactly two values. The orchestrator reads this tag and the cited claim's `claim_label/2` from `hypothesis.pl` to choose briefing shape (Stage 2d) and loopback behavior (Stage 4). Reference: `../../references/epistemic-types.md`.

If no language was detected when tests were generated (pseudotest format), halt and ask the user which language to implement in. Do not guess.

**Routing summary (Stage 2a/2d):**

| Test tag | Cited claim's `claim_label` | Briefing shape |
|---|---|---|
| `test_category(projection)` | `counterfactual` | **Removal** — delete the named fact's source location |
| `test_category(projection)` | `descriptive` or `prescriptive` | **Addition** — write code to satisfy the proven property at the sample fixture |
| `test_category(behavioral_claim)` | (no upstream claim) | **Behavioral** — engineering judgment governs |

The two orthogonal diagnostic dimensions on each `projection` test are `epistemic_label` (from the cited claim) and `negation_provenance` (from the cited claim's negated premises, when applicable). Both flow through to Stage 4 loopback decisions.

## What this skill does NOT do

- **Does not commit.** Git is the user's. The implementation log is the handoff.
- **Does not weaken tests or delete assertions.** Assumption-stub tests and `COVERAGE GAPS` items stay skipped by design.
- **Does not touch `thoughts/`** except to toggle skip annotations in the test file, write `thoughts/implementation_log.md`, and (on loopback) write `thoughts/implementation_blocked.md`.
- **Does not make large architectural decisions alone.** Any change bigger than one function's internals goes through `Agent(Explore)` first.
- **Does not trust sub-agent summaries about test results.** The orchestrator runs the tests itself.
- **Does not re-verify universal properties.** A green `projection` test samples one point in `∀x.P(x)`; the proof is what verifies the universal.

## Process

### Stage 0 — Codebase survey (`Agent(Explore)`, one-shot)

Before unskipping anything, brief `Agent(Explore)` to build a map the rest of the run will reuse:

> Survey this codebase to prepare for a TDD implementation pass against a generated test file at {path}. Report:
> 1. Where implementation code should live relative to the test file — feature root, module layout, package conventions
> 2. Any existing modules, stubs, or types that the tests reference or imply
> 3. The project's build, type-check, lint, format, and test commands (look in package.json scripts, Makefile, justfile, pyproject, Cargo.toml, etc.) — give exact invocations, not descriptions
> 4. Adjacent code whose shape the tests will constrain (shared interfaces, DI registration, public exports)
> 5. Anything unusual about how tests are run (watch mode, test tags, required env vars)
> 6. **Counterfactual locator.** Query `thoughts/hypothesis.pl` for every claim where `claim_label(ClaimId, counterfactual)` holds. For each such counterfactual claim — typically a fact like `depends_on(cli_tool, logging)` or `calls(moduleA, functionB)` that the proof requires to be *absent* from the codebase — locate the exact file(s) and line(s) where that fact currently materialises in the codebase: the import statement, the call site, the config entry, whatever. Return a table mapping each counterfactual claim (with its `negation_provenance` value) to its source locations. If a counterfactual fact has no discoverable source, flag it as `ALREADY_ABSENT` — the corresponding projection test should already pass.
> 7. **Behavioral-contract infrastructure**: if the generated test file contains any `test_category(behavioral_claim)` tests, identify the hooks this codebase already has for observing side effects / state / timing (e.g., test doubles, integration test harnesses, clock injection, retry mocks). Behavioral tests often depend on these.

Store the survey in working memory. Every subsequent briefing includes the relevant slices of it so sub-agents do not re-discover the landscape. The counterfactual locator table is load-bearing for removal briefings: it tells the implementation agent *which lines to delete*, so the agent does not guess or invent a workaround.

### Stage 1 — Baseline

Run the project's full test suite (using the command from the survey) before touching any skip annotations. Record:
- Which tests are currently green
- Which are currently failing for reasons unrelated to this work
- Whether the newly-generated test file's skips actually take effect in this runner

The baseline is the reference for detecting regressions. Pre-existing failures are not caused by this skill and are not blockers.

### Stage 2 — Main TDD loop

For each skipped test in the generated file, top-to-bottom (order is load-bearing — never jump ahead):

**Skip the assumption-stub tests and any `COVERAGE GAPS` items.** Those stay skipped. Move past them.

**2a. Read the next real test.** Extract the property name, the property statement from the test's comment, and the test's `test_category` tag. Cross-reference:
- For `test_category(projection)`: read the cited theorem from `lean_proof_results.pl` (the `theorem_verdict/2` fact and any accompanying premise/conclusion facts). If the test is upstream-of-Lean (model-level), read the corresponding `model_results.pl` entry. Then read the cited claim from `hypothesis.pl` and extract its `claim_label/2` and (if applicable) `negation_provenance/2`. The `claim_label` selects between addition and removal briefings.
- For `test_category(behavioral_claim)`: there is no upstream proof to read. Note this and proceed.

If the Prolog domain facts (`existing-world.pl`, `target-world.pl`, etc.) provide vocabulary for the property's named entities, note the exact identifiers the implementation should use.

**Route on test_category and claim_label:**
- `test_category(projection)` AND cited claim has `claim_label(_, counterfactual)` → **removal briefing**.
- `test_category(projection)` AND cited claim has `claim_label(_, descriptive)` or `claim_label(_, prescriptive)` → **addition briefing**.
- `test_category(behavioral_claim)` → **behavioral briefing**.

**2b. Unskip it.** This is one of the few edits the orchestrator makes directly — toggle the skip annotation in the test file.

**2c. Run the full project test suite.** Confirm the unskipped test now fails *for the expected reason* (missing implementation, missing module, assertion mismatch — not a compile or fixture error that would require its own fix). Capture the failure output verbatim.

**2d. Delegate implementation to `Agent(general-purpose)`** with a self-contained brief. Three shapes — **addition**, **removal**, **behavioral** — selected by the routing table in 2a.

**Addition briefing (`test_category(projection)` with `claim_label(_, descriptive | prescriptive)`):**

> Implement code to make this test pass.
>
> **Property text (from `lean_proof_results.pl`):** {full property text and the `theorem_verdict/2` reference; include the theorem statement and any accompanying premise facts}
> **Cited claim (from `hypothesis.pl`):** {`claim/2` text}
> **Claim label:** {descriptive | prescriptive}
> **Test category:** projection
> **Test file:** {path}
> **Failing test name:** {name}
> **Failure output:**
> ```
> {captured output from 2c}
> ```
> **Domain vocabulary (from `existing-world.pl` / `target-world.pl`):** {any relevant named entities — use these identifiers, not invented ones}
> **Edge predicate / sub-hypothesis notes (from `hypothesis.pl`):** {any relevant text}
>
> **Codebase map:**
> {relevant slice of the Stage 0 survey}
>
> **Project commands:**
> - Tests: `{exact command}`
> - Type check: `{exact command or "none"}`
> - Lint: `{exact command or "none"}`
>
> **Rules:**
> - This test samples one point in a proven universal property. Implement the property generally — do not hard-code only the fixture's case.
> - You may refactor existing code. Tests and proofs are the specification; existing structure is not. If the cleanest path to green touches adjacent files, take it.
> - Do not modify anything under `thoughts/`.
> - Do not weaken assertions, skip tests, or disable type checks.
> - Do not alter other tests in the generated file.
> - Run the full project test suite and type check yourself before returning. Report what you ran and what passed.

**Removal briefing (`test_category(projection)` with `claim_label(_, counterfactual)`):**

> Remove code to make this test pass. **The action is deletion, not addition.** The counterfactual claim listed below was proven load-bearing for a downstream property — the property holds only when this fact is absent from the codebase. Do not add a new abstraction, feature flag, or indirection to "hide" the fact. Delete the fact's source.
>
> **Counterfactual claim (from `hypothesis.pl`):** {the `claim/2` text — e.g., the negated form of `depends_on(cli_tool, logging)`}
> **`claim_label`:** counterfactual
> **`negation_provenance`:** {`absent` | `contradicts`}
>   - If `absent`: the proof relies on the closed-world reading that this fact is not in the KB. Removing the source is a CWA refactor — fragile against KB completeness; report carefully.
>   - If `contradicts`: the explicit-conflict premise is structurally enforced. Removing the source must not re-introduce the conflict elsewhere.
> **Downstream property this enables (from `lean_proof_results.pl`):** {property text and `theorem_verdict/2` reference}
> **Test category:** projection
> **Test file:** {path}
> **Failing test name:** {name}
> **Failure output:**
> ```
> {captured output from 2c}
> ```
>
> **Source locations for this fact (from Stage 0 counterfactual locator):**
> {file:line list — these are the lines to delete or amend}
>
> **Codebase map:**
> {relevant slice of the Stage 0 survey}
>
> **Project commands:**
> - Tests: `{exact command}`
> - Type check: `{exact command or "none"}`
> - Lint: `{exact command or "none"}`
>
> **Rules:**
> - The expected change is removal of an import, call, config entry, export, or dependency — not the creation of new code. If you find yourself adding a file or a function to make the test pass, stop and reconsider.
> - If removing the fact breaks pre-existing green tests, those tests themselves were relying on the forbidden dependency — report the situation, do not silently delete or alter them. Escalation will be decided by the orchestrator.
> - Do not add shims, re-exports, or alias modules that keep the forbidden identifier reachable under a different name. "Moving the dependency" is not removing it.
> - Do not modify anything under `thoughts/`.
> - Do not weaken assertions, skip tests, or disable type checks.
> - Do not alter other tests in the generated file.
> - Run the full project test suite and type check yourself before returning. Report what you ran and what passed.

**Behavioral briefing (`test_category(behavioral_claim)`):**

> Implement code to make this test pass.
>
> **No upstream proof.** This test is a first-class behavioral contract: I/O, state, timing, concurrency, or side effect. There is no `lean_proof_results.pl` or `model_results.pl` entry backing it, and no `claim/2` in `hypothesis.pl` enumerates it. The test itself is the specification.
> **Test category:** behavioral_claim
> **Test file:** {path}
> **Failing test name:** {name}
> **Failure output:**
> ```
> {captured output from 2c}
> ```
> **Domain vocabulary (from any Prolog facts files, if any applies):** {any relevant named entities — use these identifiers, not invented ones}
>
> **Codebase map:**
> {relevant slice of the Stage 0 survey}
>
> **Behavioral-contract infrastructure (from Stage 0 item 7):**
> {test doubles, clock injection, integration harness, retry mocks, etc.}
>
> **Project commands:**
> - Tests: `{exact command}`
> - Type check: `{exact command or "none"}`
> - Lint: `{exact command or "none"}`
>
> **Rules:**
> - The implementation is a matter of engineering judgment, not proof projection. Use the codebase's existing idioms for the behavior being asserted. If the test needs test doubles / clock injection / process-level observation, use the infrastructure identified in Stage 0 item 7.
> - **Do not treat a passing behavioral_claim test as equivalent in strength to a passing projection test.** In the implementation log, record this test's outcome as `behavioral_witness`, not as `property_verified`.
> - You may refactor existing code. The test is the specification; existing structure is not. If the cleanest path to green touches adjacent files, take it.
> - Do not modify anything under `thoughts/`.
> - Do not weaken assertions, skip tests, or disable type checks.
> - Do not alter other tests in the generated file.
> - Run the full project test suite and type check yourself before returning. Report what you ran and what passed.

**2e. Verify independently.** The orchestrator re-runs the full test suite. Two pass criteria, both required:
1. The targeted test is green.
2. No test that was green in the baseline (or after any prior iteration) is now red.

**2f. On failure or regression.** Brief a second `Agent(general-purpose)` with the fresh evidence: what the first agent changed, what still fails, what regressed. If two iterations cannot resolve it, go to Stage 4 (loopback).

**2g. Append to `thoughts/implementation_log.md`** — property name, test name, test_category, claim_label (if applicable), summary of what changed, whether a refactor occurred, which agents ran. Outcome field uses `property_verified` for projection tests (acknowledging it as a sample witness of the proof) and `behavioral_witness` for behavioral_claim tests. One entry per unskipped test.

**2h. Advance to the next test.**

### Stage 3 — Refactor pass (at logical boundaries)

After finishing a coherent group of related tests, run a dedicated refactor pass before continuing. Refactoring is a first-class, specification-driven activity — not a side effect.

**3a. `Agent(Explore)`** — briefed with the list of files touched during this group and the full property set. Ask it to find: duplication introduced across tests, naming drift from the Prolog vocabulary, unclear boundaries, dead intermediate state. Read-only — it proposes, it does not edit.

**3b. `Agent(general-purpose)`** — briefed with the Explore findings and the invariant: every generated test and every pre-existing test must remain green; every proven property must still hold. The refactor agent executes the changes the Explore agent proposed (or a reasoned subset), runs the suite itself, and returns.

**3c. Orchestrator re-runs the full suite.** Same two pass criteria as 2e. On regression, revert via the refactor agent (brief it with the regression) or escalate to loopback.

**3d. Counterfactual re-introduction check.** After the refactor pass, re-run every `test_category(projection)` test whose cited claim has `claim_label(_, counterfactual)`. Additionally, re-query `hypothesis.pl` for all `claim_label(ClaimId, counterfactual)` entries and grep the codebase for each counterfactual fact's source signature (the import path, function name, config key — whatever the Stage 0 locator originally found). A refactor that satisfies new invariants but silently re-introduces a previously-removed counterfactual under a different name is the exact failure mode the counterfactual lens exists to prevent. If a forbidden signature is found, treat it as a regression, brief the refactor agent to remove the re-introduction, and re-run.

- **Behavioral regression check.** After refactor, re-run all `test_category(behavioral_claim)` tests. These tests lack formal backing, so a refactor that satisfies a projection test but breaks a behavioral one is NOT a formally-valid trade-off — the refactor silently weakened a contract the proof layer never knew about. Treat this as a regression to revert.

Log the refactor pass in `thoughts/implementation_log.md` as its own entry.

### Stage 4 — Loopback (when a test cannot be made green)

If two implementation attempts on the same test fail, do not keep grinding. Delegate a diagnosis to `Agent(Explore)`:

> This test cannot be made to pass after two implementation attempts. Classify the failure as one of:
> - **Test is wrong** — the test's projection from the proof is incorrect (wrong assertion, wrong fixture, wrong shape)
> - **Property is wrong** — the proof is internally valid but models something different from the real system
> - **Tests conflict** — satisfying this test would violate a different proven property
> - **Missing context** — the proof depends on a precondition not expressed in any test
> - **Fragile counterfactual (CWA-absent)** *(only when `test_category(projection)` AND cited claim has `claim_label(_, counterfactual)` AND `negation_provenance(_, absent)`)* — the proof's negation depends on closed-world absence; the absent premise may be the cause of failure. The KB's completeness is suspect.
> - **Counterfactual list inaccurate** — the enumerated counterfactual claims in `hypothesis.pl` do not match reality: either a named fact cannot be cleanly removed because another proven property depends on it, or removing the fact is not enough to satisfy the downstream invariant (additional counterfactuals are needed).
> - **Behavioral test has no upstream property** — the failing test is `test_category(behavioral_claim)`. There is no proof to revise, no hypothesis to re-run. This is a TDD-layer decision: either fix the implementation, weaken the test (with human review), or accept it as a known-red behavioral contract. Recommendation: do NOT loop back to `hypothesize` or `prove-hypothesis-*`; surface to the user.
>
> **Test:** {name and path}
> **Test category:** {projection | behavioral_claim}
> **Cited property (if projection):** {text from `lean_proof_results.pl` or `model_results.pl`}
> **Cited claim (if projection):** {text and `claim_label` from `hypothesis.pl`}
> **`negation_provenance` (if applicable):** {absent | contradicts}
> **First attempt:** {diff summary and failure}
> **Second attempt:** {diff summary and failure}
>
> Do not edit anything. Read the test file, the proof artifact, the hypothesis, and the relevant source. Return the classification plus a recommendation of which pipeline stage to revisit (`hypothesize`, `prove-hypothesis-{lean,prolog}`, or `translate-to-tests`). For "counterfactual list inaccurate", recommend `hypothesize`. For "fragile counterfactual (CWA-absent)", recommend `hypothesize` (the fragile CWA premise must be re-examined). For "behavioral test has no upstream property", recommend no formal-pipeline revisit and surface to the user.

**Loopback routing (recommendations only — the human chooses):**
- Persistent failure on a `projection` test whose cited claim has `claim_label(_, counterfactual)` and `negation_provenance(_, absent)` → recommend the user revisit `hypothesize` (the fragile CWA premise may be the cause).
- Persistent failure on any other `projection` test → recommend revisiting one of the prove skills (`prove-hypothesis-lean` or `prove-hypothesis-prolog`, depending on which produced the cited property).
- Persistent failure on a `behavioral_claim` test → recommend NO formal-pipeline revisit. Surface to the user. The upstream nodes never expressed this claim; rerunning `hypothesize` cannot revise it.

For `test_category(behavioral_claim)` classifications, the `implementation_blocked.md` output must explicitly say "no upstream pipeline stage revises this claim" — this prevents the user from wasting a cycle re-running hypothesize on a behavioral failure.

Write the classification and recommended pipeline stage to `thoughts/implementation_blocked.md`. Halt. Leave the offending test unskipped with its failure intact. **This skill does not auto-restart any upstream stage** — the human reads the blocked report and decides what to re-run.

## Agent delegation reference

| Task | Agent | Why |
|---|---|---|
| Initial codebase survey | `Agent(Explore)` | Read-only, broad, scoped |
| Single-test implementation (`test_category(projection)`, descriptive/prescriptive claim) | `Agent(general-purpose)` — addition briefing | Narrow scope per test, needs edits |
| Single-test implementation (`test_category(projection)`, counterfactual claim) | `Agent(general-purpose)` — removal briefing | Deletion action; uses Stage 0 counterfactual locator |
| Single-test implementation (`test_category(behavioral_claim)`) | `Agent(general-purpose)` — behavioral briefing | No upstream proof; uses Stage 0 item 7 infrastructure |
| Refactor discovery | `Agent(Explore)` | Must not edit while finding smells |
| Refactor execution | `Agent(general-purpose)` | Briefed from Explore findings |
| Loopback diagnosis | `Agent(Explore)` | Read-only classification |
| Running tests, type checks, lint | **Orchestrator (Bash)** | Verification cannot be delegated |

Prefer delegation aggressively. The orchestrator's own edits are limited to: toggling skip annotations in the test file, writing the implementation log, and writing the blocked report. Every substantive code edit and every substantive code read happens in a sub-agent.

## Output

- **Primary**: modified source files inside `target_codebase_dir` (produced by sub-agents).
- **Always**: `thoughts/implementation_log.md` — chronological per-test record. Human-reviewed; also feeds `explain`.
- **Loopback only**: `thoughts/implementation_blocked.md` — written when Stage 4 halts. Contains the failure classification and the recommended pipeline stage to revisit. **The pipeline does not auto-loop**; a human reads this report and chooses which stage to restart from.
- Skip annotations in the test file updated in place (the progress ledger; re-running the skill resumes at the first still-skipped real test).

## Final report

- Tests unskipped and passing: N / M (of the implementable real tests)
- Tests intentionally left skipped: K (assumption stubs, coverage gaps — list them)
- Refactor passes run: list, with one-line summary of each
- Baseline regressions encountered and their resolution
- Loopback status: none, or blocked at test {name} with classification {...}
- Test category breakdown of tests completed: N `test_category(projection)` (broken down further by cited claim's `claim_label`: descriptive / prescriptive / counterfactual), M `test_category(behavioral_claim)`.
- For projection tests: count how many cited claims had `negation_provenance(_, absent)` vs `negation_provenance(_, contradicts)` — relevant for assessing CWA-fragility risk.
- Behavioral_claim tests remaining red (if any) with their classification from Stage 4.
- Path to `thoughts/implementation_log.md`
- Next steps

## Guidance

- **`lean_universal_neq_test_verified`:** **Projection tests witness a sample, not a proof. A green projection test does not re-verify ∀x.P(x).** The Lean theorem is the universal verification; the test exercises one fixture. Implement the property generally — do not let a passing fixture deceive you into believing the universal is established by the test.

- **Behavioral_claim tests have no upstream proof. Treat their outcomes as `behavioral_witness` in the log, not as `property_verified`.** A green behavioral_claim test means "the fixture passed on this run." Describe it that way; do not upgrade its confidence to match projection tests.

- **CWA-absent ≠ Lean-disproved: a counterfactual claim with `negation_provenance(absent)` is fragile against KB completeness; treat such failures as candidates for hypothesize-loopback.** The closed-world reading underlying an `absent` premise can dissolve if the KB is incomplete. When a projection test backed by such a claim cannot be made green, the right response is often to re-examine the hypothesis, not to grind on the implementation.

- **The test runner is the judge.** Not the sub-agent's summary. Not your reading of the diff. Re-run the full suite after every agent returns. If the suite disagrees with the agent, trust the suite.

- **Run the whole suite, not just the generated file.** Pre-existing tests are part of the specification too. A refactor that satisfies a new property while breaking an old test is not progress.

- **Tests and proofs outrank existing structure.** If the implementation agent proposes a refactor to adjacent code in order to keep invariants clean, let it. The skill exists to make the formal artifacts load-bearing; capitulating to legacy shape defeats the point.

- **Refactoring goes through Explore first.** Do not let an implementation agent make sweeping structural decisions mid-feature. Test-scoped edits during Stage 2, structure-scoped edits during Stage 3, each with its own Explore-then-edit split.

- **Use domain names from the Prolog facts.** If `existing-world.pl` or `target-world.pl` calls a component `auth_lib`, the implementation module should be `auth_lib`. This preserves the formal artifacts' reachability: future `explain` and `measure-adherance` runs depend on the code and the facts sharing vocabulary.

- **Assumption stubs stay skipped.** Tests marked with `skip(reason="assumption not proven — verify manually")` are deliberate gaps in the formal coverage. The skill does not unskip them. They appear in the final report as manual verification owed.

- **Halt loudly, don't drift quietly.** If two implementation attempts fail on one test, the likely cause is upstream (wrong test, wrong proof, conflicting properties, or a fragile CWA premise). The correct response is loopback, not a third attempt with looser assertions.

- **Briefings are self-contained.** A sub-agent starts with no memory of this conversation. Include the property text, the cited claim text and label, the failure output, the relevant codebase map slice, and the exact commands every time. Terse briefings produce shallow work.

- **Removal briefings are deletion work.** LLM implementors strongly prefer adding code over removing it — the default reflex against a failing test is to write something new. For `claim_label(_, counterfactual)` projections, that reflex produces "solutions" that add a wrapper, a flag, or an abstraction while leaving the forbidden dependency reachable. Use the removal briefing shape, include the Stage 0 locator output so the sub-agent has exact lines to delete, and explicitly forbid shims/re-exports/aliases. If the sub-agent returns having added code, treat it as a failed attempt regardless of whether the test passed.

- **A silently re-introduced counterfactual is worse than a failing test.** The Stage 3d re-check exists because a refactor against a descriptive/prescriptive projection can add back a forbidden import at a new call site without any counterfactual-projection test noticing (those tests assert specific source locations or identifiers, which a refactor may not trip). Grep for each counterfactual claim's signature after every refactor pass.

- **Behavioral failures don't loop back.** The upstream pipeline stages never expressed a behavioral_claim, so re-running `hypothesize` or `prove-hypothesis-*` cannot produce a revised formal artifact. The correct response to a persistent `test_category(behavioral_claim)` failure is a human decision, not a pipeline cycle.
