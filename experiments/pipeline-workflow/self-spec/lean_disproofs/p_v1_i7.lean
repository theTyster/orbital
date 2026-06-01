import Mathlib
import Proofs.TargetWorld
import Proofs.I7Fanout

/-!
# Vacuity probe against `Proofs.I7.i7_disprove_fans_out` — ATTACK FAILED (non-vacuous)

The adversarial QUESTION mirrors the I-3 free-measure trap (see
`lean_disproofs/p_v1_i3.lean`): is the I-7 theorem VACUOUS — satisfiable by a
degenerate witness while the substrate facts play no real role — or does it bind
the concrete inductive substrate and constrain the property?

I-7 as stated (`Proofs/I7Fanout.lean`):
  ∀ a : DisproveAttempt,
    (∃ x y : Adversary, AttemptAdversary a x ∧ AttemptAdversary a y ∧ x ≠ y)
    ∧ AdversariesParallel a

## VERDICT: NON-VACUOUS. The attack FAILED.

The I-3 vacuity arose from a FREE function argument (`measureM`, `idStep`) that a
substrate-free constant could inhabit (`i3_termination constMeasure idStep …`
type-checked). I-7 has NO free argument: it is a closed universal over the finite
inductive `DisproveAttempt`, whose existential body ranges over the finite
inductive `Adversary` and is gated by the inductive predicates `AttemptAdversary`
and `AdversariesParallel`. The decisive discriminator:

  * The I-7 body CANNOT be inhabited without the substrate constructors. The
    destructive test `⟨.adv1, .adv2, by decide, by decide, by decide⟩` FAILS to
    compile: `failed to synthesize Decidable (AttemptAdversary .a0 .adv1)`. The
    membership facts are not trivially-true; they require `.a0_adv1` / `.a0_adv2`.
  * Supplying the REAL constructors makes the SAME body compile — so the failure
    is attributable exactly to the missing substrate, i.e. the membership is
    load-bearing (the I-7 analogue of I-3's `step_strictDecreasing`).
  * The existential domain `Adversary` has ≥2 DISTINCT inhabitants (adv1 ≠ adv2),
    so "two distinct adversaries" is a real, satisfiable, non-empty-domain
    constraint — not a quantifier over an empty domain.
  * A degenerate one-adversary substrate FALSIFIES the ≥2 floor (Attack 6), so
    the floor is what the constructor count enforces — not decorative.

No degenerate inhabitant exists. The probes below all build under the shared
Mathlib clone (validated copy compiled at `Proofs/I7VacuityProbe.lean`).
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace AdversaryI7

open TargetWorld Proofs.I7

/-! ## Attack 1 — the existential domain is non-degenerate (≥2 distinct). -/
theorem adversary_has_two_distinct : (Adversary.adv1 : Adversary) ≠ Adversary.adv2 := by
  decide

/-! ## Attack 2 — a single adversary (x = y) cannot satisfy the body. -/
theorem cannot_collapse_to_single (a : DisproveAttempt) :
    ¬ (∃ x : Adversary, AttemptAdversary a x ∧ AttemptAdversary a x ∧ x ≠ x) := by
  rintro ⟨x, _, _, hne⟩
  exact hne rfl

/-! ## Attack 3 — membership is constructor-pinned (substrate load-bearing). -/
theorem membership_is_constructor_pinned :
    ∀ adv : Adversary, AttemptAdversary .a0 adv →
      adv = Adversary.adv1 ∨ adv = Adversary.adv2 := by
  intro adv h
  cases h
  · exact Or.inl rfl
  · exact Or.inr rfl

/-! ## Attack 4 — `AdversariesParallel` is constructor-pinned, not a catch-all. -/
theorem parallel_is_constructor_pinned (a : DisproveAttempt) (h : AdversariesParallel a) :
    a = DisproveAttempt.a0 := by
  cases h
  rfl

/-! ## Attack 5 — the theorem's OWN witness is the substrate pair (no free arg). -/
theorem theorem_witness_is_substrate :
    (∃ x y : Adversary, AttemptAdversary .a0 x ∧ AttemptAdversary .a0 y ∧ x ≠ y)
      ∧ AdversariesParallel .a0 :=
  i7_disprove_fans_out .a0

/-! ## Attack 6 — a degenerate one-adversary substrate FALSIFIES the ≥2 floor. -/
inductive AttemptAdversaryCF1 : DisproveAttempt → Adversary → Prop where
  | a0_only : AttemptAdversaryCF1 .a0 .adv1

theorem degenerate_substrate_falsifies_floor :
    ¬ (∃ x y : Adversary, AttemptAdversaryCF1 .a0 x ∧ AttemptAdversaryCF1 .a0 y ∧ x ≠ y) := by
  rintro ⟨x, y, hx, hy, hne⟩
  cases hx
  cases hy
  exact hne rfl

/-! ## Attack 7 — destructive junk test (documented; the COMMENTED form does NOT
compile). `failed to synthesize Decidable (AttemptAdversary .a0 .adv1)` — the
body has no substrate-free inhabitant. This is the I-3 analogue that DID compile
against the old I-3 (`i3_antecedent_is_free`) and here does NOT.

  example : (∃ x y : Adversary, AttemptAdversary .a0 x ∧ AttemptAdversary .a0 y ∧ x ≠ y) :=
    ⟨.adv1, .adv2, by decide, by decide, by decide⟩   -- REJECTED by the kernel
-/

/-! ## Attack 8 — the universal is not vacuous via an empty domain. -/
theorem disprove_attempt_inhabited : Nonempty DisproveAttempt := ⟨.a0⟩

/-! ## Attack 9 — the floor is pinned at EXACTLY two: both reachable, no third. -/
theorem floor_is_exactly_two :
    AttemptAdversary .a0 .adv1 ∧ AttemptAdversary .a0 .adv2
      ∧ (∀ adv : Adversary, adv = .adv1 ∨ adv = .adv2) := by
  refine ⟨.a0_adv1, .a0_adv2, ?_⟩
  intro adv
  cases adv
  · exact Or.inl rfl
  · exact Or.inr rfl

end AdversaryI7
