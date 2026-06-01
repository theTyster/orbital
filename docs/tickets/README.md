# Tickets

Durable, prioritized backlog for the orbital marketplace.

## Why here (not `thoughts/`)

The earlier convention put tickets in `thoughts/` (`thoughts/ticket-*.md`, preserved
now in `thoughts.predogfood-bak/`). But `thoughts/` is **gitignored** *and* is the
orbital-shifting pipeline's scratch space — a pipeline or dogfood run rewrites it
wholesale. A backlog the pipeline can clobber is not a backlog. Tickets therefore live
under `docs/tickets/` (tracked, durable, survives pipeline runs), beside
`docs/superpowers/specs/`.

## File naming

One ticket per file: `ticket-<kebab-slug>.md`. Completed or superseded tickets move to
`docs/tickets/archive/` — keep the filename, never delete (historical record).

## Frontmatter — priority lives here

Priority is encoded in **frontmatter**, not in a per-priority directory: re-prioritizing
is a one-field edit rather than a file move (no broken links, no `git mv` churn), and a
single flat directory stays trivially globbable (`docs/tickets/ticket-*.md`).

```yaml
---
id: <slug matching the filename minus the `ticket-` prefix>
title: <one-line imperative summary>
status: backlog | triaged | in-progress | blocked | done | superseded
priority: high | medium | low
area: <plugin or component, e.g. mission-control, shifting, trajectory>
created: YYYY-MM-DD
tags: [<short keywords>]
related: [<ticket ids or file paths>]   # optional
---
```

### Priority

- **high** — blocks a user-visible workflow with no reasonable workaround, or a
  correctness bug that silently produces wrong results.
- **medium** — breaks a documented contract but has a workaround, or a latent footgun
  that will bite a fresh / unattended invocation.
- **low** — polish, ergonomics, nice-to-have, or speculative.

### Status lifecycle

`backlog` → `triaged` → `in-progress` → `done` (or `blocked` / `superseded`). A ticket is
**triaged** once it has a confirmed `priority`, a falsifiable acceptance-criteria list,
and a row in the index below.

## Triage

To *triage* a ticket: (1) confirm / assign `priority`; (2) ensure the body has concrete,
checkable acceptance criteria — no vague intents; (3) set `status: triaged`; (4)
add or refresh its row in the index table here. Re-triage = edit frontmatter + index row
in place.

## Body template

```
## Problem
## Repro & evidence      (when observed first-hand)
## Goal
## Scope
## Proposed fix          (concrete; cite file:line)
## Open questions
## Non-goals
## Validation
## Acceptance criteria    (checkbox list)
## Out of scope (future)
```

## Index

| id | title | priority | status | area | created |
|----|-------|----------|--------|------|---------|
| initialize-arg-substitution-and-wait | `mission-control:initialize` — `$N` arg-substitution collision + non-blocking `wait` | medium | triaged | mission-control | 2026-05-29 |
| forked-skill-reads-agent-definitions | Forked stage-skills read agent-definition files before emulating specialists inline | low | triaged | shifting | 2026-05-29 |
| constrain-adversary-write-access | Constrain adversary write-access to refutation/probe dirs only (never canonical proofs/KBs) | medium | triaged | shifting | 2026-05-30 |
| mutation-testing-in-pipeline | Mutation testing in the pipeline — ephemeral probes for faster proof↔code feedback | low | backlog | shifting | 2026-05-29 |
