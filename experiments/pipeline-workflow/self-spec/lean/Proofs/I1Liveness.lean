import Proofs.TargetWorld

/-!
# I-1 liveness — every terminating run reaches the explain step

Property: `p_v1_i1` (prescriptive obligation `pr_v1_i1_liveness`; relies on
`cf_v1_d_explain_closer`, D-8/I-1).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i1,
    "I-1 liveness: every terminating run reaches the explain step.",
    "... forall (r : Run), Terminates r -> ReachesStep r Stage.explain ...").

Substrate: `op_terminates(r0)`, `op_reaches_step(r0, s_explain)`,
`is_closer(s_explain)`, and the fact that explain has NO successor in
`stage_order/2` (it is the unique terminal stage).

Two obligations:
  * liveness — `∀ r, Terminates r → ReachesExplain r`
  * explain is terminal — `∀ s, ¬ StageOrder .explain s` (the closer has no
    successor, so "reaching explain" is genuinely terminal, not a way-station).

Ontology: prescriptive obligation, no negated premise → `.absent`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I1

open TargetWorld

/-- Liveness: every terminating run reaches the explain step. -/
@[ontology .prescriptive, .absent]
theorem i1_explain_always_runs : ∀ r : Run, Terminates r → ReachesExplain r := by
  intro r h
  cases h
  exact .r0

/-- Explain is the unique terminal stage: it has no successor in `StageOrder`.
    This is what makes "reaches explain" a genuine terminal condition. The goal
    mentions the target-world predicate `StageOrder`; it closes by case-exhaust
    (`exhaust` = `intro h; cases h`), NOT by `decide`. -/
@[ontology .prescriptive, .absent]
theorem i1_explain_is_terminal : ∀ s : Stage, ¬ StageOrder .explain s := by
  intro s
  exhaust

end Proofs.I1
