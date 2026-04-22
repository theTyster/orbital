---
name: c4-pattern-to-plan
description: >
  Transform Prolog analysis into an implementation plan. Maps a user's task to C4 components, runs targeted analysis, and produces a plan grounded in formal output. Use after c4-define-patterns to create an action plan.
user-invocable: true
allowed-tools: Bash, Read, Write
argument-hint: [facts file path] [task description or component list]
---

# C4 Condense Patterns

Transform verified Prolog analysis into a concrete implementation plan. Given a
validated facts file and a task description, identify target components, run
targeted analysis, and produce a plan grounded in formal Prolog output.

Input: A verified `facts.pl` + the user's task description.

## Key Paths

- **Query runner**: `${CLAUDE_SKILL_DIR}/../scripts/run-query.sh`
- **Query log**: Written automatically next to facts file as `<name>_queries.md`

### Reasoning procedures

```!
cat ${CLAUDE_SKILL_DIR}/../prolog/reasoning.pl
```

## How to invoke queries

```bash
${CLAUDE_SKILL_DIR}/../scripts/run-query.sh <facts_file> <command> [args]
```

---

## Process

### 1. Identify target components

Map the user's task description to component names in the ontology. Read the facts
file if needed to find the right component atoms.

### 2. Run targeted analysis

```bash
${CLAUDE_SKILL_DIR}/../scripts/run-query.sh <facts_file> full <comp1>,<comp2>
```

This runs: validate, summary, change_scope, impact per target, implementation_order,
crosscut, coupling — all in one pass.

### 3. Interpret the Prolog output

Build the plan from the formal analysis:

- **CHANGE SCOPE** — which files to read and modify
- **upstream (must understand)** — prerequisites to study before touching targets
- **downstream (may break)** — components that need testing after changes
- **IMPACT per target** — blast radius of each change
- **IMPLEMENTATION ORDER** — sequence to make changes (dependencies first)
- **CROSS-CUTTING CONCERNS** — shared components requiring extra care
- **CONTAINER COUPLING** — integration boundaries needing testing

### 4. Write the implementation plan

Produce `thoughts/implementation_plan.md` (or user-specified path) using the Prolog
output as structural backbone. The plan should:

- Reference specific files from `files_to_review`
- Follow the implementation order from the topological sort
- Note upstream prerequisites and downstream testing needs

---

## Output

A structured implementation plan grounded in formal analysis, plus the query log
at `<facts_basename>_queries.md` capturing all reasoning for transparency.
Point the user to both files.
