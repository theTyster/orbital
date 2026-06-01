import Proofs.TargetWorld

/-! SHOULD-FAIL probe (survival signal, sharper form of locus a): try to make
    the NECESSITY lemma vacuous by proving the CF predicate is TOTAL — i.e.
    `∀ r, ReachesExplainCF r`. If this held, then `¬ ReachesExplainCF r` would be
    uninhabitable for every `r`, collapsing `∃ r, Terminates r ∧ ¬ ReachesExplainCF r`
    to falsehood. The `r1` case is uninhabited, so the `cases r` split cannot
    discharge it. This file MUST fail to compile — the CF predicate is genuinely
    PARTIAL (omits r1), which is what gives the necessity lemma its teeth. -/

set_option autoImplicit false
namespace FAIL_cf_total
open TargetWorld

theorem cf_is_total : ∀ r : Run, ReachesExplainCF r := by
  intro r
  cases r
  · exact .r0
  · exact .r1   -- no such constructor: r1 is omitted under the CF

end FAIL_cf_total
