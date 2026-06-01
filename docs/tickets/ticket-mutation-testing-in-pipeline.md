---
id: mutation-testing-in-pipeline
title: Mutation testing in the pipeline — ephemeral probes for faster proof↔code feedback
status: backlog
priority: low
area: shifting
created: 2026-05-29
tags: [mutation-testing, prove-invariants, vacuity, ephemeral, feedback, sagittarius]
related:
  - experiments/pipeline-workflow/FINDINGS.md
  - docs/tickets/ticket-constrain-adversary-write-access.md
---

## Problem

Proofs collide with the code too late. The 2026-05-29 pre-kimmy checklist found that 5 of 7
Lean invariants had been "proven axiom-free" while being **vacuous** — proven over a degenerate
one-point model so the universals collapsed and the load-bearing hypotheses were dead weight.
That hollowness was caught only *after the fact*, by a dedicated adversary sweep. The proving
loop itself had no mechanism to force the proof and the code into contact at author time.

## Goal

Introduce **mutation testing** as a feedback instrument in the pipeline so proofs collide with
code earlier. Two lenses:

- **Non-vacuity:** a mutation that *violates* an invariant MUST break a test/proof. If it
  doesn't, the invariant (or its test) isn't constraining the code — surface it immediately.
- **Vacuity detection:** the same mechanism flags "this proof survives a mutation that should
  break it" → vacuous → at author time, *before* a later adversary sweep. Faster feedback on
  the slowest, most expensive layer.

Possibly applicable at other stages too (e.g. mutate realized source to confirm a behavioral
test pins the behavior; mutate a KB fact to confirm a claim's evidence query depends on it).

## Scope

Early/exploratory — not yet designed. Likely starts at `prove-invariants` (the motivating
case) and may extend to `realize` and the KB stages.

## Hard constraint — mutation tests are EPHEMERAL

Mutation tests are a **probe, not a kept artifact.** Whatever generates them MUST encode the
lifecycle **create → run → discard**: never commit a mutant or a mutation test as a durable
test; never leave a mutant in the source tree; never let one survive into the kept suite. This
must be a property of the generator, not a manual cleanup step — analogous to how `thoughts/`
is treated as scratch. The `realize` stage's *durable* tests and a mutation pass's *throwaway*
ones must never be confused.

## Safety constraint — do NOT rely on worktree isolation (F-8)

The first mutation-driven probe (the 1b non-vacuity audit) hit F-8: it requested 5
worktree-isolated mutation agents, only 3 worktrees were created, and one mutation leaked into
the MAIN tree (caught by a determinism re-run, 24/24 → 23/24; reverted; pruned). A
mutation-heavy workflow must therefore be **safe by construction**:

- Writes: disjoint per-target files + serial builds (one mutant at a time, reverted before the
  next).
- Parallel phases: read-only probe-compiles only; never parallel mutators sharing a tree.
- Disposal must be **verified** (clean-tree assertion / determinism re-run), not assumed from
  worktree pruning.

## Open questions

- Which stages get a mutation pass (prove-invariants for sure; where else)?
- Who generates the mutants — a dedicated agent, or a deterministic Sagittarius segment?
- Mutant operator set for Lean/Prolog vs. for realized source code?
- How is the ephemeral-disposal guarantee encoded + verified?
- Does this subsume, complement, or pre-filter the per-invariant adversary sweep?

## Non-goals

- NOT durable tests. Mutation tests/mutants are never committed or kept.
- NOT a replacement for the adversary gate (at least not yet — relationship is an open question).

## Acceptance criteria

Deferred — design pass required before falsifiable criteria. (Ticket is `backlog`, not yet
triaged; capturing the idea so it isn't lost. Operator considers this high-value for faster
formal-layer feedback despite the `low` urgency.)

## Priority rationale (low)

Speculative/future enhancement; not blocking any current workflow. Urgency low, *value
potentially high* — pick up after the kimmy spike, as part of strengthening the dynamic-workflow
(Sagittarius).
