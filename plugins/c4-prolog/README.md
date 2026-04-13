# c4-prolog

C4 architectural modeling and Prolog-based codebase analysis.

## Skills

### Phase skills (individual loops)

- **c4-find-patterns** — Map a codebase to C4 ontology facts (explore, identify, write, validate)
- **c4-define-patterns** — Verify a C4 facts file with structural queries (summary, describe, coupling, crosscut)
- **c4-condense-patterns** — Transform Prolog analysis into an implementation plan (scope, impact, order)

### Orchestrator

- **c4-analyze** — Run the full pipeline: find > define > condense

### Legacy

- **reason-with-prolog** — Redirects to c4-analyze (backward compatibility)

## Prolog Infrastructure

Each skill contains a self-contained copy of the Prolog modules and scripts:

- `prolog/ontology.pl` — C4 schema and validation
- `prolog/reasoning.pl` — Analysis procedures (impact, scope, order, coupling, crosscut)
- `prolog/run.pl` — CLI command dispatcher
- `scripts/run-query.sh` — swipl wrapper with query logging

## Prerequisites

- **SWI-Prolog** (`swipl`)
