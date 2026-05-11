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

### 3. Search for counter-evidence within budget

Use the techniques available to the skill — escalate from cheap to expensive:

- **CLP search.** For arithmetic/boolean claims, `clpfd`, `clpb`, or `clpq`/`clpr` constraint solving. Encode the claim's negation; ask `swipl` for satisfying assignments.
- **Bounded enumeration.** For finite or small-domain claims, exhaustive search via swipl `findall/3` or `between/3`.
- **Source-grep counterfactuals.** For Prolog claims with `claim_label(_, counterfactual)`, the forbidden fact has a syntactic shape — grep the target codebase for it (this is what `realize-counterfactual-scanner` does as part of `realize-specification`; here we use it standalone).
- **Property-based fuzz.** If the target codebase has a PBT framework (`hypothesis`, `fast-check`, `proptest`, etc.), generate inputs and look for failures.
- **Manual case construction.** When automated search is infeasible, construct candidate witnesses by hand and validate each against the claim.
- **Lean term inhabiting the negation.** When the target is Lean-shaped — a theorem name from `lean_proof_results.pl`, or a Prolog claim with an attached `formal_property/3` — construct a Lean term inhabiting `¬claim` (a `theorem not_X : ¬ ... := ...` or a `Decidable` instance returning `isFalse`). Place the file under `thoughts/lean/Disproofs/`, paralleling `thoughts/lean/Proofs/`. Building the Lean project against this file machine-checks the refutation. **This technique is recommended (not required) when the target is Lean-shaped, and inadmissible when the target is purely behavioral/runtime — Lean has no theorem to inhabit for an HTTP-service trace or a wall-clock-timing claim.**
- **Specialist delegation.** Invoke a specialist agent (`lean-expert`, `agent-of-questions`, `prolog-prover`) whenever the subgoal fits its fluency — Lean-term construction, deep `swipl` queries against a complex KB, careful CLP encoding. Specialists are peer techniques, not fallbacks; for a Lean-shaped subgoal, `lean-expert` is the *first* tool, not the last. The bias-isolation rationale and delegation discipline are documented in the section below — read that section before invoking a specialist.

State the budget explicitly at the start of search and stop when it is exhausted. A budget exhausted without a witness is **abstained**, not "unrefutable."

**Lean-disproof never gates abstention.** Producing a Lean term inhabiting the negation strengthens a `refuted` verdict; failing to produce one does not block abstention or downgrade a refuted verdict to inconclusive. If a textual witness is concrete and validated against the pinned claim, the verdict is `refuted` regardless of whether a Lean term was also written.

## Specialist delegation discipline

Specialist delegation isolates the search from orchestrator bias. The orchestrator's hopes about whether a claim survives MUST NOT reach the specialist; disproof has no checker for pulled-punches, so under-searching is invisible without structural defense.

**Apply both defenses on every specialist invocation:**

1. **Role-briefing.** Open every specialist prompt with an explicit adversarial role and outcome-agnostic instruction:
   > "You are searching for refutations of the following claim. Record your result regardless of which way it falls. Abstaining within budget is a valid outcome; fabricating evidence is a foul. The orchestrator has no preferred outcome."
2. **Minimum-necessary context.** Send the pinned claim, the named refutation shape, the budget, and only the artifacts directly relevant to the subgoal. Do not paste orchestrator reasoning, hopes, or broader pipeline state. Escalate context only when the specialist returns "underspecified" with a precise question, or when substance demonstrably demands it.

**Orchestrator responsibilities (never delegated):** pin the claim in its strongest form, name the refutation shape, set the budget, validate any reported witness against the pinned claim before recording `refuted`, own the verdict. A specialist's self-reported verdict is candidate evidence, not output.

**Composition, not committee.** Run multiple specialists sequentially, composing their outputs. Never merge parallel specialist verdicts untouched.

Record which defenses were applied per invocation in `disprove_budget/2` so failure modes stay diagnostic.

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
%   under thoughts/lean/Disproofs/ AND the Lean project builds against it.
%   Recommended for Lean-shaped targets (theorems, claims with formal_property/3).
%   Inadmissible for purely behavioral/runtime targets.
%   Strengthens a refuted verdict; never gates abstention.
disprove_evidence_lean(c_007, 'thoughts/lean/Disproofs/c_007_not_sorted.lean').

% disprove_budget(TargetId, "what was spent — time, technique, depth").
disprove_budget(c_007, "clpfd search to depth 8; bounded enumeration over lists of length ≤ 5").

% disprove_obstruction(TargetId, "for abstained: what blocked progress").
disprove_obstruction(c_023, "claim references runtime behavior of an external HTTP service; no fuzzer available").

% disproved_at(TargetId, ISOTimestamp).
disproved_at(c_007, '2026-04-30T14:22:00Z').
```

## Output: `thoughts/lean/Disproofs/*.lean` (optional, Lean-shaped targets only)

When the target is Lean-shaped and a Lean term inhabiting the negation has been constructed, place the file under `thoughts/lean/Disproofs/`, paralleling `thoughts/lean/Proofs/` produced by `prove-invariants`. Use the same Lean project root so the disproof file imports the project's existing Lean library and is machine-checked by the project's build.

File-naming convention: `<TargetId>_not_<short_description>.lean` (e.g. `c_007_not_sorted.lean`).

Each Lean disproof file MUST:
- State the negated claim as a `theorem` (or a `Decidable` instance returning `isFalse`).
- Import only modules already present in the project's Lean configuration.
- Build successfully — an unbuildable disproof file is not a disproof. If the file does not build within budget, do not record `disprove_evidence_lean/2`; the verdict can still be `refuted` on textual-witness grounds alone.

Behavioral or runtime targets (HTTP traces, wall-clock timing, observed I/O) MUST NOT be encoded as Lean disproof files. Lean has no theorem to inhabit for these; the textual witness in `disprove_evidence/2` is the complete record.

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

## When this skill is invoked as a debate move

Other skills MAY invoke `disprove-proposition` against a specific claim mid-pipeline. The wiring of those injection points (which skill, against which claim, with what budget) is out of scope for this skill — it lives in each invoking skill's body. This skill provides the move; it does not prescribe when each upstream skill should make it.

What this skill **does** prescribe: every invocation, regardless of caller, follows the same four-step process and produces the same output schema. Verdicts are consumed identically whether the caller was a user or another skill.

## Loopback

A `refuted` verdict is a strong signal that the claim, as currently stated, cannot move forward. The natural next move is to invoke `decompose-proposition` to refine the offending claim — typically by adding a counterfactual sub-claim that names the witness explicitly, or by narrowing the claim's scope to exclude the witness's domain.

A `refuted` verdict is **not** a license to weaken the spec around the witness. The witness is information; weakening the spec to swallow it is a debate foul.

## What this skill is not

- Not a pipeline stage. It does not appear in the seven-stage flow; it has no fixed predecessors or successors.
- Not a verdict factory. Three verdicts are valid; abstention and inconclusive are first-class.
- Not exhaustive. A claim that resists this skill's search within budget may still be refutable by a future technique; record `abstained` honestly rather than `unrefutable`.
