import Mathlib
import Proofs.TargetWorld
import Proofs.I5Reserve

/-!
# Post-rebuild VACUITY re-attack against `Proofs.I5.i5_spend_ge_reserve`
                                       & `Proofs.I5.i5_target_ne_own_output`

The OLD attack (`p_v1_i5.lean`) succeeded against a DEGENERATE model on two
defects:

  (D1) `DisproveAttempt` was a SINGLETON (`.a0` only) — `∀ a` was decorative.
  (D2) the reserve half was stated EXISTENTIALLY
         `i5_spend_ge_reserve : ∀ a, ∃ s r, Spend a s ∧ Reserve a r ∧ r ≤ s`
       which let the adversary CHERRY-PICK a compliant (s,r) pair while a
       below-reserve pair COEXISTED in the SAME relation (old Probe 2/4: the
       `SpendBad` carrying BOTH 5 and 0).

The rebuilt, FROZEN model changed both:
  * `DisproveAttempt` now has TWO inhabitants (`a0`, `a1`).
  * the reserve half is now UNIVERSAL:
         `i5_spend_ge_reserve : ∀ a s r, Spend a s → Reserve a r → r ≤ s`.

This file re-runs the old attack against the new universal form and shows it
DIES, then POSITIVELY inhabits the negations that demonstrate the universal
genuinely constrains the substrate.

The negative probes that MUST FAIL to compile live in sibling files
`p_v1_i5_postrebuild_cherrypick_FAIL.lean` and
`p_v1_i5_postrebuild_coexist_FAIL.lean`; this file carries everything that
SHOULD build.

Closes by structural tactics + omega only (no placeholder/assumed/opaque moves).
-/

set_option autoImplicit false

namespace AdvProbeI5Post

open TargetWorld

/-! ## Part A — D1 is dead: the universal genuinely ranges over >1 attempt.

Under the OLD singleton domain, `∀ a` collapsed to its single instance at `.a0`
(old Probe 1). Now `DisproveAttempt` has `a0` AND `a1`, and the universal must
discharge DISTINCT concrete data points for each:

  * a0: spend 5 ≥ reserve 2  →  `2 ≤ 5`
  * a1: spend 3 ≥ reserve 3  →  `3 ≤ 3`

We positively WITNESS that the two attempts carry genuinely different (spend,
reserve) data — a one-point domain could not express this. -/
theorem partA_domain_has_two_distinct_data_points :
    (Spend .a0 5 ∧ Reserve .a0 2) ∧ (Spend .a1 3 ∧ Reserve .a1 3)
    ∧ (5 ≠ 3) ∧ (.a0 ≠ (.a1 : DisproveAttempt)) :=
  ⟨⟨.a0, .a0⟩, ⟨.a1, .a1⟩, by decide, by decide⟩

/-- And the universal, instantiated at `a1`, is NOT the same fact as at `a0`:
    `a1` forces `3 ≤ 3`, a distinct inequality from `a0`'s `2 ≤ 5`. The `∀ a`
    is therefore load-bearing — it is NOT decorative as in old Probe 1. -/
theorem partA_universal_bites_at_a1 :
    (3 : Nat) ≤ 3 :=
  Proofs.I5.i5_spend_ge_reserve .a1 3 3 .a1 .a1

/-! ## Part B — D2 is dead: the UNIVERSAL form forbids ANY below-reserve spend,
    so the cherry-pick (old Probe 2/4) can no longer hide a violation.

The old defect was that the EXISTENTIAL `∃ s r, … ∧ r ≤ s` was satisfiable by
ONE compliant pair even while a below-reserve pair coexisted. The UNIVERSAL
`∀ s r, Spend a s → Reserve a r → r ≤ s` admits no such hiding: it speaks of
EVERY (s,r) the relation holds, so any below-reserve pair is a DIRECT falsifier.

We make this PRECISE and POSITIVE: for the real model's `Spend`/`Reserve`, the
universal and a below-reserve spend are MUTUALLY EXCLUSIVE.  Below we show that
ASSUMING a below-reserve spend in the SAME relations the universal ranges over
yields `False` — i.e. the universal genuinely refutes coexistence. -/

/-- The universal `i5_spend_ge_reserve` and ANY below-reserve pair in the SAME
    (`Spend`,`Reserve`) relations are jointly UNSATISFIABLE. This is the exact
    property the old existential restatement LACKED — old Probe 4 inhabited the
    conjunction of the sufficiency shape and a coexisting violation; here the
    conjunction is provably empty. -/
theorem partB_universal_excludes_coexisting_violation :
    ¬ ∃ (a : DisproveAttempt) (s r : Nat), Spend a s ∧ Reserve a r ∧ s < r := by
  rintro ⟨a, s, r, hs, hr, hlt⟩
  have hle : r ≤ s := Proofs.I5.i5_spend_ge_reserve a s r hs hr
  omega

/-- Restated as the head-to-head with the old capstone
    (`probe2_shape_does_not_forbid_violation` /
     `probe4_sufficiency_shape_coexists_with_violation`): the OLD theorem let the
    sufficiency shape AND a coexisting violation be JOINTLY inhabited. Against the
    NEW universal that joint inhabitation is impossible — the conjunction
    `(universal holds) ∧ (a violation coexists)` reduces to `False`. -/
theorem partB_old_capstone_now_empty :
    ¬ ( (∀ (a : DisproveAttempt) (s r : Nat), Spend a s → Reserve a r → r ≤ s)
        ∧ (∃ (a : DisproveAttempt) (s r : Nat), Spend a s ∧ Reserve a r ∧ s < r) ) := by
  rintro ⟨huniv, a, s, r, hs, hr, hlt⟩
  have hle : r ≤ s := huniv a s r hs hr
  omega

/-! ## Part C — the SpendCF necessity is now a genuine FALSIFIER of the universal.

The briefing's load-bearing test: `SpendCF` (`a0` spend 0 < reserve 2) must
FALSIFY the universal. Under the OLD existential, the necessity lemma operated on
a SEPARATE predicate that could never disturb the cherry-picked sufficiency
(old Probe 4's complaint). Under the NEW universal, the SAME shape of universal
applied to `SpendCF` is provably FALSE — the forbidden fact, if it lived in the
relation the universal ranges over, breaks it. -/

/-- If the universal reserve discipline held of `SpendCF`/`Reserve` (i.e. of the
    relation that CONTAINS the restored below-reserve fact), it would be FALSE:
    `SpendCF .a0 0` and `Reserve .a0 2` would force `2 ≤ 0`. So the universal
    CANNOT hold over a world that contains the forbidden below-reserve spend —
    the counterfactual removal is load-bearing, exactly as
    `i5_needs_no_below_reserve` claims, and now PROVABLY so against the universal
    (not merely an existential in a sealed-off predicate). -/
theorem partC_universal_fails_over_SpendCF :
    ¬ (∀ (a : DisproveAttempt) (s r : Nat), SpendCF a s → Reserve a r → r ≤ s) := by
  intro huniv
  have hle : (2 : Nat) ≤ 0 := huniv .a0 0 2 .a0_below .a0
  omega

/-- The proof file's own necessity witness `i5_needs_no_below_reserve` is exactly
    the existential falsifier of the (SpendCF-augmented) universal — re-cited here
    to confirm it inhabits a genuine `s < r`, not a vacuous shape. -/
theorem partC_necessity_witness_is_genuine :
    ∃ (a : DisproveAttempt) (s r : Nat), SpendCF a s ∧ Reserve a r ∧ s < r :=
  Proofs.I5.i5_needs_no_below_reserve

/-! ## Part D — no-self-attack: the universal disequality genuinely fails over TargetCF.

The old Probe 3 charge was that the disequality was a FIXED two-constructor fact
("attempt is dead weight"). The rebuilt model makes Target/OwnOutput
ATTEMPT-DEPENDENT (a0: gate_target_descriptor vs disproof_results; a1:
disproof_results vs counterexamples). And the self-attack CF (`TargetCF .a0
disproof_results` = `OwnOutput .a0 disproof_results`) FALSIFIES the no-self-attack
universal: the SAME shape applied to TargetCF yields a target equal to own output. -/

/-- If no-self-attack held of `TargetCF`/`OwnOutput`, it would be FALSE: `a0`
    targets `disproof_results`, which is ALSO `a0`'s own output, forcing
    `disproof_results ≠ disproof_results`. So the no-self-attack universal cannot
    hold over a world containing the restored self-attack — the removal is
    load-bearing. -/
theorem partD_no_self_attack_fails_over_TargetCF :
    ¬ (∀ (a : DisproveAttempt) (t o : DisproveSurface),
         TargetCF a t → OwnOutput a o → t ≠ o) := by
  intro huniv
  exact huniv .a0 .disproof_results .disproof_results .a0_self .a0 rfl

/-- The proof's own self-attack necessity witness, re-cited: the target and own
    output COINCIDE under TargetCF — a genuine self-attack, not a vacuous shape. -/
theorem partD_necessity_witness_is_genuine :
    ∃ (a : DisproveAttempt) (s : DisproveSurface), TargetCF a s ∧ OwnOutput a s :=
  Proofs.I5.i5_needs_no_self_attack

end AdvProbeI5Post
