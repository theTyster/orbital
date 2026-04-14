---
name: explain-proof
description: >
  Document all decisions and artifacts made during an implementation and explain them in natural language for review. Traces the full reasoning chain from proposition through Prolog KB, hypothesis, proof, pseudocode, and tests to implementation. Produces a complete narrative reviewers can follow without knowing Lean4 or Prolog. Also explains individual proof files in isolation. Use when: "explain the implementation", "review what we built", "summarize the proof", "document this implementation", "what did we prove and build".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write
argument-hint: "[optional: thoughts/ directory or specific .lean file]"
---

# Explain Proof and Implementation

Two modes:

- **Full audit** (primary): Discover all artifacts under `thoughts/` and any
  implementation changes, then produce a complete narrative — `thoughts/implementation_review.md` — that a reviewer can read from top to bottom to understand everything that was decided, why, and what it guarantees.
- **Single-file** (secondary): Given a specific `.lean` file, produce a concise
  plain-language summary of what that proof establishes. Write to
  `thoughts/proof_summary_human.md`.

Detect the mode from the argument (or absence of one):
- No argument, or argument points to a directory → **full audit**.
- Argument is a `.lean` file → **single-file**.

---

## Input

### Full Audit Mode

Discover artifacts by searching the `thoughts/` directory (and optionally a
codebase root if the user names one). Collect every file that exists; not all
will be present for every implementation:

| Path pattern | What it contains |
|---|---|
| `thoughts/hypothesis.md` | The falsifiable proposition explored |
| `thoughts/proof_results.md` | Lean4 proof outcomes reported by prove-hypothesis |
| `thoughts/lean/*.lean` | Lean4 theorem source files |
| `thoughts/*.pl` | Prolog knowledge base files |
| `thoughts/pseudocode.md` | Pseudocode scaffold produced before implementation |
| `thoughts/implementation_plan.md` | Concrete plan derived from proof results |
| `thoughts/proof_logic.md` | LLM-oriented logical description of proofs |
| `thoughts/proof_summary_human.md` | Any existing plain-English proof summary |
| Implementation files (*.ts, *.py, *.go, *.rs, …) | Actual code changes |
| Test files (*test*, *spec*, *_test.*) | Tests that exercise the implementation |

Read every file that exists. Do not fail if some are absent — note gaps.

### Single-File Mode

Read the `.lean` file given. Also read `thoughts/hypothesis.md` if it exists,
for domain context.

---

## Process — Full Audit Mode

### 1. Inventory All Artifacts

List every artifact found. For each, record:
- File path
- File type (hypothesis, KB, proof, pseudocode, plan, implementation, test)
- One-sentence description of what it contains

If an expected artifact is missing, note it explicitly — gaps are informative.

### 2. Reconstruct the Proposition

Find the original proposition or problem statement. It may appear in:
- `thoughts/hypothesis.md` (explicit)
- Comments at the top of Prolog KB files
- The preamble of the implementation plan

State it plainly in one paragraph: what question was being answered, for whom,
and why it mattered.

### 3. Trace the Prolog Knowledge Base

If KB files (`*.pl`) exist:

- Explain what the KB models: what entities, relationships, and rules were
  encoded
- Explain how it was derived (from code, from requirements, from domain rules)
- Identify the predicates that carried the most weight in reasoning
- Note any simplifications or assumptions baked in — these are risk surfaces

### 4. Trace the Hypothesis

If `thoughts/hypothesis.md` exists:

- State the central hypothesis in plain English
- Identify supporting evidence gathered from the KB
- Identify any contradicting evidence found
- Explain why the hypothesis was accepted for formal proof (or modified if it was)
- Note any hypotheses that were rejected and why

### 5. Trace the Formal Proof

If `thoughts/lean/*.lean` or `thoughts/proof_results.md` exist:

- For each proven theorem, state in plain English: **what was proven**
- Classify the result type: universal property, safety property, conditional
  guarantee, equivalence, existence proof
- Identify the assumptions the proof rests on (in plain terms, not Lean syntax)
- Note what the proof explicitly does NOT establish
- If proof attempts failed before succeeding, explain what changed

### 6. Trace the Pseudocode and Plan

If `thoughts/pseudocode.md` or `thoughts/implementation_plan.md` exist:

- Explain how the pseudocode was derived from proof results
- Identify which proved invariants directly shaped implementation decisions
- Note any design choices in the plan that were informed by the KB or proof
  versus choices that were left to engineering judgment

### 7. Trace the Implementation

If implementation files were changed:

- Summarize what was built
- Map each major implementation decision back to an artifact that motivated it
- Identify any implementation choices that were NOT grounded in formal reasoning
  (these are unverified assumptions — flag them)

### 8. Trace the Tests

If test files exist:

- Explain what the tests verify
- Distinguish: tests that exercise formally proven properties vs tests that cover
  unverified behavior
- Note whether the test suite is sufficient to catch regressions in the proven
  invariants

### 9. Synthesize the Narrative

Write a single flowing narrative (not a bullet list) that takes the reader from
proposition to implementation. Use plain English. Connect every artifact to its
role. Use specific file names and theorem names where they add clarity, but
always explain them.

### 10. Write Output

Write `thoughts/implementation_review.md` using the structure in **Output Format**.

---

## Process — Single-File Mode

1. Read the `.lean` file. Extract theorems, definitions, and comments.
2. Read `thoughts/hypothesis.md` if available, for domain context.
3. Identify the core result: what does the proof establish?
4. Write a plain-English summary using the **Proof Summary** structure below.
5. Write to `thoughts/proof_summary_human.md`.

---

## Output Format

### Full Audit — `thoughts/implementation_review.md`

```markdown
# Implementation Review
{One sentence: what was built and why.}

**Generated by**: explain-proof  
**Artifacts reviewed**: {count}  
**Date**: {today}

---

## 1. The Proposition

{Plain-English statement of the original question or problem. Who asked it.
What decision it was meant to inform. Why formal methods were applied.}

---

## 2. The Reasoning Chain

{A flowing narrative — not bullets — that walks through every stage:}

{Example structure, adapted to what actually exists:}

We began with the proposition that {X}. To reason about it formally, we built a
Prolog knowledge base ({path}) that modeled {entities} and encoded {rules}. The
KB established that {key finding from KB queries}.

From this, we formed the hypothesis that {H}. The hypothesis was supported by
{evidence} and contradicted by {counterevidence}. After {adjustment if any}, we
accepted {H} for formal verification.

We then formalized the hypothesis as Lean4 theorems ({paths}). The central
result, `{TheoremName}`, proved that {plain-English statement}. This rests on
the assumptions that {assumptions in plain terms}.

These results directly shaped the pseudocode ({path}), which captured
{invariants}. The implementation plan ({path}) translated these into {N} ordered
steps, with {key design decisions} grounded in the proven guarantees.

The implementation in {paths} built {what}. The tests in {paths} verify
{what properties}.

---

## 3. Artifact Inventory

| Artifact | Role | Key Finding or Decision |
|---|---|---|
| {path} | {type} | {one line} |
| … | … | … |

---

## 4. Formal Guarantees

What this implementation is **formally guaranteed** to satisfy (machine-checked
by Lean4):

- {Guarantee 1 in plain English}
- {Guarantee 2 in plain English}
- …

These guarantees hold under the following assumptions:

- {Assumption 1 in plain English}
- {Assumption 2 in plain English}
- …

The guarantees are only as strong as these assumptions. If the assumptions do
not faithfully model the real system, the guarantees may not transfer.

---

## 5. Unverified Assumptions and Risks

Things that were assumed but not formally proven:

- {Unverified assumption or risk 1}
- {Unverified assumption or risk 2}
- …

Gaps in coverage (artifacts that would have been expected but were not produced):

- {Gap or "None identified"}

---

## 6. Key Decisions

The decisions that most shaped the implementation, and what drove them:

1. **{Decision}** — {Why it was made; which artifact or reasoning step motivated it.}
2. **{Decision}** — {Why.}
…

---

## 7. What Was Not Proved

Explicit limitations. What a reader might incorrectly assume is formally covered:

- {Limitation 1}
- {Limitation 2}
- …

---

## 8. Reviewer Checklist

For a reviewer validating this implementation:

- [ ] The proposition in §1 accurately reflects the original intent
- [ ] The KB predicates in {path} faithfully model the real domain
- [ ] The theorem assumptions in §4 are met by the production environment
- [ ] The unverified assumptions in §5 are acceptable for this use case
- [ ] The tests cover the formally proven invariants
- [ ] The implementation matches the pseudocode / plan

---

## Technical Reference

For reviewers who want to inspect the formal artifacts directly:

- **Prolog KB**: {paths}
- **Lean proof files**: {paths}
- **Central theorem(s)**: {names and brief descriptions}
- **Proof strategies used**: {e.g., "by induction on list length", "by decidability"}
- **Mathlib dependencies**: {what standard mathematics was used}
```

---

### Single-File — `thoughts/proof_summary_human.md`

```markdown
# What We Proved

## One-Line Summary
{A single sentence anyone can understand. No jargon.}

## What This Means
{2–3 paragraphs in plain English:}
- What property was established
- What assumptions it rests on (in plain terms)
- What guarantees it provides

## Why It Matters
{What does this proof enable? What risks does it eliminate?
Frame in terms of the project or domain, not the mathematics.}

## What It Does NOT Prove
{Explicit limitations. What might someone incorrectly assume is covered?}

## Confidence
This result is **machine-checked** — verified by the Lean 4 theorem prover,
meaning the proof is mathematically certain given the assumptions listed above.
The assumptions are modeled from {source}, and the guarantees transfer to the
real system only insofar as that model is accurate.

## Technical Details
- **Lean file**: {path}
- **Key theorem**: `{theorem name}`
- **Proof strategy**: {brief description}
- **Mathlib dependencies**: {what standard math was used}
```

---

## Output

**Full audit**: `thoughts/implementation_review.md`

**Single-file**: `thoughts/proof_summary_human.md`

Report:
- Which mode was used
- List of artifacts read
- File path of the output
- Two-sentence summary of the narrative's central finding

---

## Guidance

**Write for the skeptical reviewer.** Assume the reader was not involved in the
implementation and has no prior knowledge of Lean4 or Prolog. They are smart,
they have limited time, and they will be suspicious of over-claiming. Every
assertion needs grounding.

**Be explicit about the formal/informal boundary.** There is a hard line between
what is formally guaranteed (machine-checked proof) and what is assumed, inferred,
or left to engineering judgment. Never blur this line. State it plainly in §4 and
§5. A reviewer who can see exactly where formal rigor ends and human judgment
begins can make an informed decision about residual risk.

**Connect every artifact to its role in the chain.** The KB is not just a file —
it is the formal model of the domain. The hypothesis is not just a guess — it is a
falsifiable claim derived from KB queries. The proof is not just code — it is a
machine-checked guarantee. Each artifact depends on and extends the previous one.
Make those dependencies explicit in the narrative.

**Name gaps honestly.** If the pseudocode was skipped, say so. If tests are
absent, say so. If a hypothesis was abandoned, explain why. The absence of an
artifact is itself information.

**Prefer narrative over lists.** The reasoning chain in §2 should read as a
story, not a bullet list. Lists are for the inventory and the checklist. The
narrative is where the reviewer builds intuition about what was done and why.

**No jargon in the main sections.** Avoid `∀`, `∃`, `→`, "tactic", "proposition",
"inductive type" in §1–§7. Save Lean and Prolog syntax for Technical Reference
where readers who want it can find it.

**Do not over-claim.** "This implementation is correct" is not a conclusion the
review should draw. "This implementation satisfies the invariants encoded in the
KB, as formally proved under these assumptions" is. Precision about scope
protects the reviewer and the team.
