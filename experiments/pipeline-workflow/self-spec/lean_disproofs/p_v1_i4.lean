import Mathlib
import Proofs.TargetWorld
import Proofs.I4Monotone

/-!
# Adversary A — VACUITY probe against `Proofs.I4.i4_startidx_antitone`

The adversarial QUESTION is NOT "is the kernel proof valid" (it is) but
"is the THEOREM VACUOUS or MIS-STATED" — does antitonicity actually CONSTRAIN
the start index across steps, or does it hold trivially because the underlying
`StartIdx` relation pins every start index to the CONSTANT 0?

This is the SAME defect class caught in I-3 (`p_v1_i3.lean`): there a free
measure variable let the constant `(0,0)` inhabit well-foundedness, making the
substrate decorative. Here, `StartIdx` is a CONSTANT-0 relation:

    inductive StartIdx : Run → Nat → Nat → Prop where
      | r0_step0 : StartIdx .r0 0 0
      | r0_step1 : StartIdx .r0 1 0
      | r0_step2 : StartIdx .r0 2 0

Every constructor's third argument is 0. So `StartIdx r i si` FORCES `si = 0`,
and the conclusion `sj ≤ si` is ALWAYS `0 ≤ 0`. The `i ≤ j` premise (the only
thing that gives "antitone" its direction) is DEAD: the source proof discards it
as `_hij`. A constant function is BOTH antitone and monotone, so the theorem
holds the way `0 ≤ 0` holds — independent of any ordering of step indices.
-/

set_option autoImplicit false

namespace AdversaryA

open TargetWorld Proofs.I4

/-! ## 1. The `StartIdx` relation is constant-0 — start index never varies. -/

/-- Every inhabitant of `StartIdx` has start index 0. This is the structural
    root of the vacuity: the third coordinate is not a variable that ranges over
    "the scope at step i" — it is the literal constant 0 in all three
    constructors. So "non-increasing start index" degenerates to "the constant
    0", which is non-increasing the trivial way `0 ≤ 0` is. -/
theorem startidx_is_constant_zero :
    ∀ (r : Run) (i si : Nat), StartIdx r i si → si = 0 := by
  intro r i si h
  cases h <;> rfl

/-! ## 2. The `i ≤ j` hypothesis is DEAD — antitonicity is never tested. -/

/-- The decisive vacuity statement. The source theorem `i4_startidx_antitone`
    claims `i ≤ j → … → sj ≤ si` (later step's start ≤ earlier step's start —
    "scope only widens"). But the SAME conclusion holds with the ordering
    hypothesis REVERSED to `j ≤ i`, and indeed with NO ordering hypothesis at
    all. We exhibit the reverse-direction theorem: it proves `sj ≤ si` even when
    `j ≤ i`, which — combined with the original — gives `si = sj` for ALL pairs.
    A genuinely antitone (strictly-widening) relation could NOT satisfy both
    directions. This one can, because every value is 0. -/
theorem i4_holds_in_reverse_direction :
    ∀ (r : Run) (i j si sj : Nat),
      j ≤ i → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj _hji hi hj
  -- The `j ≤ i` hypothesis is just as dead as `i ≤ j` was in the source proof.
  cases hi <;> cases hj <;> exact Nat.le_refl 0

/-- Sharper still: the conclusion holds with NO ordering relation between the
    steps whatsoever. The "monotone scope" theorem does not depend on step
    order — it depends only on the constant 0. This is the cleanest witness that
    `i4_startidx_antitone`'s `i ≤ j` antecedent is decorative. -/
theorem i4_holds_with_no_step_ordering :
    ∀ (r : Run) (i j si sj : Nat),
      StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj hi hj
  cases hi <;> cases hj <;> exact Nat.le_refl 0

/-! ## 3. The original theorem ALSO proves the OPPOSITE inequality. -/

/-- Antitonicity for `i ≤ j` says `sj ≤ si`. If the property genuinely
    distinguished widening from narrowing, it could NOT also force `si ≤ sj`.
    But we can derive `si ≤ sj` too — so the original theorem actually pins
    `si = sj = 0`, which is the constant-function degeneracy, NOT antitonicity.
    A function that is simultaneously `≤` in both directions for all step pairs
    is constant. -/
theorem i4_collapses_to_equality :
    ∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → si = sj := by
  intro r i j si sj _hij hi hj
  have e1 : si = 0 := startidx_is_constant_zero r i si hi
  have e2 : sj = 0 := startidx_is_constant_zero r j sj hj
  rw [e1, e2]

/-! ## 4. The constant-0 inhabitant satisfies the original theorem's shape. -/

/-- The degenerate witness, in the I-3 style. We reconstruct the source
    theorem's exact statement and discharge it WITHOUT ever using the ordering
    hypothesis — exactly as the source proof does (`_hij` is underscore-bound).
    This `def` IS the source proof term re-expressed: it shows the inhabitant of
    `i4_startidx_antitone` ignores `i ≤ j` and closes every case by `0 ≤ 0`. -/
theorem i4_witness_ignores_ordering :
    ∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → sj ≤ si := by
  intro r i j si sj _ hi hj
  -- identical close to the source: ordering hypothesis dropped entirely.
  cases hi <;> cases hj <;> exact Nat.le_refl 0

/-- And it is literally the same term as the verified source theorem — the
    adversary proof and the original are definitionally interchangeable, so
    nothing the source proved goes beyond `0 ≤ 0`. -/
theorem i4_source_is_the_constant_close :
    (∀ (r : Run) (i j si sj : Nat),
      i ≤ j → StartIdx r i si → StartIdx r j sj → sj ≤ si) :=
  i4_startidx_antitone

end AdversaryA
