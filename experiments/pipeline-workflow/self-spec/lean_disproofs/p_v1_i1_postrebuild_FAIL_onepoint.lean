import Proofs.TargetWorld

/-! SHOULD-FAIL probe (survival signal): the ORIGINAL attack's keystone
    `run_is_a_one_point_domain : ∀ r : Run, r = .r0` with its exact old proof
    (`intro r; cases r; rfl`). Over the rebuilt two-inhabitant `Run` the `r1`
    case has goal `Run.r1 = Run.r0`, which `rfl` CANNOT close. This file MUST
    fail to compile; that failure is the non-vacuity signal — `Run` is no longer
    a singleton, so the quantifier `∀ r` genuinely ranges over ≥2. -/

set_option autoImplicit false
namespace FAIL_onepoint
open TargetWorld

theorem run_is_a_one_point_domain : ∀ r : Run, r = .r0 := by
  intro r; cases r; rfl

end FAIL_onepoint
