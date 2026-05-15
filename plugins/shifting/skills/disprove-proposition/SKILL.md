---
name: disprove-proposition
description: >
  Open an adversarial dialog against a specific claim — a Prolog claim ID, a Lean theorem, a failing test, or an English proposition — and search for counter-evidence within budget. Not a pipeline stage; a debate move available at any point. Emits `thoughts/disproof_results.pl` with one of three verdicts: `refuted` (witness deposited to `thoughts/counterexamples.pl`), `inconclusive` (partial evidence recorded), or `abstained` (no progress within budget; reason recorded). Triggers on user phrases like "disprove this", "try to refute", "find a counterexample for", "construct counter-evidence", "open an adversarial dialog about", "challenge this claim".
user-invocable: true
allowed-tools: Bash, Read, Grep, Write, Agent
argument-hint: "[target — claim_id | theorem_name | test_name | english_proposition] [optional: source_file]"
---

- **Proof that `swipl` exists:** !`which swipl`

# disprove-proposition

**Logical operation:** *disprove-proposition* — adversarially examine a claim and produce one of `refuted` / `inconclusive` / `abstained`, with whatever counter-evidence the budget allows.

This is a **debate move**, not a pipeline coordinate. It is invocable directly by the user against any claim, and it is also the move other skills inject when they want adversarial pressure applied to a specific claim mid-pipeline. Disproof needs to be versatile: the claim under attack may be a `claim/2` in `hypothesis.pl`, a Lean theorem in `lean_proof_results.pl`, a behavioral_claim test, or a plain English proposition the user just typed.

## The frame

The goal is **counter-evidence**, not a binary verdict. A claim that survives a budget-limited disproof attempt has *not* been proven — it has merely resisted refutation under the resources spent. The output is conceptual understanding: *where* the claim is fragile, *what* would refute it, *which* witnesses block which proofs.

Three disciplines are non-negotiable:

1. **Abstention is first-class.** "I cannot refute this within budget" is a valid, useful outcome. Fabricating a counterexample to satisfy a passing target is a debate foul, symmetric to fabricating a proof.
2. **Witnesses must be concrete.** A `refuted` verdict requires a specific value, configuration, or trace that demonstrates the claim's failure — not a hand-wave.
3. **Solutions stay open-ended.** There is always more counter-evidence one could search for. An `inconclusive` verdict is honest; an `abstained` verdict naming the obstruction is honest. Declaring a claim "unrefutable" is not.

## Current Environment

`which swipl` returns: !`which swipl`
`ls thoughts/hypothesis.pl` returns: !`ls thoughts/hypothesis.pl 2>/dev/null || echo "(not present — that's fine; this skill works against any claim shape)"`
`ls thoughts/lean_proof_results.pl` returns: !`ls thoughts/lean_proof_results.pl 2>/dev/null || echo "(not present)"`
`ls thoughts/disproof_results.pl` returns: !`ls thoughts/disproof_results.pl 2>/dev/null || echo "(will be created)"`
`ls thoughts/counterexamples.pl` returns: !`ls thoughts/counterexamples.pl 2>/dev/null || echo "(will be created on first refutation)"`
`ls thoughts/refutations/` returns: !`ls thoughts/refutations/ 2>/dev/null || echo "(will be created on first adversary refutation)"`

## Input shapes

Disproof must be versatile across the pipeline. The skill accepts any of:

- **Prolog claim** — an ID like `c_007` referring to a `claim/2` in `thoughts/hypothesis.pl`. Provenance is the claim's `claim_label/2` and `formal_property/3`.
- **Lean theorem** — a theorem name from `thoughts/lean_proof_results.pl` (e.g. one with `theorem_verdict(_, unprovable)`). Provenance is the theorem statement.
- **Test** — a `behavioral_claim` or `projection` test by name. Provenance is the test's comment-block tags.
- **English proposition** — free text. The skill must first sharpen it into a refutable form before searching.
- **Source file** (optional second argument) — anchors provenance when the target is ambiguous (e.g., "claim c_007 in `thoughts/hypothesis.pl`").

If the input is ambiguous, ask the user to disambiguate. Do not guess.

## Process

### 1. Pin the target claim

Restate the claim in one sentence in its strongest reasonable form. Disproving a strawman is a debate foul — a refutation only counts against the claim as the proponent would defend it.

If the target is a Prolog claim, query `swipl` to retrieve the `claim/2` text, `claim_label/2`, and any `formal_property/3` attached. If it's a Lean theorem, read its statement from `lean_proof_results.pl`. If it's a test, read the comment block.

Record the pinned form. The verdict references this exact form.

### 2. Identify what would refute it

Before searching, name the *shape* of a successful refutation:

- For a `∀x. P(x)` claim: a single x with `¬P(x)`.
- For a `→` claim: an instance where the antecedent holds and the consequent fails.
- For a behavioral claim: a concrete input/state the system is supposed to handle correctly but doesn't.
- For a counterfactual claim (in the Prolog `claim_label` sense): a fact that demonstrates the forbidden state still materializes.

Naming the refutation shape *before* the search prevents post-hoc rationalization of inconclusive evidence as a "win."

### 3. Delegate the search to the appropriate adversary

The skill no longer drives counterexample search inline. The search step is a **delegation** to one of two refutation specialists; the orchestrator pins the claim and the refutation shape, then hands off:

- **Prolog target** → `prolog-adversary` (Bash + Read + Write + Glob + Grep). Use for any `claim/2` from `thoughts/hypothesis.pl`, any property previously closed by `prolog-prover`, or any counterfactual claim with a grep-able forbidden shape. The adversary runs CLP-driven search and writes `thoughts/refutations/<target_id>.pl` on `refuted`.
- **Lean target** → `lean-adversary` (Bash + Read + Write + Edit + Glob + Grep). Use for any theorem name from `thoughts/lean_proof_results.pl`, or any Prolog claim with an attached `formal_property/3` that translates cleanly into Lean. The adversary constructs a Lean term inhabiting `¬claim` and writes `thoughts/refutations/<target_id>.lean` on `refuted`. **Inadmissible for purely behavioral/runtime targets** — Lean has no theorem to inhabit for an HTTP-service trace or wall-clock-timing claim; route those to `prolog-adversary` (if a Prolog encoding exists) or to source-grep / manual-construction inside this orchestrator.
- **English proposition** → sharpen first (this orchestrator's responsibility — see Process step 1), then route the sharpened form to whichever adversary the formalism maps onto. If sharpening cannot land the claim in either formalism, the skill returns `abstained` without delegating; an adversary is not the right tool for an un-formalized claim.

The shared adversary contract — inputs, output digest shape, discipline — lives at `../../agents/references/adversary-contract.md`. The two agent files are at `../../agents/prolog-adversary.md` and `../../agents/lean-adversary.md`. Read all three when changing how delegation is parameterized.

**Briefing fields the orchestrator must pin** before delegating:

| Field | Source |
|---|---|
| `target_id` | the user's input argument |
| `target_text` | this orchestrator's Process step 1 (pin in strongest defendable form) |
| `provenance` | the file the claim lives in |
| `refutation_shape` | this orchestrator's Process step 2 (name the shape before search) |
| `budget` | declared explicitly at the start of search; stops the agent when exhausted |
| `output_dir` | defaults to `thoughts/refutations/`; the orchestrator may override for Lean to a path the project's lakefile reaches |

When neither adversary fits and the orchestrator must search inline (e.g. a behavioral claim that requires a PBT framework run against the target codebase), the same disciplines from §"Specialist delegation discipline" below apply to whatever in-line technique is used. Inline search is a fallback, not a default.

**Lean-disproof never gates abstention.** A `refuted` verdict from `prolog-adversary` is sufficient on its own; failing to additionally obtain a Lean refutation does not block abstention or downgrade a refuted verdict to inconclusive. If a textual witness from a Prolog refutation is concrete and validates against the pinned claim, the verdict is `refuted` regardless of whether a Lean refutation was also constructed.

## Specialist delegation discipline

Adversary delegation isolates the search from orchestrator bias. The orchestrator's hopes about whether a claim survives MUST NOT reach the adversary; disproof has no checker for pulled-punches, so under-searching is invisible without structural defense.

**Apply both defenses on every adversary invocation:**

1. **Role-briefing.** Open every adversary prompt with an explicit adversarial role and outcome-agnostic instruction:
   > "You are searching for refutations of the following claim. Record your result regardless of which way it falls. Abstaining within budget is a valid outcome; fabricating evidence is a foul. The orchestrator has no preferred outcome."
   The adversary agents (`prolog-adversary`, `lean-adversary`) bake this discipline into their own bodies, but the briefing must restate it — agents do not infer the caller's preferred outcome from missing instructions.
2. **Minimum-necessary context.** Send the pinned claim, the named refutation shape, the budget, and only the artifacts directly relevant to the subgoal. Do not paste orchestrator reasoning, hopes, or broader pipeline state. Escalate context only when the adversary returns `abstained` with `obstruction: "underspecified — orchestrator must supply X"`, or when substance demonstrably demands it.

**Orchestrator responsibilities (never delegated):** pin the claim in its strongest form, name the refutation shape, set the budget, validate any reported witness against the pinned claim before recording `refuted`, own the verdict. The adversary's self-reported verdict is candidate evidence, not output.

**Composition, not committee.** Run adversaries sequentially when more than one formalism applies, composing their outputs. Never merge parallel adversary verdicts untouched.

Record which defenses were applied per invocation in `disprove_budget/2` so failure modes stay diagnostic. The `defenses_applied` field returned in the adversary digest is the canonical source.

### 4. Verdict and deposit

Exactly one of:

- **`refuted`** — a concrete witness was found and validated against the pinned claim. Deposit the witness to `thoughts/counterexamples.pl` (see schema below); record the verdict in `thoughts/disproof_results.pl`.
- **`inconclusive`** — partial evidence was found (a near-miss, a fragile region, a related-but-not-pinned refutation). Record the partial evidence in `thoughts/disproof_results.pl`. Do **not** deposit to `counterexamples.pl` — that file is for refutations only.
- **`abstained`** — budget exhausted with no witness or partial evidence. Record the obstruction (what the search tried, where it stalled).

The verdict is load-bearing: any pipeline skill that consumes `disproof_results.pl` must treat `refuted` as a hard signal that the claim cannot be moved forward in its current form.

## Output: `thoughts/disproof_results.pl`

```prolog
:- discontiguous disprove_attempt/3, disprove_evidence/2,
                 disprove_evidence_lean/2,
                 disprove_budget/2, disprove_obstruction/2,
                 disproved_at/2.

% disprove_attempt(TargetId, Verdict, EvidencePath).
%   Verdict ∈ {refuted, inconclusive, abstained}.
%   EvidencePath is a path under thoughts/ for refuted/inconclusive,
%   or the atom no_evidence for abstained.
disprove_attempt(c_007, refuted, 'thoughts/counterexamples.pl').

% disprove_evidence(TargetId, "natural-language description of the witness or partial evidence").
disprove_evidence(c_007, "input list [3,1,2] violates the sorted-output postcondition").

% disprove_evidence_lean(TargetId, LeanFilePath).
%   Optional. Present when a Lean term inhabiting the negation has been written
%   to thoughts/refutations/<target_id>.lean by lean-adversary AND the Lean
%   project builds against it. Recommended for Lean-shaped targets (theorems,
%   claims with formal_property/3). Inadmissible for purely behavioral/runtime
%   targets. Strengthens a refuted verdict; never gates abstention.
disprove_evidence_lean(c_007, 'thoughts/refutations/c_007.lean').

% disprove_budget(TargetId, "what was spent — time, technique, depth").
disprove_budget(c_007, "clpfd search to depth 8; bounded enumeration over lists of length ≤ 5").

% disprove_obstruction(TargetId, "for abstained: what blocked progress").
disprove_obstruction(c_023, "claim references runtime behavior of an external HTTP service; no fuzzer available").

% disproved_at(TargetId, ISOTimestamp).
disproved_at(c_007, '2026-04-30T14:22:00Z').
```

## Output: `thoughts/refutations/<target_id>.{pl,lean}` (adversary-owned)

The refutation artifact files are written by the adversary agents, not this skill. The skill records the path in `disprove_results.pl`; the agent owns the file content. Naming convention:

- Prolog refutations: `thoughts/refutations/<target_id>.pl` (written by `prolog-adversary`).
- Lean refutations: `thoughts/refutations/<target_id>.lean` (written by `lean-adversary`).
- Cross-formalism (same target refuted by both): `thoughts/refutations/<target_id>__prolog.pl` and `thoughts/refutations/<target_id>__lean.lean`.

Each artifact file is self-contained and machine-checkable. Prolog refutations load cleanly under `swipl`; Lean refutations build cleanly under `lake build` (the orchestrator must ensure the Lean project's lakefile reaches `thoughts/refutations/` as a source root before delegating to `lean-adversary`).

Per-formalism file contracts live in the agent bodies; the shared input/output/discipline contract lives at `../../agents/references/adversary-contract.md`.

Behavioral or runtime targets (HTTP traces, wall-clock timing, observed I/O) MUST NOT be routed to `lean-adversary` — Lean has no theorem to inhabit. The textual witness in `disprove_evidence/2` is the complete record for those targets, optionally supported by a Prolog refutation when an encoding exists.

## Output: `thoughts/counterexamples.pl` (refuted verdicts only)

```prolog
:- discontiguous counterexample/4, counterexample_shrunk/2,
                 counterexample_blocks_proof/2.

% counterexample(TargetId, WitnessPath, Source, RecordedAt).
%   Source ∈ {clp_search, bounded_enum, source_grep, pbt_shrink, manual, sub_agent}.
counterexample(c_007, 'thoughts/witnesses/c_007_input.txt', bounded_enum, '2026-04-30T14:22:00Z').

% counterexample_shrunk(TargetId, ShrunkValue) — shrunken witness when applicable.
counterexample_shrunk(c_007, "[3,1,2]").

% counterexample_blocks_proof(TargetId, ProofTargetId) — when the witness blocks a Lean theorem.
counterexample_blocks_proof(c_007, theorem_sorted_output).
```

## When this skill is invoked

This skill is **structurally outside** the seven-stage pipeline. Per the orchestration-substrate contract (`plugins/trajectory/references/orchestration-substrate.md`), `disprove-proposition` is `unstaged_skill/1`: it lives at the orchestration layer, not as a step the pipeline self-invokes. The **only legal invoker is the orchestrator** (the `trajectory:pipeline` skill, or a user, or a future meta-orchestrator).

What this skill prescribes: every invocation, regardless of caller, follows the same four-step process and produces the same output schema. Verdicts are consumed identically whether the caller was a user directly or the orchestrator routing around a pipeline-stage descriptor.

What this skill explicitly forbids (Phase 5 resolution of witness R1):

- **Pipeline primitives MUST NOT invoke this skill.** `close-world`, `decompose-proposition`, `model-obligations`, `prove-invariants`, `instantiate-properties`, `realize-specification`, and `measure-entailment` do not contain any `Agent(shifting:disprove-proposition)` or equivalent dispatch. If you find such an invocation in a staged primitive, it is a bug: report it.
- **Pipeline primitives MUST NOT auto-consume this skill's outputs.** `thoughts/disproof_results.pl`, `thoughts/counterexamples.pl`, and `thoughts/refutations/*` are read **only by the orchestrator**. They are `consumed_by_orchestrator(_)` facts in the orchestration-substrate KB. The pipeline does not pattern-match on them.

## How the orchestrator consumes the outputs

The orchestrator (e.g., `trajectory:pipeline`) reads `disproof_results.pl` and decides:

- **`refuted`** — halt the pipeline; surface the witness; ask the user whether to drive a non-adjacent loopback (e.g., re-invoke `decompose-proposition` with the witness as a starting axiom via `refutation_shape_briefing`) or finish with `explain` against partial state.
- **`inconclusive`** — record; decide whether to fold the partial evidence into the next stage's `refutation_shape_briefing` parameter and proceed.
- **`abstained`** — record the obstruction and proceed without halting.

The orchestrator never threads disprove outputs back into the pipeline by passing the artifact paths to a staged primitive. The threading happens through orchestrator parameters (`refutation_shape_briefing`, `halt_condition`) at the next primitive invocation, not through cross-skill reads. This is the R2 resolution by typing: disprove-proposition's outputs are *inputs to orchestrator decision-making*, never artifacts the pipeline self-attacks.

## Loopback (orchestrator-mediated)

A `refuted` verdict is a strong signal that the claim, as currently stated, cannot move forward. The natural next move — re-invoking `decompose-proposition` to refine the offending claim — is **the orchestrator's call**, not this skill's. This skill emits the verdict to `thoughts/disproof_results.pl` and stops. The orchestrator reads, decides, and parameterises the next primitive invocation accordingly.

A `refuted` verdict is **not** a license to weaken the spec around the witness. The witness is information; weakening the spec to swallow it is a debate foul.

## What this skill is not

- Not a pipeline stage. It does not appear in the seven-stage flow; it has no fixed predecessors or successors.
- Not a verdict factory. Three verdicts are valid; abstention and inconclusive are first-class.
- Not exhaustive. A claim that resists this skill's search within budget may still be refutable by a future technique; record `abstained` honestly rather than `unrefutable`.
