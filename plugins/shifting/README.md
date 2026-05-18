# orbital-shifting

Formal logic reasoning pipeline: Prolog translation, hypothesis exploration, Lean 4 or Prolog proof verification, test generation, and implementation review.

## Pipeline

```
a. close-world             — Translate a codebase into a Prolog knowledge base
b. decompose-proposition   — Ingest a proposition and create a hypothesis based on the Prolog KB
c. model-obligations / prove-invariants — Formally verify the hypothesis (loops back to b if unprovable)
d. instantiate-properties  — Combine logical patterns into TDD tests that verify those patterns
e. realize-specification   — Orchestrate sub-agents to drive the TDD suite to green, refactoring against the proofs as the spec
f. explain                 — Explain whatever was done at any pipeline stage in plain language for non-technical review
```

Step c has two alternative proof backends — use Lean for mathematical/abstract proofs, Prolog for model-based verification of relational/structural properties.

## Additional Skills

- **measure-entailment** — Score how well two or more resources adhere to each other using Prolog-based relational analysis

The Lean toolchain bootstrap skills (`setup-lean-mathlib`, `setup-lean-project`) used to live here; they moved to the `scaffolding` plugin in 5.0.0 so a single `scaffolding:setup` flow owns all marketplace-wide provisioning. Invoke them as `scaffolding:setup-lean-mathlib` and `scaffolding:setup-lean-project`, or just run `/setup` once and let it delegate.

## Plugin References

Two curated wikis live under `references/`:

- `prolog-wiki/` — general SWI-Prolog knowledge (extensions, libraries, idioms)
- `lean4-wiki/` — general Lean 4 and Mathlib knowledge (lemmas, theorems, tactics)

Both follow the same shape: a root `index.md` plus one subdirectory per category, with one markdown file per entry.

**Access boundary**: the wikis are read by the plugin's domain agents (`lean-expert`, `prolog-prover`, `agent-of-truth`, `agent-of-questions`) — not by skills. A skill's only job is to pass the absolute wiki path in the agent briefing; the agent then consults the wiki inside its own context, returning a task-shaped answer rather than raw reference content. When a wiki is thin on a topic, the agents fall back to `WebSearch` / `WebFetch` against the official Mathlib 4 or SWI-Prolog docs. The skill-local `skills/prove-invariants/references/lean-proof-method.md` methodology doc stays with the lean proving skill and is passed to `lean-expert` alongside the wiki path.

## Prerequisites

- **Lean 4** (via [elan](https://github.com/leanprover/elan)) — provisioned by `scaffolding:setup` (delegates to `scaffolding:setup-lean-mathlib`)
- **SWI-Prolog** (`swipl`) — verified by `scaffolding:setup`

Run `/setup` once per project; the result is recorded in `.claude/orbital-setup.json` and shifting's skills consult that marker instead of re-probing the filesystem on every invocation.
