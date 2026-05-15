---
name: measure-entailment
description: >
  Pipeline stage 7 of 7 — the final adherence check. Extracts claims from each input resource as Prolog facts, then scores overlap, gaps, contradictions, and extensions. In pipeline-terminal mode also loads `thoughts/hypothesis.pl` directly and runs label-aware verdicts: Pattern 3 detection (counterfactual claims whose forbidden fact is still present in the implementation), prescriptive fulfillment (required facts present), and prescriptive negation violations. Runs in two valid framings: (1) terminal pipeline step, scoring how well the implemented codebase entails the original proposition encoded in `thoughts/hypothesis.pl`; and (2) stand-alone, comparing two or more arbitrary resources with an optional `--prime` source-of-truth. Emits an intermediate `thoughts/adherence_facts.pl` and the human-reviewed `thoughts/adherence_report.md`.
user-invocable: true
context: fork
agent: general-purpose
allowed-tools: Bash, Read, Glob, Grep, Write, Agent
argument-hint: "[resource1] [resource2] [...] [--prime resource1]"
---

# measure-entailment

**Pipeline stage 7 of 7.** This is the final adherence check: it scores how much the pipeline's output entails the original proposition. Note the (intentional) misspelling — the target KB uses "adherance" consistently and this skill keeps it.

Compare two or more resources and score how well they agree. The core idea is simple: extract what each resource *claims* as structured Prolog facts, then query for what's shared, what's missing, and what contradicts. The result is a scored adherence report grounded in explicit evidence.

The word "resource" is broad on purpose — specs, implementation docs, code files, configs, READMEs, test plans, data models. Anything with extractable claims.

## Logical operation: `measure-entailment`

This skill realizes *measure-entailment* — scoring how much one KB (or codebase) entails the claims of another. Both framings below are valid uses:

- **Terminal pipeline step (the canonical flow)** — when run after `realize-specification`, this skill scores how much the implemented system (source files + `thoughts/implementation_log.md`) entails the original proposition. Prior pipeline runs leave behind a chain of artifacts: `thoughts/existing-world.pl`, `thoughts/hypothesis.pl`, `thoughts/target-world.pl`, `thoughts/model_results.pl`, `thoughts/lean_proof_results.pl`, `thoughts/tests/...`, and `thoughts/implementation_log.md`. This skill closes the loop by checking the resulting world (the implemented codebase) against the asserted hypothesis, with `thoughts/hypothesis.pl` as the prime.
- **Stand-alone mode** — designate any resource as "prime" via `--prime` and grade other resources against it. Useful for spec-vs-implementation grading, doc-vs-code drift checks, or any ad-hoc adherence question. Prime designation is optional: with no prime, scoring is symmetric.

Upstream pipeline artifacts use a shared ontology vocabulary — `claim_label(descriptive|counterfactual|prescriptive)` and `claim_negation_provenance(absent|contradicts)`. In pipeline-terminal mode this skill consults `thoughts/hypothesis.pl` *directly* alongside the extracted `adherence_facts.pl` so the label predicates are visible to the swipl session. The label-aware verdict pass then produces:

- **Counterfactual verdict** — for each `claim_label(_, counterfactual)` claim, whether its `claim_premise/2` fact is correctly absent (honored) or still asserted in the implementation (Pattern 3 violation, the named failure mode from `philosophy/cwa-owa-tension.md`).
- **Prescriptive verdict** — for each `claim_label(_, prescriptive)` claim, whether its required positive premise is present (fulfilled) or missing (unfulfilled), and whether any negated premise is still present (a Pattern-3-shaped violation on the prescriptive side).
- **Descriptive verdict** — descriptive claims have no fact-level encoding in `hypothesis.pl`; drift is surfaced when `existing-world.pl` is supplied as a separate resource so we can compare its facts against the impl extraction.

Pattern 3 detection is the headline addition: without label awareness, a counterfactual fact still present in impl looks like a benign "extension" of impl over the prime. With label awareness it is named, traced to its claim id, and surfaced at the top of the report.

## Inputs, outputs, and required tools

**Carrier-only contract (pipeline-terminal mode).** The sole carrier from the predecessor (`realize-specification`) is `thoughts/implementation_log.md` plus the `target_codebase_dir` env. `thoughts/hypothesis.pl` is loaded *directly* into the swipl session — not via a transitive carrier reference — because the label-aware verdict pass needs `claim_label/2` and `claim_negation_provenance/3` queryable in the same module; this is a documented exception to the carrier-only rule (`measure_entailment_hypothesis_direct_load` per the orchestration-substrate doc's narrowing).

- **Carrier**: `thoughts/implementation_log.md` (from `realize-specification`) + `target_codebase_dir` env. The codebase is read for claim extraction.
- **Direct-load exception**: `thoughts/hypothesis.pl` — loaded into swipl alongside `adherence_facts.pl` to enable label-aware verdicts.
- **Optional in stand-alone mode**: resource paths supplied directly, `--prime` designation.
- **Optional supplementary** (pipeline-terminal): `thoughts/existing-world.pl` for descriptive-drift checks.
- **Required tools**: `swipl`.
- **Intermediate output**: `thoughts/adherence_facts.pl` — extracted claims from every resource, in `asserts/2` form.
- **Primary output**: `thoughts/adherence_report.md` — human-reviewed Markdown report with scores, gaps, contradictions, extensions, and per-label verdicts.

## Orchestrator contract

Stage 6, terminal. Orchestration-substrate wire format: `plugins/trajectory/references/orchestration-substrate.md`.

**Orchestrator parameters accepted:** `success_criteria` (e.g., "zero Pattern 3 violations; ≥80% adherence to hypothesis prime"); `halt_condition`. No `refutation_shape_briefing` — the report itself enumerates the refutation surfaces inline.

**Gate-target descriptors emitted on completion** — two outputs:
- `adherence_facts_pl` — the extracted-claim Prolog file. Primary refutation surface: any `asserts/2` row whose predicate doesn't match a known domain shape (the agent may have over-extracted).
- `adherence_report_md` — the verdict narrative. Refutation surface: every Pattern 3 violation row (counterfactual fact still asserted in impl) is by construction what `disprove-proposition` would attack if invoked against the implementation.

**Upstream gap emission** — none. As the terminal pipeline stage, measure-entailment surfaces gaps *as adherence-report verdicts*, not as `upstream_gap/3` facts. A non-zero Pattern-3-violation count is the human-readable equivalent of an upstream gap, but routing the recovery is the orchestrator's call based on the report, not on a structured signal from this skill.

**Adjacent loopback target:** none (terminal). The orchestrator may, on reviewing the report, decide to drive any upstream stage's re-invocation with `success_criteria` derived from the report's verdict list.

## Current Environment

`which swipl` returns: !`which swipl`
`ls thoughts/hypothesis.pl` returns: !`ls thoughts/hypothesis.pl 2>/dev/null || echo "(not yet created)"`

```
PROLOG="${CLAUDE_SKILL_DIR}/prolog"
```

## Input

### Stand-alone mode

- **Two or more resource paths** — files to compare
- **Optional: `--prime` designation** — the resource that other resources are graded against
- If no prime is designated, ask the user: *"Should one of these be the source of truth (prime)? If so, which one? If not, I'll measure mutual adherence between them."*
  - If the user says no prime: proceed with symmetric measurement
  - If the user designates one: treat it as prime for all scoring

### Pipeline-terminal mode

When run as the last step of the orbital-shifting pipeline (after `realize-specification`):

- **Source files** — the implemented codebase under review
- **`thoughts/implementation_log.md`** — produced by `realize-specification`, narrating what was actually built
- **`thoughts/hypothesis.pl`** — the prime; the implementation is graded against the `claim/2` (and related) facts here
- **Optionally, the upstream artifacts** — pulled in to enrich the report:
  - `thoughts/existing-world.pl` — the pre-implementation world
  - `thoughts/target-world.pl` — the world the hypothesis described
  - `thoughts/lean_proof_results.pl` — Lean-side proof outcomes
  - `thoughts/model_results.pl` — Prolog-side model verification outcomes

## Process

### 1. Understand Each Resource

Read each resource completely. For code files, use Grep/Glob to explore the full picture. For each resource, identify:
- What domain it covers
- What kinds of claims it makes (behavioral, structural, configurational, definitional)
- Its granularity level (high-level spec vs low-level implementation detail)

The goal is to understand what each resource *asserts* — what it says is true.

### 2. Extract Claims as Prolog Facts

For each resource, extract its claims as structured Prolog facts wrapped in `asserts/2`:

```prolog
% Format: asserts(resource_id, claim_term).
asserts(spec, has_endpoint('/login', post)).
asserts(spec, requires_auth('/admin', true)).
asserts(spec, returns_format('/api/v1', json)).

asserts(impl, has_endpoint('/login', post)).
asserts(impl, has_endpoint('/logout', post)).  % extension
asserts(impl, requires_auth('/admin', true)).
asserts(impl, returns_format('/api/v1', xml)).  % contradiction!
```

**Choosing predicates:**
- Let the domain guide predicate names — `has_endpoint`, `requires_auth`, `defines_type`, `depends_on`, `configures`, `exports`, `validates`
- Use the same predicates across all resources — this is how overlap is detected
- Be specific: `has_property(auth_required, true)` beats `mentions(auth)` 
- One claim per fact: don't bundle multiple assertions into one term
- Ground terms only: no variables in the facts file

**Handling different resource types:**
- *Spec/requirements*: extract stated behaviors, constraints, interface definitions
- *Implementation docs*: extract what's described as being built or done
- *Code files*: extract exported interfaces, declared dependencies, type definitions
- *Config files*: extract key-value settings, enabled features, environment assumptions
- *Test plans*: extract what behaviors are verified, edge cases listed

Write all facts to `thoughts/adherence_facts.pl`:

```prolog
% ---- Resource: spec (path/to/spec.md) ----
asserts(spec, ...).
asserts(spec, ...).

% ---- Resource: impl (path/to/impl.md) ----
asserts(impl, ...).
asserts(impl, ...).
```

Use short, readable IDs for resource names (e.g., `spec`, `impl`, `design`, `tests`, `config_a`).

### 3. Validate the Facts File

```bash
swipl -g "halt" -t halt thoughts/adherence_facts.pl
```

Fix any syntax errors before proceeding.

#### Delegate claim extraction to `agent-of-truth`

Spawn the `shifting:agent-of-truth` sub-agent with the `Agent` tool to do the extraction. Skip delegation only when the user has explicitly asked you to extract inline this turn — resource size is not a reason. It will choose consistent, domain-appropriate predicates and validate the resulting facts file with `swipl`. Brief it with all resource paths at once so it picks predicate names that line up across resources — inconsistent predicate naming is the single biggest cause of false "gap" and "contradiction" results in this skill.

#### Bias-isolation discipline

Specialist delegation isolates claim extraction and verdict computation from orchestrator bias. The orchestrator's hopes about whether the implementation adheres MUST NOT reach the specialist; measure-entailment has no checker for under-extraction (claims silently missing make adherence look spuriously high) or for over-aligned predicate naming (forcing a spec claim and impl claim to share a predicate when they shouldn't).

**Apply both defenses on every agent-of-truth / agent-of-questions invocation:**

1. **Role-briefing.** Open every specialist prompt with:
   > "You are extracting what each resource asserts. Use the same predicate name across resources only when the claims are structurally the same; do not paper over differences by collapsing distinct claims into one predicate. Report `asserts/2` rows as facts; a low adherence score is a valid result. The orchestrator has no preferred score."

2. **Minimum-necessary context.** Send only the resource paths, the prime designation, the orchestrator-supplied `success_criteria` if present, and (in pipeline-terminal mode) the path to `hypothesis.pl` for cross-vocabulary alignment. Do not paste orchestrator commentary or framing of why this adherence check matters.

**Orchestrator responsibilities (never delegated):** decide `--prime` per run, validate the report's structural-vs-verdict ordering before recording, own the success_criteria interpretation.

### 4. Run Adherence Queries

#### Delegate the queries to `agent-of-questions`

Prefer spawning the `shifting:agent-of-questions` sub-agent with the `Agent` tool to run the adherence queries. It will introspect `thoughts/adherence_facts.pl`, invoke `adherence_report/1`, `symmetric_report/0`, `find_contradictions/1`, and `universal_claim/1`, and return structured findings. Hand it the facts file path, the list of resource IDs, and the prime designation (or "none") and ask it to produce the inputs needed for §5 scoring.

In **pipeline-terminal mode**, also brief the agent on the label-aware verdict pass: it should consult `thoughts/hypothesis.pl` into the same swipl session and call `label_aware_report/ImplResource` plus `label_aware_facts_out/2`. The agent should report the counts (counterfactual_violations, counterfactual_honored, prescriptive_unfulfilled, prescriptive_fulfilled, prescriptive_negation_violations) and the full lists of any non-empty violation/unfulfilled categories — those are what the report's "Headline Verdicts" section needs.


Load the bundled adherence module and run the standard queries:

```bash
swipl -g "
  use_module('${PROLOG}/adherence'),
  consult('thoughts/adherence_facts.pl'),
  all_resources(Rs),
  format('Resources: ~w~n', [Rs])
" -t halt
```

**If prime is designated (e.g., `spec`):**

```bash
swipl -g "
  use_module('${PROLOG}/adherence'),
  consult('thoughts/adherence_facts.pl'),
  adherence_report(spec)
" -t halt
```

**If no prime (symmetric):**

```bash
swipl -g "
  use_module('${PROLOG}/adherence'),
  consult('thoughts/adherence_facts.pl'),
  symmetric_report
" -t halt
```

**Supplementary queries** — deepen the analysis with the universal-claim and contradiction tuples. For these named-fact projections (the predicates and arities are already known — `universal_claim/1`, `find_contradictions/1` — exported by the `adherence` module), delegate to the `shifting:pl-fact-extractor` sub-agent instead of writing inline `swipl` boilerplate. The agent returns a JSON digest of fact tuples and counts; the skill consumes the digest, not raw stdout.

**Briefing fields for `pl-fact-extractor`:**

| Field | Source |
|---|---|
| `pl_paths` | `[thoughts/adherence_facts.pl]` (the agent must also pre-load the `${PROLOG}/adherence` module — pass the absolute path in the briefing prose so the agent's `consult` call sees `universal_claim/1` and `find_contradictions/1`) |
| `fact_spec` | `universal_claim/1`, `find_contradictions/1` |
| `output_format` | `json` |

The full agent contract — hard rules, missing-predicate semantics, digest schema — lives at `../../agents/pl-fact-extractor.md`.

#### Label-aware verdicts (pipeline-terminal mode only)

When `thoughts/hypothesis.pl` exists, also consult it into the same swipl session and run the per-label verdict queries. This is what turns generic "extension" findings into specific Pattern 3 verdicts. Skip this block in stand-alone mode — without `hypothesis.pl` there is nothing to label-verdict against.

Use `use_module(..., except([claim/2, claim/3]))` for the label-aware load. The adherence module exports `claim/2` (resource-claim semantics) and `hypothesis.pl` defines `claim/2` (natural-language claim) — they are different predicates that share a name. The `except` clause keeps the adherence version internal to its module so the user-module load of `hypothesis.pl` doesn't trigger a `Local definition of user:claim/2 overrides weak import` warning. The internal calls inside `label_aware_report/1` still resolve to `adherence:claim/2` correctly.

```bash
# Pattern 3 detection + prescriptive fulfillment.
# Pass the impl resource id (e.g. `impl`) as the arg to label_aware_report/1.
swipl -g "
  use_module('${PROLOG}/adherence', except([claim/2, claim/3])),
  consult('thoughts/adherence_facts.pl'),
  consult('thoughts/hypothesis.pl'),
  label_aware_report(impl)
" -t halt

# Append the verdicts to adherence_facts.pl as machine-readable result/N
# facts. Used by the report writer in §6 and by callers that want to fail
# the pipeline on any Pattern 3 violation.
swipl -g "
  use_module('${PROLOG}/adherence', except([claim/2, claim/3])),
  consult('thoughts/adherence_facts.pl'),
  consult('thoughts/hypothesis.pl'),
  open('thoughts/adherence_facts.pl', append, S),
  label_aware_facts_out(impl, S),
  close(S)
" -t halt
```

If `existing-world.pl` is also present and you want descriptive-drift detection, add `consult('thoughts/existing-world.pl')` and call `descriptive_drift(impl, existing, Lost)`. The "existing" resource id must match whatever you used in `adherence_facts.pl` — typically the agent-of-truth picks a short tag like `existing` for the existing-world facts.

### 5. Score Adherence

**Prime-relative scoring** — for each non-prime resource:
```
adherence_score = |shared claims with prime| / |total claims in prime| × 100%
```

**Symmetric scoring** — between each pair:
```
jaccard_score = |shared claims| / |union of claims| × 100%
```

Record:
- Total claims per resource
- Shared claims (with prime, or pairwise)
- Gaps: claims in prime not in this resource
- Contradictions: claims that conflict
- Extensions: claims in this resource not in prime
- Adherence score

### 6. Write the Report

In **pipeline-terminal mode**, the report has a fixed top-of-document section dedicated to the label-aware verdicts. The structural parts (scores, gaps, contradictions, extensions) come after. The reasoning: a Pattern 3 violation is more important than a 90% Jaccard score; reviewers should see the named obligation breaches before the aggregate stats.

Pull the verdict numbers directly from the result/N facts that `label_aware_facts_out/2` appended to `adherence_facts.pl` (or re-query the predicates by hand). For each `result(counterfactual_violation, _, ClaimId, Fact, Provenance)` row, look up the corresponding `claim/2` natural-language string from hypothesis.pl so the report cites the human-readable claim alongside the structural evidence.

Write to `thoughts/adherence_report.md`:

```markdown
# Adherence Report

**Date:** {date}
**Mode:** Prime-relative (prime: {resource}) | Symmetric
**Hypothesis loaded:** yes | no   <!-- "no" means Per-Label Verdicts section is skipped -->

## Headline Verdicts

<!-- Pipeline-terminal mode only. Drop this whole section in stand-alone mode. -->

| Verdict | Count | Status |
|---------|-------|--------|
| Counterfactual claims honored | {HN} / {Total_CF} | {green check / partial / red X} |
| Counterfactual violations (Pattern 3) | {VN} | {0 = clean; >0 = blocking} |
| Prescriptive fulfilled | {FN} / {Total_PR_pos} | {green / partial / red} |
| Prescriptive unfulfilled | {UN} | {0 = clean; >0 = blocking} |
| Prescriptive negation violations | {NVN} | {0 = clean; >0 = blocking} |

If any row in the "blocking" column is non-zero, surface it in the next subsection before the structural scores. A reviewer should see broken obligations before they see Jaccard percentages.

Verdict-row item formats — Pattern 3, prescriptive unfulfilled, prescriptive negation violations, descriptive drift — live in **`references/adherence-verdicts.md`**. Render each non-zero row using its template; render "skipped — no existing-world resource" for descriptive drift when existing-world.pl was not supplied.

## Resources
| ID | Path | Claims |
|----|------|--------|
| spec | path/to/spec.md | 16 |
| impl | path/to/impl.md | 19 |

## Adherence Scores
| Resource | Score | Shared | Gaps | Contradictions | Extensions |
|----------|-------|--------|------|----------------|------------|
| impl | 87.5% | 14/16 | 2 | 1 | 5 |

## Shared Facts
Claims present in all compared resources:
- `has_endpoint('/login', post)`
- `requires_auth('/admin', true)`
...

## Gaps
Claims in the prime that are absent from each resource:

### impl
- `has_endpoint('/health', get)` — not present in impl
- `rate_limits('/api/v1', 100_per_min)` — not present in impl

## Contradictions
Claims that directly conflict:
- **returns_format('/api/v1', ?)**: spec says `json`, impl says `xml`

## Extensions
Claims in each resource not found in the prime:

### impl
- `has_endpoint('/logout', post)` — additional endpoint
- `logs_to(stdout)` — implementation detail not in spec

## Analysis
{2-3 sentences interpreting the scores together with the headline verdicts:
what the gaps mean, whether contradictions are critical, whether any
Pattern 3 violations turn an apparently-high score into a misleading one.}

## Prolog Evidence
- Facts file: `thoughts/adherence_facts.pl`
- Hypothesis file: `thoughts/hypothesis.pl` (or "not loaded" in stand-alone mode)
- Prime: {resource or "none"}
- Claims per resource: {counts}
- Queries run: adherence_report, find_contradictions, universal_claim, label_aware_report
```

### 7. Report to the User

Tell the user:
- The adherence score(s)
- How many gaps and contradictions were found
- Whether the extensions are notable
- Path to the report
- One-sentence interpretation: e.g., "impl covers 87.5% of the spec, with 1 direct contradiction on response format that should be resolved."

### Hand off for human review

`thoughts/adherence_report.md` is a `reviewed_by(_, human_review)` artifact in the target KB — the terminal pipeline output a human reads to decide whether the implementation entails the original proposition. The Headline Verdicts ordering (Pattern 3 → prescriptive unfulfilled / negation violations → contradictions → descriptive drift) is documented in `references/adherence-verdicts.md`; if a run finds zero violations across all four categories, say so explicitly — absence of bad news is itself a verdict.

---

## References

The plugin ships a SWI-Prolog wiki at `${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/` covering tabling, DCGs, CLP, modules, and more. **Don't read it yourself** — wiki content flows through `agent-of-truth` and `agent-of-questions`, which both have direct access. Include the absolute wiki path in each agent's briefing and let them consult the wiki when the claim extraction or queries need an advanced extension.

## Prolog Reference

The full `adherence.pl` predicate catalogue (structural and label-aware) plus ad-hoc query patterns lives in **`references/adherence-queries.md`**. The structural family (`all_resources/1`, `shared_claims/3`, `gap_claims/3`, `extension_claims/3`, `find_contradictions/1`, `adherence_score/3`, `jaccard_score/3`, `adherence_report/1`, `universal_claim/1`) operates resource-vs-resource. The label-aware family (`hypothesis_loaded/0`, `counterfactual_violations/2`, `counterfactual_honored/2`, `prescriptive_unfulfilled/2`, `prescriptive_fulfilled/2`, `prescriptive_negation_violations/2`, `descriptive_drift/3`, `label_aware_report/1`, `label_aware_facts_out/2`) consumes `thoughts/hypothesis.pl` and powers the Headline Verdicts.
