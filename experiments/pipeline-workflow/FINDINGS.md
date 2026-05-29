# Pipeline-as-Workflow — Dogfood Findings

Findings from the end-to-end dogfood run (2026-05-28/29): `orbital-shifting` run on its own
design spec to build the pipeline-as-a-Workflow. The full artifact chain is persisted under
`self-spec/`; the plain-language account is `self-spec/explanation.md`. Outcome: **all 7 invariants
(I-1..I-7) proven axiom-free in Lean, all 24 TDD tests green, terminal adherence clean (0 Pattern 3
violations, 9/9 prescriptive, 7/7 descriptive, 100% structural).** The deliverable
(`orbital-pipeline.workflow.js` + `lib/` + `schemas/`) is built and verified.

These findings are requirements the **Workflow version** should fold in.

## F-1 — cwd-coupling (the HANDOFF-required finding) → Workflow takes an explicit project-root arg

The pipeline skills are **cwd-coupled**: they resolve `thoughts/`, `docs/`, and `.claude/` relative
to the session's project root. This is why the dogfood had to be run from a session rooted at
`/Users/ty/Projects/mine/orbital` (a mind-map-rooted session could not host them). The Workflow
version should take an **explicit project-root argument** and resolve every artifact path against it,
decoupling the pipeline from `cwd`. **Fold in as an additional requirement the Workflow satisfies.**

## F-2 — forked skill executions have no `Agent` tool → skills ran their inline-fallback path

Every staged skill invoked here via the `Skill` tool ran as a **forked execution that did NOT have
the `Agent` tool available**. `model-obligations`, `prove-invariants`, `instantiate-properties`,
`measure-entailment`, and `disprove-proposition` all reported this and fell back to their documented
inline path (doing the specialist work — prolog-prover, lean-expert, agent-of-questions,
lean-adversary, etc. — themselves rather than delegating). `realize-specification` instead loaded
inline into the orchestrator context, and the orchestrator delegated the build to a single
general-purpose sub-agent (budget-driven; the per-test choreography of ~5 agents × 24 tests was
infeasible in one context).

Implication for the Workflow: do **not** assume a `shifting:` skill driven from a workflow subagent
can itself spawn the named specialist sub-agents (this is exactly assumption **A-1** in the spec —
"skill-from-subagent" — and it came back **false** in this environment for the nested-`Agent` case).
The Workflow should either (a) call each stage's named sub-agents directly from the workflow script
(reproducing the orchestration in the substrate), or (b) confirm nested `Agent` availability in the
target runtime before relying on it. Record against A-1.

## F-3 — the verification has teeth: three real defects were caught and fixed by the pipeline's own gates

1. **Non-self-contained `target-world.pl` (model-obligations).** The emitted carrier's violation
   rules called `is_closer/1`, `stage_order/2`, `loop_limit/1`, `disprove_floor/2` — defined only in
   `existing-world.pl`. But `prove-invariants` reads `target-world.pl` as the **sole** carrier. The
   orchestrator's standalone-load gate caught it; a bounded loopback to `model-obligations`
   materialized those facts. Without the catch, 5 of 7 invariant verdicts were silently unasserted
   and the Lean theorems would have been grounded on absent facts. **Fix for the skill:**
   `model-obligations` must validate `target-world.pl` under a *standalone* consult, not co-loaded
   with `existing-world.pl`.

2. **Empty-export `:- module` wrapper on `lean_proof_results.pl` (prove-invariants).** The carrier
   was emitted with `:- module(lean_proof_results, []).` — inconsistent with all 4 sibling carriers
   (module-free) and with the schema, and it hid every fact from the downstream consult+query read
   path. Surgically removed; all facts re-verified queryable. **Fix for the skill:** `prove-invariants`
   should emit a module-free facts file matching the schema.

3. **I-3 termination proven VACUOUSLY (the headline).** The first Lean proof quantified the measure
   and step as *free* arguments and closed by `WellFounded.apply` — a tautology satisfied by a
   constant measure `(0,0)` and the identity (infinite no-op) step. A machine-checked, axiom-free
   counter-witness inhabited it (`self-spec/lean_disproofs/p_v1_i3.lean`). This is precisely the
   spec's **§8 "omitted transition ⇒ vacuous theorem"** risk. The mandatory **disprove gate**
   (D-6/I-6 floor) refuted it; an adjacent loopback re-stated I-3 over a **concrete two-move `Step`
   relation** (forward decreases cursor-distance; loopback decreases recovery-budget, bounded by
   `#keys × LOOP_LIMIT = 4`) with a `step_strictDecreasing` lemma, re-proved it axiom-free, and the
   degenerate witness now **fails to type-check**.

   **Lesson:** `lake build` + `#print axioms` *cannot* catch a vacuous-but-valid proof (the kernel
   proof was genuinely axiom-free). Only an adversary can. This is concrete evidence for **why the
   I-6/I-7 mandatory-disprove floor exists** and for **R-1 "automatic loopbacks are first-class."**
   The Workflow must preserve both: a guaranteed ≥1 disprove attempt, and the loopback machinery
   that consumes a refutation.

## F-4 — gatekeeper mtime-staleness false-positives after a loopback

The `check-chain.sh` artifact-chain hook flags downstream `.pl` files as STALE on an **mtime**
comparison. The I-3 loopback rewrote `target-world.pl` / `hypothesis.pl` *after* `model_results.pl`
was already written (a citation/sketch backfill), so the mtime ordering tripped a false STALE flag in
later stages (`instantiate-properties` and `explain` both reported it and worked around it via
ungated files / temp copies, without touching mtimes). Content was internally consistent throughout.
**Implication:** an mtime-based freshness gate is fragile under loopbacks (which legitimately rewrite
upstream artifacts after downstream ones exist). The Workflow's freshness check should be
**content/digest-based** (or loopback-aware), not mtime-based — and note this aligns with the spec's
**C-1 determinism** stance (no control decision should hinge on wall-clock, and mtime is wall-clock).

## F-5 — recommended next steps before pointing the Workflow at a real target (e.g. kimmy)

- **Re-attack C-2 against the now-realized substrate.** The disprove gate **abstained** on the C-2
  no-inversion claim pre-build (the Workflow didn't exist yet) and explicitly deferred a re-attack to
  after `realize-specification`. The realized `lib/digest-router.js` was spot-confirmed to branch
  only on agent-emitted digest fields (ignoring `artifactContent`), but a dedicated adversarial pass
  against the built orchestration loop is the proper close of that obstruction.
- **Fuller vacuity audit of I-1, I-2, I-4..I-7.** Only **I-3** received an adversarial vacuity probe
  (and failed it the first time). The other six were structurally non-vacuous on inspection (they
  bind concrete inductive model types and case-analyze real constructors, unlike I-3's free-measure
  trap), but none was adversarially probed. Run the disprove gate against each before going live.
- **Confirm nested-`Agent` availability** in the Workflow's target runtime (see F-2 / A-1) before
  relying on stage skills to spawn their specialist sub-agents.

## Status of the spec's own assumptions/risks

- **A-1 (skill-from-subagent):** came back **false** for the nested-`Agent` case in this environment
  (F-2). Inline-fallback covered it; the Workflow should call named sub-agents directly or verify the
  runtime.
- **A-2 (sandbox sibling import):** not exercised (the Workflow was built but not yet run inside the
  actual Workflow sandbox; the lib modules use plain CommonJS `require` of siblings).
- **Risk "close-world fidelity / vacuous theorem":** **materialized and caught** (F-3 item 3) — the
  mitigation (the disprove floor) worked.
- **Risk "Lean parallel memory":** not stressed — proofs were small and built against the prebuilt
  shared Mathlib clone with no rebuild.
- **Risk "inversion smell":** held (C-2 confirmed in the realized substrate; full re-attack deferred,
  see F-5).
