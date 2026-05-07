# Prolog querying reference

Patterns and modules for interrogating `existing-world.pl` (or any Prolog facts file) during the evidence-gathering phase. The `decompose-proposition` skill delegates these queries to the `logic-focused:agent-of-questions` sub-agent — this reference exists for spot-checks and for the agent's own use.

## Invoking SWI-Prolog

Every query follows this pattern:

```bash
swipl -g "<goal>" -t halt <files_to_load...>
```

`-g` runs the goal, `-t halt` exits after. Files listed after flags are consulted automatically. Use `timeout 30` for safety on ad-hoc queries.

## Loading facts and modules

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"

# Load a facts file and run a goal
swipl -g "<goal>" -t halt existing-world.pl

# Load the introspect module + facts file
swipl -g "use_module('${PROLOG}/introspect'), <goal>" -t halt existing-world.pl
```

## Introspect module

Bundled at `${CLAUDE_SKILL_DIR}/../../prolog/introspect.pl`. Explores any facts file without knowing its schema in advance.

| Predicate | What it does |
|-----------|-------------|
| `kb_summary` | List every predicate with its arity and clause count |
| `kb_describe` | Print all facts, grouped by predicate |
| `kb_describe(Name/Arity)` | Print facts for one predicate |
| `kb_find(Atom)` | Find every fact that mentions Atom in any argument |
| `kb_related(Atom)` | Find atoms that co-occur with Atom in the same fact |
| `kb_graph` | Print all binary predicates as directed edges |
| `kb_stats` | Per-predicate statistics: clause counts, unique values per arg |

## Ad-hoc query patterns

```prolog
% Print all solutions
forall(depends_on(X, Y), format('~w -> ~w~n', [X, Y]))

% Collect into a list
findall(X, depends_on(X, logging), Xs), format('Depend on logging: ~w~n', [Xs])

% Count
findall(_, depends_on(_, _), Bag), length(Bag, N), format('~w deps~n', [N])

% Unique values (findall+sort — setof fails on no solutions)
findall(X, depends_on(X, _), Xs), sort(Xs, Unique), format('~w~n', [Unique])

% Transitive closure
assert((path(A,B) :- depends_on(A,B))),
assert((path(A,B) :- depends_on(A,Mid), path(Mid,B))),
forall(path(cli_tool, X), format('cli_tool transitively reaches ~w~n', [X]))

% Negation
(\+ depends_on(logging, _) -> format('no deps~n') ; format('has deps~n'))
```

## Coverage module

Bundled at `${CLAUDE_SKILL_DIR}/../../prolog/prolog_coverage_ai.pl`. Tracks which clauses are exercised during query execution.

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(( kb_summary, kb_graph )),
  show_coverage([modules([user])])
" -t halt existing-world.pl
```

- `coverage(Goal)` runs Goal while tracking clause entry/exit
- Multiple `coverage/1` calls accumulate within one swipl session
- `show_coverage([modules([user])])` prints a coverage table for user-module facts
- Output shows `%Cov` per file
