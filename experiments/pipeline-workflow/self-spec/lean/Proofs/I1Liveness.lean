import Proofs.TargetWorld

/-!
# I-1 liveness — every terminating run reaches the explain step

Property: `p_v1_i1` (prescriptive obligation `pr_v1_i1_liveness`; relies on
`cf_v1_d_explain_closer`, D-8/I-1).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i1,
    "I-1 liveness: every terminating run reaches the explain step.",
    "... forall (r : Run), Terminates r -> ReachesStep r Stage.explain ...").

Substrate: `op_terminates(r0)`, `op_terminates(r1)`, `op_reaches_step(r0,
s_explain)`, `op_reaches_step(r1, s_explain)` (D-8: explain runs on EVERY path
including hard-stop paths), `is_closer(s_explain)`, and the fact that explain
has NO successor in `stage_order/2` (it is the unique terminal stage).

Per D-8 the `ReachesExplain` predicate is TOTAL (both `r0` and `r1` reach
explain). The sufficiency theorem therefore holds unconditionally; its
non-vacuity is carried by:

  (a) the NECESSITY lemma below (`i1_needs_explain_on_hard_stop`): dropping
      the explain-on-hard-stop fact (encoded as `ReachesExplainCF`, which has
      no constructor for `r1`) makes `r1` a terminating run that fails to
      reach explain — showing D-8 is load-bearing, not CWA fiat; and

  (b) the genuinely structural TERMINAL half (`i1_explain_is_terminal`): the
      7-edge `StageOrder` has no constructor with `.explain` as its first
      argument, so `¬ StageOrder .explain s` closes by case-exhaustion — the
      I-1 adversary conceded this half is non-vacuous.

Three obligations:
  * sufficiency    — `∀ r, Terminates r → ReachesExplain r`      (total by D-8)
  * terminality    — `∀ s, ¬ StageOrder .explain s`              (structural)
  * necessity lemma — `∃ r, Terminates r ∧ ¬ ReachesExplainCF r` (CF teeth)

Ontology: prescriptive obligation, no negated premise → `.absent`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I1

open TargetWorld

/-- Liveness: every terminating run reaches the explain step.

    `ReachesExplain` is total by D-8 (explain runs on every path including
    hard-stop paths). Both `r0` (complete) and `r1` (hard_stop) reach explain;
    the `cases h` split handles each run by the matching constructor. -/
@[ontology .prescriptive, .absent]
theorem i1_explain_always_runs : ∀ r : Run, Terminates r → ReachesExplain r := by
  intro r h
  cases h
  · exact .r0
  · exact .r1

/-- Explain is the unique terminal stage: it has no successor in `StageOrder`.
    This is what makes "reaches explain" a genuine terminal condition. The goal
    mentions the target-world predicate `StageOrder`; it closes by case-exhaust
    (`exhaust` = `intro h; cases h`), NOT by `decide`. The 7-edge `StageOrder`
    has no constructor whose first argument is `.explain`, so `cases h`
    immediately closes the goal with zero sub-goals. -/
@[ontology .prescriptive, .absent]
theorem i1_explain_is_terminal : ∀ s : Stage, ¬ StageOrder .explain s := by
  intro s
  exhaust

/-- Necessity lemma (CF teeth): removing the explain-on-hard-stop fact makes
    a terminating run fail to reach explain.

    Witness `r1`: `Terminates .r1` holds by constructor; `ReachesExplainCF .r1`
    is uninhabited (no constructor for `r1` in `ReachesExplainCF`, which models
    the counterfactual world where explain is skipped on the hard-stop path), so
    `¬ ReachesExplainCF .r1` closes by `exhaust`.

    This shows that D-8 ("explain runs on every path including hard-stop paths")
    is LOAD-BEARING: `negation_provenance(explain_skipped_on_hard_stop,
    contradicts)`. Mirrors `i6_needs_one_attempt` (I-6) and `i4_needs_no_scope_narrowing` (I-4). -/
@[ontology .prescriptive, .contradicts]
theorem i1_needs_explain_on_hard_stop :
    ∃ r : Run, Terminates r ∧ ¬ ReachesExplainCF r := by
  exact ⟨.r1, .r1, by exhaust⟩

end Proofs.I1
