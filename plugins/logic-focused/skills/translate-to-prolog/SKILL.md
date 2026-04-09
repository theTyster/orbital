---
name: translate-to-prolog
description: >
  Translate domain logic, requirements, or code behavior into a Prolog facts file.
  Maps concepts to C4 ontology predicates (context, container, component, depends_on)
  and validates the result with SWI-Prolog.
  Use when: "translate this to prolog", "model this logic", "create prolog facts from this code".
user-invocable: true
allowed-tools: Bash, Read, Grep, Glob, Write, Agent
argument-hint: "[source code, requirements, or domain logic to translate]"
---

# Translate to Prolog

Translate domain logic into a validated Prolog facts file. The input can be source
code, requirements, specifications, or any structured domain knowledge. The output
is a `.pl` file ready for querying.

## Prerequisites

- **SWI-Prolog** (`swipl`): `swipl --version` must succeed.

```
PROLOG_RUNTIME=${CLAUDE_SKILL_DIR}/../../../../lib/prolog-runtime
PROLOG_QUERY=${PROLOG_RUNTIME}/scripts/run-query.sh
PROLOG_TEMPLATE=${PROLOG_RUNTIME}/prolog/test_facts.pl
```

## Input

Accept one of:
- **Source code** — extract behavioral facts from functions, types, dependencies
- **Requirements** — extract domain entities and their relationships
- **Domain description** — extract concepts, constraints, and dependencies
- **Existing documentation** — extract structured relationships

Read the input thoroughly before translating. Use `Glob`, `Grep`, and `Read` to
explore source code. Use `Agent(Explore)` for broad codebase understanding.

## Process

### 1. Identify Entities

Map the input to C4 levels:
- **C1 Context** — top-level systems or bounded contexts
- **C2 Container** — deployable/runnable units within each system
- **C3 Component** — logical groupings within each container

For non-code inputs (requirements, domain logic), map domain concepts:
- Major domains → contexts
- Subsystems or services → containers
- Individual rules, entities, or capabilities → components

### 2. Identify Relationships

Extract dependency relationships:
- Code imports/calls → `depends_on(caller, callee)`
- Data flows → `depends_on(consumer, producer)`
- Requirement dependencies → `depends_on(dependent_req, prerequisite_req)`
- Logical implications → `depends_on(conclusion, premise)`

### 3. Write the Facts File

Generate a `.pl` file. Use the template at `${PROLOG_TEMPLATE}` as format reference.

The file MUST include:
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
- `depends_on(A, B)` means "A depends on B"

For non-code inputs where file mappings don't apply, use a placeholder:
```prolog
file_mapping(component, rule_name, 'requirements/section').
```

### 4. Validate

```bash
${PROLOG_QUERY} <facts_file> validate
```

- **PASS**: Done. Report the output file path.
- **Warnings**: Fix and re-validate. Common issues:
  - `orphan_container` — container references unknown system
  - `invalid_lineage` — component's system/container pair missing
  - `phantom_dependency` — depends_on target not a known component
  - `circular_dependency` — cycle detected (may be intentional)
  - `unmapped_component` — component has no file_mapping

Iterate until validation passes.

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

A single validated `.pl` file written to `thoughts/facts.pl` (or `thoughts/<descriptive_name>_facts.pl`).
Report:
- File path
- Count of contexts, containers, components, and dependencies
- Any circular dependencies noted (if intentional)

## Guidance

- **Scope to the task**: Don't map everything. Map what's relevant.
- **Verify dependencies**: Only assert `depends_on` for relationships you can confirm.
- **Iterate**: It's normal to validate, find issues, fix, re-validate.
- **One file, one domain**: Each facts file should cover one coherent domain or analysis scope.
