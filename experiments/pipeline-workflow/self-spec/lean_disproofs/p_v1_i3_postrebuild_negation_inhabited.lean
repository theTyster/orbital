import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# I-3 post-rebuild POSITIVE inhabitation of the negation (EXPECT: COMPILES)

The survival signal is twofold:
  (1) the degenerate witness FAILS to inhabit (the `replay` and `noop_step`
      probes both exit non-zero), and
  (2) we can POSITIVELY inhabit the negation of the degenerate reading as a
      buildable, `sorry`/`axiom`/`native_decide`-free theorem.

This file is the (2) half. We RE-DERIVE the regression facts from the raw
`Step` constructors and `step_strictDecreasing` — we do NOT merely re-export
`i3_identity_step_is_rejected` — so the survival rests on an independent
machine-checked term, not on trusting the frozen proof's own statement.

  * `noop_step_refuted` — for EVERY state, the identity/no-op transition is
    NOT a `Step`. (The old vacuity used exactly the identity step.)
  * `measure_preserving_step_refuted` — ANY `Step` strictly lowers the lex
    measure, so no transition can leave `M` fixed. (The old vacuity used a
    constant measure, i.e. one that is preserved by every step.)
  * `forward_and_loopback_decrease` — the two genuine moves DO decrease the
    measure, so the rejection is not because `Step` is empty: it is inhabited,
    just never by a non-decreasing transition.

EXPECTED: `lake env lean` exits ZERO on this file.
-/

set_option autoImplicit false

namespace I3PostRebuildNegationInhabited

open TargetWorld Proofs.I3

/-- Re-derived from scratch: a lex order over `Nat.lt` is irreflexive. -/
private theorem lex_irrefl (p : Nat × Nat) :
    ¬ Prod.Lex Nat.lt Nat.lt p p := by
  intro h
  rcases h with ⟨_, _, hfst⟩ | ⟨_, hsnd⟩
  · exact Nat.lt_irrefl _ hfst
  · exact Nat.lt_irrefl _ hsnd

/-- **No-op step refuted (independently re-derived).** For every state, the
    identity transition `Step s s` is impossible. If it held,
    `step_strictDecreasing` would give `M s <ₗ M s`, contradicting irreflexivity.
    This is the negation of the ORIGINAL degenerate witness (the identity step). -/
theorem noop_step_refuted (s : State) : ¬ Step s s := by
  intro h
  exact lex_irrefl (M s) (step_strictDecreasing h)

/-- **Measure-preserving step refuted (independently re-derived).** No transition
    can leave the measure fixed: any `Step s s'` strictly lowers `M`, so
    `M s' = M s` is contradictory. This is the negation of the ORIGINAL constant
    measure (a measure that every step preserves). -/
theorem measure_preserving_step_refuted {s s' : State}
    (h : Step s s') : M s' ≠ M s := by
  intro heq
  have hlt := step_strictDecreasing h
  rw [heq] at hlt
  exact lex_irrefl (M s) hlt

/-- The rejection is NOT because `Step` is empty: both genuine moves are
    inhabited and each strictly decreases the lex measure. So the step relation
    genuinely constrains (it is nonempty AND every member descends). -/
theorem forward_and_loopback_decrease :
    Prod.Lex Nat.lt Nat.lt (M ⟨0, 0⟩) (M ⟨0, 1⟩) ∧
    Prod.Lex Nat.lt Nat.lt (M ⟨0, 9⟩) (M ⟨1, 4⟩) :=
  ⟨step_strictDecreasing (Step.forward 0 0),
   step_strictDecreasing (Step.loopback 0 4 9)⟩

/-- Sharper: a CONCRETE measure-preserving transition is impossible. Suppose a
    forward step out of ⟨0,1⟩ that lands back at the SAME measure (0,1). No such
    `Step` exists — `measure_preserving_step_refuted` rules it out for the only
    state that could even be proposed. -/
theorem no_constant_measure_transition :
    ¬ ∃ s' : State, Step ⟨0, 1⟩ s' ∧ M s' = M ⟨0, 1⟩ := by
  rintro ⟨s', hstep, heq⟩
  exact measure_preserving_step_refuted hstep heq

end I3PostRebuildNegationInhabited
