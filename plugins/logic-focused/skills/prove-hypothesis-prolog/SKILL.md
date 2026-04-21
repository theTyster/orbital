---
name: prove-hypothesis-prolog
description: >
  Use this skill whenever the user wants to verify a hypothesis using Prolog — "verify with prolog", "check if this holds in the KB", "prove without lean", "formally check these properties". Encodes each hypothesis property as Prolog rules and runs exhaustive query-based verification; produces prolog_proofs.pl and proof_results.md.
user-invocable: true
model: opus
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[hypothesis file path] [prolog facts file path]"
---

# Formalize in Prolog

Read a structured hypothesis file and translate each formal property into Prolog rules
with exhaustive query-based verification. If a property has a counterexample in the KB,
loop back to hypothesize to refine. If the KB lacks sufficient evidence to decide,
flag the property as an assumption.

This is model-based verification: you are proving that properties hold *within the Prolog
model* (the KB), not in an abstract mathematical sense. This is the right choice when:
- The hypothesis is about relational or structural properties (dependency graphs, call graphs, taxonomies)
- The KB is the authoritative source of ground truth for the domain
- You want to stay within the existing Prolog pipeline without setting up Lean

For properties requiring mathematical proof independent of any concrete KB (e.g. "this
algorithm is correct for all possible inputs"), use `prove-hypothesis-lean` instead.

## Prerequisites

1. **SWI-Prolog**: `swipl --version` must succeed.
2. **Hypothesis file**: `thoughts/hypothesis.md` from the hypothesize skill.
3. **Prolog facts file**: The `.pl` KB that the hypothesis was derived from.

## What a Prolog Proof Looks Like

A Prolog proof of a property has three parts:

1. **Helper rules** — define any predicates needed to express the property (transitive
   closure, reachability, groupings, negation-as-failure wrappers).
2. **Property encoding** — a rule or query that holds iff the property is true.
3. **Verification goal** — a directive that runs at load time and prints VERIFIED or
   FALSIFIED with evidence.

Example:

```prolog
% ============================================================
% Property: acyclic_dependency_graph
% Description: The depends_on relation contains no cycles
% ============================================================

reaches(A, B) :- depends_on(A, B).
reaches(A, B) :- depends_on(A, Mid), reaches(Mid, B).

no_cycle :- \+ reaches(X, X).

:- (no_cycle
    -> format("[VERIFIED] acyclic_dependency_graph: no dependency cycles found~n")
    ;  findall(X, reaches(X, X), Cycles),
       format("[FALSIFIED] acyclic_dependency_graph: cycles at ~w~n", [Cycles])).
```

This structure is self-documenting, executable, and produces evidence either way.

## Delegate to `prolog-prover`

The primary way to execute this skill is to spawn the `logic-focused:prolog-prover` sub-agent with the `Agent` tool. That agent is the Prolog formal-proof specialist: it combines KB construction (agent-of-truth), query expertise (agent-of-questions), and CLP libraries (CLP(FD), CLP(B), CLP(Q/R)) with tabling, and treats every proof as a counterexample search. It owns the correction budget and the encoding-strategy choices described below.

Brief the sub-agent with:
- The hypothesis file path (e.g. `thoughts/hypothesis.md`)
- The facts file path
- The target proof file path (`thoughts/prolog_proofs.pl`)
- The per-property correction budget (5 inner / 3 outer, see §5)
- An instruction to produce `thoughts/proof_results.md` in the format in §7
- An instruction that when a property is genuinely falsified it must stop and surface the counterexample rather than patch the property to pass

For standalone intermediate queries (spot-checking a helper predicate, inspecting the KB schema mid-proof) spawn `logic-focused:agent-of-questions` instead — it's lighter weight and built for introspection queries.

Execute the methodology below inline only when the user has explicitly asked you to prove it yourself in this turn. Property count is not a reason — even a single transitive-closure proof benefits from the specialist's counterexample-search discipline and correction budget, and inline execution floods the main context with swipl output. When in doubt, delegate. The rest of this file is both your guide for the inline case and the briefing material for the sub-agent.

## Proof Methodology

Read `references/prolog-proof-method.md` before writing any proofs. The key principles
are summarized here but the reference has full detail with patterns.

### One Encoding at a Time

Write the helper rules, then test them before adding the verification goal. Never write
all parts before checking. Confirm the helper rules return expected intermediate results
before asserting the property holds.

### Proof Strategies

For each property shape, prefer a specific encoding strategy:

| Property shape | Strategy |
|---------------|----------|
| "All X satisfy P" | `forall(X, P(X))` or `\+ (X, \+ P(X))` |
| "No X satisfies P" | `\+ P(X)` or `findall(X, P(X), [])` |
| "There exists X" | `P(X), cut` (find first), confirm with `findall` |
| "A reaches B transitively" | Recursive `reaches/2` rule + query |
| "A cannot reach B" | `\+ reaches(A, B)` |
| "X is unique" | `findall(X, P(X), Xs), length(Xs, 1)` |
| "Groups are disjoint" | `\+ (member(X, Group1), member(X, Group2))` |
| "Count equals N" | `findall(_, P(_), Bag), length(Bag, N)` |

### Counterexample Search is the Proof

Rather than just confirming a positive result, always search for counterexamples. A
property is verified when you have genuinely tried to falsify it and failed:

```prolog
% Searching for counterexamples — if this returns [], the property holds
findall(X, (category(X), \+ has_owner(X)), Unowned),
(Unowned == [] -> format("VERIFIED~n") ; format("FALSIFIED: ~w~n", [Unowned]))
```

### Namespace Isolation

All helper predicates for a property should be prefixed or wrapped to avoid clobbering
other properties' helpers. Use descriptive, property-scoped names:

```prolog
% Good — scoped to property
auth_reaches(A, B) :- depends_on(A, B).
auth_reaches(A, B) :- depends_on(A, Mid), auth_reaches(Mid, B).

% Risky — generic name may conflict
reaches(A, B) :- ...
```

If multiple properties need the same helper (e.g. `reaches/2`), define it once at the
top of the file under a `% Shared helpers` section.

## Process

### 1. Read the Hypothesis

Read `thoughts/hypothesis.md`. Extract:
- The formal properties listed under "Formal Properties"
- Their natural language descriptions
- Any Lean sketch (use as a guide to the logical structure, not the syntax)
- Assumptions and scope
- The facts file path (from "Knowledge Coverage")

Also read the facts file header/schema to understand available predicates:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt <facts_file>
```

### 2. Translate Each Property to Prolog

For each formal property, write its section in `thoughts/prolog_proofs.pl`. Use this template:

```prolog
% ============================================================
% Property: {property_name}
% Description: {natural language from hypothesis}
% Source: {which sub-hypothesis this came from}
% ============================================================

% Helper rules (if needed)
{helper_predicate definitions}

% Property encoding
{property_rule_or_query}

% Verification
:- ({property_check}
    -> format("[VERIFIED] {property_name}: {success message}~n")
    ;  {find_counterexamples},
       format("[FALSIFIED] {property_name}: {failure message with evidence}~n")).
```

**Translation guidelines by property type:**

*Universal quantification* ("all X must..."):
```prolog
all_have_owner :-
    findall(X, (entity(X), \+ owner(X, _)), Missing),
    Missing == [].
```

*Existential* ("there exists at least one..."):
```prolog
some_active_user :-
    user(U), active(U), !.
```

*Relational / graph* ("A cannot reach B"):
```prolog
dep_reaches(A, B) :- depends_on(A, B).
dep_reaches(A, B) :- depends_on(A, Mid), dep_reaches(Mid, B).

no_reach(A, B) :- \+ dep_reaches(A, B).
```

*Counting* ("exactly N instances"):
```prolog
exactly_n_admins(N) :-
    findall(U, has_role(U, admin), Us),
    length(Us, N).
```

### 3. Verify Each Property

Load the facts file together with the proofs file and run:

```bash
swipl -g "halt" -l <facts_file> thoughts/prolog_proofs.pl
```

The directives (`:- ...`) run automatically at load time and print VERIFIED or FALSIFIED.

After each load:
- If VERIFIED: property is confirmed in the model. Record it.
- If FALSIFIED: counterexample found. Stop and diagnose (see §Handle Falsified Properties).
- If Prolog error: fix the encoding before proceeding.

**Checking intermediate results:** Before adding the verification goal, check that helper
rules behave as expected:

```bash
# Spot-check the helper predicate
swipl -g "use_module('${PROLOG}/introspect'), kb_describe" -t halt <facts_file>
swipl -g "dep_reaches(auth_lib, X), format('~w~n', [X]), fail ; true" -t halt \
  -l <facts_file> thoughts/prolog_proofs.pl
```

### 4. Assess Coverage After Each Property

After verifying each property, check that the KB had enough evidence:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  coverage(( {the_queries_you_ran} )),
  show_coverage([modules([user])])
" -t halt <facts_file>
```

Coverage signals confidence:
- **>60%**: The property is well-grounded — most facts contributed evidence.
- **30–60%**: Acceptable for focused properties. Note which predicates went untouched.
- **<30%**: Flag as a needed adaptation. The KB lacks the relevant facts because they don't
  exist yet — this is a gap to be filled, not a reason to skip the property.

If important predicates show 0% coverage and they seem relevant to the property, investigate
before marking as VERIFIED. If the facts simply aren't present, mark as NEEDED ADAPTATION —
these translate directly into failing tests that drive implementation.

### 5. Correction Budget

Each property gets a correction budget:

- **Inner corrections** (fix the encoding, same approach): 5 attempts
- **Outer iterations** (different proof strategy): 3 attempts
- **Total**: up to 15 attempts per property

After exhausting inner corrections (syntax errors, predicate name mismatches, missing
helper rules), step back and try a fundamentally different encoding strategy — different
quantifier pattern, different helper predicate structure, different negation approach.

### 6. Handle Falsified Properties

If a verification goal prints FALSIFIED:

**Capture the counterexample precisely:**
```bash
swipl -g "
  findall(X-Y, violating_predicate(X, Y), Pairs),
  format('Counterexamples: ~w~n', [Pairs])
" -t halt -l <facts_file> thoughts/prolog_proofs.pl
```

**Diagnose the failure mode:**

| Situation | Meaning | Action |
|-----------|---------|--------|
| Counterexample is a real violation | Property is false in the model | **Loop back to hypothesize** |
| Counterexample is a KB error | Facts file has a mistake | Fix the facts file and re-verify |
| Property encoding is wrong | Rules don't capture the intent | Fix the encoding and retry |
| KB is incomplete | Missing facts → gap to fill | Mark as NEEDED ADAPTATION with note |

**Loop back to hypothesize** when a genuine counterexample shows the property can't
hold in this model. Stop and tell the user to re-run hypothesize, providing this context:

```
The following property from hypothesis "{title}" was falsified:

Property: {name}
Statement: {natural language}
Counterexample: {the specific instance(s) from findall}

The Prolog model shows this property does not hold because:
{explanation of what the counterexample means}

Please re-query the facts file at {facts_file_path} to:
1. Confirm the counterexample is real (not a KB error)
2. Identify whether the property can be weakened to hold
3. Formulate a revised hypothesis that excludes the counterexample
```

### 7. Produce Results

Write results to `thoughts/proof_results.md`:

```markdown
# Proof Results: {hypothesis title}

## Summary
- Properties attempted: N
- Verified: M
- Falsified (looped back): K
- Needed adaptations (KB gap): J
- Status: {complete | partial | failed}

## Verified Properties

### {property_name}
- **Description**: {natural language}
- **Encoding**: `{key prolog rule or query}`
- **Coverage**: {percentage}%
- **Strategy**: {brief description — universal quantification / counterexample search / etc.}

## Falsified Properties

### {property_name}
- **Description**: {natural language}
- **Counterexample**: {the specific evidence}
- **Action**: {looped back to hypothesize / KB error fixed / property weakened}

## Needed Adaptations

### {property_name}
- **Description**: {natural language}
- **Gap**: {what facts are missing and why they don't exist yet}
- **Failing test**: {what a test asserting this property would check — designed to fail until implemented}

## Proof File
`thoughts/prolog_proofs.pl` — contains all property encodings and verification goals.
Run with: `swipl -g halt -l {facts_file} thoughts/prolog_proofs.pl`
```

## Verification

Never declare a property verified if the verification directive hasn't run cleanly (no
Prolog errors, no FALSIFIED output). Low coverage (<30%) means the KB lacks the facts to
decide the property — mark as NEEDED ADAPTATION, not silently accepted or skipped. Needed
adaptations are intentionally failing claims: they drive the next implementation cycle.

## Output

All artifacts are written to `thoughts/` (create it if it doesn't exist):

- `thoughts/prolog_proofs.pl` — formal property encodings with verification directives
- `thoughts/proof_results.md` — structured results summary (VERIFIED / FALSIFIED / NEEDED ADAPTATION)
- If any properties looped back: a request to re-run hypothesize
- Needed adaptations feed directly into translate-to-tests as pre-failing test cases

The proofs file is designed to be re-run at any time against the original facts file.
If the KB is ever updated, re-running it shows immediately which properties still hold.

## Configuration

- **Inner corrections per property**: 5
- **Outer iterations (fresh approach)**: 3
- **Max properties per hypothesis**: no limit
