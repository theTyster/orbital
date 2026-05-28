---
name: initialize
description: Bootstrap a new mission-control channel from Mission Control. Only invoke when explicitly requested as `/mission-control:initialize <peer-slug> "<message>"` — this command spawns a background PID and mutates filesystem state; do NOT auto-trigger from natural-language descriptions of channel setup.
user-invocable: true
argument-hint: "<peer-slug> \"<initial message>\""
allowed-tools: Bash, Read, Write, Skill
---

Bootstrap a new mission-control channel from this (Mission Control) session.

## Argument parsing

The `$ARGUMENTS` string contains two parts:

1. **`<peer-slug>`** — the first whitespace-separated token. e.g., `orbital`,
   `kimmy`, `c-f-a`. Used as the channel's directory name and in the symmetric
   file naming (`to-Orbital.md` etc.).
2. **`<initial message>`** — everything after the first token, with surrounding
   double-quotes (if present) stripped. This is the operator's handshake content,
   appended as the body of the seq=0 block.

If `$ARGUMENTS` has fewer than two tokens — i.e., `peer` or `rest` resolves to
empty — halt immediately with the usage hint and exit. Do NOT partially
initialize a channel.

Run this bash to parse and validate:

```bash
peer=$(printf '%s' "$ARGUMENTS" | awk '{print $1}')
rest=$(printf '%s' "$ARGUMENTS" | sed 's/^[^[:space:]]*[[:space:]]*//')

# Strip surrounding double-quotes from rest if present (bash 3.2-compatible):
if [[ "$rest" =~ ^\".*\"$ ]]; then
  rest="${rest#\"}"   # strip leading "
  rest="${rest%\"}"   # strip trailing "
fi

# Validate — both tokens must be non-empty:
if [[ -z "$peer" || -z "$rest" ]]; then
  echo 'usage: /mission-control:initialize <peer-slug> "<initial message>" (skills/initialize/SKILL.md §argument-parsing) — provide both peer-slug and an initial message' >&2
  exit 1
fi
```

**Title-casing the peer slug** for file-name construction (`to-Orbital.md` etc.).
`${peer^}` is Bash 4+ only and unavailable on macOS default Bash 3.2. Use a
portable form instead:

```bash
Peer=$(printf '%s' "$peer" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
```

Derive the canonical paths up front:

```bash
channel_dir="${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/$peer"
state_json="$channel_dir/state.json"
to_peer_md="$channel_dir/to-${Peer}.md"
```

## Pre-flight

Refuse to proceed if `state.json` already exists for this peer:

```bash
if [[ -f "$state_json" ]]; then
  echo "channel '$peer' already initialized; run /mission-control:status or /mission-control:end-mission first (skills/initialize/SKILL.md §pre-flight)" >&2
  exit 1
fi
```

## Steps

### Step 1 — Create channel directory

```bash
mkdir -p "$channel_dir"
```

### Step 2 — Write initial state.json

Use a heredoc so bash expands `$peer` and `$Peer` at runtime:

```bash
cat > "$state_json" <<EOF
{
  "schema_version": 1,
  "channel": "$peer",
  "self": "MissionControl",
  "peer": "$Peer",
  "seq": 0,
  "last_read_seq": -1
}
EOF
```

`schema_version: 1` is written explicitly from the first write (secondary concern
§state.json schema versioning).

### Step 3 — Create the channel markdown file

Use a heredoc to create `$to_peer_md` with the three-line channel header:

```bash
bootstrapped=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$to_peer_md" <<EOF
# Channel: $peer
# Self: MissionControl ↔ Peer: $Peer
# Bootstrapped: $bootstrapped
EOF
```

### Step 4 — Spawn the handoff PID

```bash
read MPID MUUID < <("${CLAUDE_PLUGIN_ROOT}/scripts/new-pid.sh" "$state_json")
```

`new-pid.sh` prints exactly one line `<pid> <uuid>` on stdout and merges
`our_pid` and `our_uuid` into `state.json` atomically. Prerequisite: `state.json`
must already exist (Step 2 satisfies this).

### Step 5 — Append the operator's initial message

```bash
printf '%s' "$rest" | "${CLAUDE_PLUGIN_ROOT}/scripts/append-message.sh" \
  "$to_peer_md" \
  "handshake-init" \
  "$MPID" \
  "$MUUID" \
  "$state_json"
```

`append-message.sh` reads the body from stdin, writes the seq-numbered block
(carrying `pid=$MPID uuid=$MUUID` in the header), and increments `state.json[seq]`.
The peer reads the PID and UUID from this header and uses them to call
`kill-pid.sh` after sending its handshake-ack.

### Step 6 — Spawn the background wait

Invoke the **Bash tool** with `run_in_background: true` and this exact command
body:

```bash
wait $MPID ; echo "channel=$peer event=peer-spoke"
```

This is a Claude-runtime behavior: use the Bash tool's `run_in_background`
parameter, NOT a `&`-backgrounded shell job. The peer will kill `$MPID` to
signal handshake-ack; the wait returns and Claude's auto-notification surfaces
the channel name so the operator knows the handshake completed.

### Step 7 — Load the FlightDirector skill

Invoke the Skill tool:

```
skill: "mission-control:FlightDirector"
```

`FlightDirector` is loaded into the session for the remainder of the
mission. It owns the turn-loop dispatch from this point on.

### Step 8 — Print operator instruction

Print this one-line message to stdout:

```
Run /mission-control:launch-sequence in your <peer-project> Claude Code session
to complete the handshake. (Ensure the mission-control plugin is enabled in the
peer project's .claude/settings.json.)
```

## Notes

- **No symlinking.** This command does NOT symlink `launch-sequence` or any other
  file into the peer's `.claude/commands/`. Per reviewer note Q#3 (in
  `docs/2026-05-25-design.md`), the peer is required to enable the
  `mission-control` plugin on their side. That gives them native access to
  `/mission-control:launch-sequence` and correct `${CLAUDE_PLUGIN_ROOT}`
  resolution in all their scripts.
- **`schema_version: 1`** is written explicitly in the initial state.json
  (reviewer secondary concern §state.json schema versioning, Q#5). Downstream
  tools (e.g., `diagnose-state.sh`) read `.schema_version // 0` — the `// 0`
  default is the upgrade-detection sentinel for files written before versioning
  was added.
- **Handshake header.** The seq=0 block written by `append-message.sh` carries
  `pid=$MPID uuid=$MUUID` in its header. The peer reads these values and passes
  them to `kill-pid.sh` to complete the handshake-ack, confirming it received the
  message and signalling the background wait in Step 6 to return.
