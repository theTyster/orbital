---
id: initialize-arg-substitution-and-wait
title: mission-control:initialize — fix $N arg-substitution collision and non-blocking wait sentinel
status: triaged
priority: medium
area: mission-control
created: 2026-05-29
tags: [skill, slash-command, bash, bug, handshake]
related:
  - plugins/mission-control/skills/initialize/SKILL.md
  - plugins/mission-control/skills/FlightDirector/SKILL.md
---

## Problem

`/mission-control:initialize` carries two latent defects that surface on a normal first
invocation. Both were hit live while bootstrapping the `orbital` channel on 2026-05-29.

### Defect 1 — `$N` positional substitution clobbers the arg-parsing bash

The skill is a slash command, so Claude Code substitutes `$ARGUMENTS`, `$0`, `$1`…`$9` in
the command body *before* the bash runs. Two lines use `$N` as **awk** constructs, which
collide with that substitution:

- `skills/initialize/SKILL.md:29` — `peer=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')`.
  The awk field ref `$1` is replaced by the second invocation token. For
  `/mission-control:initialize orbital Hi …` it rendered as `awk '{print Hi}'` → prints
  empty (`Hi` is an undefined awk variable).
- `skills/initialize/SKILL.md:50` —
  `Peer=$(printf '%s' "$peer" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')`.
  The awk whole-record refs `$0` are replaced by the first token; it rendered as
  `substr(orbital,1,1)` (`orbital` is an undefined awk variable) → prints empty.

Net effect: `peer` and `Peer` both resolve empty, so either the pre-flight halts
(`peer empty`) or the channel is created with blank names. `$ARGUMENTS` itself works (it
is *meant* to be substituted); only the awk `$N` / `$0` are wrong.

### Defect 2 — `wait $MPID` does not block (non-child sentinel)

`skills/initialize/SKILL.md:145` (Step 6) prescribes the background watcher as
`wait $MPID ; echo "channel=$peer event=peer-spoke"`. `new-pid.sh` spawns the sentinel
(`sleep 2147483647`) and **disowns** it inside the Step-4 Bash-tool shell, which then
exits. The Step-6 watcher runs in a *fresh* `run_in_background` shell, where `$MPID` is
**not a child** — bash `wait <non-child>` returns immediately (exit 127, "not a child of
this shell"), so the watcher fires `event=peer-spoke` instantly: a false handshake-ack
before the peer has run `launch-sequence`. The same pattern is in `FlightDirector`
take-turn **Step 7** (`wait $OUR_NEW_PID`).

## Repro & evidence

- Invoked `/mission-control:initialize orbital "Hi from mission control. …"` this session;
  the loaded skill body showed `awk '{print Hi}'` (line 29) and
  `awk '… substr(orbital,1,1) … substr(orbital,2)}'` (line 50) — the live render of
  Defect 1. Worked around by setting `peer=orbital`, `Peer=Orbital`, `rest=<message>`
  explicitly before running Steps 1–8.
- For Defect 2, the background watcher this session was written as a `kill -0` poll loop
  instead of `wait` (`while kill -0 "$MPID" 2>/dev/null; do sleep 3; done`); it correctly
  blocked on sentinel pid `48253` until the peer killed it — corroborating that the poll
  form is the fit one and the bare `wait` is not.

## Goal

`/mission-control:initialize <peer> "<msg>"` parses `peer` / `Peer` / `rest` correctly on
a clean first invocation, and the background watcher blocks until the peer actually kills
the sentinel — no manual intervention, no false `peer-spoke`.

## Scope

- `plugins/mission-control/skills/initialize/SKILL.md` — Defect 1 (lines 29, 50) and
  Defect 2 (Step 6, line 145).
- `plugins/mission-control/skills/FlightDirector/SKILL.md` — Defect 2 only (take-turn
  Step 7). Fix in the same pass for consistency (shared root cause).

## Proposed fix

**Defect 1** — drop all `$N` / `$0` from bash blocks; keep `$ARGUMENTS`:

```bash
# line 29 — first token without awk $1:
peer=$(printf '%s' "$ARGUMENTS" | cut -d' ' -f1)

# line 50 — title-case without awk $0 (bash 3.2 / macOS portable):
first=$(printf '%s' "$peer" | cut -c1 | tr '[:lower:]' '[:upper:]')
tailrest=$(printf '%s' "$peer" | cut -c2-)
Peer="${first}${tailrest}"
```

The `rest=` line already uses `sed` with no `$N` and is fine. Audit confirms only lines
29 & 50 use positional sigils; the `^\".*\"$` regex anchor and the `${rest#\"}` /
`${rest%\"}` named expansions are not affected by positional substitution.

**Defect 2** — replace the non-blocking `wait` with a parentage-independent poll:

```bash
# initialize Step 6 (and FlightDirector take-turn Step 7), run_in_background: true:
while kill -0 "$MPID" 2>/dev/null; do sleep 3; done
echo "channel=$peer event=peer-spoke"
```

Refinement: have the watcher re-read the pid from state.json
(`MPID=$(jq -r '.our_pid' "$state_json")`) instead of relying on a shell var captured in a
prior shell — more robust across the `run_in_background` boundary.

## Open questions

- Is there a supported escape that prevents Claude Code positional substitution inside a
  command body (e.g. `$$1`, `\$1`)? If so, the awk could be retained with escaping rather
  than the `cut` / `tr` rewrite. Verify with the `claude-code-guide` agent before
  choosing; default to the `cut` / `tr` rewrite (unambiguous, no harness-behavior
  dependency).
- Poll interval vs. latency: `sleep 3` adds ≤3s to handshake-ack surfacing. Acceptable;
  tune if needed.

## Non-goals

- No change to the handshake protocol, `state.json` schema, or the
  `kill-pid` / `append-message` / `new-pid` script contracts.
- No new dependencies (`cut` / `tr` / `kill` are coreutils; the already-required `jq`
  covers the refinement).

## Validation

- `/mission-control:initialize testpeer "hello world"` (clean, no prior channel) creates
  `~/.mission-control/testpeer/` with `state.json.channel == "testpeer"`,
  `peer == "Testpeer"`, and a seq=0 block whose body is exactly `hello world`.
- The background watcher stays alive (does **not** emit `event=peer-spoke`) until the
  sentinel pid is killed; killing `our_pid` makes it emit exactly once.
- Single-token input (`/mission-control:initialize lonelyslug`) halts with the usage hint
  (empty `rest`), not a half-created channel.

## Acceptance criteria

- [ ] `initialize/SKILL.md` arg-parsing contains no `$0` / `$1`…`$9`; `peer` / `Peer` /
      `rest` resolve correctly on first invocation.
- [ ] `initialize/SKILL.md` Step 6 watcher blocks until the sentinel dies (no false
      `peer-spoke`).
- [ ] `FlightDirector/SKILL.md` take-turn Step 7 watcher uses the same blocking form.
- [ ] Validation scenarios above pass on macOS default bash 3.2.
- [ ] Skill re-validated with `plugin-dev:plugin-validator` after edits (and authored
      under `plugin-dev:skill-development` discipline).

## Out of scope (future)

- Re-introducing the archived `orbital-ticket` front-door skill for ticket scaffolding
  (see `thoughts.predogfood-bak/archive/ticket-add-orbital-ticket-utility-skill.md`).
- A broader sweep of `$N` collisions across the other mission-control skills
  (`launch-sequence`, `status`, `end-mission`) — **CONFIRMED to recur in `end-mission`**
  (hit live 2026-05-30 during channel teardown): its rendered body showed
  `awk '{print toupper(substr(,1,1)) substr(,2)}'` (the title-case `$1` clobbered to empty)
  and `case "  " in` (the `$ARGUMENTS` guard clobbered to empty). Worked around by executing
  the skill's intent with corrected bash (proper `awk $1`; `PURGE=false`). The follow-up
  sweep is therefore warranted, not speculative — same `cut`/`tr` rewrite applies.
  `status` and `launch-sequence` still to audit.
