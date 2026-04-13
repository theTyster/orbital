---
name: query-hypothesis
description: >
  Query a Prolog knowledge base to explore relationships, derive insights, and
  formulate a structured hypothesis. Writes the hypothesis to a file for downstream
  formalization in Lean4. Works with any Prolog facts file — not tied to C4 or any
  specific ontology. Use when: "explore this hypothesis", "query the prolog facts",
  "what can we derive from this model", "what relationships exist in these facts",
  "analyze the knowledge base".
user-invocable: true
allowed-tools: Bash, Write
argument-hint: "[prolog facts file] [hypothesis or question to explore]"
---

# Query Hypothesis

Query a Prolog facts file to explore a hypothesis. The facts file is your entire
world — all reasoning happens through Prolog queries, not by reading source code.

## Prerequisites

- **SWI-Prolog** (`swipl`): `swipl --version` must succeed.
- **A facts file**: Output from translate-to-prolog, or any `.pl` file containing ground facts.

## Querying with SWI-Prolog

Every query follows this pattern:

```bash
swipl -g "<goal>" -t halt <files_to_load...>
```

`-g` runs the goal, `-t halt` exits after it completes. Files listed after flags
are consulted automatically. Wrap long goals in quotes. Use `timeout 30` for safety
on ad-hoc queries.

### Loading facts and modules

```bash
PROLOG="${CLAUDE_SKILL_DIR}/prolog"

# Load a facts file and run a goal
swipl -g "<goal>" -t halt facts.pl

# Load the introspect module + facts file
swipl -g "use_module('${PROLOG}/introspect'), <goal>" -t halt facts.pl
```

Files listed at the end of the command are consulted into the `user` module.
Modules loaded with `use_module/1` keep their own namespace.

### Introspect module

This skill bundles `introspect.pl` for exploring any facts file without
knowing its schema in advance:

| Predicate | What it does |
|-----------|-------------|
| `kb_summary` | List every predicate with its arity and clause count |
| `kb_describe` | Print all facts, grouped by predicate |
| `kb_describe(Name/Arity)` | Print facts for one predicate (e.g., `kb_describe(depends_on/2)`) |
| `kb_find(Atom)` | Find every fact that mentions Atom in any argument |
| `kb_related(Atom)` | Find atoms that co-occur with Atom in the same fact |
| `kb_graph` | Print all binary predicates as directed edges |
| `kb_stats` | Per-predicate statistics: clause counts, unique values per argument |

Example:
```bash
PROLOG="${CLAUDE_SKILL_DIR}/prolog"
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt facts.pl
swipl -g "use_module('${PROLOG}/introspect'), kb_find(auth_lib)" -t halt facts.pl
```

### Writing ad-hoc queries

SWI-Prolog is expressive. Common patterns:

```prolog
% Print all solutions to a query
forall(depends_on(X, Y), format('~w -> ~w~n', [X, Y]))

% Collect results into a list, then process
findall(X, depends_on(X, logging), Xs), format('Depend on logging: ~w~n', [Xs])

% Count
findall(_, depends_on(_, _), Bag), length(Bag, N), format('~w dependencies~n', [N])

% Unique values (setof fails if no solutions — use findall+sort instead)
findall(X, depends_on(X, _), Xs), sort(Xs, Unique), format('~w~n', [Unique])

% Transitive closure — define inline then query
assert((path(A,B) :- depends_on(A,B))),
assert((path(A,B) :- depends_on(A,Mid), path(Mid,B))),
forall(path(cli_tool, X), format('cli_tool transitively depends on ~w~n', [X]))

% Negation — check something does NOT hold
(\+ depends_on(logging, _) -> format('logging has no dependencies~n') ; format('logging has dependencies~n'))
```

Run from bash:
```bash
swipl -g "forall(depends_on(X,Y), format('~w -> ~w~n',[X,Y]))" -t halt facts.pl
```

### Coverage analysis

This skill bundles `prolog_coverage_ai.pl`, a coverage module that tracks which
clauses (facts) are exercised during query execution. Use it to assess whether
your queries explored the knowledge base thoroughly.

```bash
PROLOG="${CLAUDE_SKILL_DIR}/prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(( kb_summary, kb_graph )),
  show_coverage([modules([user])])
" -t halt facts.pl
```

Key points:
- `coverage(Goal)` runs Goal while tracking which clauses were entered/exited
- Multiple `coverage/1` calls accumulate data within the same swipl session
- `show_coverage([modules([user])])` prints a coverage table for user-module facts
- The output shows `%Cov` (percentage of clauses exercised) per file

To run several queries under coverage in one session:
```bash
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(kb_summary),
  coverage(kb_find(some_atom)),
  coverage(( forall(depends_on(X,Y), format('~w->~w~n',[X,Y])) )),
  show_coverage([modules([user])])
" -t halt facts.pl
```

## Input

- **Facts file path** — a `.pl` file containing ground Prolog facts
- **Hypothesis or question** — what to explore. Examples:
  - "Is module X isolated from module Y?"
  - "What's the blast radius of changing the auth layer?"
  - "Are there hidden coupling patterns?"
  - "Which components have no test coverage?"

## Process

### 1. Understand the Knowledge Base

Start with `kb_summary` and `kb_describe` to learn the schema and contents:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/prolog"
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt facts.pl
swipl -g "use_module('${PROLOG}/introspect'), kb_describe" -t halt facts.pl
```

### 2. Explore the Hypothesis

Run targeted queries. Use introspect predicates for broad exploration and
ad-hoc Prolog for specific questions. Each result should inform the next query.

### 3. Assess Coverage

After a round of queries, run them under coverage to check completeness:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(( <your queries here> )),
  show_coverage([modules([user])])
" -t halt facts.pl
```

Interpret the coverage percentage as a confidence signal:
- **>80%**: Most facts contributed. Hypothesis is well-grounded.
- **50–80%**: Significant portions unexplored. Consider whether they're relevant.
- **<50%**: Narrow slice. Either the hypothesis is focused (acceptable) or querying was incomplete.

If important predicates show 0% coverage, run targeted queries on them before
finalizing the hypothesis.

### 4. Formulate the Hypothesis

From query results, formulate a precise hypothesis. It must be:

- **Specific** — names concrete entities or relationships
- **Falsifiable** — could be proven wrong
- **Formalizable** — expressible as a logical proposition

Good:
- "auth_lib has no transitive dependency on cli_tool"
- "Every module that depends_on web_framework also depends_on logging"
- "The dependency graph from cli_tool is acyclic"

Bad:
- "The code is well-structured" (not falsifiable)
- "Things depend on other things" (not specific)

### 5. Write the Hypothesis File

Write to `thoughts/hypothesis.md` (create `thoughts/` if needed):

```markdown
# Hypothesis: {title}

## Statement
{One-sentence formal statement}

## Knowledge Coverage
- Facts file: {path}
- Total clauses: {N}
- Clauses exercised: {M} ({percentage}%)
- Coverage assessment: {high/medium/low}
- Unexercised predicates: {list, if any}

## Prolog Evidence

### Queries Run
{List of queries and key results}

### Supporting Facts
{Specific output that supports the hypothesis}

### Potential Counterevidence
{Results that complicate or contradict the hypothesis}

## Formal Properties
Properties to prove in Lean4:

1. **{property_name}**: {natural language description}
   - Lean sketch: `theorem {name} : {type signature sketch}`
   - Depends on: {what definitions are needed}

2. ...

## Scope
- **Proves**: {what this establishes if true}
- **Does not prove**: {explicit limitations}
- **Assumptions**: {what we take as given}
```

## Output

Write `thoughts/hypothesis.md` structured for the formalize-in-lean skill.

Report to the user:
- Hypothesis statement (one line)
- Number of formal properties identified
- Coverage percentage
- File path

Then state: **"This hypothesis is ready for formal verification. In a follow-up session, run `/formalize-in-lean thoughts/hypothesis.md` to prove or revise it."**

Do not automatically invoke formalize-in-lean. The user should review the hypothesis first.

## Guidance

- **Query broadly, then narrow.** Start with kb_summary and kb_describe, then target specifics.
- **Look for counterevidence.** Run queries that might contradict your hypothesis. A hypothesis that survives contradiction attempts is stronger.
- **Use the graph.** `kb_graph` reveals structural patterns that flat fact listings hide.
- **Multiple properties.** A single hypothesis often decomposes into several formal properties. Each should be independently provable.
- **Iterate.** If the hypothesis doesn't survive querying, revise it. Better to refine here than fail in Lean4.
