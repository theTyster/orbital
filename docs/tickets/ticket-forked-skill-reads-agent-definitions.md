---
id: forked-skill-reads-agent-definitions
title: Forked stage-skills should read agent-definition files before emulating specialists inline
status: triaged
priority: low
area: shifting
created: 2026-05-29
tags: [skill, agents, context-fork, inline-fallback, fidelity]
related:
  - experiments/pipeline-workflow/FINDINGS.md
  - plugins/shifting/agents/
  - docs/tickets/ticket-initialize-arg-substitution-and-wait.md
---

## Problem

The 2026-05-28/29 pipeline dogfood found (FINDINGS **F-2**) that staged `shifting:` skills
invoked via the `Skill` tool run as **forked executions without the `Agent` tool**, so they
cannot spawn their named specialist sub-agents (`lean-expert`, `agent-of-truth`, `prolog-prover`,
the adversaries, the `realize-*` trio, `verdict-extractor`, …). They fall back to doing the
specialist work **inline**.

The **2026-05-29 decision is to KEEP `context: fork`** on the skills (the Workflow path handles
delegation by calling named sub-agents directly per F-2(a); the forked skills are the simple,
isolated keep-alive path for direct plugin use). That decision is sound — but the inline-fallback
currently emulates a specialist from the **skill's own prose**, not from the specialist's **actual
agent-definition file**. So the emulation can drift from what the real specialist would do (its
role-brief, bias-defense discipline, halt conditions, output schema).

## Goal

When a forked stage-skill must perform a specialist's work inline (no `Agent` tool), it **reads the
relevant agent-definition file(s)** and follows them — so the inline emulation faithfully matches
the real specialist instead of improvising.

## Scope

- The inline-fallback branch of each staged `shifting:` skill that delegates to named specialists.
- Optionally a shared instruction in `trajectory:pipeline` (or a shifting reference doc) so the
  behavior is defined once rather than duplicated per-skill.

## Proposed fix

In each stage-skill's no-`Agent` fallback path, add an instruction of the form:

> If the `Agent` tool is unavailable (forked execution), **read the definition file(s)** for the
> specialist(s) this stage would otherwise delegate to — `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` —
> and follow their role-brief, bias-defense, and output discipline when performing the work inline.

Cite the exact specialist(s) per stage (e.g. `prove-invariants` → `lean-expert.md` + `lean-adversary.md`;
`close-world` → `agent-of-truth.md` + `kb-validator.md`).

## Non-goals

- **Not** un-forking the skills (settled: keep fork).
- **Not** the Workflow path — the Workflow calls named sub-agents directly (F-2(a)); this ticket is
  only about the *direct-plugin / forked* path's fidelity.

## Acceptance criteria

- [ ] A forked stage-skill, on the inline path, reads + cites the relevant specialist
      agent-definition file(s) before doing the work.
- [ ] The inline emulation visibly follows the agent-def's discipline (role-brief neutrality,
      minimum-context, output schema).
- [ ] Defined once (shared) or consistently across the staged skills.
- [ ] Re-validated with `plugin-dev:plugin-validator` after edits (authored under
      `plugin-dev:skill-development`).

## Priority rationale (low)

The pipeline already works forked — the dogfood succeeded (all 7 invariants proven, 24 tests green)
on the inline-fallback path. This is a **fidelity improvement** to that fallback, not a correctness
fix. Pick it up when polishing the direct-plugin path.
