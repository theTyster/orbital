import Proofs.TargetWorld

/-!
# I-2 safety — no stage runs before its required upstream artifact exists

Property: `p_v1_i2` (prescriptive obligation `pr_v1_i2_gating`).
Source: `thoughts/target-world.pl`
  formal_property(p_v1_i2,
    "I-2 safety: no stage runs before its required upstream artifact exists.",
    "... Runs r s -> ArtifactExists r (requiredArtifact s) ...").

Substrate: `op_requires_artifact/2` (each stage requires the predecessor's
output), `op_no_required_artifact(s1)`, derived over `stage_order/2`.

Structural reading: gating holds iff every required upstream artifact is
produced by a stage that *precedes* the requiring stage — so the artifact
exists by the time the consumer runs. In the materialized substrate the
required artifact of stage `s` is exactly its immediate predecessor's output,
so `Requires s a → StageOrder a s`: the producer is the immediate predecessor,
which by the total chain runs strictly before. No stage requires a future or
self artifact.

The companion fact — `close_world` has no required upstream artifact — is the
stage-0 carrier base case; it is encoded by the *absence* of any `Requires
.close_world _` constructor, which the theorem below makes load-bearing: the
universal is over all `Requires` facts, and none names `close_world` as
consumer.

Ontology: prescriptive obligation, no negated premise → `.absent`.
-/

set_option autoImplicit false
set_option maxHeartbeats 400000

namespace Proofs.I2

open TargetWorld

/-- Gating: every required upstream artifact is produced by a stage that runs
    strictly before the requiring stage (here: its immediate predecessor in the
    `StageOrder` chain). The goal mentions target-world predicates `Requires`
    and `StageOrder`; it closes by `cases h <;> exact …` (constructor citation),
    NOT by `decide`. -/
@[ontology .prescriptive, .absent]
theorem i2_artifact_gating :
    ∀ (s : Stage) (a : Artifact), Requires s a → StageOrder a s := by
  intro s a h
  cases h
  · exact .s1_s2
  · exact .s2_s3
  · exact .s3_s4
  · exact .s4_s5
  · exact .s5_s6
  · exact .s6_s7
  · exact .s7_se

/-- The stage-0 carrier base case: `close_world` requires no upstream artifact.
    Encoded as the absence of any `Requires .close_world _` constructor; the
    universal closes by case-exhaust over `Requires`. -/
@[ontology .prescriptive, .absent]
theorem i2_close_world_ungated : ∀ a : Artifact, ¬ Requires .close_world a := by
  intro a h
  cases h

end Proofs.I2
