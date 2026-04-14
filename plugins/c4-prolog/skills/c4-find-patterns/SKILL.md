---
name: c4-find-patterns
description: >
  Map a codebase to C4 ontology facts. Explore the codebase, identify system
  boundaries, containers, and components, then write and validate a Prolog facts file.
  Use when: "analyze this codebase", "map code to C4", "create facts file",
  "find patterns in this repo", or any task requiring structural codebase modeling.
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: [target directory to analyze]
---

# C4 Find Patterns

Explore a codebase and map its structure to C4 ontology facts in Prolog. The output
is a validated `facts.pl` file that downstream skills can query for structural analysis.

## Key Paths

- **Query runner**: `${CLAUDE_SKILL_DIR}/scripts/run-query.sh`

### Ontology schema

```!
cat ${CLAUDE_SKILL_DIR}/prolog/ontology.pl
```

### Facts template

```!
cat ${CLAUDE_SKILL_DIR}/prolog/test_facts.pl
```

## How to invoke queries

All Prolog commands go through the query runner, which logs every invocation
and its output to `<facts_basename>_queries.md` next to the facts file:

```bash
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> <command> [args]
```

Commands: `validate`, `summary`, `describe`, `describe <system>`, `impact <component>`,
`order`, `scope <comp1,comp2>`, `chain <component>`, `coupling`, `crosscut`,
`full`, `full <comp1,comp2>`

---

## Process

### 1. Explore the codebase

Use `Glob`, `Grep`, `Read`, and `Agent(Explore)` to understand the directory structure,
entry points, frameworks, and major boundaries of the target codebase.

### 2. Identify C4 levels

- **C1 Context** — Top-level systems. A monorepo might have `api`, `web`, `shared_lib`
  as separate contexts.
- **C2 Container** — Deployable/runnable units within each system: services, apps,
  databases, build targets, major source directories.
- **C3 Component** — Logical groupings within each container: modules, classes,
  significant files with distinct responsibilities.

### 3. Write `facts.pl`

Generate a Prolog facts file using the facts template above as your format reference.
Save to a `thoughts/` directory (or wherever the user specifies).

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
- `snake_case` atoms for all names
- Descriptions are single-quoted strings
- File paths are single-quoted, project-relative
- `depends_on(A, B)` means "A depends on B" (A calls/imports/uses B)

### 4. Validate

```bash
${CLAUDE_SKILL_DIR}/scripts/run-query.sh <facts_file> validate
```

- **PASS**: Done. Report the validated facts file path.
- **Warnings**: Fix the facts file and re-validate. Common issues:
  - `orphan_container` — container references a system not in any `context/2`
  - `invalid_lineage` — component's system/container pair doesn't exist
  - `phantom_dependency` — `depends_on` target isn't a known component
  - `circular_dependency` — dependency cycle (may be intentional, note it)
  - `unmapped_component` — component has no `file_mapping`

**Output**: A validated `facts.pl` file.

---

## Guidance

- **Granularity**: Don't map every file. Focus on files relevant to the user's task.
  A 50-component ontology for a 500-file repo is fine. Map what matters.
- **Dependencies**: Only assert `depends_on` for relationships you can verify
  (imports, API calls, shared types). Don't guess.
- **Iteration**: It's normal to validate, discover you missed a container, re-explore,
  update facts, re-validate. That's the process working.
- **Scope**: For small tasks, you might only need 1 context, 1-2 containers, and
  3-5 components. Scale the ontology to the task.
