# Stage 0 sub-agent briefs — codebase survey + counterfactual locator

Two read-only sub-agents run in parallel after the SKILL's Stage 0 pre-flight (carrier-check) passes. Both write to `thoughts/.realize_scratch/`. The pre-flight itself is defined in `../SKILL.md` § "Stage 0 — Pre-flight + codebase survey + counterfactual locator" and is not duplicated here.

## Survey brief — `Agent(Explore)`

> Survey this codebase to prepare for a TDD implementation pass against a generated test file at {path}. Write your findings to `thoughts/.realize_scratch/survey.md` as a structured markdown document with these sections (use these exact headers — the briefer agent will pick slices by header):
>
> 1. `## Code layout` — where implementation code should live relative to the test file; module/package conventions
> 2. `## Existing modules referenced by tests` — stubs, types, public exports the tests touch
> 3. `## Project commands` — exact invocations for tests, type check, lint, format, build (look in package.json scripts, Makefile, justfile, pyproject, Cargo.toml, etc.). Give exact commands, not descriptions.
> 4. `## Adjacent constraints` — shared interfaces, DI registration, public exports the tests will constrain
> 5. `## Test runner notes` — anything unusual: watch mode, test tags, required env vars
> 6. `## Behavioral-contract infrastructure` — only if the test file contains `test_category(behavioral_claim)` tests. Identify hooks for observing side effects / state / timing: test doubles, integration harnesses, clock injection, retry mocks. The behavioral briefings will copy this slice.
>
> Return only the path you wrote to and a one-paragraph summary. Do not edit any source.

## Counterfactual-locator brief — `Agent(realize-counterfactual-scanner)` in `initial` mode

> Build the counterfactual locator table for this realize-specification run.
>
> - mode: initial
> - hypothesis_path: `thoughts/hypothesis.pl`
> - target_codebase_dir: {dir}
> - scratch_dir: `thoughts/.realize_scratch/`
>
> Emit `counterfactual_locator.json` and `counterfactual_locator.md`. Return counts and path.

If `hypothesis.pl` does not exist (a behavioral-only test file), skip the counterfactual-locator brief and note it in the run log.

The orchestrator records only the paths and counts. The contents stay in the scratch dir.
