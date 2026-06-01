import Proofs.TargetWorld
import Proofs.I4Monotone

/-! Sanity probe: confirm the standalone `lake env lean` compilation harness
    resolves `Proofs.*` imports and that a TRUE statement type-checks. If this
    builds and the FORWARD original theorem is reusable, the harness is sound. -/

open TargetWorld Proofs.I4

-- The original (forward) theorem must remain inhabited.
example : ∀ (r : Run) (i j si sj : Nat),
    i ≤ j → StartIdx r i si → StartIdx r j sj → sj ≤ si :=
  i4_startidx_antitone
