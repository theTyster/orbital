import Proofs.TargetWorld
import Proofs.I7Fanout

/-!
# I-7 VACUITY RE-ATTACK over the FROZEN rebuilt model — VERDICT: SURVIVES

Target (frozen `Proofs/I7Fanout.lean`):
  i7_disprove_fans_out :
    ∀ a : DisproveAttempt,
      (∃ x y : Adversary, AttemptAdversary a x ∧ AttemptAdversary a y ∧ x ≠ y)
      ∧ AdversariesParallel a

The non-degenerate rebuild quantifies I-7 over BOTH attempts (`a0`, `a1`) and
`AttemptAdversary` now carries four constructors (a0→adv1, a0→adv2, a1→adv1,
a1→adv2). The vacuity question: is the ≥2 fan-out floor (`∃ x y, … ∧ x ≠ y`)
real for EACH attempt, or can a degenerate one-adversary world satisfy it?

This file is the SURVIVAL build-matrix:

  * SHOULD_FAIL probes (the degenerate/vacuity witnesses) — documented below as
    the COMMENTED forms; each was compiled in isolation with
    `lake env lean` and REJECTED by the kernel (see EXIT codes in the
    per-probe notes). Their failure to inhabit IS the survival signal.
  * POSITIVE negation inhabitants (the theorems below) — buildable proofs that a
    one-adversary substrate FALSIFIES the ≥2 floor for `a0` AND `a1` AND the full
    I-7 universal, while the REAL substrate genuinely witnesses the floor for both
    attempts. The floor is therefore load-bearing, not decorative.

This is the ORIGINAL Attack-6 (`degenerate_substrate_falsifies_floor`) extended
from the single-attempt old model to BOTH attempts of the rebuilt model.

No `sorry` / `axiom` / `native_decide`.

----------------------------------------------------------------------
SHOULD_FAIL build-matrix (each COMMENTED form was compiled standalone and FAILED):

(A) decide-junk witness — membership is NOT Decidable-trivial, so the body has
    no substrate-free inhabitant.  EXIT=1, error:
      failed to synthesize Decidable (AttemptAdversary DisproveAttempt.a0 Adversary.adv1)

  example : (∃ x y : Adversary, AttemptAdversary .a0 x ∧ AttemptAdversary .a0 y ∧ x ≠ y) :=
    ⟨.adv1, .adv2, by decide, by decide, by decide⟩          -- REJECTED

(B) one-adversary floor for a0 — the only a0 constructor in a one-adversary world
    forces x = y = adv1, so `x ≠ y` (adv1 ≠ adv1) is unprovable.  EXIT=1.

(C) degenerate collapse to a single adversary (x = x) in the REAL substrate —
    the body's `x ≠ y` clause rejects `adv1 ≠ adv1`.  EXIT=1, error:
      Function expected at h … term has type Adversary.adv1 = Adversary.adv1

  example : (∃ x : Adversary, AttemptAdversary .a0 x ∧ AttemptAdversary .a0 x ∧ x ≠ x) :=
    ⟨.adv1, .a0_adv1, .a0_adv1, by intro h; exact h rfl⟩      -- REJECTED

(D) phantom third adversary — `Adversary` is a CLOSED 2-element enum; no `.adv3`
    exists, so the floor's domain is pinned at exactly two.  EXIT=1, error:
      Unknown constant `TargetWorld.Adversary.adv3`

  example : Adversary := .adv3                                -- REJECTED
----------------------------------------------------------------------
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace AdversaryI7Postrebuild

open TargetWorld Proofs.I7

/-- The I-7 floor body abstracted over the membership relation, so we can
    instantiate it at the REAL substrate and at the degenerate CF substrate. -/
abbrev Floor (R : DisproveAttempt → Adversary → Prop) (a : DisproveAttempt) : Prop :=
  ∃ x y : Adversary, R a x ∧ R a y ∧ x ≠ y

/-! ## Degenerate ONE-adversary CF substrate (the survival target).
Both attempts fan out to EXACTLY ONE adversary (`adv1`). This is the rebuilt
analogue of the old single-attempt `AttemptAdversaryCF1`, now covering `a1`. -/
inductive AttemptAdversaryCF : DisproveAttempt → Adversary → Prop where
  | a0_only : AttemptAdversaryCF .a0 .adv1
  | a1_only : AttemptAdversaryCF .a1 .adv1

/-! ## POSITIVE negation 1 — the one-adversary world FALSIFIES the floor for `a0`.
The degenerate ≥2-floor witness cannot be inhabited: the only `a0` membership
constructor forces both existential witnesses to `adv1`, contradicting `x ≠ y`. -/
theorem cf_falsifies_floor_a0 : ¬ Floor AttemptAdversaryCF .a0 := by
  rintro ⟨x, y, hx, hy, hne⟩
  cases hx; cases hy; exact hne rfl

/-! ## POSITIVE negation 2 — the one-adversary world FALSIFIES the floor for `a1`.
The SECOND attempt the rebuild added is likewise floor-constrained: a single
adversary for `a1` cannot witness two distinct ones. -/
theorem cf_falsifies_floor_a1 : ¬ Floor AttemptAdversaryCF .a1 := by
  rintro ⟨x, y, hx, hy, hne⟩
  cases hx; cases hy; exact hne rfl

/-! ## POSITIVE negation 3 — the one-adversary world FALSIFIES the FULL I-7
universal (quantified over BOTH attempts). The rebuilt I-7's universal genuinely
fails when any attempt drops below the ≥2 floor. -/
theorem cf_falsifies_i7_universal :
    ¬ (∀ a : DisproveAttempt, Floor AttemptAdversaryCF a ∧ AdversariesParallel a) := by
  intro h
  exact cf_falsifies_floor_a0 (h .a0).1

/-! ## POSITIVE negation 4 — the COLLAPSE witness is refuted in the REAL substrate.
A single-adversary collapse (the same adversary used twice) cannot satisfy the
real floor body — `x ≠ y` rejects it. This is the positively-inhabited form of
SHOULD_FAIL probe (C). -/
theorem real_floor_rejects_collapse (a : DisproveAttempt) :
    ¬ (∃ x : Adversary, AttemptAdversary a x ∧ AttemptAdversary a x ∧ x ≠ x) := by
  rintro ⟨x, _, _, hne⟩
  exact hne rfl

/-! ## Counter-sanity — the floor IS satisfiable in the REAL substrate for BOTH
attempts (so I-7 is not vacuous via an empty/unsatisfiable body either). -/
theorem real_floor_a0 : Floor AttemptAdversary .a0 :=
  ⟨.adv1, .adv2, .a0_adv1, .a0_adv2, by intro h; cases h⟩
theorem real_floor_a1 : Floor AttemptAdversary .a1 :=
  ⟨.adv1, .adv2, .a1_adv1, .a1_adv2, by intro h; cases h⟩

/-! ## Domain is closed at EXACTLY two distinct adversaries — not an empty/open
domain (no vacuity via an empty existential range; the ≥2 floor is exactly the
domain cardinality, no phantom third — see SHOULD_FAIL probe (D)). -/
theorem adversary_two_distinct : (Adversary.adv1 : Adversary) ≠ Adversary.adv2 := by decide
theorem adversary_domain_closed : ∀ a : Adversary, a = .adv1 ∨ a = .adv2 := by
  intro a; cases a
  · exact Or.inl rfl
  · exact Or.inr rfl

/-! ## The theorem's OWN witness is the real substrate pair, for BOTH attempts
(no free argument — I-7 is a closed universal binding the inductive substrate,
unlike the I-3 free-measure vacuity). -/
theorem theorem_witness_is_substrate_a0 :
    (∃ x y : Adversary, AttemptAdversary .a0 x ∧ AttemptAdversary .a0 y ∧ x ≠ y)
      ∧ AdversariesParallel .a0 :=
  i7_disprove_fans_out .a0
theorem theorem_witness_is_substrate_a1 :
    (∃ x y : Adversary, AttemptAdversary .a1 x ∧ AttemptAdversary .a1 y ∧ x ≠ y)
      ∧ AdversariesParallel .a1 :=
  i7_disprove_fans_out .a1

end AdversaryI7Postrebuild
