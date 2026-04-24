---
name: measure-adherance
description: >
  Pipeline stage 7 of 7 — the final adherence check. Extracts claims from each input resource as Prolog facts, then scores overlap, gaps, contradictions, and extensions. Runs in two valid framings: (1) terminal pipeline step, scoring how well the implemented codebase entails the original proposition encoded in `thoughts/hypothesis.pl`; and (2) stand-alone, comparing two or more arbitrary resources with an optional `--prime` source-of-truth. Emits an intermediate `thoughts/adherence_facts.pl` and the human-reviewed `thoughts/adherence_report.md`.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write, Agent
argument-hint: "[resource1] [resource2] [...] [--prime resource1]"
---

# Measure Adherance

**Pipeline stage 7 of 7.** This is the final adherence check: it scores how much the pipeline's output entails the original proposition. Note the (intentional) misspelling — the target KB uses "adherance" consistently and this skill keeps it.

Compare two or more resources and score how well they agree. The core idea is simple: extract what each resource *claims* as structured Prolog facts, then query for what's shared, what's missing, and what contradicts. The result is a scored adherence report grounded in explicit evidence.

The word "resource" is broad on purpose — specs, implementation docs, code files, configs, READMEs, test plans, data models. Anything with extractable claims.

## Logical operation: `measure_entailment`

This skill realizes *measure_entailment* — scoring how much one KB (or codebase) entails the claims of another. Both framings below are valid uses:

- **Terminal pipeline step (the canonical flow)** — when run after `translate-to-implementation`, this skill scores how much the implemented system (source files + `thoughts/implementation_log.md`) entails the original proposition. Prior pipeline runs leave behind a chain of artifacts: `thoughts/existing-world.pl`, `thoughts/hypothesis.pl`, `thoughts/target-world.pl`, `thoughts/model_results.pl`, `thoughts/lean_proof_results.pl`, `thoughts/tests/...`, and `thoughts/implementation_log.md`. This skill closes the loop by checking the resulting world (the implemented codebase) against the asserted hypothesis, with `thoughts/hypothesis.pl` as the prime.
- **Stand-alone mode** — designate any resource as "prime" via `--prime` and grade other resources against it. Useful for spec-vs-implementation grading, doc-vs-code drift checks, or any ad-hoc adherence question. Prime designation is optional: with no prime, scoring is symmetric.

Upstream pipeline artifacts use a shared epistemic vocabulary — `epistemic_label(descriptive|counterfactual|prescriptive)` and `negation_provenance(absent|contradicts)`. The adherence pass reads these directly as Prolog facts and produces a per-label / per-provenance breakdown in the report.

## Inputs, outputs, and required tools

- **Primary input**: `source_files` — the codebase under review (in pipeline-terminal mode) or the resource files supplied directly (stand-alone).
- **Also consumes**: `thoughts/implementation_log.md` (when present from `translate-to-implementation`), `thoughts/adherence_facts.pl` (regenerated each run; prior copies are overwritten).
- **Required environment**: `resource_paths` (2 or more), and optionally `prime_designation` to nominate one as source-of-truth.
- **Required tools**: `swipl`.
- **Intermediate output**: `thoughts/adherence_facts.pl` — extracted claims from every resource, in `asserts/2` form.
- **Primary output**: `thoughts/adherence_report.md` — human-reviewed Markdown report with scores, gaps, contradictions, and extensions.

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

When run as the last step of the logic-focused pipeline (after `translate-to-implementation`):

- **Source files** — the implemented codebase under review
- **`thoughts/implementation_log.md`** — produced by `translate-to-implementation`, narrating what was actually built
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

Spawn the `logic-focused:agent-of-truth` sub-agent with the `Agent` tool to do the extraction. Skip delegation only when the user has explicitly asked you to extract inline this turn — resource size is not a reason. It will choose consistent, domain-appropriate predicates and validate the resulting facts file with `swipl`. Brief it with all resource paths at once so it picks predicate names that line up across resources — inconsistent predicate naming is the single biggest cause of false "gap" and "contradiction" results in this skill.

### 4. Run Adherence Queries

#### Delegate the queries to `agent-of-questions`

Prefer spawning the `logic-focused:agent-of-questions` sub-agent with the `Agent` tool to run the adherence queries. It will introspect `thoughts/adherence_facts.pl`, invoke `adherence_report/1`, `symmetric_report/0`, `find_contradictions/1`, and `universal_claim/1`, and return structured findings. Hand it the facts file path, the list of resource IDs, and the prime designation (or "none") and ask it to produce the inputs needed for §5 scoring.


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

**Supplementary queries** — run these to deepen the analysis:

```bash
# What facts are shared across ALL resources?
swipl -g "
  use_module('${PROLOG}/adherence'),
  consult('thoughts/adherence_facts.pl'),
  findall(C, universal_claim(C), Cs),
  length(Cs, N),
  format('Universal claims (~w): ~n', [N]),
  forall(member(C, Cs), format('  ~q~n', [C]))
" -t halt

# What contradictions exist?
swipl -g "
  use_module('${PROLOG}/adherence'),
  consult('thoughts/adherence_facts.pl'),
  find_contradictions(Contradictions),
  length(Contradictions, N),
  format('Contradictions (~w):~n', [N]),
  forall(member(C, Contradictions), format('  ~q~n', [C]))
" -t halt
```

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

In **pipeline-terminal mode**, the report must explicitly call out:

- **Per-claim adherence** — for each `claim/2` in `thoughts/hypothesis.pl`, how well does the implementation realize it? Score and cite evidence per claim.
- **Counterfactual claims** — claims tagged `epistemic_label(..., counterfactual)` should be *absent* in the implementation. Verify each one and flag any that still appear.
- **Prescriptive claims** — claims tagged `epistemic_label(..., prescriptive)` should now be *provable* in the implementation. Verify their evidence and link back to source files / tests / proof artifacts.
- **Per-label and per-provenance breakdown** — group results by `epistemic_label(descriptive|counterfactual|prescriptive)` and `negation_provenance(absent|contradicts)` so reviewers see at a glance which categories are healthy and which have drift.

Write to `thoughts/adherence_report.md`:

```markdown
# Adherence Report

**Date:** {date}
**Mode:** Prime-relative (prime: {resource}) | Symmetric

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
{2-3 sentences interpreting the scores: what the gaps mean, whether contradictions
are critical, whether extensions are concerning or benign}

## Prolog Evidence
- Facts file: `thoughts/adherence_facts.pl`
- Prime: {resource or "none"}
- Claims per resource: {counts}
- Queries run: adherence_report, find_contradictions, universal_claim
```

### 7. Report to the User

Tell the user:
- The adherence score(s)
- How many gaps and contradictions were found
- Whether the extensions are notable
- Path to the report
- One-sentence interpretation: e.g., "impl covers 87.5% of the spec, with 1 direct contradiction on response format that should be resolved."

### Hand off for human review

`thoughts/adherence_report.md` is a `reviewed_by(_, human_review)` artifact in the target KB — it is the terminal pipeline output a human reads to decide whether the implementation entails the original proposition. Surface at the top of the report: (a) any contradictions found, (b) all `claim_label(_, counterfactual)` claims that still appear in the implementation, (c) any prescriptive claims missing evidence. These three categories are what a reviewer needs to see first.

---

## References

The plugin ships a SWI-Prolog wiki at `${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/` covering tabling, DCGs, CLP, modules, and more. **Don't read it yourself** — wiki content flows through `agent-of-truth` and `agent-of-questions`, which both have direct access. Include the absolute wiki path in each agent's briefing and let them consult the wiki when the claim extraction or queries need an advanced extension.

## Prolog Reference

### adherence.pl predicates

Bundled at `${CLAUDE_SKILL_DIR}/prolog/adherence.pl`.

| Predicate | What it does |
|-----------|-------------|
| `all_resources(-Rs)` | List all distinct resource IDs in the facts file |
| `total_claims(+R, -N)` | Count total claims for resource R |
| `shared_claims(+R1, +R2, -Claims)` | Claims present in both R1 and R2 |
| `gap_claims(+Prime, +Other, -Claims)` | Claims in Prime missing from Other |
| `extension_claims(+Prime, +Other, -Claims)` | Claims in Other not in Prime |
| `find_contradictions(-Pairs)` | Find pairs of conflicting claims across resources |
| `adherence_score(+Other, +Prime, -Score)` | 0.0–1.0 prime-relative adherence |
| `jaccard_score(+R1, +R2, -Score)` | 0.0–1.0 symmetric Jaccard similarity |
| `adherence_report(+Prime)` | Print full prime-relative report to stdout |
| `symmetric_report` | Print pairwise symmetric report to stdout |
| `universal_claim(-Claim)` | Claims present across all resources |

### Ad-hoc query patterns

```prolog
% What does only resource A assert (not B or C)?
findall(C, (asserts(a, C), \+ asserts(b, C), \+ asserts(c, C)), Unique)

% How many claims does each resource make?
forall(
  (all_resources(Rs), member(R, Rs)),
  (total_claims(R, N), format('~w: ~w claims~n', [R, N]))
)

% Find all values for a given predicate across resources
findall(R-V, asserts(R, has_property(key_name, V)), Pairs)
```
