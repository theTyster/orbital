---
name: translate-to-prolog
description: >
  Use this skill whenever the user wants to translate a codebase, document, or logical system into a Prolog facts file — "translate to prolog", "model this as prolog facts", "create a knowledge base from", "make this queryable with swipl". Builds the KB incrementally from source files and validates with SWI-Prolog.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: "[source code, requirements, domain rules, or any logical system to document]"
---

# Translate to Prolog

Document any logical system as a validated Prolog facts file. The output is a
knowledge base that can be loaded, queried, and inspected — a precise, executable
record of what is true, how things relate, what constraints must hold, and what patterns emerge.
The knowledge base is built incrementally: each source file is read, analyzed, and its Prolog
representation is written or appended to the facts file before the next file is processed.
This approach provides faster feedback and catches errors early.

## Prerequisites

- **SWI-Prolog** (`swipl`): `swipl --version` must succeed.

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

For any non-trivial domain (more than a handful of files, or any unfamiliar subject matter), spawn the `logic-focused:agent-of-truth` sub-agent with the `Agent` tool to do the modeling. That agent is the Prolog KB construction specialist — it picks predicates that fit the domain, uses DCGs where helpful, writes constraint rules, and validates the result with `swipl`. Doing this inside a sub-agent keeps predicate-design deliberation out of the main context window and gives you a cleaner, more idiomatic KB.

Brief the agent with:
- The source material (file paths, or the domain description)
- The target output path (`thoughts/facts.pl` by default)
- Any predicates or constraints the user has already asked for
- The validation tiers below — the agent must run each one before reporting done

Skip delegation only when the user has explicitly asked you to translate it yourself in this turn. "The input looks small" is not a reason — small inputs still benefit from a specialist picking consistent predicate names, and inline execution clutters the main context with validation output. When in doubt, delegate.

#### Inline procedure (when not delegating)

#### When reading files:
On the first iteration read the first 2-3 most relevant files. Starting out with 2-3 files in context before writing prolog makes it easier to identify relationships and patterns. Subsequent iterations should read one file before adding or appending to the Prolog KB.

For each source file in sequence:

1. **Read and analyze any relevant files** — Use `Read`, `Glob`, or `Grep` to understand logical content.
2. **Extract and document patterns** — Identify recurring structures, idioms, or conventions. Document these as comments in the facts file or as a separate patterns section. Examples: common error handling patterns, naming conventions, state transition idioms, compositional structures.
3. **Capture facts** — Write ground facts (true statements about entities, values, states).
4. **Capture relationships** — Write rules that express how entities relate or compose.
5. **Capture constraints** — Write validation rules that express invariants or domain rules.
6. **Write/append to facts file** — Immediately write or append all facts, relationships, and constraints from this file to `thoughts/facts.pl`. Do not batch all file reading first.
7. **Move to the next file** — Repeat steps 1–6 for each source file.

This incremental approach gives faster feedback, makes errors easier to localize, and allows the facts file to grow in parallel with your understanding.

#### When documenting more abstract logical systems:
- Perform any referential lookups on helpful `swi-prolog` extensions.
- Web search any domain knowledge which may help illustrate the domain logic.
- Question the user on facts, constraints, relationships and patterns as needed.
Be creative in how you explore topics. As long as the information you document in Prolog is true, there is no need to spend significant energy on reasoning about the actual logic yourself. That is what Prolog is for.

### 3. Validate

Run each tier in order. Do not advance to the next tier until the current one passes.

**Tier 1 — Load cleanly.** The file must load without errors or warnings.

```bash
swipl -g "halt" <file>
```

Fix syntax errors, missing operators, and undefined predicates before continuing.

**Tier 2 — Referential integrity.** Every predicate referenced in a rule body must be defined (as a fact or another rule). Query for orphan references:

```bash
swipl -g "use_module(library(check)), check, halt" <file>
```

If the KB declares `:- discontiguous` predicates, confirm each one actually appears.

**Tier 3 — Spot-check ground truth.** Pick 3–5 representative facts and verify them against the source material. For each, run a query and confirm the result matches reality:

```prolog
?- <predicate>(X, Y), write(X-Y), nl, fail ; true.
```

If any fact is wrong, audit neighboring facts from the same source — errors tend to cluster.

**Tier 4 — Run constraints.** If the KB includes constraint rules (`:- \+ ...` or validation predicates), invoke them and confirm no violations fire. If a constraint fires, determine whether the constraint is wrong or the facts are wrong — fix the correct one.

**Tier 5 — Coverage check.** Revisit the domain survey from Step 1. For each key entity and relationship identified, confirm at least one predicate covers it. Flag any domain concept that was surveyed but has zero corresponding facts — it was either intentionally excluded (document why in a comment) or accidentally missed.

## Output

Write to the `thoughts/` directory (create it if it doesn't exist).
After, ask the user: "Are you ready to hypothesize on this file?"

Filename: `thoughts/facts.pl` or `thoughts/<domain>_facts.pl` for specificity.

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
