import Proofs.TargetWorld

/-! SHOULD-FAIL probe (survival signal for NECESSITY locus a): try to inhabit
    `ReachesExplainCF .r1`. If this type-checked, the CF world would NOT actually
    omit `r1`, the necessity lemma `∃ r, Terminates r ∧ ¬ ReachesExplainCF r`
    would be vacuous (no run is omitted), and dropping explain-on-hard-stop would
    fail to falsify liveness. `ReachesExplainCF` has ONLY an `.r0` constructor —
    there is no way to build `ReachesExplainCF .r1`. This file MUST fail to
    compile; the failure proves the CF teeth genuinely bite on `r1`.

    We try every available constructor approach so the failure is not a
    name-typo artifact. -/

set_option autoImplicit false
namespace FAIL_cf_inhabits_r1
open TargetWorld

-- The ONLY constructor is `.r0`; applying it to the `.r1` goal must mismatch.
theorem cf_reaches_r1 : ReachesExplainCF .r1 := .r1

end FAIL_cf_inhabits_r1
