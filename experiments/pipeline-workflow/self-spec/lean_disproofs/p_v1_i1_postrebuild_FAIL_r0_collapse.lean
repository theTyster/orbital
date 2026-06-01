import Proofs.TargetWorld
import Proofs.I1Liveness

/-! SHOULD-FAIL probe (survival signal): the ORIGINAL attack reduced the I-1
    universal to its single `r0` instance via `i1_is_just_its_r0_instance`
    `(∀ r, Terminates r → ReachesExplain r) ↔ (Terminates .r0 → ReachesExplain .r0)`,
    whose `←` direction was closed by `intro h r; cases r; exact h` — valid ONLY
    because `Run` was a singleton so the lone `r0` case made `h` directly fit.

    We replay that EXACT reverse-direction proof over the rebuilt two-point
    `Run`. The `r1` case now has goal `Terminates .r1 → ReachesExplain .r1` while
    `h : Terminates .r0 → ReachesExplain .r0`, so `exact h` mismatches: the r0
    instance does NOT determine the r1 instance. This file MUST fail to compile;
    the failure shows the universal no longer collapses to its r0 point. -/

set_option autoImplicit false
namespace FAIL_r0_collapse
open TargetWorld

theorem i1_collapses_to_r0 :
    (∀ r : Run, Terminates r → ReachesExplain r)
      ↔ (Terminates .r0 → ReachesExplain .r0) := by
  constructor
  · intro h; exact h .r0
  · intro h r; cases r; exact h   -- r1 case: `exact h` cannot fit; no longer a singleton

end FAIL_r0_collapse
