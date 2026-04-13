# Plan: Query-Hypothesis Overhaul

## Goal

Deeply modify query-hypothesis to: (a) use coverage analysis for query completeness, (b) work with arbitrary Prolog models instead of C4, (c) restrict the skill to querying only (no file reading), and (d) prompt for formal proof in a follow-up session.

## Approach: Direct SWI-Prolog

Instead of routing queries through wrapper scripts (`run.pl`, `run-query.sh`), the skill teaches the agent to use `swipl` directly. The SKILL.md provides:

- The `swipl -g "<goal>" -t halt <files...>` invocation pattern
- A bundled `introspect.pl` module for generic KB exploration
- A bundled `prolog_coverage_ai.pl` module for coverage analysis
- Common Prolog query patterns (findall, forall, transitive closure)

This is simpler, more flexible, and doesn't hide the Prolog from the agent.

## Changes Made

### 1. Restrict allowed-tools

Changed from:
```yaml
allowed-tools: Bash, Read, Grep, Glob, Write
```
To:
```yaml
allowed-tools: Bash, Write
```

The skill only runs `swipl` (Bash) and writes the hypothesis file (Write).

### 2. Created `introspect.pl` — generic KB introspection

Replaces C4-specific `ontology.pl` and `reasoning.pl` with a model-agnostic module:

```prolog
:- module(introspect, [
    kb_summary/0,        % Print predicate names, arities, counts
    kb_describe/0,       % Print all facts grouped by predicate
    kb_describe/1,       % Print facts for a specific predicate
    kb_find/1,           % Find facts containing a given atom
    kb_related/1,        % Find all facts that reference a given atom
    kb_graph/0,          % Print binary predicates as edge lists
    kb_stats/0           % Predicate-level statistics (count, unique values)
]).
```

Works by introspecting the `user` module — any facts file consulted without a module declaration gets its predicates there. Filters out SWI-Prolog system predicates (multifile, `$`-prefixed, imported).

### 3. Integrated `prolog_coverage_ai.pl`

The agent wraps queries in `coverage/1` and calls `show_coverage/1`:

```bash
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(kb_summary),
  coverage(kb_find(some_atom)),
  show_coverage([modules([user])])
" -t halt facts.pl
```

Coverage percentage is included in the hypothesis file as a confidence metric.

### 4. Removed C4-specific files and wrappers

- `prolog/ontology.pl` — removed (replaced by introspect.pl)
- `prolog/reasoning.pl` — removed (replaced by introspect.pl)
- `prolog/run.pl` — removed (agent uses swipl directly)
- `scripts/run-query.sh` — removed (agent uses swipl directly)
- `scripts/validate-facts.sh` — removed (C4-specific hook)

### 5. Updated test_facts.pl

Replaced C4-specific example with a generic software library ecosystem model using arbitrary predicates (module_type, depends_on, exports, has_test, maintainer, license).

### 6. Session boundary

After writing the hypothesis file, the skill tells the user to run `/formalize-in-lean` in a follow-up session rather than auto-invoking it.

## Final File Layout

```
query-hypothesis/
├── SKILL.md                      — rewritten skill definition
└── prolog/
    ├── introspect.pl             — generic KB introspection module
    ├── prolog_coverage_ai.pl     — coverage analysis module
    └── test_facts.pl             — non-C4 example facts
```

## Dependencies

- **Plan 02 (translate-to-prolog)** should land first, since query-hypothesis consumes facts files.
- **SWI-Prolog 8.4+** required for coverage module internals.

## Risk

- **Multifile predicates filtered**: `introspect.pl` excludes multifile predicates to avoid SWI-Prolog system predicates leaking through. If a user's facts file declares multifile predicates, they won't appear in introspect output (but can still be queried with ad-hoc Prolog).
- **Coverage numbers may be misleading**: A focused hypothesis legitimately ignores large portions of the facts file. The skill frames coverage as a signal, not a gate.
- **No file reading**: The agent can't read source code. If the facts file is incomplete, the agent is stuck. The user should run translate-to-prolog first.
