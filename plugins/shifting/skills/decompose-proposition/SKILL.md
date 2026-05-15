---
name: decompose-proposition
description: >
  Explore a proposition against a Prolog KB through a counterfactual lens: identify which existing-world KB facts would need to be false, and which new facts would need to become provable, for the proposition to hold. Takes an existing-world `.pl` file and a proposition; decomposes it into falsifiable sub-hypotheses and emits `thoughts/hypothesis.pl` — a Prolog facts file carrying labeled claims (descriptive / counterfactual / prescriptive), query evidence, and formal-property sketches.
user-invocable: true
allowed-tools: Bash, Write, Agent
argument-hint: "[existing-world.pl path] [proposition or question to explore]"
---

- **Proof that `swipl` exists:** !`which swipl`

# decompose-proposition

**Logical operation:** *decompose-proposition* — split a proposition into claims each labeled with its *ontology label* (descriptive / counterfactual / prescriptive) and backed by Prolog evidence.

Take a proposition — a planned change, an architectural claim, a design question — and systematically explore what would have to be different in the existing-world KB for the proposition to hold. The end product is `thoughts/hypothesis.pl`, a Prolog facts file that names specific, labelled, falsifiable claims ready for model construction (`model-obligations`) and machine-checked proof (`prove-invariants`).

**The counterfactual lens.** The existing-world KB is a snapshot of what IS true about the codebase today (`close-world` only models existing facts). A proposition — especially one about a planned change or a desired invariant — is usually about a state the KB does *not* yet reflect. So the driving question is:

> **What about the existing world would need to be false, and what new facts would need to become provable, for `{proposition}` to be true?**

A hypothesis that merely restates facts the KB already entails proves nothing interesting. A hypothesis that names the *delta* — the specific KB facts that must be falsified plus the new obligations that must be provable — is falsifiable, actionable, and worth formalizing.

## Two orthogonal dimensions

Every claim carries two independent ontology labels — a claim-origin label (`descriptive` / `counterfactual` / `prescriptive`) and, for any negated premise, a negation-provenance label (`absent` / `contradicts`). Downstream skills depend on both. Semantics live in `${CLAUDE_SKILL_DIR}/../../references/ontology.md`; syntactic schema lives in `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/hypothesis.md`. Read both before emitting claims.

The reasoning follows a simple arc: **proposition → labeled decomposition → evidence → hypothesis.pl**.
Prolog is the evidence-gathering tool, not the focus.

## Loopback role

Decompose is the canonical non-adjacent recovery target. When `model-obligations`, `prove-invariants`, `instantiate-properties`, or `realize-specification` cannot make progress against their immediate predecessor, they emit `upstream_gap/3` with `recovery_hint(decompose_proposition, refutation_shape_briefing([...]))`. The orchestrator decides whether to honor; this skill never auto-re-invokes. On re-invocation, consult the previous `hypothesis.pl` plus the cited `gap_descriptor` + `ParamSpec` and *amend*; do not regenerate unless the proposition itself changed.

## Orchestrator contract

This skill sits at stage 2; carrier is `existing-world.pl` from `close-world`. The orchestration-substrate wire format is `plugins/trajectory/references/orchestration-substrate.md`.

**Orchestrator parameters accepted:**

- **`refutation_shape_briefing`** — counterfactual classes the orchestrator wants surfaced (e.g., "narrow the search to absent-fact premises"; "include CWA-fragile claims even when contradiction evidence is weak"). Fold into the agent-of-questions brief.
- **`artifact_versioning`** — when the orchestrator anticipates a re-decomposition, the v1/v2/... namespace for emission (e.g., `cf_v2_*`, `pr_v2_*` claim ids). Default: no version suffix.
- **`halt_condition`** — when to stop and report a partial hypothesis rather than continue.

**Gate-target descriptor emitted on completion** — `hypothesis.pl` paired with its declared shape (per `references/pipeline-schema/hypothesis.md`) and refutation-shape suggestions: **new premises and claim-label assignments are the primary refutation surface** — every counterfactual claim's pinned absent-fact and every prescriptive claim's new-fact assertion are candidates for `disprove-proposition` to challenge.

**Upstream gap emissions** — when introspection of `existing-world.pl` reveals that the KB does not carry predicates the proposition requires:

- `upstream_gap(decompose_proposition, gap_descriptor(missing_predicate, predicate(Name, Arity)), recovery_hint(close_world, predicate_schema_extension([Name/Arity, ...])))` — the canonical case (the DD fp_i06/fp_i07 substrate-audit pattern).
- `upstream_gap(decompose_proposition, gap_descriptor(schema_insufficient, claim(ClaimId, missing_evidence_class)), recovery_hint(close_world, predicate_schema_extension([...])))` — when an entire evidence class (e.g., constructor-injection metadata, content-include directives) is absent.

Emit gap facts into `hypothesis.pl` alongside the claims; the orchestrator pattern-matches and decides whether to re-invoke `close-world` with the extended schema before proceeding to `model-obligations`.

## Current Environment

`which swipl` returns: !`which swipl`
`ls thoughts/existing-world.pl` returns: !`ls thoughts/existing-world.pl 2>/dev/null || echo "(not yet created)"`
`ls thoughts/hypothesis.pl` returns: !`ls thoughts/hypothesis.pl 2>/dev/null || echo "(not yet created)"`

**Find the existing-world file**: The `.pl` KB produced by `close-world`. Default: `thoughts/existing-world.pl`.

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

Prefer spawning the `shifting:agent-of-questions` sub-agent with the `Agent` tool to run the evidence-gathering pass. That agent is the Prolog query specialist — it never reads `.pl` files directly, it discovers the schema through `swipl` introspection (`kb_summary`, `kb_describe`, `kb_find`, `kb_related`, `kb_graph`, `kb_stats`) and writes targeted queries against whatever predicates actually exist. This avoids a common failure mode where the main agent guesses at predicate names from memory and writes queries that silently return empty.

Brief the sub-agent with:
- The existing-world file path
- Each sub-hypothesis from step 2, phrased as a counterfactual question: "Enumerate every KB fact that would contradict `{sub-hypothesis}`. The absence of such facts is itself a result — report 'no counterfactuals found after exhaustive search' rather than going silent."
- An instruction to return, for each sub-hypothesis: the queries it ran, the raw results, and **the specific KB facts (if any) that must be false for the sub-hypothesis to hold**
- For each claim reported, assign an ontology label via `claim_label/2`: `descriptive` if the claim restates what the existing world already entails; `counterfactual` if the claim asserts that an existing fact must become false; `prescriptive` if the claim asserts that a new fact (not yet in the KB) must become true in target-world.
- For every *negated* premise (counterfactual claims and any claim with a negative assertion in its body), also record a negation-provenance label via `claim_negation_provenance/3`: `absent` if the negation comes from closed-world absence (`\+ fact` succeeds under CWA); `contradicts` if the KB or an integrity constraint explicitly derives the negation. The two dimensions are orthogonal — one labels the claim, one labels each negation it depends on.
- An instruction that contradiction-hunting is the priority; confirming queries are secondary. The hypothesis file's value comes from the concrete list of counterfactual claims plus new prescriptive obligations, not from restating what the KB already entails.

If the KB is clearly missing facts the hypothesis depends on, spawn `shifting:agent-of-truth` to extend the KB before continuing — don't try to patch facts by hand.

Drop to inline querying only when the user has explicitly asked you to query it yourself in this turn. KB size is not a reason — a specialist running `swipl` introspection finds relationships you'd miss by eye, and delegation keeps the raw query noise out of the main context. When in doubt, delegate.

#### Bias-isolation discipline

Specialist delegation isolates the search from orchestrator bias. The orchestrator's hopes about whether the proposition decomposes "cleanly" or with rich counterfactual surface MUST NOT reach the specialist; decompose-proposition has no checker for missing-counterfactual under-reporting, so a too-clean hypothesis is invisible without structural defense.

**Apply both defenses on every specialist invocation** (agent-of-questions for queries, agent-of-truth for KB extensions, lean-expert for Mathlib name lookups):

1. **Role-briefing.** Open every specialist prompt with an explicit outcome-agnostic role:
   > "You are enumerating the counterfactual surface of a proposition against the KB. Report every contradicting fact the KB contains; report exhaustive search returning empty as a positive finding; do not infer facts the KB does not assert in order to make the hypothesis 'work.' Abstention on a sub-hypothesis is a valid outcome; fabricating evidence to satisfy the proposition is a foul."

2. **Minimum-necessary context.** Send only:
   - The existing-world file path + the sub-hypothesis under attack
   - The orchestrator-supplied `refutation_shape_briefing` if present
   - The introspection module path

   Do **not** paste orchestrator reasoning, the user's framing of the proposition's significance, or downstream model-obligations / prove-invariants hopes. Escalate context only when the specialist returns "underspecified" with a precise question.

**Orchestrator responsibilities (never delegated):** pin the proposition in its strongest form, decide the `refutation_shape_briefing` per ticket, validate the agent's returned counterfactual surface against `existing-world.pl` before recording claims, own the ontology-label assignments.

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
- The **ontology label** of each claim: `descriptive` (what the existing world already entails), `counterfactual` (an existing fact that must become false), or `prescriptive` (a new fact that must become provable in target-world).
- For every *negated* premise, the **negation provenance**: `absent` (CWA default — the KB does not derive the fact) or `contradicts` (the KB explicitly derives the negation from negative facts or integrity constraints). The `absent` case is fragile — it holds only as strongly as the KB is complete; the `contradicts` case is structurally necessary. Downstream `prove-invariants` uses this label to annotate theorems at the CWA→OWA boundary; dropping it silently upgrades CWA-absence into logical falsity.

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
- **Conditional** — contradicting KB facts found → these become **counterfactual claims** (KB facts that must become false in target-world) plus optional **prescriptive claims** (new facts that must become provable in target-world). Each claim carries its ontology label and, if it involves a negation, its negation-provenance label (`absent` or `contradicts`). The prove skills use both: `model-obligations` reads the label to decide whether a claim enters target-world as a removal or as a new assertion; `prove-invariants` reads the provenance to calibrate how fragile the corresponding theorem is at the CWA→OWA boundary.
- **Open** — insufficient evidence → flag as an assumption and note what additional facts would resolve it.

A hypothesis with zero counterfactual requirements is a proved invariant. A hypothesis with counterfactual requirements is a roadmap for the change the proposition implies — and that roadmap is exactly what the downstream proof skill formalizes.

**Phrasing formal properties for the prove backends.** Default to quantified-invariant shape over enumerated conjunctions: phrase `formal_property/3` as `∀ a b, P a b → Q a b`, not as a list of explicit pair facts. The invariant form expresses the spec directly; the enumerated form degrades to `decide`-over-list at the Lean stage. For *conditional* sub-hypotheses, state the property over a *target relation* that excludes the counterfactual facts (e.g. `depends_on_target(X,Y) := depends_on(X,Y) ∧ ¬ cf(X,Y)`), plus one necessity claim per counterfactual. See `references/pipeline-schema/hypothesis.md` for the full shape contract and the `formal_property/3` argument layout.

Good hypotheses:
- "auth_lib has no transitive dependency on cli_tool" (with an empty counterfactual list, if the KB confirms it)
- "`cli_tool` can stop depending on `logging` iff the KB facts `{depends_on(cli_tool, logging), depends_on(cli_tool, formatter), depends_on(formatter, logging)}` are falsified"
- "The dependency graph from cli_tool is acyclic"

### 6. Write the Hypothesis File

Write to `thoughts/hypothesis.pl` (create `thoughts/` if needed). The file is a Prolog facts file — loadable with `swipl` and queryable by downstream skills. Every piece of hypothesis content lands as a ground fact, not as prose.

**Emit against the canonical schema.** The predicate names, arities, and argument orders for `hypothesis.pl` are defined in `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/hypothesis.md`. Read that file before writing; do not invent local variations. `cross-skill-map.md` in the same directory documents how each predicate is consumed or translated downstream.

**Validate** with `swipl -g halt thoughts/hypothesis.pl` before reporting done. The file must load without errors and every `claim/2` must have a matching `claim_label/2` and `claim_status/2`.

## References

- **`references/prolog-querying.md`** — `swipl -g` invocation patterns, the introspect module, ad-hoc query patterns, the coverage module. For spot-checks; the agent-of-questions sub-agent already uses these.
- **`${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/`** — Prolog extensions (tabling, DCGs, CLP). **Don't read directly.** Pass the absolute path to `agent-of-questions` when a query needs an advanced extension.
- **`${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/`** — Mathlib theorem names and type signatures for the Lean sketches in formal properties. **Don't read directly.** Spawn `shifting:lean-expert` with a one-line description; it returns real Mathlib names. Using real names (not plausible guesses) in sketches gives `prove-invariants` a head start.

Keeping wiki content inside sub-agent contexts preserves your context window for the hypothesis itself.

## Output

Write `thoughts/hypothesis.pl` — a Prolog facts file structured for both `model-obligations` (target-world model construction) and `prove-invariants` (theorem proving).

Report to the user:
- The original proposition (one line)
- The counterfactual question
- Claim breakdown by ontology label (`claim_label/2`): N descriptive / M counterfactual / K prescriptive
- Claim status breakdown: N clear / M conditional / K open
- Negation-provenance breakdown across all negated premises: N absent / M contradicts — the `absent` subset is what `prove-invariants` will annotate as CWA-fragile at the Prolog→Lean boundary
- Number of formal properties identified
- Coverage percentage
- Open questions / assumptions
- File path

Then state: **"This hypothesis is ready for model construction and proof. In a follow-up session, run:"**
- **`/model-obligations thoughts/hypothesis.pl`** — construct `target-world.pl` from the claims (applies counterfactual negations, asserts prescriptive obligations) and emit per-property `model_results.pl` verdicts.
- **`/prove-invariants thoughts/hypothesis.pl`** — machine-check each formal property against `target-world.pl` and emit `lean_proof_results.pl`.

In the new pipeline `model-obligations` runs *before* `prove-invariants`: the first builds the substrate, the second proves over it. Do not automatically invoke either — the user should review `hypothesis.pl` first.

---

