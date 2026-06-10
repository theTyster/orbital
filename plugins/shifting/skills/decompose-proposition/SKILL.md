---
name: decompose-proposition
description: >
  Stage 2 of `trajectory:pipeline` (the seven-stage pipeline). Reads `thoughts/existing-world.pl` and a proposition, then explores the proposition through a counterfactual lens — which existing-world facts would need to be false, and which new facts would need to become provable, for the proposition to hold. Emits `thoughts/hypothesis.pl`: labeled claims (descriptive / counterfactual / prescriptive), query evidence, and formal-property sketches. The canonical entry point is `trajectory:pipeline`, which dispatches here when stage 2 is in scope. Invoke this skill directly only to refine a hypothesis against an existing KB without running model-obligations or later stages — e.g., "re-decompose this proposition against the existing KB", "rebuild hypothesis.pl from this new proposition".
user-invocable: true
agent: general-purpose
model: opus
effort: high
allowed-tools: Bash, Write, Agent
argument-hint: "[existing-world.pl path] [proposition or question to explore]"
---

- **Setup marker:** !`CHECK="${CLAUDE_PLUGIN_ROOT}/../scaffolding/skills/setup/scripts/check-setup.sh"; [ -x "$CHECK" ] && "$CHECK" --summary || echo "orbital: scaffolding plugin not installed; setup state unknown"`

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

Setup marker: !`CHECK="${CLAUDE_PLUGIN_ROOT}/../scaffolding/skills/setup/scripts/check-setup.sh"; [ -x "$CHECK" ] && "$CHECK" --summary || echo "orbital: scaffolding plugin not installed; setup state unknown"`
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

Before touching Prolog, the proposition must be one sentence that is **falsifiable, scoped, and contestable** against the KB's vocabulary. Delegate this sharpening pass to `shifting:proposition-sharpener` — that agent isolates the falsifiability check from orchestrator bias, returns either a sharpened sentence or an abstention naming what the user must clarify, and refuses to invent KB predicates to make the proposition "work."

Briefing fields for the agent:

- `raw_proposition_text` — the user's proposition verbatim. Do not paraphrase before delegation.
- `existing_world_path` — the KB path from this skill's input.
- `prolog_introspect_path` — `${CLAUDE_SKILL_DIR}/../../prolog/introspect`.

Handle the two return shapes:

- **`outcome: "sharpened"`** — record the `sentence` as the pinned proposition. If `note` reports "KB already entails this," the proposition is a trivial invariant; surface that to the user and stop, or proceed only if the user explicitly asks for the descriptive write-up.
- **`outcome: "abstained"`** — surface `reason` and `what_user_should_clarify` to the user and stop. Do not guess a sharpening to keep the skill moving; the agent already considered and rejected every reading that exceeded the evidence.

Once the pinned sentence is in hand, immediately restate it as a counterfactual question against the KB:

> **What about the existing KB would need to be false for this proposition to be true?**

This is the question the rest of the skill answers. If the agent's `note` flagged trivial entailment, report the proposition as a descriptive invariant rather than continuing. The interesting hypotheses are ones where the KB contains facts that stand in the way.

### 2. Delegate claim synthesis to `hypothesis-decomposer`

With the pinned proposition in hand, delegate the full claim-synthesis pass — counterfactual decomposition into sub-hypotheses, evidence gathering via `agent-of-questions`, ontology-label and negation-provenance assignment, `formal_property/3` sketches, schema-validated emission of `thoughts/hypothesis.pl` — to `shifting:hypothesis-decomposer` via the `Agent` tool. That agent is the claim-synthesis specialist on opus/high effort: it owns the halt-on-ambiguity discipline (refusing to label a claim two ways, refusing to split silently, refusing to invent predicates the KB does not enumerate), validates the file against the canonical schema before exit, and returns a fixed-shape digest the skill consumes for the user-facing report. The orchestrator-level bias-isolation discipline (role-briefing + minimum-necessary context) lives inside the agent body; the skill's job is to assemble a clean briefing and consume the digest.

**Briefing fields for `hypothesis-decomposer`:**

| Field | Source |
|---|---|
| `sharpened_proposition` | The pinned sentence from §1's `proposition-sharpener` return. Verbatim. |
| `existing_world_pl_path` | The KB path from this skill's input. |
| `output_path` | `thoughts/hypothesis.pl` (or the orchestrator-overridden path). |
| `schema_reference_path` | `${CLAUDE_SKILL_DIR}/../../references/pipeline-schema/hypothesis.md` |
| `ontology_reference_path` | `${CLAUDE_SKILL_DIR}/../../references/ontology.md` |
| `prolog_introspect_path` | `${CLAUDE_SKILL_DIR}/../../prolog/introspect` |
| `refutation_shape_briefing` | The orchestrator-supplied value if present (per the orchestrator-contract section above); otherwise omit. |
| `artifact_versioning` | The orchestrator-supplied namespace suffix if present; otherwise omit. |

Drop to inline synthesis only when the user has explicitly asked you to do the decomposition yourself in this turn. KB size is not a reason; claim count is not a reason. When in doubt, delegate — the agent's halt-on-ambiguity discipline cannot run inside the orchestrator's context.

Handle the two digest shapes:

- **`outcome: "emitted"`** — the agent wrote a validated `hypothesis.pl` at `output_path`. Read off `claim_count`, `label_counts`, `status_counts`, `provenance_counts`, `formal_property_count`, `coverage_percentage`, `open_assumptions` for the user-facing report (§3 below).
- **`outcome: "halted"`** — the agent emitted no file. Surface `halt_reason`, `halt_detail`, and `what_orchestrator_should_clarify` to the user and stop. Do not retry the synthesis yourself or with adjusted inputs unless the user explicitly directs — the agent already considered the inputs and chose to halt rather than guess.

### 3. Synthesize the user-facing digest

From the agent's `emitted` digest, build the user-facing report. The skill does not re-validate the file the agent wrote — that validation happened inside the agent before emission, and re-validating in the orchestrator just adds context noise. The skill's job here is presentation, not verification.

## References

- **`references/prolog-querying.md`** — `swipl -g` invocation patterns, the introspect module, ad-hoc query patterns, the coverage module. For spot-checks; the agent-of-questions sub-agent already uses these.
- **`${CLAUDE_SKILL_DIR}/../../references/prolog-wiki/`** — Prolog extensions (tabling, DCGs, CLP). **Don't read directly.** Pass the absolute path to `agent-of-questions` when a query needs an advanced extension.
- **`${CLAUDE_SKILL_DIR}/../../references/lean4-wiki/`** — Mathlib theorem names and type signatures for the Lean sketches in formal properties. **Don't read directly.** Spawn `shifting:lean-expert` with a one-line description; it returns real Mathlib names. Using real names (not plausible guesses) in sketches gives `prove-invariants` a head start.

Keeping wiki content inside sub-agent contexts preserves your context window for the hypothesis itself.

## Output

`thoughts/hypothesis.pl` — a Prolog facts file structured for both `model-obligations` (target-world model construction) and `prove-invariants` (theorem proving). The `hypothesis-decomposer` agent writes and validates this file before returning its digest; the skill consumes the digest for the user-facing report.

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

