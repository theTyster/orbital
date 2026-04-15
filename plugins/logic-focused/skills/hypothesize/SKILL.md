---
name: hypothesize
description: >
  Explore a proposition by decomposing it into falsifiable hypotheses and gathering evidence from a Prolog knowledge base. Teaches logical heuristics for breaking a claim apart, querying for supporting and contradicting evidence, and producing a structured hypothesis ready for formal verification in Lean4. Works with any Prolog facts file. Use when: "explore this hypothesis", "what would break if we changed X", "is this claim true in the model", "analyze the knowledge base", "what can we derive from these facts", "what relationships exist", "query the prolog facts", "hypothesize about", "what if we changed", "is it safe to modify".
user-invocable: true
allowed-tools: Bash, Write
argument-hint: "[prolog facts file] [proposition or question to explore]"
---

# Hypothesize

Take a proposition — a planned change, an architectural claim, a design question — and systematically explore whether it holds. The end product is a structured hypothesis file that names specific, falsifiable properties ready for formal verification in Lean4.

The reasoning follows a simple arc: **proposition → decomposition → evidence → hypothesis**.
Prolog is the evidence-gathering tool, not the focus.

## Prerequisites

- **SWI-Prolog** (`swipl`): `swipl --version` must succeed.
- **A facts file**: a `.pl` file containing ground Prolog facts (output from translate-to-prolog, or hand-authored).

## Input

- **Facts file path** — the `.pl` file that models the domain
- **Proposition** — a claim, action, or question to explore. Examples:
  - "Changing the auth layer won't break the CLI tool"
  - "The dependency graph from cli_tool is acyclic"
  - "Every module that depends on web_framework also depends on logging"
  - "We can safely remove cache_lib without affecting auth_lib"

## Process

### 1. State the Proposition Clearly

Before touching Prolog, write down the proposition in one sentence. If the user gave a vague request ("analyze the knowledge base"), sharpen it into something actionable by scanning the KB schema first (see §Understand the KB below) and proposing a concrete claim.

A good proposition is:
- **Actionable** — it implies a decision or design consequence
- **Scoped** — it names specific entities or relationships
- **Contestable** — a reasonable person could disagree

Weak: "The code is well-structured."
Strong: "auth_lib has no transitive dependency on cli_tool."

### 2. Decompose into Hypotheses

A proposition rarely stands on a single fact. Break it into smaller claims that can each be independently tested. Use these heuristics:

**Assumption surfacing** — What must be true for the proposition to hold? If someone claims "changing logging won't break anything," the hidden assumptions might be:
(a) nothing depends on logging's internal API,
(b) all dependents use logging through a stable interface,
(c) logging has no transitive dependents beyond the obvious ones.

**Boundary identification** — Where does the claim stop being true? "auth_lib is isolated" might hold for direct dependencies but fail for transitive ones. Identify the boundary.

**Negation testing** — What would a counterexample look like? Before searching for evidence *for* the proposition, describe what evidence *against* it would look like. This prevents confirmation bias.

**Dependency tracing** — What entities are involved, and what connects them? Most propositions about a system involve paths through a graph. Trace the relevant paths before querying.

Write each sub-hypothesis as a concrete, falsifiable statement:
- "logging has no reverse transitive dependencies from cli_tool"
- "Every module in the depends_on graph from web_framework also appears in the depends_on graph from cli_tool"
- "The depends_on relation contains no cycles"

### 3. Gather Evidence

Now query the knowledge base. Each query should target a specific sub-hypothesis.

#### Understand the KB

Start with the schema and contents:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt facts.pl
swipl -g "use_module('${PROLOG}/introspect'), kb_describe" -t halt facts.pl
```

This tells you what predicates exist and what the data looks like. Use this to refine your hypotheses if needed — you may discover relationships you didn't know about.

#### Query for each sub-hypothesis

Run targeted queries. For each one, record:
- The query itself
- What you expected to find
- What you actually found
- Whether this supports, contradicts, or is neutral toward the sub-hypothesis

Look for **both** supporting and contradicting evidence. A hypothesis that survives contradiction attempts is stronger than one with only confirming data.

#### Query patterns (reference)

See the Prolog Reference section at the end of this document for:
- How to invoke swipl
- The introspect module (kb_summary, kb_find, kb_related, kb_graph, etc.)
- Ad-hoc query patterns (forall, findall, transitive closure, negation)

### 4. Assess Coverage

After gathering evidence, check how much of the knowledge base your queries actually exercised:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(( <your queries here> )),
  show_coverage([modules([user])])
" -t halt facts.pl
```

Interpret coverage as a confidence signal:
- **>80%**: Most facts contributed to the exploration. The hypothesis is well-grounded in the available evidence.
- **50–80%**: Significant portions unexplored. Ask whether the unexplored predicates are relevant to the proposition. If they are, query them.
- **<50%**: Narrow slice. This is acceptable for a focused proposition, but flag it — there may be relevant evidence you missed.

If important predicates show 0% coverage, investigate them before finalizing.

### 5. Synthesize the Hypothesis

From the evidence, formulate the hypothesis. It must be:

- **Specific** — names concrete entities or relationships from the KB
- **Falsifiable** — a Lean4 proof could demonstrate it false
- **Formalizable** — expressible as a logical proposition (∀, ∃, →, ¬)

Each sub-hypothesis from step 2 should either:
- **Survive** — it has supporting evidence and no counterevidence → becomes a formal property
- **Fall** — counterevidence found → note it and revise the proposition
- **Remain open** — insufficient evidence → flag as an assumption

Good hypotheses:
- "auth_lib has no transitive dependency on cli_tool"
- "Every module that depends_on web_framework also depends_on logging"
- "The dependency graph from cli_tool is acyclic"

### 6. Write the Hypothesis File

Write to `thoughts/hypothesis.md` (create `thoughts/` if needed):

```markdown
# Hypothesis: {title}

## Proposition
{The original proposition, stated clearly}

## Statement
{One-sentence formal statement of the hypothesis}

## Knowledge Coverage
- Facts file: {path}
- Total clauses: {N}
- Clauses exercised: {M} ({percentage}%)
- Coverage assessment: {high/medium/low}
- Unexercised predicates: {list, if any}

## Decomposition
{List of sub-hypotheses and their status: confirmed / refuted / assumed}

## Prolog Evidence

### Queries Run
{List of queries and key results, organized by sub-hypothesis}

### Supporting Facts
{Specific output that supports the hypothesis}

### Counterevidence
{Results that contradict or complicate the hypothesis — or explicit
statement that none was found despite searching}

## Formal Properties
Properties to prove in Lean4:

1. **{property_name}**: {natural language description}
   - Lean sketch: `theorem {name} : {type signature sketch}`
   - Depends on: {what definitions are needed}
   - Derived from: {which sub-hypothesis}

2. ...

## Scope
- **Proves**: {what this establishes if true}
- **Does not prove**: {explicit limitations}
- **Assumptions**: {what we take as given — especially sub-hypotheses that
  remained open}
```

## References

### SWI-Prolog Extensions
Documentation for SWI-Prolog extension modules is at `${CLAUDE_SKILL_DIR}/../../references/swi-prolog-extensions/`. Consult the README there when you need guidance on advanced Prolog features (tabling, DCGs, constraint logic programming, etc.).

### Mathlib Lemmas & Theorems
When writing Lean sketches in the "Formal Properties" section, consult the Mathlib wiki at `${CLAUDE_SKILL_DIR}/../../references/wiki/` for accurate theorem names and type signatures. The wiki index at `references/wiki/index.md` is organized by mathematical domain. Using real Mathlib names in sketches gives `prove-hypothesis-lean` a head start.

## Output

Write `thoughts/hypothesis.md` structured for the prove-hypothesis-lean skill.

Report to the user:
- The original proposition (one line)
- Hypothesis statement (one line)
- Number of formal properties identified
- Coverage percentage
- Notable counterevidence or open questions
- File path

Then state: **"This hypothesis is ready for formal verification. In a follow-up session, run one of:"**
- **`/prove-hypothesis-prolog thoughts/hypothesis.md`** — verify in Prolog (model-based, no extra setup, best for relational/structural properties)
- **`/prove-hypothesis-lean thoughts/hypothesis.md`** — verify in Lean 4 (machine-checked, best for mathematical/abstract properties)

Do not automatically invoke either proof skill. The user should review first.

---

## Prolog Reference

### Invoking SWI-Prolog

Every query follows this pattern:

```bash
swipl -g "<goal>" -t halt <files_to_load...>
```

`-g` runs the goal, `-t halt` exits after. Files listed after flags are consulted automatically. Use `timeout 30` for safety on ad-hoc queries.

### Loading facts and modules

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"

# Load a facts file and run a goal
swipl -g "<goal>" -t halt facts.pl

# Load the introspect module + facts file
swipl -g "use_module('${PROLOG}/introspect'), <goal>" -t halt facts.pl
```

### Introspect module

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

### Ad-hoc query patterns

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

### Coverage module

Bundled at `${CLAUDE_SKILL_DIR}/../../prolog/prolog_coverage_ai.pl`. Tracks which clauses are exercised during query execution.

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  use_module('${PROLOG}/introspect'),
  coverage(( kb_summary, kb_graph )),
  show_coverage([modules([user])])
" -t halt facts.pl
```

- `coverage(Goal)` runs Goal while tracking clause entry/exit
- Multiple `coverage/1` calls accumulate within one swipl session
- `show_coverage([modules([user])])` prints a coverage table for user-module facts
- Output shows `%Cov` per file
