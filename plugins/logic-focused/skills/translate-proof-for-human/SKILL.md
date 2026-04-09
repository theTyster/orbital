---
name: translate-proof-for-human
description: >
  Translate a proven Lean4 file into a clear natural language summary for human
  readers. Explains what was proven, why it matters, and what guarantees it provides,
  without requiring formal logic or Lean4 knowledge.
  Use when: "explain this proof", "summarize the lean proof", "what did we prove".
user-invocable: true
allowed-tools: Read, Glob, Grep, Write
argument-hint: "[lean proof file or proof_results.md path]"
---

# Translate Proof for Human

Read a proven Lean4 file and produce a human-friendly summary. The audience is
a developer or stakeholder who doesn't know Lean4 or formal logic but needs to
understand what guarantees the proof establishes.

## Input

Accept one of:
- A `.lean` proof file (single file)
- A `thoughts/proof_results.md` from the formalize-in-lean skill (processes all proven files)

Read the input. Extract theorems, definitions, and comments.

## Process

### 1. Identify the Core Result

Answer: **What did we prove?** Strip away the formal machinery and find the
essential claim. Most proofs reduce to one of:

- "X always holds" (universal property)
- "X is impossible" (safety property)
- "If A then B" (conditional guarantee)
- "X and Y are equivalent" (equivalence)
- "There exists an X satisfying Y" (existence)

### 2. Explain in Context

Connect the proof to the domain. Use the comments in the Lean file and any
referenced hypothesis file to understand what real-world property was being verified.

### 3. Write the Summary

Write to `thoughts/proof_summary_human.md` (create `thoughts/` if it doesn't exist):

```markdown
# What We Proved

## One-Line Summary
{A single sentence anyone can understand. No jargon.}

## What This Means
{2-3 paragraphs explaining the result in plain English:}

- What property was established
- What assumptions it rests on (in plain terms)
- What guarantees it provides

## Why It Matters
{What does this proof enable? What risks does it eliminate?
 Frame in terms of the project/domain, not the math.}

## What It Does NOT Prove
{Explicit limitations. What might someone incorrectly assume is covered?}

## Confidence
This result is **machine-checked** — it was verified by the Lean 4 theorem
prover, which means the proof is mathematically certain given the assumptions.
The assumptions themselves ({list key assumptions in plain English}) are modeled
from {source}, and the model's accuracy depends on how faithfully it represents
the real system.

## Technical Details
For those who want to inspect the proof:
- **Lean file**: {path}
- **Key theorem**: `{theorem name}`
- **Proof strategy**: {brief description — e.g., "by induction on the list length"}
- **Mathlib dependencies**: {what standard math was used}
```

## Output

All artifacts are written to the `thoughts/` directory (create it if it doesn't exist).

A `thoughts/proof_summary_human.md` file.

Report:
- File path
- One-line summary of what was proven

## Guidance

- **No jargon**: Avoid "∀", "∃", "→", "iff", "proposition", "tactic" in the main sections. Save these for Technical Details.
- **Be honest about limitations**: State what the proof does NOT cover. Over-claiming undermines trust.
- **Connect to stakes**: Why should the reader care? What decision does this inform?
- **Analogy over precision**: In the main sections, a good analogy that conveys the right intuition beats a precise statement that nobody reads.
