---
name: explain
description: >
  Use this skill whenever the user wants a plain-language explanation of logic-focused pipeline work — "explain what we did", "explain the proof", "summarize for my PM", or when a reviewer needs to understand formal artifacts. Discovers pipeline artifacts (Prolog KB, hypotheses, Lean proofs, tests) and produces a non-technical narrative.
user-invocable: true
allowed-tools: Read, Glob, Grep, Write
argument-hint: "[optional: thoughts/ directory, specific file, or codebase directory]"
---

# Explain

Produce a plain-language narrative of whatever work has been done. The reader is someone who was not involved, does not know Lean4 or Prolog, and needs to understand what happened, what was decided, and what guarantees (if any) exist — without ever reading a formal artifact.

This skill works at **any point in the pipeline**, not just the end. After translating a codebase to Prolog, it explains what was modeled. After forming a hypothesis, it explains what was proposed and why. After proving theorems, it explains what was guaranteed. After a full pipeline run, it narrates the whole journey. After a code change with no formal methods at all, it documents what changed and why.

The output scales to whatever artifacts are present. One artifact gets a focused explanation. Many get a connected narrative.

---

## How to detect the mode

Decide what to do based on the argument (or absence of one):

| Argument | Mode |
|----------|------|
| None, or a directory | **Discovery mode** — scan for all artifacts, produce the broadest narrative possible |
| A specific `.lean` file | **Single proof** — explain what that one proof establishes |
| A specific `.pl` file | **Single KB** — explain what the knowledge base models |
| A specific `.md` file | **Single document** — explain that document's role and content |

In discovery mode, scan `thoughts/` and optionally a codebase directory. Read everything that exists. Missing artifacts are fine — just note what stages haven't been reached yet.

---

## What to look for

These are the artifacts the pipeline produces. Not all will exist at any given point. Read what's there, skip what isn't, and note the gaps.

| Artifact | Pipeline stage | What it tells you |
|----------|---------------|-------------------|
| `thoughts/facts.pl` or `thoughts/*_facts.pl` | translate-to-prolog | A structured model of the codebase or domain — entities, relationships, rules |
| `thoughts/hypothesis.md` | hypothesize | A falsifiable claim about how something should work, with evidence for and against |
| `thoughts/lean/Proofs/*.lean` | prove-hypothesis-lean | Machine-checked proofs that certain properties are mathematically guaranteed |
| `thoughts/proof_results.md` | prove-hypothesis-lean | A summary of what the proofs established, in more readable form |
| `thoughts/tests/*` | translate-to-tests | Tests that check whether the implementation satisfies proven properties |
| Implementation files (`.ts`, `.py`, `.go`, etc.) | manual or planned | The actual code that was written or changed |
| `thoughts/implementation_review.md` | previous explain run | An existing narrative (check if it needs updating rather than rewriting) |

---

## Writing the explanation

The entire point of this skill is that the reader should never need to open a `.lean` file or a `.pl` file to understand what happened. Every formal concept must be translated.

### Translation principles

**Prolog knowledge bases** are structured maps. When explaining a KB:
- Don't say "predicates" — say "relationships" or "facts the model tracks"
- Don't say `depends_on(auth, database)` — say "the auth system depends on the database"
- Don't say "query" — say "question we asked the model"
- Frame the KB as: "We built a map of how the system's parts connect to each other, then asked questions about that map"

**Lean proofs** are mathematical guarantees. When explaining a proof:
- Don't say "theorem" — say "guarantee" or "verified property"
- Don't say "tactic" or "induction" — say "the proof works by checking every possible case" or "the proof works by showing it holds for the simplest case and then showing each step preserves it"
- Don't say `∀`, `∃`, `→` — say "for every", "there exists", "if ... then"
- Frame proofs as: "We used a tool that checks mathematical reasoning automatically. If the tool accepts the proof, the property is guaranteed — not just tested, but proven for all possible inputs"

**Hypotheses** are structured bets. When explaining a hypothesis:
- Don't say "falsifiable claim" — say "a specific, testable prediction"
- Frame as: "Based on what we learned from the model, we predicted that [X]. We then looked for evidence that would prove us wrong"

**Pseudocode** is a blueprint. When explaining pseudocode:
- Frame as: "Before writing code, we wrote out the logical steps the system needs to follow, drawing from [sources]"

**Tests** are acceptance criteria. When explaining tests:
- Frame as: "We wrote checks that will fail if the implementation doesn't satisfy the properties we proved. An implementor works through these one by one"

### Structuring the narrative

Write in **flowing prose**, not bullet lists. The narrative should read like a technical memo someone could skim in 5 minutes. Use headings to break up sections, but within each section, write connected paragraphs.

**Start with context**: What question or problem was being addressed? Why did it matter?

**Follow the chronological pipeline order**: Even if you're only explaining one stage, briefly acknowledge what came before it (if anything) and what would come next.

**For each artifact that exists, cover three things**:
1. What it is (in plain terms — see translation principles above)
2. What it found or established (the actual content, simplified)
3. What decisions it informed (why it matters for what came next)

**End with the current state**: Where does this work stand right now? What's been established, what's still open, and what would a next step look like?

---

## Output

### Discovery mode

Write to `thoughts/explanation.md`. Structure:

```markdown
# Explanation

{One sentence: what this work is about.}

---

## Context

{What problem was being addressed. Who cares about it. Why formal methods
were used (if they were), explained in terms a project manager could follow.}

## What Was Done

{The narrative. One section per pipeline stage that produced artifacts.
Follow the chronological order. Use the translation principles above
to keep everything in plain language.

For a full pipeline, this might have subsections:

### Mapping the System
{Explain the KB}

### Forming a Prediction
{Explain the hypothesis}

### Proving the Prediction
{Explain the proof — what's guaranteed and what it rests on}

### Writing the Blueprint / Writing the Tests
{Explain pseudocode and/or tests}

### Building It
{Explain the implementation}

For a partial pipeline, only include the sections that have artifacts.}

## What We Know Now

{A summary of the current state:}

- What has been **established** (proven, modeled, tested — be precise
  about the level of confidence for each)
- What has been **assumed but not verified** (flag these clearly)
- What **hasn't been done yet** (remaining pipeline stages, if any)

## What This Means for a Reviewer

{Practical guidance: what should a reviewer look at, what can they trust,
what should they scrutinize? If formal proofs exist, explain that "proven"
means mathematically certain under stated assumptions — stronger than
"tested" but only as strong as the assumptions. If only a KB exists,
explain that the model is only as accurate as the facts fed into it.}
```

### Single-file mode

Write to `thoughts/explanation.md` (or append a section if the file already exists). Use the same translation principles but focused on the one artifact. Keep it under 2 pages.

---

## Report

After writing, tell the user:
- File path
- Which artifacts were found and explained
- A two-sentence summary of the narrative's central finding
- Which pipeline stages have not been reached yet (if any)

---

## Guidance

**Write for the outsider.** The reader was not in the room. They don't know what Lean is. They don't know what Prolog is. They may not be a developer at all. If you find yourself typing a word that requires specialist knowledge to understand, replace it with a plain phrase and — if the precise term matters — put the technical term in parentheses after the plain explanation. Example: "We built a structured map of the system (a Prolog knowledge base) that tracks which components depend on each other."

**Be honest about the strength of each claim.** There is a spectrum from "we modeled it" through "we predicted it" through "we tested it" to "we proved it mathematically." Each level is stronger than the last. Don't say "guaranteed" for something that was only modeled. Don't say "assumed" for something that was machine-checked. Name the level explicitly every time.

**Narrate, don't list.** The explanation should read as a story with a beginning (the problem), middle (the work), and end (where we are now). Lists are for the "What We Know Now" section. Everything else should be prose that a person can read straight through.

**Explain absence.** If the pipeline stopped at hypothesize and never reached proofs, say so and explain what that means: "The prediction has supporting evidence from the model but has not been formally verified — it should be treated as a well-informed estimate, not a guarantee." Missing stages are information, not failures.

**Don't pad.** If only one artifact exists, the explanation might be a single page. That's fine. Don't inflate the narrative to seem more thorough than the work actually was.
