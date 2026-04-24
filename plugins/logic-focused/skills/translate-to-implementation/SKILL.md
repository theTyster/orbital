---
name: translate-to-implementation
description: >
  Use this skill whenever the user wants to implement code from proven formal properties — "drive the TDD suite to green", "implement the skipped tests", "implement from proof", or "make these tests pass". Unskips one test at a time and orchestrates sub-agents to implement each proven invariant.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write, Edit, Agent
argument-hint: "[test file path] [target codebase directory]"
---

# Translate to Implementation

Take the skipped test file produced by `translate-to-tests` and drive it to green. Every test encodes a machine-verified invariant; the implementation must satisfy all of them without weakening any. This skill is a **thin orchestrator** — the real work of reading code, writing code, and refactoring is delegated to sub-agents. The orchestrator decides what to do next, runs the test suite as the source of truth, and keeps the implementation log.

The tests and proofs are the specification. Refactoring existing code to satisfy them is not only permitted — it is encouraged, because tests and proofs outrank prior structure.

## Inputs

- **Required**: `thoughts/tests/{file}` — the skipped TDD suite from `translate-to-tests`
- **Required**: a target codebase directory
- **Strongly recommended**: `thoughts/proof_results.md` — each test cites a property; the proof is the ground truth when a test is ambiguous. In **conditional mode** it also lists the counterfactual facts that must be removed from the codebase and flags each as `NECESSARY` or `EXTRANEOUS`.
- **Recommended**: `thoughts/hypothesis.md` — edge predicates, open assumptions, refuted sub-hypotheses, and the **counterfactual question** ("what about the existing KB needs to be false for the proposition to be true?") that motivates Phase 0 removal work
- **Recommended**: `thoughts/*.pl` — domain vocabulary the implementation should adopt verbatim, plus structural constraints
- **Each test in the generated file carries an `epistemic_origin` tag** (one of `TEST_PROJECTED`, `TEST_PROJECTED+CWA_LIFTED`, `TEST_ABSENCE`, `TEST_ABSENCE+CWA_LIFTED`, `TEST_GUARD`, `TEST_BEHAVIORAL`). The orchestrator reads this tag from the test's comment block and uses it to choose briefing shape (Stage 2d) and loopback behaviour (Stage 4). Reference: `../../references/epistemic-types.md`.

If no language was detected when tests were generated (pseudotest format), halt and ask the user which language to implement in. Do not guess.

**Conditional mode changes the action.** When `proof_results.md` carries `Proof mode: conditional` for any property, the implementation action for the associated tests may be **deletion** of existing code rather than addition of new code. The test file's Phase 0 tests (absence + guard) cannot be driven green by writing more code; they go green only when a named import / call / dependency is removed. Treat this as the default failure mode to prepare for, not an edge case.

## What this skill does NOT do

- **Does not commit.** Git is the user's. The implementation log is the handoff.
- **Does not weaken tests or delete assertions.** Assumption-stub tests and `COVERAGE GAPS` items stay skipped by design.
- **Does not touch `thoughts/`** except to toggle skip annotations in the test file, write `thoughts/implementation_log.md`, and (on loopback) write `thoughts/implementation_blocked.md`.
- **Does not make large architectural decisions alone.** Any change bigger than one function's internals goes through `Agent(Explore)` first.
- **Does not trust sub-agent summaries about test results.** The orchestrator runs the tests itself.

## Process

### Stage 0 — Codebase survey (`Agent(Explore)`, one-shot)

Before unskipping anything, brief `Agent(Explore)` to build a map the rest of the run will reuse:

> Survey this codebase to prepare for a TDD implementation pass against a generated test file at {path}. Report:
> 1. Where implementation code should live relative to the test file — feature root, module layout, package conventions
> 2. Any existing modules, stubs, or types that the tests reference or imply
> 3. The project's build, type-check, lint, format, and test commands (look in package.json scripts, Makefile, justfile, pyproject, Cargo.toml, etc.) — give exact invocations, not descriptions
> 4. Adjacent code whose shape the tests will constrain (shared interfaces, DI registration, public exports)
> 5. Anything unusual about how tests are run (watch mode, test tags, required env vars)
> 6. **Counterfactual locator** (conditional mode only): for each counterfactual fact listed in `proof_results.md` (e.g., `depends_on(cli_tool, logging)`, `calls(moduleA, functionB)`), locate the exact file(s) and line(s) where that fact currently holds in the codebase — the import statement, the call site, the config entry, whatever materialises the fact. Return a table mapping each fact to its source locations. If a fact has no discoverable source, flag it as `ALREADY_ABSENT` — the absence test should already pass.
> 7. **Behavioral-contract infrastructure**: if the generated test file contains any `TEST_BEHAVIORAL` tests, identify the hooks this codebase already has for observing side effects / state / timing (e.g., test doubles, integration test harnesses, clock injection, retry mocks). Behavioral tests often depend on these.

Store the survey in working memory. Every subsequent briefing includes the relevant slices of it so sub-agents do not re-discover the landscape. The counterfactual locator table is load-bearing for Phase 0 briefings: it tells the implementation agent *which lines to delete*, so the agent does not guess or invent a workaround.

### Stage 1 — Baseline

Run the project's full test suite (using the command from the survey) before touching any skip annotations. Record:
- Which tests are currently green
- Which are currently failing for reasons unrelated to this work
- Whether the newly-generated test file's skips actually take effect in this runner

The baseline is the reference for detecting regressions. Pre-existing failures are not caused by this skill and are not blockers.

### Stage 2 — Main TDD loop

For each skipped test in the generated file, top-to-bottom (phase order is load-bearing — never jump phases):

**Skip the assumption-stub tests and any `COVERAGE GAPS` items.** Those stay skipped. Move past them.

**2a. Read the next real test.** Extract the property name, the property statement from the test's comment, and cross-reference the entry in `proof_results.md`. If the test comments a sub-hypothesis, read that section of `hypothesis.md` too. If the Prolog KB provides the domain vocabulary, note the exact identifiers the implementation should use.

Read the test's `epistemic_origin` tag. Route on it:
- `TEST_PROJECTED` or `TEST_PROJECTED+CWA_LIFTED` → use the **addition briefing** (existing).
- `TEST_ABSENCE` / `TEST_ABSENCE+CWA_LIFTED` / `TEST_GUARD` → use the **removal briefing** (existing Phase 0 shape).
- `TEST_BEHAVIORAL` → use the new **behavioral briefing** (third shape in Stage 2d below).

**2b. Unskip it.** This is one of the few edits the orchestrator makes directly — toggle the skip annotation in the test file.

**2c. Run the full project test suite.** Confirm the unskipped test now fails *for the expected reason* (missing implementation, missing module, assertion mismatch — not a compile or fixture error that would require its own fix). Capture the failure output verbatim.

**2d. Delegate implementation to `Agent(general-purpose)`** with a self-contained brief. The brief has two shapes — **addition** (invariant-mode tests) and **removal** (Phase 0 absence/guard tests in conditional mode) — and the orchestrator chooses the shape based on the test's phase and the proof mode of the cited property.

**Addition briefing (invariant mode, or any non-Phase-0 test):**

> Implement code to make this test pass.
>
> **Property:** {full property text from `proof_results.md`, including the proof reference}
> **Test file:** {path}
> **Failing test name:** {name}
> **Failure output:**
> ```
> {captured output from 2c}
> ```
> **Domain vocabulary (from Prolog KB):** {any relevant named entities — use these identifiers, not invented ones}
> **Edge predicate / assumption notes (from hypothesis):** {any relevant text}
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
> - You may refactor existing code. Tests and proofs are the specification; existing structure is not. If the cleanest path to green touches adjacent files, take it.
> - Do not modify anything under `thoughts/`.
> - Do not weaken assertions, skip tests, or disable type checks.
> - Do not alter other tests in the generated file.
> - Run the full project test suite and type check yourself before returning. Report what you ran and what passed.

**Removal briefing (Phase 0 absence and guard tests — conditional mode):**

> Remove code to make this test pass. **The action is deletion, not addition.** The counterfactual listed below was proven load-bearing for a downstream property — the property holds only when this fact is absent from the codebase. Do not add a new abstraction, feature flag, or indirection to "hide" the fact. Delete the fact's source.
>
> **Counterfactual fact:** {e.g., `depends_on(cli_tool, logging)`}
> **Counterfactual status from proof:** {NECESSARY | EXTRANEOUS — if EXTRANEOUS, still remove but flag in your report}
> **Downstream property this enables:** {property text from `proof_results.md`}
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
> - The expected change is removal of an import, call, config entry, export, or dependency — not the creation of new code. If you find yourself adding a file or a function to make the absence test pass, stop and reconsider.
> - If removing the fact breaks pre-existing green tests, those tests themselves were relying on the forbidden dependency — report the situation, do not silently delete or alter them. Escalation will be decided by the orchestrator.
> - Do not add shims, re-exports, or alias modules that keep the forbidden identifier reachable under a different name. "Moving the dependency" is not removing it.
> - Do not modify anything under `thoughts/`.
> - Do not weaken assertions, skip tests, or disable type checks.
> - Do not alter other tests in the generated file.
> - Run the full project test suite and type check yourself before returning. Report what you ran and what passed.

**Behavioral briefing (TEST_BEHAVIORAL tests):**

> Implement code to make this test pass.
>
> **Property:** **No upstream proof.** This test is a first-class behavioral contract: I/O, state, timing, concurrency, or side effect. There is no `proof_results.md` entry backing it. The test itself is the specification.
> **Test file:** {path}
> **Failing test name:** {name}
> **Failure output:**
> ```
> {captured output from 2c}
> ```
> **Domain vocabulary (from Prolog KB, if any applies):** {any relevant named entities — use these identifiers, not invented ones}
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
> - **Do not treat a passing behavioral test as equivalent in strength to a passing projected test.** In the implementation log, record this test's outcome as `behavioral_witness`, not as `property_verified`.
> - You may refactor existing code. The test is the specification; existing structure is not. If the cleanest path to green touches adjacent files, take it.
> - Do not modify anything under `thoughts/`.
> - Do not weaken assertions, skip tests, or disable type checks.
> - Do not alter other tests in the generated file.
> - Run the full project test suite and type check yourself before returning. Report what you ran and what passed.

**2e. Verify independently.** The orchestrator re-runs the full test suite. Two pass criteria, both required:
1. The targeted test is green.
2. No test that was green in the baseline (or after any prior iteration) is now red.

**2f. On failure or regression.** Brief a second `Agent(general-purpose)` with the fresh evidence: what the first agent changed, what still fails, what regressed. If two iterations cannot resolve it, go to Stage 4 (loopback).

**2g. Append to `thoughts/implementation_log.md`** — property name, test name, summary of what changed, whether a refactor occurred, which agents ran. One entry per unskipped test.

**2h. Advance to the next test.**

### Stage 3 — Refactor pass (at each phase boundary)

After finishing every test in a phase, run a dedicated refactor pass before starting the next phase. Refactoring is a first-class, specification-driven activity — not a side effect.

**3a. `Agent(Explore)`** — briefed with the list of files touched during this phase and the full property set. Ask it to find: duplication introduced across tests, naming drift from the Prolog vocabulary, unclear boundaries, dead intermediate state. Read-only — it proposes, it does not edit.

**3b. `Agent(general-purpose)`** — briefed with the Explore findings and the invariant: every generated test and every pre-existing test must remain green; every proven property must still hold. The refactor agent executes the changes the Explore agent proposed (or a reasoned subset), runs the suite itself, and returns.

**3c. Orchestrator re-runs the full suite.** Same two pass criteria as 2e. On regression, revert via the refactor agent (brief it with the regression) or escalate to loopback.

**3d. Counterfactual re-introduction check (conditional mode only).** After the refactor pass, re-run the Phase 0 absence tests explicitly and additionally grep the codebase for each counterfactual fact's source signature (the import path, function name, config key — whatever the Stage 0 locator originally found). A refactor that satisfies new invariants but silently re-introduces a previously-removed counterfactual under a different name is the exact failure mode the counterfactual lens exists to prevent. If a forbidden signature is found, treat it as a regression, brief the refactor agent to remove the re-introduction, and re-run.

- **Behavioral regression check.** After refactor, re-run all `TEST_BEHAVIORAL` tests. These tests lack formal backing, so a refactor that satisfies a projected test but breaks a behavioral one is NOT a formally-valid trade-off — the refactor silently weakened a contract the proof layer never knew about. Treat this as a regression to revert.

Log the refactor pass in `thoughts/implementation_log.md` as its own entry.

### Stage 4 — Loopback (when a test cannot be made green)

If two implementation attempts on the same test fail, do not keep grinding. Delegate a diagnosis to `Agent(Explore)`:

> This test cannot be made to pass after two implementation attempts. Classify the failure as one of:
> - **Test is wrong** — the test's projection from the proof is incorrect (wrong assertion, wrong fixture, wrong shape)
> - **Property is wrong** — the proof is internally valid but models something different from the real system
> - **Tests conflict** — satisfying this test would violate a different proven property
> - **Missing context** — the proof depends on a precondition not expressed in any test
> - **Counterfactual list inaccurate** *(conditional mode only)* — the enumerated counterfactual facts do not match reality: either a named fact cannot be cleanly removed because another proven property depends on it (the list was over-aggressive — INSUFFICIENT + EXTRANEOUS mix), or removing the fact is not enough to satisfy the downstream invariant (the list was incomplete — additional counterfactuals are needed)
> - **Behavioral test has no upstream property** — the failing test is `TEST_BEHAVIORAL`. There is no proof to revise, no hypothesis to re-run. This is a TDD-layer decision: either fix the implementation, weaken the test (with human review), or accept it as a known-red behavioral contract. Recommendation: do NOT loop back to `hypothesize` or `prove-hypothesis-*`; surface to the user.
>
> **Test:** {name and path}
> **Property:** {text from proof_results.md}
> **Proof mode:** {invariant | conditional}
> **Counterfactual context (if conditional):** {the fact under test, its NECESSARY/EXTRANEOUS label, and its source locations from Stage 0}
> **First attempt:** {diff summary and failure}
> **Second attempt:** {diff summary and failure}
>
> Do not edit anything. Read the test file, the proof, the hypothesis, and the relevant source. Return the classification plus a recommendation of which pipeline stage to revisit (`hypothesize`, `prove-hypothesis-{lean,prolog}`, or `translate-to-tests`). For a "counterfactual list inaccurate" classification, always recommend `hypothesize` — the hypothesis's counterfactual enumeration is what must change.

For `TEST_BEHAVIORAL` classifications, the `implementation_blocked.md` output must explicitly say "no upstream pipeline stage revises this claim" — this prevents the user from wasting a cycle re-running hypothesize on a behavioral failure.

Write the classification and recommendation to `thoughts/implementation_blocked.md`. Halt. Leave the offending test unskipped with its failure intact — the user's next pipeline run is the fix.

## Agent delegation reference

| Task | Agent | Why |
|---|---|---|
| Initial codebase survey | `Agent(Explore)` | Read-only, broad, scoped |
| Single-test implementation (TEST_PROJECTED) | `Agent(general-purpose)` — addition briefing | Narrow scope per test, needs edits |
| Single-test implementation (TEST_ABSENCE / TEST_GUARD) | `Agent(general-purpose)` — removal briefing | Deletion action; uses Stage 0 counterfactual locator |
| Single-test implementation (TEST_BEHAVIORAL) | `Agent(general-purpose)` — behavioral briefing | No upstream proof; uses Stage 0 item 7 infrastructure |
| Refactor discovery | `Agent(Explore)` | Must not edit while finding smells |
| Refactor execution | `Agent(general-purpose)` | Briefed from Explore findings |
| Loopback diagnosis | `Agent(Explore)` | Read-only classification |
| Running tests, type checks, lint | **Orchestrator (Bash)** | Verification cannot be delegated |

Prefer delegation aggressively. The orchestrator's own edits are limited to: toggling skip annotations in the test file, writing the implementation log, and writing the blocked report. Every substantive code edit and every substantive code read happens in a sub-agent.

## Output

- Modified source files in the target codebase (produced by sub-agents)
- `thoughts/implementation_log.md` — chronological per-test record; feeds `explain`
- `thoughts/implementation_blocked.md` — only written on loopback, with classification and recommended next pipeline stage
- Skip annotations in the test file updated in place (the progress ledger; re-running the skill resumes at the first still-skipped real test)

## Final report

- Tests unskipped and passing: N / M (of the implementable real tests)
- Tests intentionally left skipped: K (assumption stubs, coverage gaps — list them)
- Refactor passes run: list, with one-line summary of each
- Baseline regressions encountered and their resolution
- Loopback status: none, or blocked at test {name} with classification {...}
- Epistemic tag breakdown of tests completed: N projected, M absence, K guard, B behavioral.
- Behavioral tests remaining red (if any) with their classification from Stage 4.
- Path to `thoughts/implementation_log.md`
- Next steps

## Guidance

- **The test runner is the judge.** Not the sub-agent's summary. Not your reading of the diff. Re-run the full suite after every agent returns. If the suite disagrees with the agent, trust the suite.

- **Run the whole suite, not just the generated file.** Pre-existing tests are part of the specification too. A refactor that satisfies a new property while breaking an old test is not progress.

- **Tests and proofs outrank existing structure.** If the implementation agent proposes a refactor to adjacent code in order to keep invariants clean, let it. The skill exists to make the formal artifacts load-bearing; capitulating to legacy shape defeats the point.

- **Refactoring goes through Explore first.** Do not let an implementation agent make sweeping structural decisions mid-feature. Feature-scoped edits during Stage 2, structure-scoped edits during Stage 3, each with its own Explore-then-edit split.

- **Use domain names from the Prolog KB.** If the KB calls a component `auth_lib`, the implementation module should be `auth_lib`. This preserves the formal artifacts' reachability: future `explain` and `measure-adherance` runs depend on the code and the KB sharing vocabulary.

- **Phase order is a proof ordering.** A Phase 2 property often composes Phase 1 properties. Implementing Phase 2 before Phase 1 can produce code that passes Phase 2's test by accident while the foundation is wrong. Finish every phase before starting the next, including its refactor pass.

- **Assumption stubs stay skipped.** Tests marked with `skip(reason="assumption not proven — verify manually")` are deliberate gaps in the formal coverage. The skill does not unskip them. They appear in the final report as manual verification owed.

- **Halt loudly, don't drift quietly.** If two implementation attempts fail on one test, the likely cause is upstream (wrong test, wrong proof, conflicting properties). The correct response is loopback, not a third attempt with looser assertions.

- **Briefings are self-contained.** A sub-agent starts with no memory of this conversation. Include the property text, the failure output, the relevant codebase map slice, and the exact commands every time. Terse briefings produce shallow work.

- **Phase 0 is deletion work.** LLM implementors strongly prefer adding code over removing it — the default reflex against a failing test is to write something new. In conditional mode, that reflex produces "solutions" that add a wrapper, a flag, or an abstraction while leaving the forbidden dependency reachable. Use the removal briefing shape for Phase 0 tests, include the Stage 0 locator output so the sub-agent has exact lines to delete, and explicitly forbid shims/re-exports/aliases. If the sub-agent returns having added code, treat it as a failed attempt regardless of whether the test passed.

- **A silently re-introduced counterfactual is worse than a failing test.** The Stage 3d re-check exists because an invariant-mode refactor can add back a forbidden import in a new call site without any Phase 0 test noticing (the Phase 0 tests assert specific source locations or identifiers, which a refactor may not trip). Grep for the counterfactual's signature after every refactor pass, not just after Phase 0.

- **A passing behavioral test is not a proof.** `TEST_BEHAVIORAL` tests have no upstream formal backing. A green behavioral test means "the fixture passed on this run." Describe it that way in the log; do not upgrade its confidence to match projected tests.

- **Behavioral failures don't loop back.** The upstream pipeline stages never expressed a behavioral claim, so re-running `hypothesize` or `prove-hypothesis-*` cannot produce a revised formal artifact. The correct response to a persistent `TEST_BEHAVIORAL` failure is a human decision, not a pipeline cycle.
