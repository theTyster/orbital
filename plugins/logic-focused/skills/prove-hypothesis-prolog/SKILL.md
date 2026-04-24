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

## Two kinds of negation, two tags

Prolog verifies properties against a KB using negation-as-failure (`\+ P`) and, when
integrity constraints or explicit negative facts are present, also detects outright
contradictions. These are epistemically different and must not be flattened.

- `\+ P` succeeds means "the KB does not derive P" — a closed-world absence
  (`KB_ABSENT_CWA`). Downstream (especially when lifted into Lean) this is a *weak*
  negation.
- A contradiction (derived via integrity constraint violation, an explicit
  `\+_fact(...)` predicate, or `false :- P`) is a strong negation — `KB_CONTRADICTED`.
- Every property verified by this skill is emitted into `proof_results.md` with an
  `Epistemic origin` field capturing which kind(s) of negation it depended on, plus
  `PROLOG_MODEL_VERIFIED` to indicate exhaustive model search succeeded.

Reference: `../../references/epistemic-types.md`.

## Current Environment

`which swipl` returns: !`which swipl`
`ls thoughts/hypothesis.md` returns: !`ls thoughts/hypothesis.md 2>/dev/null || echo "(not yet created)"`

**Find Prolog facts file**: The `.pl` KB that the hypothesis was derived from.

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

## Proof Modes

The hypothesis file's `## Counterfactual Requirements` section determines the mode. Read it *before* encoding anything:

**Invariant mode** — counterfactual list is empty ("*The KB contains no facts contradicting the proposition; it holds as an invariant of the current system.*"). Each formal property is proved directly against the facts file. This is the classical verification mode — the rest of this skill treats it as the default.

**Conditional mode** — counterfactual list is non-empty. The hypothesis claims *"the proposition holds iff these specific KB facts are false."* That claim has two proof obligations per property:

1. **Sufficiency** — define a *target relation* that excludes the counterfactual facts from the base relation, and prove the property holds in the target relation. This is the constructive direction: "if the underlying system is refactored so these facts no longer hold, the proposition becomes true."
2. **Necessity** — for each counterfactual fact F, show the property re-falsifies when F is re-introduced to the target relation. This audits the counterfactual list: any F that doesn't re-break the property was padding, and should be flagged.

If *any* sub-hypothesis in `## Decomposition` is marked `conditional`, the proof is conditional. Do not mix modes — a partially conditional hypothesis is conditional as a whole.

### Target relation pattern (conditional mode)

Encode the counterfactuals as a separate predicate, then define a filtered view of the base relation:

```prolog
% From hypothesis.md "Counterfactual Requirements":
cf_fact(cli_tool, logging).
cf_fact(cli_tool, formatter).
cf_fact(formatter, logging).

% Target relation: the base relation with counterfactuals removed.
depends_on_target(X, Y) :-
    depends_on(X, Y),
    \+ cf_fact(X, Y).

% Sufficiency: property holds in the target relation
dep_t_reaches(A, B) :- depends_on_target(A, B).
dep_t_reaches(A, B) :- depends_on_target(A, Mid), dep_t_reaches(Mid, B).

:- (\+ dep_t_reaches(cli_tool, logging)
    -> format("[SUFFICIENT] removing counterfactuals isolates cli_tool from logging~n")
    ;  findall(P, dep_t_reaches(cli_tool, logging), Ps),
       format("[INSUFFICIENT] counterfactuals do not isolate cli_tool; still reaches via ~w~n", [Ps])).

% Necessity: for each counterfactual F, adding F back to target must re-break the property.
% Here shown for one; generate one directive per counterfactual fact.
depends_on_target_plus_cli_logging(X, Y) :- depends_on_target(X, Y).
depends_on_target_plus_cli_logging(cli_tool, logging).

dep_tpl_reaches(A, B) :- depends_on_target_plus_cli_logging(A, B).
dep_tpl_reaches(A, B) :- depends_on_target_plus_cli_logging(A, Mid), dep_tpl_reaches(Mid, B).

:- (dep_tpl_reaches(cli_tool, logging)
    -> format("[NECESSARY] cf_fact(cli_tool,logging) is load-bearing~n")
    ;  format("[EXTRANEOUS] cf_fact(cli_tool,logging) — removing it alone did not restore reachability; counterfactual list may be over-specified~n")).
```

A conditional property is VERIFIED only when sufficiency holds *and* every counterfactual fact is marked NECESSARY. Any EXTRANEOUS flag gets reported in the results as a counterfactual-list refinement that should go back to `hypothesize`.

## Delegate to `prolog-prover`

The primary way to execute this skill is to spawn the `logic-focused:prolog-prover` sub-agent with the `Agent` tool. That agent is the Prolog formal-proof specialist: it combines KB construction (agent-of-truth), query expertise (agent-of-questions), and CLP libraries (CLP(FD), CLP(B), CLP(Q/R)) with tabling, and treats every proof as a counterexample search. It owns the correction budget and the encoding-strategy choices described below.

Brief the sub-agent with:
- The hypothesis file path (e.g. `thoughts/hypothesis.md`)
- The facts file path
- The target proof file path (`thoughts/prolog_proofs.pl`)
- The per-property correction budget (5 inner / 3 outer, see §5)
- An instruction to produce `thoughts/proof_results.md` in the format in §7
- An instruction that when a property is genuinely falsified it must stop and surface the counterexample rather than patch the property to pass
- An explicit instruction to first read `## Counterfactual Requirements` and `## Decomposition` to determine proof mode (invariant vs. conditional — see §Proof Modes above), and to produce necessity + sufficiency directives per property in conditional mode. Conditional proofs must not be collapsed into a single "does it hold in the current KB" check — that check is guaranteed to falsify and loses the constructive content.
- For each verified property, report whether its proof relied on negation-as-failure (`\+`), explicit contradiction (integrity constraints, explicit `\+_fact` predicates), or both. The calling skill will use this to populate the `Negation kind` field in `proof_results.md`.

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
- **The counterfactual requirements** (from "Counterfactual Requirements") and the **decomposition status** (clear / conditional / open) of each sub-hypothesis. Decide the proof mode here — invariant vs. conditional — and record it at the top of `prolog_proofs.pl` as a comment. This decision governs every property encoding that follows.
- For each counterfactual requirement, extract its origin tag. This tag flows into the proof_results entry for the verified property — properties whose counterfactuals are all `KB_PRESENT` or `KB_CONTRADICTED` verify cleanly; properties depending on `KB_ABSENT_CWA` carry that tag forward so `prove-hypothesis-lean` (if run on the same hypothesis) knows to mark the Lean theorem `LEAN_CWA_LIFTED`.

Also read the facts file header/schema to understand available predicates:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt <facts_file>
```

### 2. Translate Each Property to Prolog

For each formal property, write its section in `thoughts/prolog_proofs.pl`.

**In invariant mode**, use this template:

```prolog
% ============================================================
% Property: {property_name}        (mode: invariant)
% Description: {natural language from hypothesis}
% Source: {which sub-hypothesis this came from}
% ============================================================

% Helper rules (if needed)
{helper_predicate definitions}

% Property encoding
{property_rule_or_query}

% Epistemic annotation: this directive uses \+ (negation-as-failure / CWA)
%   — OR —
% Epistemic annotation: this directive depends on explicit contradiction
% (integrity constraint violated if this fact is asserted)
%
% Verification
:- ({property_check}
    -> format("[VERIFIED] {property_name}: {success message}~n")
    ;  {find_counterexamples},
       format("[FALSIFIED] {property_name}: {failure message with evidence}~n")).
```

Annotate every proof directive with whether it relies on `\+` (CWA) or on explicit
contradiction. The annotation becomes the source for the `CWA-bound` /
`contradiction-bound` flag in `proof_results.md`. Example shapes:

```prolog
% Epistemic annotation: this directive uses \+ (negation-as-failure / CWA)
:- forall(depends_on_target(X, Y),
          ( ... \+ ... )).

% Epistemic annotation: this directive depends on explicit contradiction
% (integrity constraint violated if this fact is asserted)
:- \+ clause(conflicting_invariant(_, _), _).
```

**In conditional mode**, use this template instead — sufficiency directive plus one necessity directive per counterfactual fact:

```prolog
% ============================================================
% Property: {property_name}        (mode: conditional)
% Description: {natural language from hypothesis}
% Source: {which sub-hypothesis this came from}
% Counterfactuals required false:  {list them by ground term}
% ============================================================

% Counterfactual facts from hypothesis:
cf_fact({arg1}, {arg2}).   % one per counterfactual

% Target relation (base minus counterfactuals)
{base}_target(X, Y) :- {base}(X, Y), \+ cf_fact(X, Y).

% Helper rules built on the target relation (not the base relation)
{helper predicates over _target}

% Epistemic annotation: this directive uses \+ (negation-as-failure / CWA)
%   — OR —
% Epistemic annotation: this directive depends on explicit contradiction
% (integrity constraint violated if this fact is asserted)
%
% Sufficiency verification
:- ({property_check over _target}
    -> format("[SUFFICIENT] {property_name}: holds in target relation~n")
    ;  {find counterexamples in target},
       format("[INSUFFICIENT] {property_name}: target relation still contains ~w~n", [Ctr])).

% Necessity verification — one directive per counterfactual fact F
{base}_target_plus_F(X, Y) :- {base}_target(X, Y).
{base}_target_plus_F({F_arg1}, {F_arg2}).
{helper predicates over _target_plus_F}

% Epistemic annotation: this directive uses \+ (negation-as-failure / CWA)
%   — OR —
% Epistemic annotation: this directive depends on explicit contradiction
% (integrity constraint violated if this fact is asserted)
:- ({property_check FAILS over _target_plus_F}
    -> format("[NECESSARY] cf_fact({F_arg1},{F_arg2}) is load-bearing~n")
    ;  format("[EXTRANEOUS] cf_fact({F_arg1},{F_arg2}): removing it alone did not restore the property — flag counterfactual list as over-specified~n")).
```

Annotate every proof directive with whether it relies on `\+` (CWA) or on explicit
contradiction. The annotation becomes the source for the `CWA-bound` /
`contradiction-bound` flag in `proof_results.md`.

Keep helper predicates scoped per property (see §Namespace Isolation) — conditional encodings multiply the number of derived relations, so prefix discipline matters more.

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
- **Invariant mode**:
  - `VERIFIED` → property is confirmed in the model. Record it.
  - `FALSIFIED` → counterexample found. Stop and diagnose (see §Handle Falsified Properties).
- **Conditional mode**: a property is only `VERIFIED` when *all* directives for it print `SUFFICIENT` *and* every necessity directive prints `NECESSARY`. Specifically:
  - `SUFFICIENT` + all `NECESSARY` → property verified; the counterfactual list is both complete and minimal.
  - `INSUFFICIENT` → counterfactual list is incomplete; the property still falsifies after removing the named facts. Loop back to `hypothesize` with the leftover counterexample.
  - `SUFFICIENT` but some `EXTRANEOUS` → property verified, but the counterfactual list has padding. Report the extraneous facts so `hypothesize` can drop them.
- `Prolog error` (either mode) → fix the encoding before proceeding.

When classifying the overall proof, distinguish the two negation kinds for the results
report. A property verified entirely via `\+` is `PROLOG_MODEL_VERIFIED` but also carries
`CWA_BOUND`; a property verified via explicit contradiction or integrity constraint
carries `CWA_FREE`. A property whose directives mix both kinds carries `MIXED`. This is
the information Lean needs if the same hypothesis is later proved in Lean.

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
| Counterexample is a real violation (invariant mode) | Property is false in the model | **Loop back to hypothesize** — it may belong in conditional mode |
| Counterexample is a KB error | Facts file has a mistake | Fix the facts file and re-verify |
| Property encoding is wrong | Rules don't capture the intent | Fix the encoding and retry |
| KB is incomplete | Missing facts → gap to fill | Mark as NEEDED ADAPTATION with note |
| `INSUFFICIENT` in conditional mode | Counterfactual list is incomplete — target relation still contains a violating path | **Loop back to hypothesize** with the specific leftover path; it names what else must be false |
| `EXTRANEOUS` in conditional mode | One or more counterfactuals are not load-bearing | **Loop back to hypothesize** to prune the counterfactual list; proof is otherwise valid |

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
- Proof mode: {invariant | conditional}
- Properties attempted: N
- Verified: M
- Falsified (looped back): K
- Counterfactual-list gaps (INSUFFICIENT): I
- Counterfactual-list padding (EXTRANEOUS): E
- Needed adaptations (KB gap): J
- Status: {complete | partial | failed}

## Verified Properties

### {property_name}
- **Description**: {natural language}
- **Mode**: {invariant | conditional}
- **Encoding**: `{key prolog rule or query}`
- **Coverage**: {percentage}%
- **Strategy**: {brief description — universal quantification / counterexample search / etc.}
- **Epistemic origin:** PROLOG_MODEL_VERIFIED
- **Negation kind:** {CWA_BOUND | CWA_FREE | MIXED}
- **CWA-bound premises:** {list of premises verified via `\+`, or "none"}
- **Contradiction-bound premises:** {list of premises verified via explicit negative facts / integrity constraints, or "none"}
- **Counterfactuals** (conditional mode only): list each with `NECESSARY` status;
  if any were `EXTRANEOUS`, the property is still verified but the list should be pruned.

## Falsified Properties

### {property_name}
- **Description**: {natural language}
- **Counterexample**: {the specific evidence}
- **Action**: {looped back to hypothesize / KB error fixed / property weakened}

## Counterfactual-List Issues (conditional mode)

### {property_name} — INSUFFICIENT
- **Description**: {natural language}
- **Remaining counterexample after target filter**: {the path/fact that still violates}
- **Action**: looped back to `hypothesize` — the counterfactual list must name the missing fact(s) too.

### {property_name} — EXTRANEOUS counterfactual
- **Fact flagged**: `cf_fact({args})`
- **Reason**: re-introducing this fact alone to the target relation did not re-break the property; it is not load-bearing.
- **Action**: looped back to `hypothesize` to drop this from the counterfactual list.

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

- **Not all Prolog negation is created equal.** `\+ P` is CWA-absence — the KB did not
  derive P, not that P is impossible. Explicit negative facts and integrity constraints
  give genuine `KB_CONTRADICTED` status. Mark each in `proof_results.md`. The downstream
  Lean lift and the TDD absence tests both weaken under `CWA_BOUND` — dropping the
  distinction is an epistemic bug.

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
