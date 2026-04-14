---
name: translate-to-prolog
description: >
  Translate any logical system — domain rules, code behavior, requirements, data models —
  into a Prolog facts file. Choose predicates that naturally fit the domain.
  Captures facts, relationships, and constraints. Validates with SWI-Prolog.
  Use when: "translate this to prolog", "model this logic", "document this system as prolog facts".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: "[source code, requirements, domain rules, or any logical system to document]"
---

# Translate to Prolog

Document any logical system as a validated Prolog facts file. The output is a
knowledge base that can be loaded, queried, and inspected — a precise, executable
record of what is true, how things relate, and what constraints must hold.

## Prerequisites

- **SWI-Prolog** (`swipl`): `swipl --version` must succeed.

## Input

Accept any of:
- **Source code** — functions, types, modules, call graphs, data flows
- **Requirements / specifications** — entities, rules, preconditions, postconditions
- **Domain descriptions** — business rules, protocols, state machines, taxonomies
- **Data models** — schemas, relationships, cardinality constraints
- **Existing documentation** — any structured knowledge worth querying later

Ensure that you have a complete understanding of a logical system before documenting it. Use `Glob`, `Grep`, and `Read` to explore files.
Use `Agent(Explore)` for broad codebase understanding.

## Process

### 1. Survey the Domain

Understand what you're modeling before choosing predicates. Ask:
- What are the key *entities* or *things* in this domain?
- How do they *relate* to each other?
- What *rules* or *invariants* must always hold?

### 2. Create the Knowledge Base
- Choose a model for your predicates.
- Capture Facts
- Capture Relationships
- Capture Constraints

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

## References

SWI-Prolog extension documentation is at `${CLAUDE_SKILL_DIR}/../../references/swi-prolog-extensions/`. Consult it before you write when you need advanced Prolog features (tabling, DCGs, constraint logic programming, modules, etc.).

## Guidance

- **Fit the domain**: Choose predicates that naturally express the domain's concepts.
- **Be specific over generic**: `calls(A, B)` beats `related(A, B, calls)`.
- **Scope to the task**: Model what's relevant to the questions you'll want to ask.
- **Constraints are rules**: Use Prolog rules (`:- ...`) for invariants, not just facts.
- **One file, one domain**: Each facts file should cover one coherent analysis scope.
- **Verify before asserting**: Only write facts you can confirm from the source material.
