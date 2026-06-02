# Manual test checklist for mission-control v1

Layer 3 of the test plan in `docs/2026-05-25-design.md` §Testing. Steps the
operator follows once to exercise the parts that require two real Claude
Code sessions (specifically Claude's auto-notification on background-bash
completion, which can't be faked without a real session).

The state root path used below is
`${MISSION_CONTROL_ROOT:-$HOME/.mission-control}`. If you have set
`MISSION_CONTROL_ROOT` in your shell or symlinked the default, substitute
your path; otherwise the default `~/.mission-control/` applies.

Two terminals needed:

- **Terminal A:** the Mission Control Claude Code session (any working
  directory; this is the central coordinator).
- **Terminal B:** an Astronaut peer Claude Code session (e.g.,
  `~/Projects/mine/orbital/`).

Both must have `mission-control` enabled in their `.claude/settings.json`.

## Stage 1 — Initialize + launch-sequence

- [ ] In Terminal A, run `/mission-control:initialize orbital "Test message: please respond with ack."`
- [ ] Confirm Terminal A prints the "Run /mission-control:launch-sequence in your `<peer-project>` Claude Code session" instruction.
- [ ] Confirm `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/orbital/state.json` exists.
- [ ] In Terminal B, run `/mission-control:launch-sequence`.
- [ ] Confirm B reads MC's seq=0 handshake-init block and prints its body.
- [ ] Confirm B appends a seq=0 handshake-ack block to `./thoughts/to-MissionControl.md`.
- [ ] Confirm Terminal A receives an auto-notification with stdout
  `channel=orbital event=peer-spoke` (or, if Claude does NOT auto-dispatch
  on the stdout pattern, the operator manually says "FlightDirector, take
  the orbital turn"). **This is the load-bearing reviewer-question Q#1
  verification.**

## Stage 2 — Three turns

- [ ] Terminal A: FlightDirector reads B's handshake-ack, appends a turn-1
  question to `to-Orbital.md`, kills B's PID. Confirm B's wait returns
  `channel=mission-control event=peer-spoke`.
- [ ] Terminal B: FlightDirector reads MC's question, generates an answer,
  appends a turn-1 response, kills MC's PID.
- [ ] Repeat for turns 2 and 3.

## Stage 3 — Status

- [ ] In Terminal A, run `/mission-control:mission-status`.
- [ ] Confirm the table shows `orbital | healthy | <our pid> | <peer pid> | <seqs> | continue`.

## Stage 4 — Splashdown one channel

- [ ] In Terminal A, say "FlightDirector, splashdown orbital."
- [ ] Confirm the channel directory moves to
  `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/.archive/<TS>/orbital/`.
- [ ] Confirm Terminal B sees a final `intent=farewell` block (next time it
  checks).

## Stage 5 — End-mission

- [ ] In Terminal A, initialize a second channel:
  `/mission-control:initialize kimmy "Test kimmy channel."`
- [ ] Walk through the launch-sequence in a third terminal (Terminal C)
  in the kimmy directory.
- [ ] In Terminal A, run `/mission-control:end-mission`.
- [ ] Confirm the kimmy channel is archived alongside the previously
  splashed-down orbital channel.

## Stage 6 — Purge

- [ ] In Terminal A, run `/mission-control:end-mission --purge`.
- [ ] Confirm any active channels are deleted (not archived).
- [ ] Confirm the archive subdirs (which the operator may want to keep)
  are deleted too — `--purge` is the cleanup-cruft mode.

## Failure-mode spot checks

- [ ] **Peer-crashed:** With a healthy channel, manually `kill -9` the peer's
  canonical-sentinel PID (find it via `ps aux | grep "sleep 2147483647"`).
  Run `/mission-control:mission-status` on the Mission Control side. Confirm the
  row shows `peer-crashed` and suggests resync.
- [ ] **UUID mismatch:** Manually edit `state.json` to change `their_uuid`.
  Trigger a turn (impossible to trigger from outside; instead: manually run
  `${CLAUDE_PLUGIN_ROOT}/scripts/kill-pid.sh <peer-pid> <correct-uuid> <state-path>`
  — it should succeed — then change UUID and try again, it should refuse
  with "UUID mismatch".
- [ ] **Double-initialize:** With orbital active, run
  `/mission-control:initialize orbital "..."` again. Confirm it refuses.

## What this checklist does NOT cover

- Cross-machine: the plugin is single-machine only (design accepted limitation).
- Heartbeat for silent peer hangs: deferred to v2.
- SessionEnd auto-teardown: not implemented (per operator preference).

If any item fails, file a bug under `thoughts/ticket-mission-control-*.md`
with the failure mode and a reproduction.
