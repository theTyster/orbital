# Epistemic Types for the Logic-Focused Pipeline

This document is the canonical reference for the *typed artifact system* used across the logic-focused pipeline. Every claim that flows from one skill to another carries an epistemic tag that records its origin, its strength, and what was preserved or lost when it crossed a boundary. Boundary skills MUST preserve these tags — treating a CWA-negation as a Lean-proof, or a Lean-universal as a test-verified fact, is a category error the tag system exists to prevent.

## The three-node ontology

The pipeline has three distinct reasoning systems. Each is strong in a different dimension. Each weakness becomes the motivation for the next node.

| Node | Strong on | Weak on | Negation semantics |
|---|---|---|---|
| **Prolog** | *what is* — deterministic, closed, contradiction-native over a finite KB | generality beyond the KB; cannot reason about state it was never told about | `\+ P` = "not derivable" under closed-world assumption (CWA) — absence, not falsity |
| **Lean** | *what must be* — universal, constructive, ∀-quantified over arbitrary types | purely logical; cannot reason about side effects, I/O, state mutation, timing, concurrency | `¬ P` = logical negation — a theorem `¬P` proves P is inconsistent with axioms |
| **TDD** | *what does* — behavioral, imperative, implementation-bound, can assert against runtime | no universality — every assertion is over a specific fixture; no automatic generalisation | a failing test = implementation-does-not-satisfy-property-on-this-fixture, not ¬property |

The skills that cross between these nodes are the **edges of the ontology**. An edge must encode four facts about every claim that crosses it:

1. **What survived the crossing** (preserved strength)
2. **What was weakened** (downgraded but still present)
3. **What was lost entirely** (provenance stripped, distinction flattened)
4. **What new claims the destination introduces** (claims with no upstream backing)

## The epistemic tag vocabulary

Every claim carried by a pipeline artifact (`hypothesis.md`, `proof_results.md`, a Lean theorem, a generated test) must carry one or more of these tags. Tags compose — a claim can be `LEAN_UNIVERSAL + CWA_LIFTED` to mean "Lean proved it universally, but one of the premises was lifted from a CWA-negation and therefore the theorem is only as strong as the KB's completeness assumption."

### Origin tags (where did this claim come from?)

- **`KB_PRESENT`** — Derived positively from asserted Prolog facts. Strong: the KB contains the witnessing fact. Limit: only as accurate as the KB.
- **`KB_ABSENT_CWA`** — The fact was *not derivable* from the KB under closed-world assumption. `\+ fact` succeeded. This is a **weak negation** — it says "the KB didn't mention this," not "this is logically false." If the KB is incomplete, a CWA-negation can be wrong without anyone noticing.
- **`KB_CONTRADICTED`** — The KB asserts `¬fact` directly, or derives `false` from assuming `fact`. This is a **strong negation** — the fact is incompatible with what the KB explicitly claims. Rare but precious; prefer over CWA when available.
- **`LEAN_UNIVERSAL`** — Proven by Lean for all inputs of the quantified type. `∀ x : T, P(x)` holds by construction. Strongest form of generality available in this pipeline.
- **`LEAN_CONDITIONAL`** — Proven by Lean under an explicit hypothesis (`A → B`). The consequent holds whenever the antecedent does — but the antecedent itself may carry its own tags (it may be `KB_PRESENT` or `CWA_LIFTED`).
- **`LEAN_CWA_LIFTED`** — A Lean theorem whose premises include propositions that originated as CWA-negations in Prolog. Lean sees `¬depends_on(cli_tool, logging)` as a logical claim, but it entered Lean's language through a closed-world gap in the KB. **Lean cannot detect this provenance; the skill that does the lift must preserve it in a comment and in `proof_results.md`.**
- **`PROLOG_MODEL_VERIFIED`** — A Prolog directive exhaustively searched for a counterexample in the KB and found none. Verified against the model, not against all possible models — still stronger than `KB_PRESENT` because it is the result of a search, not a lookup.
- **`TEST_PROJECTED`** — A test that witnesses a proven universal at a specific fixture. The proof is the authority; the test is a sample. Green means the fixture satisfies the property; it does NOT mean the property was re-proven.
- **`TEST_BEHAVIORAL`** — A test that asserts something no upstream proof backs: I/O behaviour, state mutation, timing, concurrency, side effects. First-class claim in the TDD layer, but no formal guarantee — a failing behavioral test cannot loop back to `hypothesize` or the prove skills, because those nodes never expressed the claim.
- **`TEST_ABSENCE`** — A test that asserts a counterfactual fact is absent (e.g., "no import from cli_tool to logging"). Carries two weaknesses: inherits `CWA_LIFTED` if the counterfactual came from a CWA-negation, AND is sampled at a specific source location (grep at this file, not a proof over the entire dependency graph).
- **`TEST_GUARD`** — A test that re-introduces a counterfactual at runtime (or in a fixture) and asserts the invariant breaks. Behavioral witness that the counterfactual was load-bearing — pairs with a `LEAN_CONDITIONAL` necessity lemma upstream.
- **`ASSUMED_UNPROVEN`** — The hypothesis or proof marked this as taken-as-given. Downstream artifacts MUST propagate this tag; skipping it silently upgrades an assumption to a proof.

### Strength ordering (for `explain` and for escalation decisions)

From strongest to weakest:

1. `LEAN_UNIVERSAL` (constructive, ∀)
2. `KB_CONTRADICTED` + `PROLOG_MODEL_VERIFIED` (KB-grounded, exhaustive in the model)
3. `LEAN_CONDITIONAL` (∀ under a hypothesis — as strong as the hypothesis)
4. `LEAN_CWA_LIFTED` (∀ under a CWA premise — the universal is only as strong as KB completeness)
5. `KB_PRESENT` (asserted, not searched)
6. `KB_ABSENT_CWA` (not derivable, not contradicted)
7. `TEST_PROJECTED` (sampled witness of a stronger claim)
8. `TEST_GUARD` (sampled witness of a conditional necessity)
9. `TEST_ABSENCE` (grep-scoped witness of `KB_ABSENT_CWA`)
10. `TEST_BEHAVIORAL` (no upstream backing — strength is exactly "the fixture passed")
11. `ASSUMED_UNPROVEN` (untested marker; not a claim, a gap)

## The edge semantics

Each boundary-crossing skill carries explicit loss/gain obligations.

### `translate-to-prolog` edge: source code → Prolog

- **Preserved**: declared relationships, structural dependencies, named entities
- **Lost**: runtime behaviour, state transitions, timing, I/O, concurrency
- **Introduced**: CWA default — every fact not asserted becomes `KB_ABSENT_CWA` by default

### `hypothesize` (internal to Prolog node, but produces the first typed artifact)

- **Preserved**: what the KB says (positively and negatively)
- **Introduced**: counterfactual enumeration. Each counterfactual requirement must be tagged:
  - If the existing KB contains the fact → `KB_PRESENT` (the counterfactual asks us to falsify it)
  - If the existing KB does not contain the fact → `KB_ABSENT_CWA` (weaker: absence may be KB incompleteness)
  - If the KB explicitly contradicts the fact → `KB_CONTRADICTED` (strongest; the fact cannot be reintroduced without making the KB inconsistent)

### `prove-hypothesis-lean` edge: Prolog hypothesis → Lean proof

- **Preserved**: logical structure of the property (∀, ∃, →, ¬)
- **Weakened**: nothing inherently, but Lean's `¬P` is *logically* stronger than Prolog's `\+ P`. **Lifting a CWA-negation into Lean overstates it unless the provenance is carried in a comment.**
- **Lost (if not actively preserved)**: CWA provenance. Lean cannot distinguish a theorem with a genuinely false premise from one with a CWA-absent premise. The skill MUST tag each such theorem as `LEAN_CWA_LIFTED` and record the lift in both the `.lean` source (as a docstring or comment block) and in `proof_results.md` (as a header field).
- **Introduced**: universal quantification. A Lean-proven property for `∀ x : Module, P(x)` holds for *all* modules, not just those in the KB. When the quantified type is larger than the KB's domain, this generalisation is real new strength — but only if the definitions were set up honestly (quantifying over the actual open set, not over the KB's finite enumeration).

### `prove-hypothesis-prolog` edge: hypothesis → Prolog model check

- **Preserved**: CWA provenance is native to the node; no lift is required. But the skill should still distinguish in `proof_results.md` whether a verified property depended on `\+` (CWA-bound) or on explicit negative facts (CWA-free).
- **Introduced**: exhaustive model verification — upgrades `KB_PRESENT` / `KB_ABSENT_CWA` claims to `PROLOG_MODEL_VERIFIED` within the current KB.

### `translate-to-tests` edge: Lean or Prolog proof → TDD suite

- **Preserved**: the proof reference. Each projected test cites its source property.
- **Weakened — the sampling downgrade**: universality is lost. `∀ x, P(x)` becomes `P(specific_fixture)`. A green test is a witness, not a re-proof. Every test must record which quantified domain it samples and what values of that domain it does NOT cover.
- **Lost**: the ability to re-verify the full strength of the proof. The suite is a tripwire, not a reproduction.
- **Introduced**: behavioral claims. Tests can assert I/O, state, timing, async ordering — things Lean never touched. These are `TEST_BEHAVIORAL` and must be listed separately in the output; they have no upstream backing.
- **Carried through from conditional mode**: `TEST_ABSENCE` tests inherit `CWA_LIFTED` when their counterfactual came from a CWA-negation — doubly weak (sampled location + absence-based). `TEST_GUARD` tests witness that a removed counterfactual was load-bearing.

### `translate-to-implementation` edge: TDD suite → source code

- **Preserved**: the test-to-property link via the implementation log.
- **Introduced**: behavioral tests that fail cannot loop back to upstream stages — there is no upstream property to revise. Loopback classification must include "behavioral test, no formal revision possible, decide in TDD layer."

### `explain` edge: any stage → plain-language narrative

- **Obligation**: translate epistemic tags into calibrated plain-language confidence statements. The reader should know whether a claim is "proven for all inputs" (`LEAN_UNIVERSAL`), "checked exhaustively in our model" (`PROLOG_MODEL_VERIFIED`), "assumed because the KB didn't contradict it" (`KB_ABSENT_CWA`), "witnessed by a specific test case" (`TEST_PROJECTED`), or "asserted behaviourally but not formally proven" (`TEST_BEHAVIORAL`). Flattening these into "proven" is the failure mode.

## How skills should emit and consume tags

- **Emit**: every artifact a skill writes (hypothesis, proof results, Lean source, test file, implementation log) must tag each claim. Use a YAML-ish `origin:` line, a comment block, or a Markdown bold field — the specific format is per-skill, but the vocabulary is this document's.
- **Consume**: when a skill reads a prior artifact, it must propagate tags forward. Never emit a downstream claim with a stronger tag than its weakest upstream input. Adding strength mid-pipeline is how CWA-negations silently become "proven."
- **Never flatten**: when translating a claim into a different artifact's format (e.g., a Lean theorem becoming a test), the tag must travel with the claim. A `TEST_PROJECTED` test that samples a `LEAN_CWA_LIFTED` theorem is still CWA-lifted — record it.

## Failure modes this system is designed to catch

- **CWA-as-truth**: Treating `\+ depends_on(A, B)` as a proof that A does not depend on B. It is a proof that the KB does not *say* A depends on B.
- **Universal-as-tested**: Treating a green test suite as re-verifying the upstream proof. Green means "the implementation passed the sampled witnesses." The proof is still the authority on universality; the suite is a tripwire.
- **Behavioral-as-formal**: Treating a behavioral test as though it were backed by a proof. A green behavioral test means the fixture passed on this run. It does not mean the behaviour is guaranteed for other inputs, other timings, or other environments.
- **Loopback-to-wrong-stage**: Failing a behavioral test and looping back to `hypothesize`. The hypothesize/prove stages never expressed a behavioral claim — there is nothing to revise upstream. The fix lives in the TDD layer or in a manual decision.
- **Silent upgrade across a boundary**: Stripping a `CWA_LIFTED` tag when translating into Lean, or a `TEST_PROJECTED` tag when translating into implementation. Each strip is a category error that compounds downstream.
