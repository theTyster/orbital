---
name: close-world
description: >
  Use this skill whenever the user wants to translate a codebase, document, or logical system into a Prolog facts file — "translate to prolog", "model this as prolog facts", "create a knowledge base from", "make this queryable with swipl". Stage 1 of the 7-stage pipeline: applies the Closed World Assumption to source material and produces `thoughts/existing-world.pl` — ground facts, relationship rules, and constraint rules. Everything absent from the output is, by CWA, false.
user-invocable: true
context: fork
agent: general-purpose
model: opus
effort: high
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: "[source code, requirements, domain rules, or any logical system to document]"
---

# close-world

**Logical operation:** `close-world` (CWA application) — apply the closed-world assumption to source material, producing a descriptive KB where everything absent is false.

**Pipeline position:** Stage 1 of 7. Primary input: `source_material` (env-provided). Primary output: `thoughts/existing-world.pl`. Downstream: `decompose-proposition` (stage 2) consumes `existing-world.pl`.

The three ingredients the KB must contain — and nothing else — are:

1. **Ground facts** — true statements about entities, values, states.
2. **Relationship rules** — rules that express how entities compose/relate.
3. **Constraint rules** — validation rules that express invariants.

Everything the source asserts becomes one of these; everything the source does not assert is, by CWA, false. The KB is the "existing world" snapshot. Build it incrementally: each source file is read, analyzed, and its Prolog representation is written or appended before the next file is processed. This provides faster feedback and catches errors early.

The output filename — `thoughts/existing-world.pl` — names what it models: the world as it currently is, under CWA. The "target world" (what must become true for a proposition to hold) is built downstream by `model-obligations`.

## Orchestrator contract

This skill is the stage-0 primitive at the boundary between the orchestration substrate and the pipeline. The substrate's wire format is `plugins/trajectory/references/orchestration-substrate.md` — read it before parameterising this skill.

**Orchestrator parameters accepted** (consult at startup; if a needed parameter is missing for the run, halt with `missing_required_parameter` recorded in the output rather than guessing — under `context: fork` there is no user to ask mid-run):

- **`predicate_schema_extension`** — bespoke predicates the orchestrator wants in `existing-world.pl` for this ticket (e.g., `csproj_content_directive/1`, `published_artifact/1` for substrate-audit cases that close-world cannot infer from the source alone). Inject these into the agent-of-truth brief so the extracted KB carries them.
- **`success_criteria`** — minimum coverage targets, required predicate families. Drives tier-5 of the validation cascade.
- **`halt_condition`** — when to stop and surface a partial KB rather than continue.

**Gate-target descriptor emitted on completion** — the `existing-world.pl` artifact paired with its declared shape (the discontiguous block at the top of the file plus any predicate families the orchestrator extended) and refutation-shape suggestions: **open-domain CWA assumptions are the primary refutation surface** — every predicate family that is not closed-domain is a candidate for `disprove-proposition` to challenge. The orchestrator decides per run whether to attack.

**Upstream gap emission** — close-world is stage 0; it has no upstream pipeline stage to gap toward. Gaps in close-world's input surface as the absence of expected predicate families post-run, handled by the orchestrator pre-invocation on the next run via `predicate_schema_extension`, not via `upstream_gap/3` emission.

## Current Environment

Setup marker: !`CHECK="${CLAUDE_PLUGIN_ROOT}/../scaffolding/skills/setup/scripts/check-setup.sh"; [ -x "$CHECK" ] && "$CHECK" --summary || echo "orbital: scaffolding plugin not installed; setup state unknown"`
`ls thoughts/existing-world.pl` returns: !`ls thoughts/existing-world.pl 2>/dev/null || echo "(not yet created)"`

If the marker reports that `swipl` is missing or that orbital is not set up, stop and ask the user to run `/setup` rather than reaching for `which swipl` directly. The marker is the single source of truth.

## Input

Accept any of:
- **Source code** — functions, types, modules, call graphs, data flows
- **Requirements / specifications** — entities, rules, preconditions, postconditions
- **Domain descriptions** — business rules, protocols, state machines, taxonomies
- **Data models** — schemas, relationships, cardinality constraints
- **Existing documentation** — any structured knowledge worth querying later

Use `Glob`, `Grep`, and `Read` to explore files, if that is relevant to what you are translating.
Use `Agent(Explore)` for broad codebase understanding, if that is relevant to what you are translating.

## Process

### 1. Survey the Domain

Understand what you're modeling before choosing predicates. Ask:
- What are the key *entities* or *things* in this domain?
- How do they *relate* to each other?
- What *rules* or *invariants* must always hold?
- What identifiable structural patterns exist in this domain?

### 2. Create the Knowledge Base (Incremental)

#### Delegate the heavy lifting to `agent-of-truth`

For any non-trivial domain (more than a handful of files, or any unfamiliar subject matter), spawn the `shifting:agent-of-truth` sub-agent with the `Agent` tool to do the modeling. That agent is the Prolog KB construction specialist — it picks predicates that fit the domain, uses DCGs where helpful, writes constraint rules, and validates the result with `swipl`. Doing this inside a sub-agent keeps predicate-design deliberation out of the main context window and gives you a cleaner, more idiomatic KB.

Skip delegation only when the user has explicitly asked you to translate it yourself in this turn. "The input looks small" is not a reason — small inputs still benefit from a specialist picking consistent predicate names, and inline execution clutters the main context with validation output. When in doubt, delegate.

#### Bias-isolation discipline

Specialist delegation isolates KB construction from orchestrator bias. The orchestrator's expectations about which predicates "should" exist MUST NOT reach the specialist; close-world has no checker for over-claiming, so a too-optimistic KB is invisible without structural defense.

**Apply both defenses on every agent-of-truth invocation:**

1. **Role-briefing.** Open the brief with an explicit outcome-agnostic role:
   > "You are extracting facts that are asserted in the source material under the Closed World Assumption. Record what the source declares; do not infer what the user 'probably means' or what a reasonable system 'usually has.' Mark gaps via comments. The orchestrator has no preferred predicate set — only what the source asserts and what the orchestrator named in `predicate_schema_extension`."

2. **Minimum-necessary context.** Send only:
   - The source material (file paths or domain description)
   - The target output path
   - Any `predicate_schema_extension` predicates the orchestrator supplied for this run
   - The validation tiers below — the agent must run each one before reporting done

   Do **not** paste orchestrator reasoning, downstream hopes, hypothesis hints, or pipeline state. Escalate context only when the agent returns "underspecified" with a precise question.

**Orchestrator responsibilities (never delegated):** supply the source material, decide the `predicate_schema_extension` parameters per ticket, validate the agent's digest, own the `success_criteria` verdict. The agent's reported tier-5 coverage is candidate evidence, not the run's verdict.

#### Inline procedure (when not delegating)

#### When reading files:
On the first iteration read the first 2-3 most relevant files. Starting out with 2-3 files in context before writing prolog makes it easier to identify relationships and patterns. Subsequent iterations should read one file before adding or appending to the Prolog KB.

For each source file in sequence:

1. **Read and analyze any relevant files** — Use `Read`, `Glob`, or `Grep` to understand logical content.
2. **Extract and document patterns** — Identify recurring structures, idioms, or conventions. Document these as comments in the facts file or as a separate patterns section. Examples: common error handling patterns, naming conventions, state transition idioms, compositional structures.
3. **Capture facts** — Write ground facts (true statements about entities, values, states).
4. **Capture relationships** — Write rules that express how entities relate or compose.
5. **Capture constraints** — Write validation rules that express invariants or domain rules.
6. **Write/append to facts file** — Immediately write or append all facts, relationships, and constraints from this file to `thoughts/existing-world.pl`. Do not batch all file reading first.
7. **Move to the next file** — Repeat steps 1–6 for each source file.

This incremental approach gives faster feedback, makes errors easier to localize, and allows the facts file to grow in parallel with your understanding.

#### When documenting more abstract logical systems:
- Perform any referential lookups on helpful `swi-prolog` extensions.
- Web search any domain knowledge which may help illustrate the domain logic.
- Question the user on facts, constraints, relationships and patterns as needed.
Be creative in how you explore topics. As long as the information you document in Prolog is true, there is no need to spend significant energy on reasoning about the actual logic yourself. That is what Prolog is for.

### 3. Validate

Delegate the five-tier validation cascade to the `kb-validator` sub-agent. The agent runs strict-load → referential integrity → constraint firing → spot-check sample → uncovered-predicate report with halt-on-tier-fail discipline and writes a JSON digest to a path the orchestrator chooses. The orchestrator reads the digest and decides whether to re-invoke `agent-of-truth` for repair, fail the run, or proceed to step 4.

**Briefing fields the orchestrator must pin** before delegating:

| Field | Source |
|---|---|
| `pl_path` | the `existing-world.pl` artifact just written (typically `thoughts/existing-world.pl`) |
| `digest_path` | orchestrator's scratch path (e.g., `thoughts/validation-digest.json`) |
| `top_predicates` | optional; the predicate names surveyed in step 1 plus any `predicate_schema_extension` entries — drives tier-4 sampling and tier-5 uncovered-report scope |

The agent file is at `../../agents/kb-validator.md`; read it before changing how delegation is parameterized. The agent never modifies the validated `.pl` file — it reports, the orchestrator routes repair. Coverage assessment against `success_criteria` is the orchestrator's call, not the agent's; tier-5 lists uncovered predicates flatly and the orchestrator decides whether the count is acceptable.

## Output

Write to the `thoughts/` directory (create it if it doesn't exist).
After, ask the user: "Are you ready to decompose-proposition on this file?"

Filename: **`thoughts/existing-world.pl`** (default) or `thoughts/<domain>-world.pl` for specificity. The name is deliberate — this KB models the *existing* world under CWA; downstream skills build a separate `target-world.pl` when the hypothesis requires counterfactual changes.

**Artifact contract** (what stage 2 will read): ground facts, relationship rules, and constraint rules for the current state. CWA — everything absent is false.

Report:
- File path
- Count of facts per major predicate
- Any constraint rules included
- Patterns captured — recurring structures, idioms, conventions, or compositional rules discovered during translation

## References

The plugin ships a SWI-Prolog wiki at `${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/` covering tabling, DCGs, CLP(FD/B/Q/R), modules, persistency, and more. **Don't read it yourself** — wiki content flows through `agent-of-truth`, which has direct access. When briefing that agent (§2), include the absolute wiki path and let it consult the wiki for extension recipes. This keeps reference material out of the main context and preserves the separation between skill orchestration and Prolog modelling expertise.

## Guidance

- **Fit the domain**: Choose predicates that naturally express the domain's concepts.
- **Be specific over generic**: `calls(A, B)` beats `related(A, B, calls)`.
- **Scope to the task**: Model what's relevant to the questions you'll want to ask.
- **Constraints are rules**: Use Prolog rules (`:- ...`) for invariants, not just facts.
- **One file, one domain**: Each facts file should cover one coherent analysis scope.
- **Verify before asserting**: Only write facts you can confirm from the source material.
- **CWA is the whole contract**: `existing-world.pl` says only what the source says. Absence in the KB means "not asserted in the source," not "false." The `negation_provenance` distinction (`absent` vs. `contradicts`) is consumed downstream — do not paper over it here by writing speculative facts to fill gaps. Two boundary crossings downstream depend on this contract — `prolog → lean` (carrier `thoughts/target-world.pl`) and `lean → tdd` (carrier `thoughts/lean_proof_results.pl`). The `negation_provenance(absent | contradicts)` distinction set up here is the only signal that survives the first crossing intact.
