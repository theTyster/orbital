# mission-control

Cross-session communication substrate. A central Mission Control session and
N project sessions ("Astronauts") run strict-turn-taking conversations through
per-pair state directories on a single machine.
The plugin's contribution is the *protocol* — a small, fail-loud state
machine using Unix PIDs as turn-handoff semaphores and markdown files as
the message payload.

See `docs/2026-05-25-design.md` for the full design.

## Commands

- **`/mission-control:initialize <peer> "<message>"`** — Mission Control side only. Bootstrap a new pair; the message is the operator's handshake content.
- **`/mission-control:launch-sequence`** — Peer side only. Complete the handshake. Requires the plugin to be enabled in the peer project.
- **`/mission-control:mission-status`** — Either side. Read-only diagnostic of all active pairs.
- **`/mission-control:end-mission [--purge]`** — Mission Control side only. Archive (default) or purge (`--purge`) all pairs.

## Skill

- **`FlightDirector`** — Loaded into both sides during their respective bootstrap commands. Runs the turn-loop state machine: diagnose state, dispatch to action, halt-loud on unhealthy states.

## Dependencies

- `jq` — JSON read/write. Declared as a soft dependency; scripts halt with attribution when absent (see `docs/2026-05-25-design.md` §Error handling).
- Bash 3.2+ (macOS) or 5.x (Linux). Scripts are cross-platform between BSD and GNU userland (no OS-detection).
- Claude Code's auto-notification on background-bash completion (load-bearing — see `docs/2026-05-25-design.md` §"Reviewer notes" Q#1).

## Setup

Both sides must have the plugin enabled in their `.claude/settings.json`.
The slash commands create the state directories on first invocation.

### Channel state location

The Mission Control side stores per-channel state under
`${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/`. The default is
`$HOME/.mission-control/`. To use a different location, either set
`MISSION_CONTROL_ROOT` in your shell rc:

```bash
export MISSION_CONTROL_ROOT="/path/to/your/dir"
```

or symlink the default to your preferred location:

```bash
ln -s /path/to/your/dir ~/.mission-control
```

The Astronaut side always stores its single state file at
`./thoughts/.mission-control-state.json` relative to the project root.

## Naming (NASA-coherent)

| Term | Role |
|---|---|
| Mission Control | The central coordinator session |
| Astronaut | A peer project session |
| FlightDirector | The skill running the turn-loop |
| Mission | One pairing arc (`initialize` → `end-mission`) |
| Channel | One peer pair's state directory |
| Launch Sequence | Peer-side bootstrap |
| Splashdown | Graceful close of one pair |
| End of Mission | Global teardown |

## Testing

Three layers (per `docs/2026-05-25-design.md` §Testing):

1. **Unit smoke tests** — `scripts/test/test_*.sh`. Each script has its own
   test. Run all:
   ```bash
   for t in plugins/mission-control/scripts/test/test_*.sh; do "$t"; done
   ```
2. **One-sided integration** — `scripts/test/integration/test_one-sided.sh`.
   Simulates the peer side via direct file writes + kill calls; exercises
   the five-script ensemble through a full handshake + 1 turn cycle.
3. **Manual two-session integration** — `docs/manual-test-checklist.md`.
   Steps the operator follows once to exercise the parts that need real
   Claude sessions (the auto-notification mechanism).

## Status

v1.0.0 — initial implementation. Heartbeat, cross-machine, and SessionEnd
auto-teardown are v2 candidates.
