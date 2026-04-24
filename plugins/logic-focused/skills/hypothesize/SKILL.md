---
name: hypothesize
description: >
  Explore a proposition against a Prolog KB through a counterfactual lens: identify which existing KB facts would need to be false for the proposition to hold. Takes a .pl facts file and a proposition; decomposes it into falsifiable sub-hypotheses and produces a structured hypothesis file naming the counterfactual requirements.
user-invocable: true
allowed-tools: Bash, Write, Agent
argument-hint: "[prolog facts file] [proposition or question to explore]"
---

- **Proof that `swipl` exists:** !`which swipl`

# Hypothesize

Take a proposition — a planned change, an architectural claim, a design question — and systematically explore what would have to be different in the existing KB for the proposition to hold. The end product is a structured hypothesis file that names specific, falsifiable properties ready for formal verification in Lean4.

**The counterfactual lens.** The Prolog KB is a snapshot of what IS true about the codebase today (`translate-to-prolog` only models existing facts). A proposition — especially one about a planned change or a desired invariant — is usually about a state the KB does *not* yet reflect. So the driving question is:

> **What about the existing KB would need to be false for `{proposition}` to be true?**

A hypothesis that merely restates facts the KB already entails proves nothing interesting. A hypothesis that names the *delta* — the specific KB facts that must be falsified, removed, or refactored away — is falsifiable, actionable, and worth formalizing.

**Epistemic origin tags.** Every counterfactual requirement this skill emits carries an *epistemic origin* tag drawn from the vocabulary in `../../references/epistemic-types.md`. Downstream skills — especially `prove-hypothesis-lean` — rely on this tag to avoid treating Prolog's closed-world absence as Lean-style logical falsity. The three tag values a counterfactual can carry are:
- `KB_PRESENT` — the KB asserts the fact; falsifying it is concrete deletion or refactoring work.
- `KB_ABSENT_CWA` — the KB does not derive the fact; closed-world absence is weak evidence of falsity and can be wrong if the KB is incomplete.
- `KB_CONTRADICTED` — the KB explicitly derives `¬fact` from negative facts or integrity constraints; strongest of the three.

The reasoning follows a simple arc: **proposition → counterfactual decomposition → evidence → hypothesis**.
Prolog is the evidence-gathering tool, not the focus.

## Current Environment

`which swipl` returns: !`which swipl`
`ls thoughts/hypothesis.md` returns: !`ls thoughts/hypothesis.md 2>/dev/null || echo "(not yet created)"`

**Find Prolog facts file**: The `.pl` KB that the hypothesis was derived from.

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

Once the proposition is sharp, immediately restate it as a counterfactual question against the KB:

> **What about the existing KB would need to be false for this proposition to be true?**

This is the question the rest of the skill answers. If the answer is "nothing — the KB already entails it," say so and report the proposition as a trivial invariant. The interesting hypotheses are ones where the KB contains facts that stand in the way.

### 2. Decompose into Counterfactual Sub-Hypotheses

A proposition rarely stands on a single fact. Break it into smaller claims that can each be independently tested against the KB. The goal is to locate the *counterfactual surface*: the specific KB facts or relations whose falsity is a precondition for the proposition.

**Counterfactual decomposition (primary)** — For each entity and relation named in the proposition, ask: "If the KB contained a fact that contradicts this proposition, what would that fact look like?" Then query for exactly those facts. A proposition like "auth_lib has no transitive dependency on cli_tool" decomposes into the counterfactual query: "enumerate every path `auth_lib →* cli_tool` in `depends_on`." Any such path found is a *counterfactual requirement* — a KB fact that must be falsified (removed, refactored, broken) for the proposition to hold.

**Assumption surfacing** — What must be true for the proposition to hold? If someone claims "changing logging won't break anything," the hidden assumptions might be:
(a) nothing depends on logging's internal API,
(b) all dependents use logging through a stable interface,
(c) logging has no transitive dependents beyond the obvious ones.
Each assumption becomes a counterfactual question: "what KB fact would violate (a)?"

**Boundary identification** — Where does the claim stop being true? "auth_lib is isolated" might hold for direct dependencies but fail for transitive ones. The boundary is usually where counterfactual facts start appearing.

**Dependency tracing** — What entities are involved, and what connects them? Most propositions about a system involve paths through a graph. Trace the relevant paths — each existing path is a candidate counterfactual.

Write each sub-hypothesis as a concrete, falsifiable statement phrased against the KB:
- "The KB contains no path from `cli_tool` to `logging` in `depends_on`" (counterfactual: any such path must be broken)
- "The KB contains no module that `depends_on(web_framework)` but does not `depends_on(logging)`"
- "The `depends_on` relation in the KB contains no cycles"

### 3. Gather Evidence

Now query the knowledge base. Each query should target a specific sub-hypothesis.

#### Delegate querying to `agent-of-questions`

Prefer spawning the `logic-focused:agent-of-questions` sub-agent with the `Agent` tool to run the evidence-gathering pass. That agent is the Prolog query specialist — it never reads `.pl` files directly, it discovers the schema through `swipl` introspection (`kb_summary`, `kb_describe`, `kb_find`, `kb_related`, `kb_graph`, `kb_stats`) and writes targeted queries against whatever predicates actually exist. This avoids a common failure mode where the main agent guesses at predicate names from memory and writes queries that silently return empty.

Brief the sub-agent with:
- The facts file path
- Each sub-hypothesis from step 2, phrased as a counterfactual question: "Enumerate every KB fact that would contradict `{sub-hypothesis}`. The absence of such facts is itself a result — report 'no counterfactuals found after exhaustive search' rather than going silent."
- An instruction to return, for each sub-hypothesis: the queries it ran, the raw results, and **the specific KB facts (if any) that must be false for the sub-hypothesis to hold**
- For each counterfactual fact reported, tag its origin: `KB_PRESENT` if the fact is asserted in the KB; `KB_ABSENT_CWA` if `\+ fact` succeeds but no explicit contradiction exists; `KB_CONTRADICTED` if the KB derives `\+ fact` from stated negative facts or integrity constraints.
- An instruction that contradiction-hunting is the priority; confirming queries are secondary. The hypothesis file's value comes from the concrete list of counterfactual facts, not from restating what the KB already entails.

If the KB is clearly missing facts the hypothesis depends on, spawn `logic-focused:agent-of-truth` to extend the KB before continuing — don't try to patch facts by hand.

Drop to inline querying only when the user has explicitly asked you to query it yourself in this turn. KB size is not a reason — a specialist running `swipl` introspection finds relationships you'd miss by eye, and delegation keeps the raw query noise out of the main context. When in doubt, delegate.

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
- What a counterfactual fact would look like (the shape of a contradicting result)
- What the KB actually returned
- The concrete list of KB facts (if any) that must be falsified for the sub-hypothesis to hold
- The **epistemic origin** of each counterfactual: `KB_PRESENT` if the fact is present in the KB, `KB_ABSENT_CWA` if it is absent under closed-world assumption, or `KB_CONTRADICTED` if the KB explicitly derives its negation. This tag travels with the counterfactual into the hypothesis file and must not be dropped — downstream prove skills depend on it to calibrate the strength of any Lean lift.

Prioritize contradiction-hunting. A sub-hypothesis that survives exhaustive attempts to falsify it is a strong invariant. A sub-hypothesis with a concrete list of contradicting facts is a roadmap — state both outcomes explicitly.

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
- **Falsifiable** — a Lean4 or Prolog proof could demonstrate it false
- **Formalizable** — expressible as a logical proposition (∀, ∃, →, ¬)
- **Counterfactual-aware** — explicitly names the KB facts (if any) that must be false for it to hold

Each sub-hypothesis from step 2 lands in one of three states:

- **Clear** — no contradicting KB facts found after exhaustive search → becomes a formal property asserting the universal negation (e.g., `∀ x, ¬ depends_on_trans(auth_lib, x) ∧ x = cli_tool`). This is a strong invariant of the current KB.
- **Conditional** — contradicting KB facts found → these become the **counterfactual requirements**: the hypothesis is "the proposition holds *iff* the following KB facts are false: `{list}`." This is the most informative outcome — it names a concrete refactoring target. Each counterfactual requirement must carry its origin tag (`KB_PRESENT`, `KB_ABSENT_CWA`, or `KB_CONTRADICTED`); the prove skill will use the tag to decide whether the corresponding Lean lift needs to be marked `LEAN_CWA_LIFTED`.
- **Open** — insufficient evidence → flag as an assumption and note what additional facts would resolve it.

A hypothesis with zero counterfactual requirements is a proved invariant. A hypothesis with counterfactual requirements is a roadmap for the change the proposition implies — and that roadmap is exactly what the downstream proof skill formalizes.

**Phrasing formal properties for the prove backends.** How a property is stated determines whether the prove skill can actually verify it.

- *Clear* sub-hypothesis → state the property directly over the KB's predicates (e.g. `¬ depends_on_trans(auth_lib, cli_tool)`). The prove skill will verify it as an invariant.
- *Conditional* sub-hypothesis → state the property over a *target relation* that excludes the counterfactual facts, and name each counterfactual as a companion necessity claim. Example:

  > **Property**: `cli_tool` has no transitive dependency on `logging` in `depends_on_target`, where `depends_on_target(X,Y) := depends_on(X,Y) ∧ ¬ cf(X,Y)` and `cf` is the set of counterfactual facts listed above.
  > **Necessity claims** (one per counterfactual): re-introducing `cf_fact(cli_tool, logging)` to the target relation restores a path `cli_tool →* logging`.

  The prove skills (`prove-hypothesis-prolog`, `prove-hypothesis-lean`) both consume this shape: they derive the target relation from the counterfactual list, prove sufficiency over the target, and prove a necessity lemma for each counterfactual fact. A property phrased directly over the base relation in conditional mode is unprovable by construction — the current KB contradicts it.

Good hypotheses:
- "auth_lib has no transitive dependency on cli_tool" (with an empty counterfactual list, if the KB confirms it)
- "`cli_tool` can stop depending on `logging` iff the KB facts `{depends_on(cli_tool, logging), depends_on(cli_tool, formatter), depends_on(formatter, logging)}` are falsified"
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

## Counterfactual Question
{The proposition restated as: "What about the existing KB needs to be false
for this proposition to be true?"}

## Decomposition
{List of sub-hypotheses and their status: clear / conditional / open}

## Prolog Evidence

### Queries Run
{List of queries and key results, organized by sub-hypothesis}

### Supporting Facts
{Specific output that supports the hypothesis}

### Counterevidence
{Results that contradict or complicate the hypothesis — or explicit
statement that none was found despite searching}

## Counterfactual Requirements
KB facts that must be false for the proposition to hold. This is the delta
between the current KB and the world in which the proposition is true.

- **`{fact as it appears in the KB}`** (from sub-hypothesis `{id}`, origin: `{KB_PRESENT | KB_ABSENT_CWA | KB_CONTRADICTED}`) —
  {why this fact blocks the proposition, and what change to the underlying
  system would falsify it. If origin is `KB_ABSENT_CWA`, note: this is a
  closed-world negation; Lean cannot detect this provenance and will treat
  it as logical falsity unless the prove skill marks the lifted theorem
  `LEAN_CWA_LIFTED`.}
- ...

If no counterfactuals were found: state explicitly *"The KB contains no facts
contradicting the proposition; it holds as an invariant of the current system."*

## Formal Properties
Properties to prove in Lean4:

1. **{property_name}**: {natural language description}
   - Lean sketch: `theorem {name} : {type signature sketch}`
   - Depends on: {what definitions are needed}
   - Derived from: {which sub-hypothesis}

2. ...

## Scope
- **Proves**: {what this establishes if true — either "the proposition is an
  invariant of the current KB" or "the proposition holds iff the
  counterfactual requirements above are falsified"}
- **Does not prove**: {explicit limitations}
- **Assumptions**: {what we take as given — especially sub-hypotheses that
  remained open}
```

## References

The plugin ships two wikis under `${CLAUDE_SKILL_DIR}/../../references/` — `prolog-wiki/` and `lean4-wiki/`. **Don't read either yourself.** Wiki content flows through the domain agents this skill already delegates to:

- **Prolog extensions** (tabling, DCGs, CLP, etc.) for queries you're drafting: `agent-of-questions` has direct wiki access. When you spawn it (§3), include the absolute path `${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/` in the briefing if the query needs an advanced extension.
- **Accurate Mathlib theorem names and type signatures** for Lean sketches in the "Formal Properties" section: spawn `logic-focused:lean-expert` with a one-line description of the property and it will return real Mathlib names. Using real names (not plausible guesses) in sketches gives `prove-hypothesis-lean` a head start. Include the absolute path `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/` in the briefing.

Keeping the wiki content inside sub-agent contexts preserves your context window for the hypothesis itself.

## Output

Write `thoughts/hypothesis.md` structured for the prove-hypothesis-lean skill.

Report to the user:
- The original proposition (one line)
- The counterfactual question ("what about the KB must be false for this to hold?")
- Hypothesis statement (one line)
- Count and summary of **counterfactual requirements** — the KB facts that must be falsified (or "none: the KB already entails the proposition")
- Counterfactual origin breakdown: N present / M absent-CWA / K contradicted — the absent-CWA subset is the part the prove skill will mark `LEAN_CWA_LIFTED`.
- Number of formal properties identified
- Coverage percentage
- Open questions / assumptions
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
