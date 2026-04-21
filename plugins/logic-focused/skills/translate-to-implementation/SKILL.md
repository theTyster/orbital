---
name: translate-to-implementation
description: >
  Drive a TDD test suite to green by orchestrating sub-agents that implement code against proven properties. Reads the skipped test file from translate-to-tests, plus proof_results.md, hypothesis.md, and the Prolog KB. Unskips one test at a time, delegates each implementation and refactor to Explore and general-purpose agents, and runs the project's full test suite as the authority on correctness. Tests and proofs are treated as specifications — refactoring to satisfy them is encouraged. Use when: "implement the tests", "translate tests to implementation", "drive the TDD suite to green", "write the code for the proven properties", "implement from proof".
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
- **Strongly recommended**: `thoughts/proof_results.md` — each test cites a property; the proof is the ground truth when a test is ambiguous
- **Recommended**: `thoughts/hypothesis.md` — edge predicates, open assumptions, refuted sub-hypotheses
- **Recommended**: `thoughts/*.pl` — domain vocabulary the implementation should adopt verbatim, plus structural constraints

If no language was detected when tests were generated (pseudotest format), halt and ask the user which language to implement in. Do not guess.

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

Store the survey in working memory. Every subsequent briefing includes the relevant slices of it so sub-agents do not re-discover the landscape.

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

**2b. Unskip it.** This is one of the few edits the orchestrator makes directly — toggle the skip annotation in the test file.

**2c. Run the full project test suite.** Confirm the unskipped test now fails *for the expected reason* (missing implementation, missing module, assertion mismatch — not a compile or fixture error that would require its own fix). Capture the failure output verbatim.

**2d. Delegate implementation to `Agent(general-purpose)`** with a self-contained brief:

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

Log the refactor pass in `thoughts/implementation_log.md` as its own entry.

### Stage 4 — Loopback (when a test cannot be made green)

If two implementation attempts on the same test fail, do not keep grinding. Delegate a diagnosis to `Agent(Explore)`:

> This test cannot be made to pass after two implementation attempts. Classify the failure as one of:
> - **Test is wrong** — the test's projection from the proof is incorrect (wrong assertion, wrong fixture, wrong shape)
> - **Property is wrong** — the proof is internally valid but models something different from the real system
> - **Tests conflict** — satisfying this test would violate a different proven property
> - **Missing context** — the proof depends on a precondition not expressed in any test
>
> **Test:** {name and path}
> **Property:** {text from proof_results.md}
> **First attempt:** {diff summary and failure}
> **Second attempt:** {diff summary and failure}
>
> Do not edit anything. Read the test file, the proof, the hypothesis, and the relevant source. Return the classification plus a recommendation of which pipeline stage to revisit (`hypothesize`, `prove-hypothesis-{lean,prolog}`, or `translate-to-tests`).

Write the classification and recommendation to `thoughts/implementation_blocked.md`. Halt. Leave the offending test unskipped with its failure intact — the user's next pipeline run is the fix.

## Agent delegation reference

| Task | Agent | Why |
|---|---|---|
| Initial codebase survey | `Agent(Explore)` | Read-only, broad, scoped |
| Single-test implementation | `Agent(general-purpose)` | Narrow scope per test, needs edits |
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
- Path to `thoughts/implementation_log.md`

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
