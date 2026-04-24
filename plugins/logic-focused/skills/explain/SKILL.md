---
name: explain
description: >
  Cross-cutting support resource — produces a plain-language explanation of logic-focused work for non-technical review. Triggers: "explain what we did", "explain the proof", "summarize for my PM", "write this up for a stakeholder". NOT a pipeline stage and has no place in the linear flow; invoke it at any time, against whatever artifacts already exist. Cited by `prove-invariants` as a downstream readability resource, but never consumed by any other skill.
user-invocable: true
allowed-tools: Read, Glob, Grep, Write
argument-hint: "[optional: thoughts/ directory, specific file, or codebase directory]"
---

# explain

Produce a plain-language narrative of whatever work has been done in simple terms. The reader is someone who was not involved, does not know Lean4 or Prolog, and needs to understand what happened, what was decided, and what guarantees (if any) exist — without ever reading a formal artifact.

This skill is a **cross-cutting support resource for non-technical review**, not a pipeline stage. It has no position in the linear pipeline — there is no stage that must come before it and no stage that depends on its output. It does not produce an artifact that any other skill consumes; deleting `thoughts/explanation.md` does not break the pipeline. Use it whenever a stakeholder, project manager, reviewer, or non-technical collaborator needs to understand the work without reading Prolog or Lean. After translating a codebase to Prolog, it explains what was modeled. After forming a hypothesis, it explains what was proposed and why. After proving theorems, it explains what was guaranteed. After a full pipeline run, it narrates the whole journey. After a code change with no formal methods at all, it documents what changed and why.

The output is a plain-language report at `thoughts/explanation.md`, written for a non-technical audience. The canonical machine-readable results live elsewhere (`thoughts/model_results.pl`, `thoughts/lean_proof_results.pl`, `thoughts/adherence_report.md`, etc.) — this skill exists only to translate them into prose suitable for review by readers who do not read formal logic.

The output scales to whatever artifacts are present. One artifact gets a focused explanation. Many get a connected narrative.

**The epistemic-strength obligation.** Every claim in the upstream artifacts carries an epistemic label (see `../../references/epistemic-types.md`). The reader of this explanation cannot see those labels, so the prose must translate them into calibrated language: "proven for all inputs" (a `prescriptive` Lean theorem) is stronger than "checked exhaustively in our model" (a `descriptive` Prolog model claim), which is stronger than "the fixture passed in our test suite" (`test_category(projection)`), which is stronger than "we asserted behaviourally without formal proof" (`test_category(behavioral_claim)`), which is stronger than "the knowledge base did not contradict it" (`negation_provenance(absent)` under closed-world). Flattening these into the undifferentiated word "proven" is the failure mode this skill exists to prevent.

---

## How to detect the mode

Decide what to do based on the argument (or absence of one):

| Argument | Mode |
|----------|------|
| None, or a directory | **Discovery mode** — scan for all artifacts, produce the broadest narrative possible |
| A specific `.lean` file | **Single proof** — explain what that one proof establishes |
| A specific `.pl` file | **Single KB or results file** — explain what the knowledge base models or what the results record |
| A specific `.md` file | **Single document** — explain that document's role and content |

In discovery mode, scan `thoughts/` and optionally a codebase directory. Read everything that exists. Missing artifacts are fine — just note what stages haven't been reached yet.

---

## Typical Artifacts to Look For

These are the artifacts this pipeline produces. Not all will exist at any given point. Read what's there, skip what isn't, and note the gaps.

| Artifact | Producing skill | What it tells you |
|----------|-----------------|-------------------|
| `thoughts/existing-world.pl` | close-world | A structured model of the codebase or domain as it exists today — entities, relationships, rules |
| `thoughts/hypothesis.pl` | decompose-proposition | A falsifiable claim decomposed into Prolog sub-hypotheses, with evidence for and against |
| `thoughts/target-world.pl` | model-obligations | The hypothesised target world being verified against the existing world |
| `thoughts/model_results.pl` | model-obligations | Per-obligation outcomes from model-based verification |
| `thoughts/lean/Proofs/*.lean` | prove-invariants | Machine-checked proofs that certain properties are mathematically guaranteed |
| `thoughts/lean_proof_results.pl` | prove-invariants | Per-theorem outcomes (proved / failed / sorry) from Lean |
| `thoughts/tests/*` | instantiate-properties | Tests that check whether the implementation satisfies proven properties |
| `thoughts/implementation_log.md` | realize-specification | A record of how each test was driven to green |
| Implementation files (`.ts`, `.py`, `.go`, etc.) | manual or planned | The actual code that was written or changed |
| `thoughts/adherence_report.md` | measure-entailment | How well two or more resources agree on shared facts |
| `thoughts/explanation.md` | previous explain run | An existing narrative (check if it needs updating rather than rewriting) |

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

### Translating epistemic labels

The upstream artifacts label every claim with an epistemic origin via `epistemic_label/1`, `negation_provenance/1`, and `test_category/1`. These labels never appear in the plain-language output, but the calibrated phrase they translate into does. Use this reference while writing prose — pick the phrase that matches the label, then weave it into a sentence. Do not paste the label into the narrative; the reader is an outsider.

**`epistemic_label(prescriptive)` from a Lean theorem with no closed-world premises** → "proven mathematically for all possible inputs — the strongest guarantee this pipeline produces."

**`epistemic_label(prescriptive)` proven under a stated hypothesis** → "proven mathematically, assuming [stated hypothesis]. Strong — but only as strong as that hypothesis."

**`epistemic_label(prescriptive)` whose proof rests on a closed-world premise (a `negation_provenance(absent)` fact lifted into Lean)** → "proven mathematically, but one or more premises came from 'the knowledge base did not mention this' — so the guarantee is only as strong as the completeness of what we modeled. Call out the specific closed-world premise if it matters to the reader."

**`epistemic_label(descriptive)` from a Prolog model verification** → "verified exhaustively within the model we built — no counterexample exists in our knowledge base."

**`negation_provenance(contradicts)`** → "the model explicitly rules it out — there is a fact that contradicts the claim."

**`negation_provenance(absent)`** → "the model did not derive this; treated as absent under closed-world assumption. Weaker than a contradiction — if the model is incomplete, the absence may be wrong."

**`epistemic_label(counterfactual)`** → "explored as a hypothetical alternative world — useful for reasoning about possible futures, but not a claim about what is true today."

**`test_category(projection)`** → "the implementation passed a test case that samples the proven property at specific inputs. The universal guarantee lives in the proof, not the test — the test is a tripwire."

**`test_category(projection)` for an absence claim** → "the implementation's structure was checked and confirmed to not contain a specific forbidden dependency at a specific place."

**`test_category(projection)` paired with a guard test** → "we also confirmed that re-introducing the forbidden dependency breaks the invariant — the removal was load-bearing."

**`test_category(behavioral_claim)`** → "asserted by a test but not formally proven. Green means the test case passed; this is weaker than any proof-backed claim."

**No label, taken as given** → "taken as given without verification — flag this explicitly to the reader."

If a claim composes labels (e.g., a `test_category(projection)` that samples a Lean theorem whose proof rested on `negation_provenance(absent)`), combine the phrases — "the implementation passed a test that samples a property whose premise came from closed-world absence, so the guarantee is twice weakened." Do not simplify it into "verified."

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

{A summary of the current state, broken down by the strength of the claim.
Sort every finding into one of these five buckets — do not collapse them:}

- What has been **proven universally** (`epistemic_label(prescriptive)` Lean theorems with no closed-world premises)
- What has been **model-verified** (`epistemic_label(descriptive)` from Prolog — exhaustive within our model)
- What has been **sampled and passed** (`test_category(projection)` — test cases witness the property; proof is still authority on universality)
- What has been **asserted behaviourally** (`test_category(behavioral_claim)` — no formal backing)
- What has been **assumed** (`negation_provenance(absent)` or otherwise unverified — treated as true but not verified; may be wrong if the model is incomplete)

## What This Means for a Reviewer

{Practical guidance: what should a reviewer look at, what can they trust,
what should they scrutinize? If formal proofs exist, explain that "proven"
means mathematically certain under stated assumptions — stronger than
"tested" but only as strong as the assumptions. If only a KB exists,
explain that the model is only as accurate as the facts fed into it.

Tell the reviewer which claims fall into each of the five strength buckets
from "What We Know Now" and why the bucket matters for their scrutiny.
Closed-world claims (any premise carrying `negation_provenance(absent)`,
whether it ended up in a Lean proof or as a projection test for absence)
deserve extra attention because the guarantee is only as strong as the
completeness of the knowledge base — if the model missed a dependency,
the absence-based claim may be wrong. Behavioral tests
(`test_category(behavioral_claim)`) also deserve extra scrutiny because
nothing upstream backs them: a green behavioral test means the fixture
passed on this run, not that the behaviour is guaranteed. Point the
reviewer at these weaker buckets explicitly rather than burying them
alongside the proven claims.}
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

**Explain absence.** If the pipeline stopped at decompose-proposition and never reached proofs, say so and explain what that means: "The prediction has supporting evidence from the model but has not been formally verified — it should be treated as a well-informed estimate, not a guarantee." Missing stages are information, not failures.

**Don't pad.** If only one artifact exists, the explanation might be a single page. That's fine. Don't inflate the narrative to seem more thorough than the work actually was.

**Never flatten strength into "proven."** Every claim in the artifacts has an epistemic label. If the explanation uses the same word ("proven", "verified", "confirmed") for a prescriptive Lean theorem and a `test_category(behavioral_claim)` fixture, it has silently erased the distinction the whole pipeline exists to produce. Calibrate every confidence word.
