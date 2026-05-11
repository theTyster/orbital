# orbital-trajectory

End-to-end orchestration of the orbital-shifting pipeline.

## Skills

- **pipeline** — Run a single ticket through the full orbital-shifting pipeline (`close-world` → `decompose-proposition` → `model-obligations` → `prove-invariants` → `instantiate-properties` → `realize-specification`) and finish with `explain`. Renamed from `single-ticket-pipeline`.

## History

This plugin was previously named `orchestrate` (and before that `multi-plan`, after the parallel multi-enhancement worktree orchestrator that lived alongside `single-ticket-pipeline`). The `multi-plan` skill was retired in favor of the single-ticket flow that has become the dominant pattern; its design is preserved at `thoughts/archive/multi-plan-skill-design.md` for future revival.
