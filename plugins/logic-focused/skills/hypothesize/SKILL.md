---
name: hypothesize
description: >
  Explore a proposition against a Prolog KB through a counterfactual lens: identify which existing-world KB facts would need to be false, and which new facts would need to become provable, for the proposition to hold. Takes an existing-world `.pl` file and a proposition; decomposes it into falsifiable sub-hypotheses and emits `thoughts/hypothesis.pl` — a Prolog facts file carrying labeled claims (descriptive / counterfactual / prescriptive), query evidence, and formal-property sketches.
user-invocable: true
allowed-tools: Bash, Write, Agent
argument-hint: "[existing-world.pl path] [proposition or question to explore]"
---

- **Proof that `swipl` exists:** !`which swipl`

# Hypothesize

**Logical operation:** *decompose_proposition* — split a proposition into claims each labeled with its `epistemic_label` (descriptive / counterfactual / prescriptive) and backed by Prolog evidence.

Take a proposition — a planned change, an architectural claim, a design question — and systematically explore what would have to be different in the existing-world KB for the proposition to hold. The end product is `thoughts/hypothesis.pl`, a Prolog facts file that names specific, labelled, falsifiable claims ready for model construction (`prove-hypothesis-prolog`) and machine-checked proof (`prove-hypothesis-lean`).

**The counterfactual lens.** The existing-world KB is a snapshot of what IS true about the codebase today (`translate-to-prolog` only models existing facts). A proposition — especially one about a planned change or a desired invariant — is usually about a state the KB does *not* yet reflect. So the driving question is:

> **What about the existing world would need to be false, and what new facts would need to become provable, for `{proposition}` to be true?**

A hypothesis that merely restates facts the KB already entails proves nothing interesting. A hypothesis that names the *delta* — the specific KB facts that must be falsified plus the new obligations that must be provable — is falsifiable, actionable, and worth formalizing.

## Two orthogonal dimensions

Every claim this skill emits carries two independent tags. Downstream skills depend on both — dropping either is an epistemic bug.

**Dimension 1 — `epistemic_label/1` on the claim itself.** Exactly one of:

| Label | Meaning | World semantics |
|---|---|---|
| `descriptive` | What is currently true in the existing world | Prolog KB under CWA |
| `counterfactual` | What must become false for the goal to hold | Prolog KB under CWA, inverted |
| `prescriptive` | What must exist or be provable in the target world | Lean proof under OWA |

**Dimension 2 — `negation_provenance/1` on any *negated* fact** (applies to counterfactual claims and any negative premise). Exactly one of:

| Provenance | Meaning | Strength |
|---|---|---|
| `absent` | False because the fact is not declared in the KB (CWA default) | Fragile — depends on KB completeness |
| `contradicts` | False because the KB contains an explicit conflicting fact | Structurally necessary — holds regardless of KB completeness |

These are orthogonal: a single counterfactual claim has both a label (`counterfactual`) *and* a negation provenance (`absent` or `contradicts`). Downstream:
- `prove-hypothesis-prolog` reads `epistemic_label` to decide whether a claim enters `target-world.pl` as a negation (counterfactual) or as a new assertion (prescriptive).
- `prove-hypothesis-lean` reads `negation_provenance` to decide whether a theorem over a negated premise is CWA-fragile (`absent`) or structurally sound (`contradicts`).

Reference: `../../references/epistemic-types.md`.

The reasoning follows a simple arc: **proposition → labeled decomposition → evidence → hypothesis.pl**.
Prolog is the evidence-gathering tool, not the focus.

## Loopback role

This skill is re-invoked whenever a downstream prove step fails. If `prove-hypothesis-prolog` reports `inconsistent` or `gap` verdicts in `model_results.pl`, or `prove-hypothesis-lean` reports `unprovable` theorems in `lean_proof_results.pl`, the pipeline returns here to refine `hypothesis.pl` — typically by resharpening a claim, adjusting an epistemic label, adding missing counterfactual requirements, or breaking a formal property into provable sub-properties. The loopback is **human-gated**: neither prove skill re-invokes `hypothesize` automatically. A user (or the previous prove-skill's report) must explicitly request a refinement pass, pointing at the specific unresolved property. On re-invocation, consult the previous `hypothesis.pl` plus any `model_results.pl` / `lean_proof_results.pl` verdicts and *amend* the hypothesis file — do not regenerate from scratch unless the proposition itself changed.

## Current Environment

`which swipl` returns: !`which swipl`
`ls thoughts/existing-world.pl` returns: !`ls thoughts/existing-world.pl 2>/dev/null || echo "(not yet created)"`
`ls thoughts/hypothesis.pl` returns: !`ls thoughts/hypothesis.pl 2>/dev/null || echo "(not yet created)"`

**Find the existing-world file**: The `.pl` KB produced by `translate-to-prolog`. Default: `thoughts/existing-world.pl`.

## Input

- **Existing-world file path** — the `.pl` file that models the existing world (default `thoughts/existing-world.pl`)
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
- The existing-world file path
- Each sub-hypothesis from step 2, phrased as a counterfactual question: "Enumerate every KB fact that would contradict `{sub-hypothesis}`. The absence of such facts is itself a result — report 'no counterfactuals found after exhaustive search' rather than going silent."
- An instruction to return, for each sub-hypothesis: the queries it ran, the raw results, and **the specific KB facts (if any) that must be false for the sub-hypothesis to hold**
- For each claim reported, assign an `epistemic_label`: `descriptive` if the claim restates what the existing world already entails; `counterfactual` if the claim asserts that an existing fact must become false; `prescriptive` if the claim asserts that a new fact (not yet in the KB) must become true in target-world.
- For every *negated* premise (counterfactual claims and any claim with a negative assertion in its body), also assign a `negation_provenance`: `absent` if the negation comes from closed-world absence (`\+ fact` succeeds under CWA); `contradicts` if the KB or an integrity constraint explicitly derives the negation. The two dimensions are orthogonal — one tags the claim, one tags each negation it depends on.
- An instruction that contradiction-hunting is the priority; confirming queries are secondary. The hypothesis file's value comes from the concrete list of counterfactual claims plus new prescriptive obligations, not from restating what the KB already entails.

If the KB is clearly missing facts the hypothesis depends on, spawn `logic-focused:agent-of-truth` to extend the KB before continuing — don't try to patch facts by hand.

Drop to inline querying only when the user has explicitly asked you to query it yourself in this turn. KB size is not a reason — a specialist running `swipl` introspection finds relationships you'd miss by eye, and delegation keeps the raw query noise out of the main context. When in doubt, delegate.

#### Understand the KB

Start with the schema and contents:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt existing-world.pl
swipl -g "use_module('${PROLOG}/introspect'), kb_describe" -t halt existing-world.pl
```

This tells you what predicates exist and what the data looks like. Use this to refine your hypotheses if needed — you may discover relationships you didn't know about.

#### Query for each sub-hypothesis

Run targeted queries. For each one, record:
- The query itself
- What a counterfactual fact would look like (the shape of a contradicting result)
- What the KB actually returned
- The concrete list of KB facts (if any) that must be falsified for the sub-hypothesis to hold
- The **epistemic label** of each claim: `descriptive` (what the existing world already entails), `counterfactual` (an existing fact that must become false), or `prescriptive` (a new fact that must become provable in target-world).
- For every *negated* premise, the **negation_provenance**: `absent` (CWA default — the KB does not derive the fact) or `contradicts` (the KB explicitly derives the negation from negative facts or integrity constraints). The `absent` case is fragile — it holds only as strongly as the KB is complete; the `contradicts` case is structurally necessary. Downstream `prove-hypothesis-lean` uses this tag to annotate theorems at the CWA→OWA boundary; dropping it silently upgrades CWA-absence into logical falsity.

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
" -t halt existing-world.pl
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

- **Clear** — no contradicting KB facts found after exhaustive search → becomes a formal property asserting the universal negation (e.g., `∀ x, ¬ depends_on_trans(auth_lib, x) ∧ x = cli_tool`). This is a strong invariant of the current KB. Label the claim `descriptive`.
- **Conditional** — contradicting KB facts found → these become **counterfactual claims** (KB facts that must become false in target-world) plus optional **prescriptive claims** (new facts that must become provable in target-world). Each claim carries its `epistemic_label` and, if it involves a negation, its `negation_provenance` (`absent` or `contradicts`). The prove skills use both: `prove-hypothesis-prolog` reads the label to decide whether a claim enters target-world as a removal or as a new assertion; `prove-hypothesis-lean` reads the provenance to calibrate how fragile the corresponding theorem is at the CWA→OWA boundary.
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

Write to `thoughts/hypothesis.pl` (create `thoughts/` if needed). The file is a Prolog facts file — loadable with `swipl` and queryable by downstream skills. Every piece of hypothesis content lands as a ground fact, not as prose.

Use the schema below. Predicate names are stable across pipeline runs; downstream skills match on them.

```prolog
% ==========================================================================
% Hypothesis: {short title} — machine-readable record of the decomposition
% Generated by: hypothesize skill
% ==========================================================================

:- discontiguous claim/2, claim_label/2, claim_status/2, negation_provenance/2,
                 evidence/3, formal_property/3, sub_hypothesis/2, coverage/2,
                 assumption/2.

% --- Source ---
proposition("{one-sentence natural-language proposition}").
existing_world_file('thoughts/existing-world.pl').
counterfactual_question("What about the existing world needs to be false, and what new facts must become provable, for the proposition to be true?").

% --- Coverage snapshot against existing-world ---
coverage(total_clauses, {N}).
coverage(clauses_exercised, {M}).
coverage(percentage, {P}).
coverage(assessment, {high|medium|low}).
coverage(unexercised_predicates, [{pred/arity}, ...]).

% --- Sub-hypotheses ---
% sub_hypothesis(Id, "natural-language statement").
sub_hypothesis(sh_001, "cli_tool has no transitive dependency on logging in depends_on").
% ...

% --- Claims (one fact per labeled claim) ---
% claim(ClaimId, "natural-language statement").
% claim_label(ClaimId, descriptive|counterfactual|prescriptive).
% claim_status(ClaimId, clear|conditional|open).
% If the claim is a counterfactual or otherwise involves negation, record provenance:
% negation_provenance(ClaimId, absent|contradicts).
claim(c_001, "depends_on(cli_tool, logging) must not hold in target-world").
claim_label(c_001, counterfactual).
claim_status(c_001, conditional).
negation_provenance(c_001, absent).   % CWA absence post-refactor

claim(c_002, "auth_lib exposes a stable public interface").
claim_label(c_002, prescriptive).
claim_status(c_002, open).

% --- Evidence (ties claims to Prolog queries and results) ---
% evidence(ClaimId, query_text, result_summary).
evidence(c_001,
         "findall(P, depends_on_trans(cli_tool, logging, P), Ps)",
         "found paths: [[cli_tool,formatter,logging], [cli_tool,logging]]").

% --- Formal properties (sketches for the prove skills) ---
% formal_property(PropertyId, "natural-language description", "lean-sketch").
formal_property(p_001,
                "cli_tool has no transitive path to logging in the target relation",
                "theorem cli_tool_not_reaches_logging : ¬ Reach depends_on_target Module.cli_tool Module.logging := by sorry").

% --- Assumptions (open sub-hypotheses and their unresolved questions) ---
% assumption(Id, "what would resolve this").
assumption(a_001, "need structural facts about public-interface definitions before we can close c_002").
```

**Schema notes.**
- `claim_label/2` is the `epistemic_label` dimension: exactly one of `descriptive`, `counterfactual`, `prescriptive`. Every claim must have one.
- `negation_provenance/2` applies only to claims whose body involves a negation (every `counterfactual` claim, plus any `prescriptive` claim whose body contains `¬...`). Absent from a `descriptive` claim.
- `claim_status/2` is `clear` (no evidence-backed counterfactuals), `conditional` (counterfactual or prescriptive claim with enumerable evidence), or `open` (insufficient evidence to decide — becomes an assumption).
- If the hypothesis has no counterfactual or prescriptive claims (pure invariant mode), emit `claim_label(_, descriptive)` for every claim and skip `negation_provenance` entirely.

**Validate** with `swipl -g halt thoughts/hypothesis.pl` before reporting done. The file must load without errors and every `claim/2` must have a matching `claim_label/2` and `claim_status/2`.

## References

The plugin ships two wikis under `${CLAUDE_SKILL_DIR}/../../references/` — `prolog-wiki/` and `lean4-wiki/`. **Don't read either yourself.** Wiki content flows through the domain agents this skill already delegates to:

- **Prolog extensions** (tabling, DCGs, CLP, etc.) for queries you're drafting: `agent-of-questions` has direct wiki access. When you spawn it (§3), include the absolute path `${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/` in the briefing if the query needs an advanced extension.
- **Accurate Mathlib theorem names and type signatures** for Lean sketches in the "Formal Properties" section: spawn `logic-focused:lean-expert` with a one-line description of the property and it will return real Mathlib names. Using real names (not plausible guesses) in sketches gives `prove-hypothesis-lean` a head start. Include the absolute path `${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/` in the briefing.

Keeping the wiki content inside sub-agent contexts preserves your context window for the hypothesis itself.

## Output

Write `thoughts/hypothesis.pl` — a Prolog facts file structured for both `prove-hypothesis-prolog` (target-world model construction) and `prove-hypothesis-lean` (theorem proving).

Report to the user:
- The original proposition (one line)
- The counterfactual question
- Claim breakdown by `epistemic_label`: N descriptive / M counterfactual / K prescriptive
- Claim status breakdown: N clear / M conditional / K open
- `negation_provenance` breakdown across all negated premises: N absent / M contradicts — the `absent` subset is what `prove-hypothesis-lean` will annotate as CWA-fragile at the Prolog→Lean boundary
- Number of formal properties identified
- Coverage percentage
- Open questions / assumptions
- File path

Then state: **"This hypothesis is ready for model construction and proof. In a follow-up session, run:"**
- **`/prove-hypothesis-prolog thoughts/hypothesis.pl`** — construct `target-world.pl` from the claims (applies counterfactual negations, asserts prescriptive obligations) and emit per-property `model_results.pl` verdicts.
- **`/prove-hypothesis-lean thoughts/hypothesis.pl`** — machine-check each formal property against `target-world.pl` and emit `lean_proof_results.pl`.

In the new pipeline `prove-hypothesis-prolog` runs *before* `prove-hypothesis-lean`: the first builds the substrate, the second proves over it. Do not automatically invoke either — the user should review `hypothesis.pl` first.

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
swipl -g "<goal>" -t halt existing-world.pl

# Load the introspect module + facts file
swipl -g "use_module('${PROLOG}/introspect'), <goal>" -t halt existing-world.pl
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
" -t halt existing-world.pl
```

- `coverage(Goal)` runs Goal while tracking clause entry/exit
- Multiple `coverage/1` calls accumulate within one swipl session
- `show_coverage([modules([user])])` prints a coverage table for user-module facts
- Output shows `%Cov` per file
