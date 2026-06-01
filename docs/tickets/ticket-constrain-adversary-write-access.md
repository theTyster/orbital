# Ticket: constrain adversary write-access to refutation dirs only

**Priority:** medium
**Status:** open
**Filed:** 2026-05-30
**Area:** plugins/shifting (lean-adversary, prolog-adversary) + the realized pipeline disprove briefs

## Problem

Adversary specialists run with broad Write/Edit access and have twice written outside
their proper output area:

1. **Canonical-proof pollution (dogfood).** During the pre-kimmy vacuity audit, the
   `lean-adversary` agents — which only need to author refutation/probe files — registered a
   probe `import` in the canonical `Proofs.lean` aggregator and dropped probe modules
   (`AdvProbeI5.lean`, `I6VacuityProbe.lean`) into the `Proofs/` source tree. This was
   reverted (`git checkout -- Proofs.lean` + `rm`), with the witnesses preserved under
   `lean_disproofs/`. A canonical proof library should never be mutated by an adversary.

2. **Worktree-isolation leak (FINDINGS F-8).** A mutation agent run under the Workflow tool's
   `isolation:'worktree'` leaked an edit into the **main tree** (only 3 worktrees were created
   for 5 agents). Independent of the agent type, this shows isolation is not a reliable guard;
   the write-SCOPE must be constrained at the agent/brief level, not assumed from isolation.

## Fix

Constrain adversaries to write ONLY to refutation/probe directories, never to canonical
artifacts:

- **`lean-adversary`** → may write under `thoughts/lean_disproofs/` (and the persisted
  `self-spec/lean_disproofs/`) and `thoughts/refutations/`. NEVER under `Proofs/`,
  `lean/Proofs/`, the `Proofs.lean` aggregator, `lib/`, or any source-of-truth file.
- **`prolog-adversary`** → may write under `thoughts/refutations/` / the counterexample
  files only. NEVER the canonical KBs (`existing-world.pl`, `hypothesis.pl`,
  `target-world.pl`) or `lib/`.

Implement at two layers:
1. **Agent definitions** (`plugins/shifting/agents/lean-adversary.md`,
   `plugins/shifting/agents/prolog-adversary.md`): add an explicit WRITE-SCOPE constraint to
   each system prompt — "you write refutation/probe files under <dir> ONLY; you must never
   edit canonical proof/KB/source files; to demonstrate a counterexample, author a NEW probe
   file, do not modify the artifact under attack."
2. **The realized pipeline disprove briefs** (`experiments/pipeline-workflow/realized/…` +
   any workflow that dispatches adversaries): repeat the constraint inline (already done in
   the `template-check-i4` workflow's adversary brief — "write probe files under
   `self-spec/lean_disproofs/` ONLY; NEVER edit canonical Proofs/ files"). Make it standard.

## Note (use plugin-dev)

Editing the agent definitions under `plugins/shifting/agents/` is a plugin-component change —
route it through the `plugin-dev:*` skills + validators, and halt for the mind-map
philosophical-completeness pass before committing (project conventions).
