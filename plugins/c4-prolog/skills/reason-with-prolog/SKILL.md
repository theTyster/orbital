---
name: reason-with-prolog
description: >
  Formal reasoning skill using SWI-Prolog and C4 model ontologies to analyze
  codebases before planning implementation. Use when a task requires understanding
  system structure, dependency impact, or implementation ordering across a codebase.
  Triggers: "analyze this codebase", "plan this change formally", "what's the impact of changing X", "explore relationships".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: [target directory or description of change]
---

# Formal Reasoning with Prolog

You use SWI-Prolog (`swipl`) and the C4 architectural model to formally reason
about a codebase before creating an implementation plan. This forces you to
externalize your understanding as typed, provable facts — not prose.

## Key Paths

```
PROLOG_RUNTIME=${CLAUDE_SKILL_DIR}/../../../../lib/prolog-runtime
```

- **Query runner**: `${PROLOG_RUNTIME}/scripts/run-query.sh`
- **Prolog runner**: `${PROLOG_RUNTIME}/prolog/run.pl`
- **Ontology schema**: `${PROLOG_RUNTIME}/prolog/ontology.pl`
- **Reasoning procedures**: `${PROLOG_RUNTIME}/prolog/reasoning.pl`
- **Facts template**: `${PROLOG_RUNTIME}/prolog/test_facts.pl`
- **Query log**: Written automatically next to facts file as `<name>_queries.md`

## How to invoke queries

All Prolog commands go through the query runner, which logs every invocation
and its output to `<facts_basename>_queries.md` next to the facts file:

```bash
${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> <command> [args]
```

Commands: `validate`, `summary`, `describe`, `describe <system>`, `impact <component>`,
`order`, `scope <comp1,comp2>`, `chain <component>`, `coupling`, `crosscut`,
`full`, `full <comp1,comp2>`

The wrapper calls swipl under the hood. Output is printed normally to stdout
and also appended to the query log for the user to review.

---

## Orbital Flow

Work proceeds in three loops. Each loop has a clear input, a Prolog checkpoint,
and a typed output. Do not skip loops or proceed when validation fails.

### Loop 1: Find Patterns

**Goal**: Map the target codebase to C4 ontology facts.

1. **Explore the codebase.** Use `Glob`, `Grep`, `Read`, and `Agent(Explore)` to
   understand the directory structure, entry points, frameworks, and major boundaries.

2. **Identify C4 levels:**
   - **C1 Context** — What are the top-level systems? (e.g., a monorepo might have
     `api`, `web`, `shared-lib` as separate contexts)
   - **C2 Container** — What are the deployable/runnable units within each system?
     (services, apps, databases, build targets, major source directories)
   - **C3 Component** — What are the logical groupings within each container?
     (modules, classes, significant files with distinct responsibilities)

3. **Write `facts.pl`.** Generate a Prolog facts file. Use the template at
   `${CLAUDE_SKILL_DIR}/prolog/test_facts.pl` as your format reference.

   The file MUST include the discontiguous directive and use ONLY these predicates:
   ```prolog
   :- discontiguous context/2, container/3, component/4,
                     file_mapping/3, depends_on/2.

   %% C1: context(SystemName, Description).
   %% C2: container(SystemName, ContainerName, Technology).
   %% C3: component(SystemName, ContainerName, ComponentName, Responsibility).
   %% Maps: file_mapping(Level, EntityName, FilePath).
   %% Deps: depends_on(Dependent, Dependency).
   ```

   **Naming conventions:**
   - Use `snake_case` atoms for all names
   - Descriptions are single-quoted strings
   - File paths are single-quoted, project-relative
   - `depends_on(A, B)` means "A depends on B" (A calls/imports/uses B)

4. **Validate.** Run:
   ```bash
   ${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> validate
   ```
   - If `PASS`: proceed to Loop 2.
   - If warnings: fix the facts file and re-validate. Common issues:
     - `orphan_container` — container references a system not in any `context/2`
     - `invalid_lineage` — component's system/container pair doesn't exist
     - `phantom_dependency` — `depends_on` target isn't a known component
     - `circular_dependency` — dependency cycle detected (may be intentional, note it)
     - `unmapped_component` — component has no `file_mapping`

**Output**: A validated `facts.pl` file.

### Loop 2: Define Patterns

**Goal**: Use Prolog to analyze the structural patterns and verify alignment.

1. **Run system summary** to confirm the ontology matches your understanding:
   ```bash
   ${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> summary
   ```
   Check: Do the counts match what you explored? If not, go back to Loop 1.

2. **Run describe** to see the full C4 tree:
   ```bash
   ${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> describe
   ```
   Check: Does the hierarchy look right? Are components in the right containers?

3. **Run coupling and crosscut** to understand system boundaries:
   ```bash
   ${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> coupling
   ${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> crosscut
   ```
   These reveal which containers depend on each other and which components
   are shared infrastructure.

**Output**: Verified ontology. You now have a formally validated structural model.

### Loop 3: Condense Patterns

**Goal**: Transform Prolog analysis into an implementation plan.

1. **Identify target components** from the user's task description. Map their request
   to component names in your ontology.

2. **Run targeted analysis:**
   ```bash
   ${PROLOG_RUNTIME}/scripts/run-query.sh <facts_file> full <comp1>,<comp2>
   ```
   This runs: validate → summary → change_scope → impact per target → implementation_order → crosscut → coupling

3. **Interpret the Prolog output** to build your plan:
   - **CHANGE SCOPE** → which files to read and modify
   - **upstream (must understand)** → prerequisites to study before touching targets
   - **downstream (may break)** → components that need testing after changes
   - **IMPACT per target** → blast radius of each change
   - **IMPLEMENTATION ORDER** → sequence to make changes (deps first)
   - **CROSS-CUTTING CONCERNS** → shared components that need extra care
   - **CONTAINER COUPLING** → integration boundaries that need testing

4. **Write the implementation plan** using the Prolog output as your structural backbone.
   The plan should reference specific files from `files_to_review` and follow the
   implementation order from the topological sort.

**Output**: A structured implementation plan grounded in formal analysis.
All queries and their results are captured in `<facts_basename>_queries.md`
next to your facts file — point the user to this file for full reasoning transparency.

---

## Guidance

- **Granularity**: Don't map every file. Focus on files relevant to the user's task.
  A 50-component ontology for a 500-file repo is fine. Map what matters.
- **Dependencies**: Only assert `depends_on` for relationships you can verify
  (imports, API calls, shared types). Don't guess.
- **Iteration**: It's normal to run Loop 1 → validate → discover you missed a
  container → re-explore → update facts → re-validate. That's the process working.
- **Scope**: For small tasks (changing one file), you might only need 1 context,
  1-2 containers, and 3-5 components. Scale the ontology to the task.
- **Speed**: For quick impact checks, skip straight to Loop 3 if you already
  have a facts file from a previous run.
