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

## Re-statement / pre-kimmy re-probe findings (2026-05-30)

Executing the MC-agreed pre-kimmy sequence (re-probes → model rebuild → re-prove → adversary re-run).
Updates F-5. The re-probes were run via the **Workflow tool** (dogfooding the deliverable's host).

### F-6 — C-2 regression-guard landed (re-probe 1a)

`foldDigest` (the pure assembler that replaced the lossy-projection AGENT) was realization-only +
untested. Promoted to a tested mechanic `lib/digest-fold.js` (verbatim-mirrored inline in
`realized/orbital-pipeline.realized.mjs` — 44-line body diff-clean) + lock-test
`self-spec/tests/digest_fold.c2_regression_guard.test.js` (8 tests, green). Locks the two C-2
violations the pre-build re-attack found: (a) `gapClass` is content-agnostic (a fixed constant
fallback) and NEVER derived from substrate identity (`__agentType`/stage) — it keys `withinLoopLimit`,
a control decision; (b) `coreObligation=true` forces halt even on a gap-routed result (hard-stop axis,
never demoted to a loopback). Plus: the verdict is carried verbatim or null, never derived. Closes the
C-2 regression-guard half of F-5 bullet 1.

### F-7 — behavioral tests are NON-VACUOUS (re-probe 1b) — with two thin-coverage caveats

Mutation-tested all 5 properties that went vacuous in Lean (I-1, I-3, I-4, I-5, I-6): for each, a
minimal genuine violation of the implementing mechanic was applied and the suite re-run. **All 5 have
≥1 dedicated test that turns RED under the violation** — so the behavioral layer is non-vacuous (no
double-false-green pairing vacuous proofs with thin tests). Caveats (thin *redundancy*, not
gate-failures — each still meets MC's "would actually FAIL on violation" bar):
- **I-1 hard-stop coverage rests entirely on `crit8`**; `explain_always_runs` (happy-path fixture) and
  `explain_is_terminal` (static query) are each individually thin for the hard-stop case.
- **I-4 sufficiency test `scope_narrowing_fact_absent` is fixture-thin** — its fixture
  (`target=1 < startIdx=3`) dodges a narrowing mutation; only the necessity test caught it.

Closes the BEHAVIORAL half of F-5 bullet 2 (the Lean re-statement is steps 2–4 of the sequence).

### F-8 — Workflow `isolation:'worktree'` LEAKED a mutation into the main tree (tool finding)

1b ran as a Workflow with `isolation:'worktree'` on 5 parallel mutation agents. Only **3** worktrees
were created for the 5 agents, and the **I-6 agent's mutation (commenting out `runMandatoryDisprove`)
LEAKED into the main-tree `orbital-pipeline.workflow.js`** — caught by a post-run determinism re-run
(24/24 → a deterministic 23/24 with `disprove_floor` red), reverted via `git checkout`, leftover
locked worktrees pruned. **Implication: `isolation:'worktree'` is NOT a reliable isolation guarantee
for parallel file-mutating agents in this runtime.** For the upcoming parallel Lean re-proofs /
adversaries (steps 3–4): do NOT rely on worktree isolation — FREEZE the shared `TargetWorld.lean`
(read-only) and have parallel agents write DISJOINT per-invariant files (`Proofs/I*.lean`,
`lean_disproofs/*`), which is conflict-free regardless of isolation, and verify the main tree after
every parallel batch. Directly relevant to kimmy: a mutation-heavy workflow must not assume isolation.

### F-9 — persisted test had a stale require path

`self-spec/tests/orbital_pipeline.proof_properties.test.js` required
`../../experiments/pipeline-workflow/orbital-pipeline.workflow.js` — valid only from the original
dogfood location (`thoughts/tests/`), broken from the persisted `self-spec/tests/`. Fixed to
`../../orbital-pipeline.workflow.js` (24/24 baseline restored). Implication: the persist step should
re-base relative import paths to the persisted location.

### F-10 — re-statement COMPLETE: all 7 invariants non-vacuous + adversary-survive

The model rebuild → re-prove → adversary re-run sequence is done (all via the Workflow tool). Outcome:
- `TargetWorld.lean` rebuilt NON-DEGENERATE: Run/DisproveAttempt → 2 inhabitants; StartIdx 3→1→0;
  varying Spend/Reserve; attempt-dependent Target/OwnOutput; RunAttempt over both runs; + CF predicates
  (`ReachesExplainCF`, `StartIdxCF1`, `SpendCF`, `TargetCF`, `RunAttemptCF`). Full `lake build` = 8259
  jobs, exit 0.
- I-1/I-4/I-5/I-6 re-proven non-vacuously (each with a CF necessity lemma); I-3 preserved (the proven
  template); I-2 preserved; I-7 extended for `a1`. I-5's reserve half was re-stated from the vacuous
  EXISTENTIAL (`∀a ∃s r …`) to the UNIVERSAL (`∀a s r, Spend a s → Reserve a r → r ≤ s`).
- ALL 7 adversaries RE-RUN over the frozen model → **7/7 SURVIVE** (the original vacuity/degenerate
  witnesses can no longer be inhabited; negations positively inhabited). 29 probes under
  `lean_disproofs/*_postrebuild*`.

Two SUPERVISION CATCHES — caught by orchestrator model-review + the full-build gate, NOT by the
per-stage adversary (which only attacked its own invariant):
- **I-1 D-8 inversion.** The rebuild made `ReachesExplain` non-total ("hard-stop r1 doesn't reach
  explain") — contradicting D-8 (explain runs on EVERY path; `crit8` + the implementation confirm) and
  making `i1_explain_always_runs` FALSE. Fixed: `ReachesExplain` total + `ReachesExplainCF` necessity
  witness. The I-4-only template-check adversary would NOT have caught this — orchestrator model-review
  is a necessary gate (the rebuild agent confidently mis-modelled the invariant).
- **I-7 `a1` cascade.** Adding `a1` to `DisproveAttempt` (for I-5/I-6) broke I-7's `∀ a` proof (a1 case
  unsolved). Caught by the FULL-library `lake build` (per-module builds had passed). A model change
  cascades to "preserved" invariants; the full build is the gate, not per-module builds.

HONEST RESIDUAL CAVEATS (the boundary of what the formal layer establishes):
- **CF-augmentation fidelity:** each necessity lemma's teeth rest on a CF predicate authored by
  constructor-omission (e.g. `ReachesExplainCF` omits r1); the teeth are only as strong as the
  modeller's fidelity — a standard CWA-augmentation caveat shared across I-1/I-4/I-5/I-6.
- **I-1 sufficiency antecedent is discardable BY DESIGN** (D-8 makes explain unconditional); non-vacuity
  is carried by the necessity lemma + the structural terminal half, not the bare implication.
- **I-2 by-fiat encoding:** Requires/StageOrder are constructor-faithful transcriptions; Lean confirms
  the chain is internally proper but cannot witness that the 7 edges mirror the implementation's actual
  runtime artifact dependencies — a translation/behavioral concern outside the theorem.
- Liveness verified over exactly 2 outcome classes (complete / hard_stop).

### F-11 — DEFERRED: target-world.pl shares the original I-1 / D-8 error (Prolog↔Lean divergence)

The Prolog model `self-spec/target-world.pl` still carries the ORIGINAL D-8 error the Lean just shed:
it has `op_reaches_step(r0, s_explain)` ONLY (omits r1) and frames I-1 as "every NORMALLY-terminating
run reaches explain" (`op_terminates(r0)`; `r1 = op_hard_stop`, excluded from the antecedent). This
contradicts D-8 (explain runs on every path, incl. hard-stop — the implementation + `crit8` confirm),
so the Prolog and (now-corrected) Lean models diverge on I-1. The faithful `.pl` fix: add
`op_reaches_step(r1, s_explain)`; add an `explain_skipped_on_hard_stop` CF (`cf_fact/2` +
`negation_provenance(_, contradicts)`) — minding the `.pl`'s cf-count validation `forall` (it currently
asserts over a fixed cf_fact set); and reframe the `i1_violation` rule so a HALTING run (normal OR
hard-stop) that fails to reach explain is a violation. DEFERRED: the `.pl` is the model-obligations
PROLOG layer (a separate verification path), NOT the Lean gate kimmy's formal NorthStar rests on; the
fix touches the `.pl`'s internal validation machinery and warrants a careful pass, not a momentum edit.

### KIMMY GATE — SATISFIED at the formal-verification layer

All 7 Lean invariants are non-vacuous + adversary-survive over a non-degenerate model. The flagship
Workflow no longer rests on hollow proofs. (Behavioral test layer confirmed non-vacuous in F-7; C-2
regression-guarded in F-6.) Remaining before a real kimmy run: the deferred `.pl` reconciliation (F-11,
non-blocking for the Lean gate) and operator/MC go on a concrete ticket.
