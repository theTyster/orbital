# Explanation

A plain-language account of a full, end-to-end run of the orbital-shifting
reasoning pipeline against *its own design document* — a "dogfood" run that used
the pipeline to build a piece of software described by that document, and to
verify the result before it is ever pointed at real work.

> Audience: a reviewer who is technical but does not read Lean or Prolog. Read
> this before the new Workflow is pointed at any real target (for example, a
> kimmy feature). Nothing below requires you to open a formal file.

---

## The short version (what was built, and can you trust it?)

We took a design document — a spec describing how the orbital-shifting pipeline
*itself* could be re-built as a single, automated, background-running program
(a "Workflow") — and we ran that document through the very pipeline it
describes. The pipeline read the document, formed a precise claim about it,
modeled that claim, **mathematically proved** seven core safety properties about
it, turned those proofs into automated tests, **wrote the actual program** to
pass those tests, and then scored how faithfully the finished program matches
the original claim.

The finished program lives at `experiments/pipeline-workflow/`. It is real,
runnable code: one main file (`orbital-pipeline.workflow.js`) plus nine small
supporting modules and a data-shape definition. All **24** of its automated
tests pass (independently re-run during this review — 24 passed, 0 failed, 0
skipped). All **seven** of its core safety properties are **proven
mathematically** by a proof checker, with no hidden assumptions.

**Can you trust it?** For what it actually claims, yes — and with unusually
strong evidence, because the pipeline's own adversarial checks *caught and fixed
three real defects during the run*, including one serious one. That last point
is the most important thing on this page: the verification is not a rubber
stamp. It found problems. The three defects, and how each was caught, are the
core of the "is this real?" question and are detailed below. The honest caveats:
the proofs are about the **control logic** (how the program decides what to do
next), not about the *content* of the work the program will eventually drive;
and a few claims are guaranteed only as strongly as the design document is
complete. Those are spelled out at the end under "What to check before kimmy."

---

## Context

### The problem being solved

Orbital-shifting is a multi-stage reasoning pipeline. Today it is driven by a
"smart" orchestrator (an AI skill running at high effort) that walks a ticket
through seven stages. The goal of this work was to **move that orchestration out
of a smart skill and into a plain, deterministic program** — a Workflow script —
so it can run in the background, on a fixed budget, resume if interrupted, and
crucially, *be formally verified itself*. A program's control flow can be proven
correct in a way a free-roaming AI skill cannot.

There is a sharp line the design insists on, because a previous attempt at this
was *rejected* for crossing it. The line is: **the program may do the bookkeeping
(sequencing the stages, counting budgets, routing requests), but it must never
make a judgment call itself** — never decide "this claim is proven" or "this is
refuted." Those judgments stay with the AI agents. The program is only allowed
to *read* a judgment an agent already made and act on it. The design calls this
"separation of authority"; the forbidden failure is called the "inversion smell."
Holding that line is the whole point, and it is the thing this review pays the
most attention to.

### Why formal methods were used

Two reasons. First, the design document deliberately wrote down its
*decisions and rules* rather than code, on the theory that "code changes; the
decisions about the code should be firmer." That makes the document an ideal
input to a pipeline that turns rules into proofs. Second, this run is the
**proof of concept for the pipeline itself**: if orbital-shifting can verify its
own design and build a working program from it, that is strong evidence it is
ready to be pointed at a real feature.

---

## What was done, stage by stage

The pipeline ran all seven stages in order, plus a mandatory adversarial
"disprove" challenge, plus this closing explanation. Here is the journey.

### 1. Reading the design into a structured map (close-world)

The first stage read the design document and turned every decision, constraint,
requirement, and invariant in it into a structured set of facts — a map of what
the design says (a Prolog knowledge base, `thoughts/existing-world.pl`). This
captured 13 firm decisions, 6 hard constraints, 7 invariants (the properties to
be proven), and 11 requirements. The key move here is the "closed-world"
assumption: anything the document does *not* say is treated as false. The map
also recorded, for each "this must never happen" rule, whether the document
**explicitly forbids it** (a strong, deliberate negation) versus merely **never
mentions it** (a weak, "we just didn't see it" absence). That distinction
matters later, and the pipeline tracked it carefully.

### 2. Forming a precise, testable claim (decompose-proposition)

The second stage took the document's central proposition — *"the seven-stage
pipeline can be rebuilt as one deterministic, background-runnable Workflow that
preserves its seven invariants, runs stages in parallel where safe without
losing determinism, can verify itself, and does not cross the separation line"* —
and broke it into 26 individually-checkable claims (recorded in
`thoughts/hypothesis.pl`). These claims come in three flavors, and the
difference in flavor is the difference in how much you can trust each one:

- **7 "descriptive" claims** — things the design already asserts (for example,
  "orchestration is a Workflow, not a skill"). These are simply restatements of
  the design's own decisions.
- **10 "counterfactual" claims** — things that must be *false* in the finished
  program for the proposition to hold (for example, "no control decision depends
  on a clock or a coin flip"; "the program never computes a verdict itself").
  Notably, all 10 of these correspond to rules the document **explicitly
  forbids** — so their falseness is structurally required, not a fragile "we
  didn't notice it" absence.
- **9 "prescriptive" claims** — things that must *become true* through proof or
  through building the program (the seven invariants, which must be proven; plus
  "the Workflow comes to exist on disk" and "this verification run completes").
  These two existence claims were the only ones resting on a weak "not yet true,
  must come true" footing.

### 3. Building the model to verify against (model-obligations)

The third stage built a working model of the *target* world — the world in which
the proposition holds — and checked each of the seven invariants against it
(`thoughts/target-world.pl` and `thoughts/model_results.pl`). The verdict: all
seven invariants are **consistent** within the model — there is no contradiction;
the proposition *can* be realized as written. Importantly, the stage also
confirmed each check was **non-vacuous**: for every "this must hold" rule, it
deliberately fed in a broken example and confirmed the rule actually rejects it.
A rule that accepts everything proves nothing; these rules were shown to bite.

This stage is also where the **first defect** was caught — see the defects
section below.

### 4. Proving the seven invariants mathematically (prove-invariants)

The fourth stage is the strongest link in the chain. It translated each of the
seven invariants into a formal theorem and proved it with the Lean proof checker
(`thoughts/lean/Proofs/*.lean`, with verdicts recorded in
`thoughts/lean_proof_results.pl`). The proof checker mechanically verifies every
logical step; if it accepts the proof, the property holds **for all possible
inputs**, not just for tested examples. All seven invariants were proven, and a
follow-up check confirmed **none of the proofs lean on any unproven assumption or
shortcut** ("axiom-free"). In plain terms: these seven properties are guaranteed
mathematically, the strongest level of assurance this pipeline produces.

The seven proven properties are:

- **I-1 (explain always runs):** every path through the program that finishes
  ends by producing a plain-language explanation. No run can silently skip it.
- **I-2 (artifact gating):** no stage ever runs before the upstream work it
  depends on exists.
- **I-3 (termination):** the program's main loop always halts — it cannot spin
  forever. *(This is the proof that was attacked and re-done; see below.)*
- **I-4 (scope only widens):** once the program decides to revisit work, its
  working scope can only grow, never shrink, mid-run.
- **I-5 (disprove stays within bounds):** the adversarial challenge never spends
  below its reserved budget and never attacks its own output.
- **I-6 (disprove runs at least once):** every run performs at least one
  adversarial challenge.
- **I-7 (disprove fans out):** every adversarial challenge uses at least two
  independent challengers, run in parallel.

This stage also recorded one important honesty point. The two "existence" claims
from stage 2 (the Workflow exists; the run completed) were **deliberately not
turned into proofs**. They rest on a "we didn't see it, so it's absent" footing,
and the pipeline's discipline is that a "didn't see it" absence must never be
laundered into a mathematical proof. They were verified separately, directly, as
facts about the world — not proven as theorems.

This stage is also where the **second defect** was caught, and it was the trigger
for catching the **third (and most serious) defect** in the disprove gate.

### 5. Turning proofs into automated tests (instantiate-properties)

A mathematical proof covers all inputs but does not, by itself, run against the
actual code. The fifth stage converted each proven property into concrete
automated tests that *sample* the property at specific inputs and check the real
program against it (`thoughts/tests/orbital_pipeline.proof_properties.test.js`,
24 tests). It is worth being precise about what these tests are: they are
**tripwires, not the guarantee**. The universal guarantee lives in the Lean
proofs; each test checks that the real code behaves correctly at a particular
spot. Most tests (the seventeen tagged "projection") sample a proven property;
the rest (tagged "behavioral") check operational behaviors — like "the program
never reads a clock to make a decision" — that the proofs did not directly
express. The distinction is tracked so no one mistakes a passing behavioral test
for a mathematical proof.

### 6. Building the program to pass the tests (realize-specification)

The sixth stage wrote the actual Workflow program, one test at a time, driving
the whole suite from all-skipped to all-passing
(`experiments/pipeline-workflow/`, with a running record in
`thoughts/implementation_log.md`). The result is the deliverable under review:
the orchestration loop plus pure, separately-testable mechanics for scope,
budget, the termination measure, stage ordering, gap batching, the loop limit,
digest routing, and the decision trail. The effectful parts (the AI agent, the
clock, the random-number source) are *injected* from outside, which is what lets
the tests substitute fakes and what lets the program prove it never lets a clock
or coin flip influence a control decision.

### 7. Scoring how faithfully the program matches the claim (measure-entailment)

The final stage compared the finished program against the original 26-claim
proposition and scored the match (`thoughts/adherence_report.md`). The result:

- **0** "Pattern 3" violations — not one of the 10 forbidden facts leaked into
  the code.
- **9 / 9** prescriptive obligations satisfied — the seven invariants are
  machine-checked green, and the two existence claims are now resolved (the
  Workflow exists; this run completed).
- **7 / 7** descriptive design decisions realized in the source.
- **100%** structural match, with **0** real contradictions. (The automated
  comparison flagged 8 apparent contradictions; all 8 were confirmed to be
  false alarms from a tool that does not understand a field can legitimately
  hold a *set* of values — both sides held identical sets.)

In short, the implementation faithfully entails the original proposition.

---

## The three defects the pipeline caught and fixed (why the verification is real)

This is the section to read closely. A verification pipeline that never finds
anything is indistinguishable from a rubber stamp. This run found three genuine
problems and corrected each before declaring success. Two were caught by the
pipeline's structural gates; the third — the serious one — was caught only
because an adversary was deliberately sent to attack the work.

### Defect 1 — A model that secretly depended on a file the prover wouldn't see

When stage 3 first built the target-world model, the model's "this must never
happen" rules quietly referenced facts (the stage ordering, the loop limit, the
disprove floors, and which stage is the closer) that lived only in the *previous*
stage's file. On their own, those rules were ungrounded. The orchestrator's gate
caught this by loading the model file **by itself** — exactly the way the proof
stage (stage 4) would later load it — and noticing the missing references. A
short, bounded "loopback" re-ran stage 3 and copied those facts directly into the
model file so it stands alone.

**Why it mattered:** without the catch, five of the seven invariants would have
been "proven" against a model that was missing the very facts those proofs needed
to be meaningful. The fix made the model self-contained, and the stage
re-confirmed that loading it alone leaves nothing undefined.

### Defect 2 — A results file wrapped so that nothing downstream could read it

When stage 4 first wrote its proof-results file, it wrapped the file in a
declaration that **exported nothing** — inconsistent with every sibling file in
the pipeline and with the file's own schema. The downstream stages read these
files by loading them and asking questions; an empty-export wrapper would have
hidden every proof verdict from them, silently. The wrapper was surgically
removed and every verdict confirmed readable again.

**Why it mattered:** the proofs were fine, but their *results* would have been
invisible to the stages that depend on them — a silent break in the chain.

### Defect 3 — THE BIG ONE: the termination proof was technically valid but proved nothing

This is the defect that justifies the whole exercise.

After the proofs were done, the pipeline ran its **mandatory adversarial
challenge** — a step that deliberately tries to *break* the run's riskiest
claims. It sent two independent challengers (a requirement: at least two, with
different perspectives) at the two riskiest targets: the termination proof
(I-3), and the "no inversion" separation claim.

The challenger attacking **I-3 (termination)** found that the original proof,
while accepted by the proof checker, was **vacuous** — it proved a tautology. The
original theorem had been stated so loosely that it left the "measure" (the thing
that's supposed to shrink each step) and the "step" (the thing the program
actually does) as free, unconstrained stand-ins. The challenger demonstrated this
by *inhabiting the theorem* with a deliberately broken pair: a measure that never
changes, paired with a step that does nothing at all — a literal infinite no-op
loop. The original "termination proof" happily accepted this non-terminating
program. In other words, the proof was true, but it was the **wrong theorem**: it
established "a certain ordering is well-founded" (a generic math fact), not "this
program's loop actually halts." This is precisely the "vacuous theorem" risk the
design document itself warned about. The challenger's counter-example was itself
a fully machine-checked, assumption-free proof — concrete, not hand-waved.

The response was a "loopback": stage 4 **re-stated I-3 over a concrete model of
what the program actually does** — a real transition relation with exactly two
moves (a forward step that shrinks the distance to the end; a loopback step that
consumes one unit of a recovery budget that is *finitely* bounded by the number
of recovery points times the loop limit, which works out to 4). It then proved a
key lemma that *every* such move strictly shrinks the measure, and proved
termination from that. The re-done proof is again machine-checked and
assumption-free — but now it is the *right* theorem, and the old broken no-op
witness **no longer type-checks**: the program literally cannot express a
"do-nothing" step anymore. Two regression checks were folded in to keep it that
way.

**Why this is the headline:** the routine checks the proof stage already runs
(does it build? does it avoid shortcuts?) **could not have caught this** — the
vacuous proof passed both cleanly. Only an adversary actively trying to break the
claim could expose that a valid proof was meaningless. This is the design's
"automatic loopbacks are first-class" requirement and its "mandatory adversarial
floor" requirement *working on a real defect, in the run that built the tool* —
the single strongest piece of evidence that the verification here is substantive.

---

## The "no inversion" line held — and there is a recommended next check

The separation line (the program must never compute a judgment itself, only read
one an agent made) was the other thing the adversary attacked. Against the
*design*, the adversary **abstained** — it could find no control decision the
program must make by computing a verdict itself; every branch reads a field an
agent already filled in. It abstained rather than clearing the claim outright for
an honest reason: at the time of the attack, the program did not yet exist, so a
deeper attack had nothing concrete to bite.

Now that the program *does* exist, the finished code confirms the line held: the
routing function (`lib/digest-router.js`) branches only on the agent-emitted
fields of a structured "digest" (status, gaps, a core-obligation flag), and the
data-shape definition pins an explicit allowlist of routable fields. The router
**deliberately ignores** the actual content of the work product — re-judging that
content is exactly the forbidden inversion, and a comment in the code marks the
spot. Determinism holds for the same reason: the clock and random-number source
are passed in but are threaded only to the agent surface, never into a control
decision, and a dedicated test proves two runs with different clocks and
different random values produce an **identical** decision trail.

**Recommended next step:** the adversary's deferred re-attack on the separation
claim should now be run against the *realized* program (not just the design), to
confirm under active attack what source inspection already shows — that no branch
in the finished code derives a verdict from raw stage output. This is a known,
named follow-up, not a gap that blocks use.

---

## What we know now

Sorted by strength of evidence — strongest first. The buckets are not
interchangeable, and the difference is the whole point of this pipeline.

- **Proven mathematically, for all inputs (strongest).** The seven invariants
  I-1 through I-7: explain always runs; no stage runs before its inputs exist;
  the control loop always halts (re-proven correctly after the vacuity defect);
  scope only widens; the adversarial challenge stays within its budget and never
  self-attacks; it runs at least once; it fans out to at least two parallel
  challengers. All machine-checked, all with no hidden assumptions.

- **Verified exhaustively within the model.** The seven invariants are also
  consistent in the Prolog model, with each consistency verdict confirmed
  non-vacuous (each rule was shown to reject a deliberately broken example).

- **Sampled by passing tests (a tripwire, not the guarantee).** All 24 automated
  tests pass. Seventeen sample a proven property at specific inputs; the
  universal guarantee for those lives in the proofs, and the tests are tripwires
  that would catch a regression in the code.

- **Asserted by passing tests, with no proof behind them (weaker — scrutinize).**
  Seven "behavioral" tests check operational behavior the proofs did not express
  — most importantly, determinism (different clock and random inputs yield an
  identical decision trail) and the hard-stop paths. A green here means the test
  case passed on this run, not that the behavior is mathematically guaranteed.

- **Verified directly as facts, but never proven as theorems (weakest — by
  design).** The two existence claims — "the Workflow now exists on disk" and
  "this self-verification run completed" — were true at the end of the run and
  recorded as such, but were deliberately kept out of the proof system because
  they rest on a "we didn't see it, so it's absent" footing. Treat them as
  confirmed observations, not guarantees about all future runs.

---

## What this means for a reviewer — and what to check before kimmy

**What you can lean on hardest:** the seven invariants. "Proven" here means
mathematically certain for all inputs, not merely "tested" — and the termination
proof in particular survived a deliberate, machine-checked attack and was
strengthened as a result. The separation line (no inversion) is confirmed by both
the design-stage adversary and by inspection of the finished code. Determinism is
confirmed by a passing test. Zero forbidden facts leaked into the implementation.

**What deserves your scrutiny before this is pointed at a real feature:**

1. **The proofs guarantee the control flow, not the work.** Everything proven is
   about *how the program decides what to do next* — it halts, it gates correctly,
   it always explains, it always challenges itself. None of it speaks to the
   *quality of the reasoning the program will drive* on a real ticket. The
   Workflow is a trustworthy conductor; it makes no promise about the music. When
   it is pointed at a kimmy feature, the kimmy feature's own correctness is a
   separate question this run does not address.

2. **Two claims are only as strong as the design document is complete.** The
   "existence" claims rest on closed-world absence, and more broadly, every proof
   is only as faithful as the design model it was built from — the document
   itself flagged that "an omitted transition yields a vacuous theorem." That
   exact risk *materialized* (defect 3) and was caught — but it was caught for
   I-3 specifically because an adversary went looking. The other six invariants
   were not subjected to the same vacuity attack. Before a high-stakes run, it is
   worth considering whether the other invariants deserve the same adversarial
   vacuity probe I-3 received.

3. **Run the deferred separation re-attack against the real code.** The
   adversary's challenge to the "no inversion" line abstained because the code
   didn't exist yet. The code exists now. Running that attack against the realized
   program is the recommended next step before going live — to confirm under
   active attack what inspection already indicates.

4. **The Workflow is an experiment, by design.** It lives self-contained under
   `experiments/pipeline-workflow/` and is deliberately *not* wired into the
   canonical pipeline. Pointing it at kimmy is the intended next trial; promoting
   it to replace the existing orchestrator is a separate, later decision.

None of these is a defect. They are the honest edges of what a control-flow
verification can and cannot tell you. Within those edges, this is a strong
result: a working program, seven machine-checked safety guarantees, a clean
adherence score, and — most tellingly — a verification process that proved it has
teeth by catching three real problems, one of them serious, before anyone called
the work done.

---

## Where the stages stand

All seven pipeline stages ran, plus the mandatory adversarial challenge, plus
this explanation (the always-runs closer). One stage (proof) was revisited once
via an automatic loopback to repair the termination proof after the adversary
refuted its first form. No stage was skipped; no stage is outstanding. The one
explicitly deferred item is the separation re-attack against the now-realized
code, noted above as the recommended next step.

### Artifacts this explanation is drawn from

- `docs/superpowers/specs/2026-05-28-pipeline-as-workflow-design.md` — the design
  document that was the input to the whole run.
- `thoughts/existing-world.pl` — the design read into a structured map (stage 1).
- `thoughts/hypothesis.pl` — the 26-claim precise proposition (stage 2).
- `thoughts/target-world.pl`, `thoughts/model_results.pl` — the model and its
  consistency verdicts (stage 3).
- `thoughts/lean/Proofs/*.lean`, `thoughts/lean_proof_results.pl` — the seven
  machine-checked proofs and their verdicts (stage 4).
- `thoughts/disproof_results.pl`, `thoughts/counterexamples.pl`,
  `thoughts/lean_disproofs/p_v1_i3.lean` — the adversarial challenge, including
  the machine-checked counter-example that refuted the first termination proof.
- `thoughts/tests/orbital_pipeline.proof_properties.test.js`,
  `thoughts/tests/manifest.pl` — the 24 automated tests (stage 5).
- `experiments/pipeline-workflow/` — the finished Workflow program (stage 6):
  `orbital-pipeline.workflow.js`, `lib/*.js`, `schemas/stage-digest.schema.js`.
- `thoughts/implementation_log.md` — the build record (stage 6).
- `thoughts/adherence_facts.pl`, `thoughts/adherence_report.md` — the final
  faithfulness score (stage 7).
