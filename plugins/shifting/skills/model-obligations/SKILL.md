---
name: model-obligations
description: >
  Stage 3 of `trajectory:pipeline` (the seven-stage pipeline). Reads `thoughts/existing-world.pl` and `thoughts/hypothesis.pl`, applies counterfactual negations and prescriptive obligations, and emits `thoughts/target-world.pl` (the substrate Lean later proves against) plus `thoughts/model_results.pl` (per-property verdicts). The canonical entry point is `trajectory:pipeline`, which dispatches here when stage 3 is in scope. Invoke this skill directly only when re-running model construction against an existing hypothesis — typically an adjacent loopback from `prove-invariants` — or when the user asks to "rebuild the target world from the current hypothesis without re-decomposing."
user-invocable: true
context: fork
agent: general-purpose
model: opus
effort: xhigh
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
argument-hint: "[hypothesis.pl path] [existing-world.pl path]"
---

# model-obligations

This skill performs the **model-obligations** logical operation: it builds a new
Prolog knowledge base — `thoughts/target-world.pl` — from the existing-world KB
and the hypothesis. The target world is the substrate that `prove-invariants`
proves over; without it, Lean has no model to reason against.

The skill no longer "proves" against a fixed KB as an alternative to Lean. It is
the **first** of two sequential proof steps:

1. `model-obligations` (this skill) — construct `target-world.pl` from
   `existing-world.pl` + `hypothesis.pl`. Emits per-property verdicts as Prolog
   facts in `model_results.pl`.
2. `prove-invariants` — prove the formal properties hold in `target-world.pl`.

Conceptually, `target-world.pl` is **`existing-world.pl` with counterfactual
negations applied and prescriptive obligations asserted**. Each fact carries an
ontology label. The result is CWA-valid: a closed-world model Lean can lift into
its own logic.

## Three enforcement rules to remember

These shape every choice in this skill:

- `cwa_negation_neq_lean_proof` — A fact's CWA-absence in target-world is not the
  same as Lean disproving it. Negation-as-failure is fragile; only explicit
  `contradicts` provenance is structurally necessary.
- `lean_universal_neq_test_verified` — A universal property proven by Lean over
  target-world is not the same as a sample test passing. Don't conflate the two
  in `model_results.pl`.
- `behavioral_claim_neq_proven_property` — A behavioral test that exercises a
  claim is not the projection of a proof. The model verdict tracks structural
  consistency, not runtime behavior.

## Schema and ontology dimensions

Two orthogonal ontology dimensions carry across the boundary: the claim-origin label (`claim_label/2`) on each claim (descriptive / counterfactual / prescriptive) and the negation-provenance label on each negated premise (absent / contradicts). Semantics: `${CLAUDE_SKILL_DIR}/../../references/ontology.md`. Wire format for every artifact this skill touches: `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/` — read `hypothesis.md` for the input, `target-world.md` and `model-results.md` for the outputs, and `cross-skill-map.md` for the per-claim → per-fact translation this skill performs.

## Orchestrator contract

This skill is stage 3. Carrier from predecessor: `thoughts/hypothesis.pl`. The orchestration-substrate wire format is `plugins/trajectory/references/orchestration-substrate.md`.

**Carrier-only reads.** The carrier is `hypothesis.pl`; it carries the metadata pointer to `existing-world.pl` that this skill follows transitively to read the substrate facts. No optional reads of other skill outputs are permitted — what hypothesis.pl points at is in scope; everything else is not.

**Orchestrator parameters accepted:** `refutation_shape_briefing` (refutation classes the orchestrator wants surfaced in `model_results.pl` verdicts when later attacked); `halt_condition`.

**Gate-target descriptors emitted on completion** — three outputs, each its own descriptor:
- `target_world_pl` — the Prolog substrate (carrier into prove-invariants).
- `target_world_shape_lean` — the Lean structural translation (omitted when no closed domains; see "Dual emission" below).
- `model_results_pl` — per-property `verdict/2`, `counterexample/2`, `gap_reason/2`, `cf_status/2` facts.

Primary refutation surface for these descriptors: the counterfactual-vs-prescriptive split in target-world (a counterfactually-removed fact that the implementation still asserts is a Pattern-3 violation) and any `verdict(_, consistent)` row whose `cf_status` says `extraneous` (over-specified hypothesis).

**Upstream gap emissions.** When the hypothesis cannot be lifted into a coherent target-world, emit:

- `upstream_gap(model_obligations, gap_descriptor(unresolvable_negation_provenance, claim(ClaimId, absent_fact(Predicate, Args))), recovery_hint(decompose_proposition, refutation_shape_briefing([reframe_absent_as_required_premise])))` — when a counterfactual claim's `negation_provenance` is `absent` and the resulting target-world would silently weaken Lean's downstream reach. The DD substrate-audit pattern.

Emit gap facts into `model_results.pl` alongside the verdict facts; the orchestrator decides whether to re-invoke `decompose-proposition` with the briefing folded in or to proceed.

**Adjacent loopback target.** When this skill's own work cannot reach a consistent target-world from a given hypothesis, the adjacent loopback target is `decompose-proposition` (gap=`inconsistent` / `gap` / `extraneous_counterfactual` per existing-world.pl). That loop runs through the orchestrator via the gap emissions above.

## Current Environment

Setup marker: !`CHECK="${CLAUDE_PLUGIN_ROOT}/../scaffolding/skills/setup/scripts/check-setup.sh"; [ -x "$CHECK" ] && "$CHECK" --summary || echo "orbital: scaffolding plugin not installed; setup state unknown"`
`ls thoughts/hypothesis.pl` returns: !`ls thoughts/hypothesis.pl 2>/dev/null || echo "(not yet created)"`
`ls thoughts/existing-world.pl` returns: !`ls thoughts/existing-world.pl 2>/dev/null || echo "(not yet created)"`

**Find the existing-world facts file**: the `.pl` KB the hypothesis was derived
from. Defaults to `thoughts/existing-world.pl`.

## What target-world.pl Looks Like

`target-world.pl` is constructed by composing four operations on
`existing-world.pl`:

1. **Load** every fact from `existing-world.pl` as a starting baseline.
2. **For each `claim_label(Id, counterfactual)`**: *remove* the corresponding
   fact (it was previously in existing-world but must not appear in
   target-world). Tag the removed-fact-equivalent with
   `negation_provenance(Fact, absent)` or `negation_provenance(Fact, contradicts)`
   matching what `hypothesis.pl` recorded.
3. **For each `claim_label(Id, prescriptive)`**: *assert* a new fact (it must
   hold in target-world even though it isn't in existing-world). The new fact is
   the obligation; tag it with `provenance(Fact, prescriptive)`.
4. **For each `claim_label(Id, descriptive)`**: leave as-is from existing-world.
   Already-true claims do not need fresh entries in target-world unless they are
   load-bearing for one of the formal properties Lean must prove.

For the exact predicate shape of `target-world.pl` and `model_results.pl`, see
`${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/target-world.md` and
`model-results.md` respectively. This file is the substrate Lean proves against —
self-documenting, re-runnable, and structurally distinct from `existing-world.pl`
so the diff between worlds is auditable.

## Dual emission — `target-world.pl` and `target-world-shape.lean`

`target-world.pl` continues to carry the flat ground facts (downstream Prolog consumers, adherence checking, and `instantiate-properties` query patterns all need them). In addition, this skill emits `thoughts/target-world-shape.lean` — the structural translation that `prove-invariants` consumes directly instead of transcribing facts into Lean `List` literals. Both outputs encode the same world; they differ only in representation.

The Lean shape file declares one inductive enum per closed Prolog domain, one inductive `Prop` per Prolog predicate (one constructor per surviving ground fact), and one parallel CF-augmented inductive predicate per counterfactual claim. Worked example, the 2312-Extra rework, the close-vs-open-domain heuristic, and the rationale for keeping the tiered classifier on hold for v1 all live in **`references/dual-emission-example.md`**.

## Constructing target-world: counterfactual + prescriptive encoding

The mechanics: counterfactuals are applied via a target-relation filter (`depends_on_target(X, Y) :- depends_on(X, Y), \+ cf_fact(X, Y)`); prescriptive obligations are asserted directly as new facts with `provenance(_, prescriptive)` tags; per-property verdicts come from querying the target relation.

A property verdict is `consistent` only when (a) the target-relation check succeeds and (b) every counterfactual feeding into it is `load_bearing` — re-introducing the cf fact must re-violate at least one property; otherwise it's `extraneous` and gets recorded for loopback to `decompose-proposition`.

Full Prolog encoding — cf-fact assertions, target-relation rule, transitive-closure helper, verdict directive, counterfactual minimality check — lives in **`references/target-world-encoding.md`**.

## Delegate to `prolog-prover`

The primary way to execute this skill is to spawn the `shifting:prolog-prover`
sub-agent with the `Agent` tool. That agent is the Prolog formal-proof specialist:
it combines KB construction (agent-of-truth), query expertise (agent-of-questions),
and CLP libraries (CLP(FD), CLP(B), CLP(Q/R)) with tabling, and treats every
verdict-derivation as a counterexample search.

Execute the methodology below inline only when the user has explicitly asked you
to construct the target-world yourself in this turn. Property count is not a
reason — even a single transitive-closure verdict benefits from the specialist's
counterexample-search discipline. When in doubt, delegate.

### Bias-isolation discipline

Specialist delegation isolates verdict derivation from orchestrator bias. The orchestrator's hopes about which properties "should" be consistent MUST NOT reach the specialist; model-obligations has no checker for patched-to-pass encodings, so a too-optimistic verdict is invisible without structural defense.

**Apply both defenses on every prolog-prover / agent-of-questions invocation:**

1. **Role-briefing.** Open every specialist prompt with:
   > "You are deriving target-world consistency verdicts via counterexample search. A `consistent` verdict is earned only after a genuine falsification attempt fails. If a property is genuinely `inconsistent`, stop and surface the counterexample — do not patch the encoding to pass. Abstention with a `gap` verdict and gap_reason is a valid outcome. The orchestrator has no preferred verdict."

2. **Minimum-necessary context.** Send only:
   - The hypothesis path + existing-world path (transitively cited)
   - The target output paths
   - The per-property correction budget (5 inner / 3 outer, see §5)
   - The orchestrator-supplied `refutation_shape_briefing` if present
   - The `negation_provenance` propagation rule (`absent` vs `contradicts`; CWA-absent ≠ Lean-disproved)

   Do **not** paste orchestrator reasoning, hopes about which counterfactuals are "real," or downstream prove-invariants targets. Escalate context only when the specialist returns "underspecified" with a precise question.

**Orchestrator responsibilities (never delegated):** pin the hypothesis in its strongest form, set the `refutation_shape_briefing`, validate the verdict file's structure before recording, own the `consistent` / `inconsistent` / `gap` assignments.

For standalone intermediate queries (spot-checking a helper predicate, inspecting
the KB schema mid-construction) spawn `shifting:agent-of-questions` instead —
it's lighter weight and built for introspection queries. The same bias-isolation
discipline applies.

## Methodology

Read **`references/prolog-proof-method.md`** before writing any encodings. The reference covers: one-encoding-at-a-time discipline (helper rules first, verdict directive last), the property-shape → encoding strategy table (`forall` / `findall` / recursive reaches / disjoint membership / cardinality patterns), counterexample-search-as-verdict (a `consistent` verdict is earned only after a genuine falsification attempt fails), and namespace isolation for helper predicates. Do not re-derive these from this file.

## Process

### 1. Read the Hypothesis (Prolog facts)

Load `thoughts/hypothesis.pl` and query its claim structure. Do not parse markdown.

For the named-fact projection (the predicates and arities are already known — `claim_label/2`, `formal_property/3`, `claim_negation_provenance/3`, plus the prescriptive obligation atoms), delegate to the `shifting:pl-fact-extractor` sub-agent instead of writing inline `swipl` boilerplate. The agent returns a JSON digest of fact tuples and counts; the skill consumes the digest, not raw stdout.

**Briefing fields for `pl-fact-extractor`:**

| Field | Source |
|---|---|
| `pl_paths` | `[thoughts/hypothesis.pl]` |
| `fact_spec` | `claim_label/2`, `formal_property/3`, `claim_negation_provenance/3` |
| `output_format` | `json` |

The full agent contract — hard rules, missing-predicate semantics, digest schema — lives at `../../agents/pl-fact-extractor.md`.

Extract from the digest:
- The formal property identifiers (`formal_property/3` facts) and their
  natural-language descriptions and Lean sketches (arg 2 and arg 3).
- The claim breakdown by `claim_label/2` value.
- For each `claim_label(Id, counterfactual)`, the associated
  `claim_negation_provenance(Id, Fact, absent|contradicts)` record.
- For each `claim_label(Id, prescriptive)`, the obligation fact to assert.
- The existing-world path (from `hypothesis.pl`'s metadata, or argument hint).

Also read the existing-world schema to understand available predicates:

```bash
swipl -g "use_module('${PROLOG}/introspect'), kb_summary" -t halt \
  thoughts/existing-world.pl
```

### 2. Construct target-world.pl

Open `thoughts/target-world.pl` for write. Emit, in order:

1. A header comment naming the source files and the construction date.
2. **Carried-over descriptive facts** — every fact from existing-world that is
   not negated by a counterfactual claim, each followed by
   `provenance(Fact, descriptive).`
3. **Prescriptive obligations** — for each `claim_label(Id, prescriptive)`,
   assert the obligation fact and its `provenance(Fact, prescriptive).`
4. **Negation-provenance markers** — for each counterfactual claim's
   `claim_negation_provenance(ClaimId, Fact, Mode)` in `hypothesis.pl`, emit the
   per-fact form `negation_provenance(Fact, absent).` or
   `negation_provenance(Fact, contradicts).` in `target-world.pl`. The per-claim
   3-arg form becomes the per-fact 2-arg form here — this is the translation
   step at the hypothesis → target-world boundary. The fact itself is *omitted*
   from target-world (CWA-absent) but the provenance marker is preserved so
   Lean can decide how to lift the negation.
5. **cf_fact/N facts** for the counterfactual list, used by target-relation
   filters in step 3 (encoding).
6. **Formal-property propagation** — copy every `formal_property(Id, NL, Sketch)`
   fact from `hypothesis.pl` into `target-world.pl` verbatim. This is
   `prove-invariants`'s schema-level handle on the property list; without it,
   Lean has no source of truth for which theorems to discharge. Do **not**
   rename to `property/2`; do **not** strip the Lean sketch.

Annotate every fact with its ontology label so the diff between existing-world
and target-world is auditable from the file alone. The canonical schemas for
the two files this skill touches live in
`${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/` — read `hypothesis.md`
before reading the input, `target-world.md` before emitting the output, and
`model-results.md` before emitting the verdict dump. `cross-skill-map.md` in
the same directory documents the per-claim → per-fact translation this skill
performs at the boundary.

### 2b. Emit `target-world-shape.lean`

Alongside `target-world.pl`, write `thoughts/target-world-shape.lean` — the
inductive declarations `prove-invariants` consumes. See "Dual emission" above
for the shape; the file imports `Ontology.Prelude` (the scaffold from
`plugins/shifting/lean/Ontology/Prelude.lean`) and exposes:

- One `inductive ... where | ...` enum per closed Prolog domain (carried-over
  descriptive atoms ∪ prescriptive obligation atoms; counterfactual values
  added only as constructors of the parallel CF-augmented predicate, never as
  enum constructors that survive into target-world).
- One `inductive ... : DomA → DomB → … → Prop where | name : ...` per Prolog
  predicate, with one constructor per *surviving* ground fact. The
  counterfactually-removed pairs are excluded.
- For each counterfactual claim, a parallel `inductive PCF{n} : … → Prop where`
  that mirrors the target-world predicate plus a constructor for the
  counterfactually-removed pair. The CF-augmented predicate is what
  `prove-invariants` cites in its necessity lemma.

A target-world fact that has no closed-domain encoding (open-string position,
file path, free-form identifier) stays in `target-world.pl` only and is not
mirrored into `target-world-shape.lean`. The Lean side encodes only the
structural / inductive surface; open-string facts cross the boundary as
`String`-indexed predicates the downstream skill writes by hand.

If `target-world-shape.lean` would be empty (no closed-domain predicates this
ticket), skip emission and surface a note in `model_results.pl`:
`emission_note(target_world_shape, omitted_no_closed_domains).` `prove-invariants`
falls back to its prior list-transcription path in that case, but trips its
hard-rule check if any theorem closes by `decide` on a target-world predicate.

### 3. Encode and Run Verdict Directives

For each `formal_property/3` in `hypothesis.pl`, write its verdict block in
`target-world.pl`:

```prolog
% ============================================================
% Property: {property_id}
% Description: {natural-language description}
% Claims relied on: {ids from hypothesis.pl}
% ============================================================

% Helper rules (target-relation-scoped)
{helper predicates over target relations}

% Verdict directive — emits verdict/2 (and counterexample/2 or gap_reason/2)
:- ({property check over target world}
    -> assertz(verdict({property_id}, consistent))
    ;  findall({Counterexample shape}, {falsifying query}, Cs),
       (Cs == []
         -> assertz(verdict({property_id}, gap)),
            assertz(gap_reason({property_id}, "{why target-world lacks deciding facts}"))
         ;  assertz(verdict({property_id}, inconsistent)),
            assertz(counterexample({property_id}, Cs)))).
```

For each counterfactual claim feeding the property, also emit the
`load_bearing | extraneous` minimality check shown in §"Constructing
target-world." Any `extraneous` counterfactual flags the hypothesis's claim
list as over-specified and triggers a loop back to `decompose-proposition`.

Run target-world together with existing-world to populate verdicts:

```bash
swipl -g "halt" -l thoughts/existing-world.pl thoughts/target-world.pl
```

The directives (`:- ...`) run automatically at load time and assert
`verdict/2` facts. After loading, dump them to `model_results.pl`:

```bash
swipl -g "
  consult('thoughts/existing-world.pl'),
  consult('thoughts/target-world.pl'),
  tell('thoughts/model_results.pl'),
  forall(verdict(P, V), (writeq(verdict(P, V)), write('.'), nl)),
  forall(counterexample(P, C), (writeq(counterexample(P, C)), write('.'), nl)),
  forall(gap_reason(P, R), (writeq(gap_reason(P, R)), write('.'), nl)),
  forall(cf_status(F, S), (writeq(cf_status(F, S)), write('.'), nl)),
  told
" -t halt
```

After each verdict:
- `consistent` → record it; safe to hand off to `prove-invariants`.
- `inconsistent` → counterexample found. Stop and diagnose (see §Handle
  Inconsistent Verdicts).
- `gap` → target-world lacks deciding facts. Either the hypothesis is missing
  prescriptive obligations or existing-world is incomplete. Loop back to
  `decompose-proposition` to add the missing obligations.
- `Prolog error` → fix the encoding before proceeding.

Per the enforcement rules: a `consistent` verdict is structural consistency in
target-world only. It is not a universal proof (`lean_universal_neq_test_verified`)
and CWA-absent counterfactuals do not constitute a Lean disproof
(`cwa_negation_neq_lean_proof`).

### 4. Assess Coverage After Each Verdict

After a verdict is recorded, check that target-world had enough evidence to
decide it:

```bash
PROLOG="${CLAUDE_SKILL_DIR}/../../prolog"
swipl -g "
  use_module('${PROLOG}/prolog_coverage_ai'),
  coverage(( {the_queries_you_ran} )),
  show_coverage([modules([user])])
" -t halt thoughts/existing-world.pl thoughts/target-world.pl
```

Coverage signals confidence:
- **>60%**: The verdict is well-grounded — most facts contributed evidence.
- **30–60%**: Acceptable for focused properties. Note which predicates went
  untouched.
- **<30%**: Target-world is sparse for this property. If important predicates
  show 0% coverage and they seem relevant, either the hypothesis needs another
  prescriptive obligation, or existing-world is missing the supporting facts.
  Mark the verdict as `gap` with a `gap_reason` describing what is missing.

### 5. Correction Budget

Each property gets a correction budget:

- **Inner corrections** (fix the encoding, same approach): 5 attempts
- **Outer iterations** (different encoding strategy): 3 attempts
- **Total**: up to 15 attempts per property

After exhausting inner corrections (syntax errors, predicate name mismatches,
missing helper rules), step back and try a fundamentally different encoding —
different quantifier pattern, different helper predicate structure, different
negation approach.

### 6. Handle Inconsistent Verdicts

If a verdict is `inconsistent`:

**Capture the counterexample precisely:**
```bash
swipl -g "
  findall(X-Y, violating_predicate(X, Y), Pairs),
  format('Counterexamples: ~w~n', [Pairs])
" -t halt -l thoughts/existing-world.pl thoughts/target-world.pl
```

**Diagnose the failure mode:**

| Situation | Meaning | Action |
|-----------|---------|--------|
| Counterexample is a real violation | Property does not hold in target-world | **Loop back to `decompose-proposition`** — the claim list is incomplete |
| Counterexample is an existing-world error | Existing-world has a bad fact | Fix existing-world and re-run |
| Encoding is wrong | Helper rules don't capture the intent | Fix the encoding and retry |
| `gap` (no counterexamples, no proof) | Target-world is missing deciding facts | Loop back to `decompose-proposition` to add the prescriptive obligation |
| Counterfactual `extraneous` flag | A counterfactual claim is not load-bearing | Loop back to `decompose-proposition` to prune the claim |

**Loop back to `decompose-proposition`** when a genuine counterexample shows the
property cannot be made consistent in target-world. Stop and tell the user to
re-run decompose-proposition, providing this context:

```
The following property from hypothesis "{title}" is inconsistent in target-world:

Property: {property_id}
Statement: {natural language}
Counterexample: {the specific instance(s) from findall}

Target-world (existing-world with {N} counterfactuals applied and {M}
prescriptive obligations asserted) still contains a counterexample because:
{explanation}

Please re-run decompose-proposition to:
1. Confirm the counterexample is real (not an existing-world error)
2. Decide whether the property needs additional counterfactual or prescriptive
   claims to reach consistency
3. Emit a revised hypothesis.pl that excludes the counterexample
```

### 7. Produce model_results.pl

The final artifact is `thoughts/model_results.pl` — a Prolog facts file (not
markdown). Emit against the schema in
`${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/model-results.md`.
Downstream skills query it directly with `swipl` rather than parsing prose.

## Verification

Never declare a verdict `consistent` if the verdict directive hasn't run
cleanly (no Prolog errors, no `inconsistent` output). Low coverage (<30%) means
target-world lacks the facts to decide the property — record as `gap`, not
silently as `consistent`. Gap verdicts are intentional and feed back into
`decompose-proposition` so the next iteration adds the missing prescriptive obligations.

- **CWA-absent ≠ Lean-disproved** (`cwa_negation_neq_lean_proof`). A
  `negation_provenance(_, absent)` marker means the fact is missing from
  target-world by closed-world default — Lean cannot lift this to a structural
  disproof. Only `negation_provenance(_, contradicts)` carries that strength.
  This distinction is preserved in target-world for Lean to read.
- **Universal proof ≠ test verification** (`lean_universal_neq_test_verified`).
  A `consistent` verdict is structural consistency in this finite model only.
  It does not establish the universal claim Lean proves.
- **Behavioral claim ≠ proven property**
  (`behavioral_claim_neq_proven_property`). Verdicts here track structural
  consistency only — runtime behavior is the test suite's job.

## Output

All artifacts are written to `thoughts/` (create it if it doesn't exist):

- `thoughts/target-world.pl` — the constructed substrate KB. Existing-world
  with counterfactual negations applied and prescriptive obligations asserted.
  Each fact carries an ontology label. **Primary deliverable** — Lean proves
  against this.
- `thoughts/target-world-shape.lean` — the structural translation
  `prove-invariants` consumes directly. Inductive enums for closed Prolog
  domains, inductive `Prop` predicates with one constructor per ground fact,
  and parallel CF-augmented predicates for each counterfactual. Imports
  `Ontology.Prelude`. Omitted (with a note in `model_results.pl`) when the
  ticket has no closed-domain predicates.
- `thoughts/model_results.pl` — per-property `verdict/2`, `counterexample/2`,
  `gap_reason/2`, and `cf_status/2` facts plus summary counts. **Primary
  deliverable** — downstream skills query it directly.
- If any verdicts are `inconsistent` or `gap`: a request to re-run
  `decompose-proposition`.
- Gap verdicts feed directly into `instantiate-properties` as pre-failing test
  cases.

Both files are designed to be re-run at any time against an updated
existing-world. If the underlying KB changes, re-running this skill shows
immediately which verdicts still hold.

## Configuration

- **Inner corrections per property**: 5
- **Outer iterations (fresh approach)**: 3
- **Max properties per hypothesis**: no limit
- **Role**: model-obligations (constructs target-world.pl as the substrate that
  `prove-invariants` proves over). Runs *before* `prove-invariants`
  in the pipeline, not as an alternative to it.
