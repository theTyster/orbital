# orbital-scaffolding

C4 architectural modeling and Prolog-based codebase analysis.

## Skills

### Adopter onboarding

- **setup** — First-time bootstrap for a fresh orbital install. Interviews the adopter, creates `thoughts/`, appends `.gitignore` entries, and delegates to the Lean setup skills if the proof backend is wanted. Re-runnable as a doctor / health check via `--check`.

### Phase skills (individual loops)

- **c4-find-patterns** — Map a codebase to C4 ontology facts (explore, identify, write, validate)
- **c4-define-patterns** — Verify a C4 facts file with structural queries (summary, describe, coupling, crosscut)
- **c4-condense-patterns** — Transform Prolog analysis into an implementation plan (scope, impact, order)

### Orchestrator

- **c4-analyze** — Run the full pipeline: find > define > condense

## Prolog Infrastructure

The three phase skills share a common Prolog runtime, bundled once at `skills/`:

- `skills/prolog/ontology.pl` — C4 schema and validation
- `skills/prolog/reasoning.pl` — Analysis procedures (impact, scope, order, coupling, crosscut)
- `skills/prolog/run.pl` — CLI command dispatcher
- `skills/scripts/run-query.sh` — swipl wrapper with query logging

Each SKILL.md references it via `${CLAUDE_SKILL_DIR}/../prolog/…` and `${CLAUDE_SKILL_DIR}/../scripts/…`.

## Prerequisites

- **SWI-Prolog** (`swipl`)
