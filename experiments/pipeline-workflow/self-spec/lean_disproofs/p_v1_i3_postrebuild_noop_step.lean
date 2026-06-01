import Mathlib
import Proofs.TargetWorld
import Proofs.I3Termination

/-!
# I-3 post-rebuild NO-OP / MEASURE-PRESERVING step attack (EXPECT: FAILS to compile)

The original vacuity rested on a step that does NOT decrease the measure (the
identity). The rebuilt model relocates termination onto a CONCRETE inductive
`Step` whose only two constructors (`forward`, `loopback`) each strictly
decrease the lex measure. To resurrect the old vacuity I must produce a `Step`
that leaves the state (hence the measure) unchanged — an identity/no-op
transition `Step s s`.

The body below attempts to BUILD such a witness by case-analysis on a
hypothetical `Step s s` and discharging it — i.e. it asserts `∃ s, Step s s`
constructively. There is NO constructor of `Step` whose source and target
coincide:
  * `forward`  : `Step ⟨rb, d+1⟩ ⟨rb, d⟩`     — target's 2nd component is `d`,
                 source's is `d+1`; `d ≠ d+1`, so source ≠ target.
  * `loopback` : `Step ⟨rb+1, d⟩ ⟨rb, d'⟩`    — target's 1st component is `rb`,
                 source's is `rb+1`; `rb ≠ rb+1`, so source ≠ target.
So `Step s s` is uninhabited and the existential cannot be constructed without
`sorry`. EXPECT a type/elaboration error (an unsolved goal / no applicable
constructor) => the no-op step cannot inhabit the rebuilt step relation.

EXPECTED: `lake env lean` exits NON-ZERO on this file.
-/

set_option autoImplicit false

namespace I3PostRebuildNoOp

open TargetWorld Proofs.I3

/-- Attempt to constructively exhibit a no-op (identity) step `Step s s`. There
    is no reflexive constructor, so `exact?`-style closure is impossible; the
    only honest closers (`sorry`/`exact ...`) are unavailable. We try the two
    constructors explicitly — BOTH fail to unify source with target. EXPECT an
    elaboration error. -/
theorem noop_step_exists : ∃ s : State, Step s s := by
  refine ⟨⟨0, 0⟩, ?_⟩
  -- Goal: Step ⟨0,0⟩ ⟨0,0⟩. Neither constructor unifies:
  --   forward needs target.2 = source.2 - 1 (0 = ... impossible at the source ⟨0,0⟩);
  --   loopback needs source.1 = target.1 + 1 (0 = 0+1 impossible).
  -- The `constructor` tactic should find NO applicable constructor.
  constructor

end I3PostRebuildNoOp
