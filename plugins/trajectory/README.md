# orbital-trajectory

End-to-end orchestration of the orbital-shifting pipeline.

## Skills

- **pipeline** — Run a single ticket through some contiguous slice of the orbital-shifting pipeline (`close-world` → `decompose-proposition` → `model-obligations` → `prove-invariants` → `instantiate-properties` → `realize-specification`) and finish with `explain`. Defaults to the full sequence when no scope is given; supports partial runs (entry mid-pipeline, early exit, or both) when the user names entry/exit stages or when `thoughts/` already holds upstream artifacts from a prior run. Renamed from `single-ticket-pipeline`.

## History

This plugin was previously named `orchestrate` (and before that `multi-plan`, after the parallel multi-enhancement worktree orchestrator that lived alongside `single-ticket-pipeline`). The `multi-plan` skill was retired in favor of the single-ticket flow that has become the dominant pattern; its design is preserved at `thoughts/archive/multi-plan-skill-design.md` for future revival.
