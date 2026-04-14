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

```
PROLOG_QUERY=${CLAUDE_SKILL_DIR}/scripts/run-query.sh
```

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

```bash
${PROLOG_QUERY} <facts_file> validate
```

Fix any load errors (syntax, undefined predicates) and re-validate until it passes.

## Output

Write to the `thoughts/` directory (create it if it doesn't exist).
After, ask the user: "Are you ready to hypothesize on this file?"

Filename: `thoughts/facts.pl` or `thoughts/<domain>_facts.pl` for specificity.

Report:
- File path
- Count of facts per major predicate
- Any constraint rules included

## References

SWI-Prolog extension documentation is at `${CLAUDE_SKILL_DIR}/../../references/swi-prolog-extensions/`. Consult it when you need advanced Prolog features (tabling, DCGs, constraint logic programming, modules, etc.).

## Guidance

- **Fit the domain**: Choose predicates that naturally express the domain's concepts.
- **Be specific over generic**: `calls(A, B)` beats `related(A, B, calls)`.
- **Scope to the task**: Model what's relevant to the questions you'll want to ask.
- **Constraints are rules**: Use Prolog rules (`:- ...`) for invariants, not just facts.
- **One file, one domain**: Each facts file should cover one coherent analysis scope.
- **Verify before asserting**: Only write facts you can confirm from the source material.
