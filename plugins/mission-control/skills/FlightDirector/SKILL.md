---
name: FlightDirector
description: >
  Runtime state-machine for the mission-control channel. Loaded on both sides
  by the bootstrap commands (`/mission-control:initialize` and
  `/mission-control:launch-sequence`). On each invocation, diagnoses the
  channel(s) it's responsible for via `diagnose-state.sh`, maps the diagnosed
  state crossed with the invocation intent to a deterministic next action,
  executes, and halts loud on unhealthy states. Invocation triggers: (a) a
  background-bash completion notification whose stdout contains
  `channel=<peer> event=peer-spoke`, (b) the user mentioning FlightDirector
  in natural language ("FlightDirector, status of orbital", "FlightDirector,
  resync kimmy", "FlightDirector, splashdown orbital"), or (c) other commands
  (`/mission-control:status`, `/mission-control:end-mission`) invoking it
  internally.
user-invocable: false
allowed-tools: Bash, Read, Write, Skill
---

# FlightDirector — runtime state machine for mission-control

FlightDirector is the runtime intelligence for the mission-control channel.
Once loaded, direct Claude's behavior on every turn until the channel ends or
the session terminates. Every action is deterministic: diagnose first, map
diagnosis × intent to exactly one action, execute, halt loud on anything
unhealthy.

## Invocation contexts

### Notification-triggered

A background Bash process spawned during `/mission-control:initialize` or a
prior take-turn completes. Its stdout contains the canonical line:

```
channel=<peer> event=peer-spoke
```

Claude Code surfaces this as a completion notification. On seeing such a
notification, immediately dispatch the FlightDirector flow against the `<peer>`
channel. The peer name is the exact token between `channel=` and the space
before `event=`.

### User-triggered

The user types a natural-language request that names FlightDirector explicitly
or addresses the channel by peer name. Parse the intent into one of:

`status | resync <peer> | splashdown <peer> | take-turn <peer>`

Intent recognition patterns:

| Spoken variation | Resolved intent |
|---|---|
| "status", "check", "report", "how's \<peer\>", "what's the status of \<peer\>" | `status` |
| "resync \<peer\>", "re-sync", "restart channel", "reinitialize \<peer\>" | `resync` |
| "splashdown \<peer\>", "close \<peer\>", "graceful end of \<peer\>", "end \<peer\>" | `splashdown` |
| "turn", "respond", "continue \<peer\>", "take a turn on \<peer\>" | `take-turn` (rare — usually notification-triggered) |

When no peer name is given ("FlightDirector, what's happening?"), the channel
target is **all** — iterate every channel under the appropriate state root.

### Command-triggered

`/mission-control:status` and `/mission-control:end-mission` invoke this skill
internally for per-channel work. The invoking command passes the channel name
and intent explicitly.

## Channel identification

Determine which channel(s) to act on per invocation context:

- **Notification context:** parse `channel=<peer>` from the notification
  stdout. Act on that single channel.
- **User-triggered, peer named:** act on the named peer.
- **User-triggered, no peer named ("all"):** iterate every channel under the
  appropriate state root (Mission Control side: every non-dot subdirectory
  under `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/`; Astronaut side:
  the single file `./thoughts/.mission-control-state.json`).
- **Command-triggered:** act on the channel(s) the invoking command specifies.

## State-path resolution

Resolve the correct paths before calling any script.

| Context | File | Path |
|---|---|---|
| Mission Control side, channel `<peer>` — state | `state.json` | `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/<peer>/state.json` |
| Mission Control side, channel `<peer>` — outbound | `to-<Peer>.md` | `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/<peer>/to-<Peer>.md` |
| Mission Control side, channel `<peer>` — inbound | `from-<Peer>.md` | `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/<peer>/from-<Peer>.md` (symlink set by Astronaut's `launch-sequence`) |
| Astronaut side — state | `.mission-control-state.json` | `./thoughts/.mission-control-state.json` |
| Astronaut side — outbound | `to-MissionControl.md` | `./thoughts/to-MissionControl.md` |
| Astronaut side — inbound | `from-MissionControl.md` | `./thoughts/from-MissionControl.md` (symlink to Mission Control's `to-<Peer>.md`) |

`<Peer>` is the title-cased form of `<peer>` (e.g., `orbital` → `Orbital`).
Use portable awk title-casing — `${peer^}` is Bash 4+ only and unavailable on
macOS default Bash 3.2:

```bash
Peer=$(printf '%s' "$peer" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
```

## Dispatch matrix (state × intent → action)

Run `${CLAUDE_PLUGIN_ROOT}/scripts/diagnose-state.sh <state-path>` first to
obtain the JSON report. The `diagnosis` field crossed with the invocation
intent maps to exactly one action.

| Diagnosis | Intent | Action |
|---|---|---|
| `not-init` | initialize | Run `/mission-control:initialize <peer> "<msg>"` (Mission Control side). |
| `not-init` | anything else | **Halt loud:** `no channel for <peer>; run /mission-control:initialize <peer> "<message>"` — attribute `(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §state_exists`. |
| `awaiting-handshake` | notification | Handshake-ack arriving — peer just killed our PID. Run take-turn flow with `intent=handshake-ack`. |
| `awaiting-handshake` | status | Report: "channel `<peer>` is awaiting handshake; waiting on peer to run `/mission-control:launch-sequence`". |
| `awaiting-handshake` | anything else | Report awaiting-handshake status; no action until peer responds. |
| `healthy` | notification | Run take-turn flow (see below). |
| `healthy` | status | Report: "channel `<peer>` healthy; last-out seq=N, last-in seq=M". |
| `healthy` | take-turn | Run take-turn flow. |
| `healthy` | resync | Tear down + re-initialize (see resync row below). |
| `healthy` | splashdown | Run splashdown action (see splashdown row below). |
| `peer-crashed` | any | **Halt loud:** `peer PID dead for <peer>` — attribute `(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §their_pid_alive`. Recovery hint: `FlightDirector, resync <peer>` or `/mission-control:end-mission`. |
| `self-crashed` | any | **Halt loud:** `our PID died unexpectedly for <peer>` — attribute `(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §our_pid_alive`. Recovery hint: `FlightDirector, resync <peer>`. |
| `both-dead` | any | **Halt loud:** `channel <peer> stale — both PIDs dead` — attribute `(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §pid-alive-check`. Recovery hint: `FlightDirector, resync <peer>` or `/mission-control:end-mission`. |
| `uuid-corrupt` | any | **Halt loud:** `state corrupt for <peer> — ps command does not match the canonical sentinel (sleep 2147483647)` — attribute `(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §is_canonical_sentinel`. Recovery hint: `FlightDirector, resync <peer>`. |
| `parse-error` | any | **Halt loud:** `state.json corrupt for <peer> — JSON parse failed or jq absent` — attribute `(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §parse-error`. Recovery hint: `FlightDirector, resync <peer>`. |
| any | resync | Archive channel dir, then run `/mission-control:initialize <peer> "<resync message>"`. Briefly acknowledge the resync reason in the handshake message. |
| any | splashdown | Append `intent=farewell` block to `to-<Peer>.md` via `append-message.sh`, kill our own PID (`kill-pid.sh` with our `our_pid` / `our_uuid`), then `mv` the channel dir to `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/.archive/<TS>/`. Per-channel graceful equivalent of `/mission-control:end-mission`. |
| any | end-mission | Defer to `/mission-control:end-mission` command. |

## Take-turn flow

The take-turn flow is the **only LLM-reasoning step** in the loop. All other
steps are mechanical bash. Execute in this exact order:

### Step 1 — Read new blocks

```bash
new_blocks=$("${CLAUDE_PLUGIN_ROOT}/scripts/read-since-seq.sh" \
  "$from_file" "$state_path")
```

If `new_blocks` is empty (peer hasn't spoken yet), log "no new blocks" and
stop — do not advance state or emit a response.

### Step 2 — Inject peer's new pid/uuid from block header

For each new block, parse `pid=` and `uuid=` from the `## seq=N intent=X pid=Y uuid=Z ...` header line. These are the peer's NEW PID and UUID, registered for this turn.

```bash
PEER_NEW_PID=$(printf '%s\n' "$new_blocks" | grep -oE 'pid=[0-9]+' | head -n1 | sed 's/^pid=//')
PEER_NEW_UUID=$(printf '%s\n' "$new_blocks" | grep -oE 'uuid=[^ ]+' | head -n1 | sed 's/^uuid=//')

jq --arg p "$PEER_NEW_PID" --arg u "$PEER_NEW_UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u}' \
   "$state_path" > "$state_path.tmp.$$" \
   && mv "$state_path.tmp.$$" "$state_path"
```

### Step 3 — ACT (LLM-reasoning step)

Read the body of each new block — everything after the `## seq=N ...` header
line. The `intent=` field on the header hints at the kind of content:
`handshake-init`, `handshake-ack`, `turn`, `question`, `answer`, `farewell`.

Reason about what the peer asked, what task to perform, or what response to
give. This is the only step that requires LLM judgment; all others are
mechanical. Complete the work before proceeding to Step 4.

### Step 4 — Spawn our new handoff PID

```bash
read OUR_NEW_PID OUR_NEW_UUID < <("${CLAUDE_PLUGIN_ROOT}/scripts/new-pid.sh" "$state_path")
```

`new-pid.sh` prints exactly one line `<pid> <uuid>` on stdout and merges
`our_pid` / `our_uuid` into `state.json` atomically.

### Step 5 — Update last_read_seq

```bash
HIGHEST_SEQ=$(printf '%s\n' "$new_blocks" | grep -oE '^## seq=[0-9]+' | grep -oE '[0-9]+$' | sort -n | tail -n1)
jq --argjson s "$HIGHEST_SEQ" '. + {last_read_seq: $s}' \
   "$state_path" > "$state_path.tmp.$$" \
   && mv "$state_path.tmp.$$" "$state_path"
```

### Step 6 — Append our response block

```bash
printf '%s' "<response body from Step 3>" | \
  "${CLAUDE_PLUGIN_ROOT}/scripts/append-message.sh" \
  "$to_file" \
  "turn" \
  "$OUR_NEW_PID" \
  "$OUR_NEW_UUID" \
  "$state_path"
```

Use `intent=handshake-ack` when responding to a `handshake-init` block.

### Step 7 — Spawn the background wait (run_in_background: true)

Invoke the Bash tool with `run_in_background: true`:

```bash
wait $OUR_NEW_PID ; echo "channel=<peer> event=peer-spoke"
```

This is a Claude-runtime behavior — use the Bash tool's `run_in_background`
parameter, NOT a `&`-backgrounded shell job. The peer will kill `$OUR_NEW_PID`
to signal they are ready; the wait returns and Claude's notification surfaces
the event.

### Step 8 — Kill the peer's currently-alive pid to signal our turn is done

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/kill-pid.sh" \
  "$PEER_NEW_PID" "$PEER_NEW_UUID" "$state_path"
```

This kills the peer's currently-alive sentinel — the pid the peer just
registered in their latest block header (extracted and injected into
state.json in Step 2). `kill-pid.sh` performs a UUID guard against
`state.json.their_uuid` (which holds `PEER_NEW_UUID` after the inject) and a
`ps` canonical-sentinel check before issuing the kill. Killing this sentinel
is the signal to the peer that our response is written and they can proceed.

## Multi-channel fanout

When Mission Control has N channels active:

- Each channel has its own background `wait` process. Each `wait` prints
  `channel=<peer>` so notifications are unambiguously disambiguated by peer
  name.
- Two near-simultaneous notifications are handled in arrival order.
- Each channel's state directory is isolated under
  `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/<peer>/`. An error in one
  channel must NOT halt processing of another. Apply the same per-pair fault
  isolation discipline used in `/mission-control:status`: on a fault in one
  channel, emit the halt-loud message for that channel and continue iterating
  the remaining channels.
- When iterating "all channels", skip any directory entry whose basename starts
  with `.` (covers `.archive/` and other dot-prefixed system directories).

## Operator-interjection between turns

If the operator types a new question to Mission Control while a turn is in
flight (our response has been sent, the peer has not yet replied), route the
operator's question as a normal Mission Control task — do not gate it on the
peer's reply. Mission Control's primary interlocutor is the operator; channels
are a secondary surface. When the peer's reply eventually arrives,
FlightDirector will notice the notification and resume the turn loop at that
point.

## Halt-loud-with-attribution discipline

Every error path must print three things before stopping:

1. **Failing condition** — what was wrong (UUID mismatch, dead PID, dangling
   symlink, parse error, etc.).
2. **Attribution** — the script and section that diagnosed the failure, in the
   form `(skills/FlightDirector/SKILL.md §<section>) — scripts/<name>.sh §<section>`.
3. **Recovery hint** — exactly one of: `run /mission-control:status` or
   `FlightDirector, resync <peer>` or `/mission-control:end-mission`.

Do NOT silently retry, fabricate state, or fall back to defaults. Failures must
be visible to the operator immediately.

Example halt-loud message:

```
state corrupt for orbital — ps command does not match the canonical sentinel (sleep 2147483647)
(skills/FlightDirector/SKILL.md §dispatch-matrix) — scripts/diagnose-state.sh §is_canonical_sentinel
Recovery: FlightDirector, resync orbital
```
