import Proofs.TargetWorld
import Proofs.I1Liveness

/-! Baseline: confirm `lake env lean` sees the frozen model + I-1 proofs.
    This file SHOULD compile (read-only check of the toolchain wiring). -/

namespace I1PostRebuildBaseline
open TargetWorld Proofs.I1

-- The model is reachable and the necessity lemma exists with the expected type.
example : ∃ r : Run, Terminates r ∧ ¬ ReachesExplainCF r := i1_needs_explain_on_hard_stop
example : ∀ s : Stage, ¬ StageOrder .explain s := i1_explain_is_terminal
example : ∀ r : Run, Terminates r → ReachesExplain r := i1_explain_always_runs

end I1PostRebuildBaseline
