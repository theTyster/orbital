---
name: query-hypothesis
description: >
  Query a Prolog knowledge base to explore relationships, derive insights, and
  formulate a structured hypothesis. Writes the hypothesis to a file for downstream
  formalization in Lean4.
  Use when: "explore this hypothesis", "query the prolog facts", "what can we derive from this model".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write
argument-hint: "[prolog facts file] [hypothesis or question to explore]"
---

# Query Hypothesis

Query an existing Prolog facts file to explore a hypothesis. Run structured queries,
interpret results, and write a hypothesis file that can be formalized in Lean4.

## Prerequisites

- **SWI-Prolog** (`swipl`): `swipl --version` must succeed.
- **A validated facts file**: Output from translate-to-prolog or reason-with-prolog.

```
PROLOG_SKILL=${CLAUDE_SKILL_DIR}/../../plugins/marketplaces/logic-focused-plugins/skills/reason-with-prolog
PROLOG_QUERY=${PROLOG_SKILL}/scripts/run-query.sh
```

If these paths don't exist, search for `run-query.sh` with Glob and adjust.

## Input

- **Facts file path** — a validated `.pl` file
- **Hypothesis or question** — what the user wants to explore. Examples:
  - "Is component X isolated from component Y?"
  - "What's the blast radius of changing the auth module?"
  - "Are there hidden coupling patterns?"
  - "Does the dependency graph have a clean layering?"

## Process

### 1. Understand the Knowledge Base

Run initial queries to understand what's in the facts file:
```bash
${PROLOG_QUERY} <facts_file> summary
${PROLOG_QUERY} <facts_file> describe
```

Review the C4 hierarchy, component counts, and dependency structure.

### 2. Explore the Hypothesis

Run targeted queries based on the hypothesis:

| Question type | Query commands |
|---------------|---------------|
| Impact/blast radius | `impact <component>` |
| Dependency chains | `chain <component>` |
| Coupling between areas | `coupling`, `scope <comp1,comp2>` |
| Cross-cutting concerns | `crosscut` |
| Implementation ordering | `order` |
| Full analysis | `full` or `full <comp1,comp2>` |

Run multiple queries. Each query result informs the next. Build understanding
incrementally.

### 3. Formulate the Hypothesis

From the query results, formulate a precise hypothesis. A hypothesis must be:

- **Specific** — names concrete components or relationships
- **Falsifiable** — could be proven wrong
- **Formalizable** — expressible as a logical proposition

Good hypotheses:
- "Component auth_middleware has no transitive dependency on database_cache"
- "All components in the api container can be modified without affecting the web container"
- "The dependency graph from payment_service to notification_service is acyclic"

Bad hypotheses:
- "The code is well-structured" (not falsifiable)
- "Things depend on other things" (not specific)

### 4. Write the Hypothesis File

Write the hypothesis to `thoughts/hypothesis.md` (create `thoughts/` if it doesn't exist).
Use this structure:

```markdown
# Hypothesis: {title}

## Statement
{One-sentence formal statement of the hypothesis}

## Prolog Evidence

### Queries Run
{List of queries and their key results}

### Supporting Facts
{Specific Prolog output that supports the hypothesis}

### Potential Counterevidence
{Any query results that complicate or contradict the hypothesis}

## Formal Properties
Properties to prove in Lean4:

1. **{property_name}**: {natural language description}
   - Lean sketch: `theorem {name} : {type signature sketch}`
   - Depends on: {what definitions are needed}

2. ...

## Scope
- **Proves**: {what this hypothesis establishes if true}
- **Does not prove**: {explicit limitations}
- **Assumptions**: {what we take as given}
```

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

A `thoughts/hypothesis.md` file structured for direct consumption by the formalize-in-lean skill.

Report:
- Hypothesis statement (one line)
- Number of formal properties identified
- File path
- Confidence level (strong/moderate/weak) based on Prolog evidence

## Guidance

- **Query broadly, then narrow**: Start with `summary` and `describe`, then target specific components.
- **Look for counterevidence**: A good hypothesis survives attempts to disprove it. Run queries that might contradict your hypothesis.
- **Multiple properties**: A single hypothesis may decompose into multiple formal properties. Each should be independently provable.
- **Iterate**: If the hypothesis doesn't hold up under querying, revise it. Better to refine here than fail in Lean4.
