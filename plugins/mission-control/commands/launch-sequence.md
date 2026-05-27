---
description: Complete a mission-control handshake initiated by Mission Control.
argument-hint: "(no arguments)"
allowed-tools: Bash, Read, Write, Skill
---

Complete a mission-control handshake. Run this in the peer (Astronaut) project
after Mission Control has invoked `/mission-control:initialize <peer> "<message>"`.

## Channel-slug determination

The channel slug is derived from the basename of the current working directory.
This assumes the operator runs the command from the project root — if not, the
pre-flight will catch the mismatch when
`${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/<slug>/` does not exist. If the operator
wants a different slug (e.g., because the project directory name differs from
what Mission Control used), surface and ask before proceeding.

Derive the slug and title-cased form. `${peer^}` is Bash 4+ only — use the
portable awk form instead:

```bash
peer=$(basename "$(pwd)")
Peer=$(printf '%s' "$peer" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
```

Derive canonical paths up front:

```bash
mc_channel_dir="${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/$peer"
peer_state="./thoughts/.mission-control-state.json"
to_mc_md="./thoughts/to-MissionControl.md"
from_mc_md="./thoughts/from-MissionControl.md"
mc_to_peer_md="$mc_channel_dir/to-${Peer}.md"
mc_from_peer_md="$mc_channel_dir/from-${Peer}.md"
```

## Pre-flight

Two checks must both pass before any initialization is attempted.

**Refusal 1 — double-launch guard.** If `$peer_state` exists, run
`diagnose-state.sh` on it and refuse if the diagnosis is `healthy` or
`awaiting-handshake`:

```bash
if [[ -f "$peer_state" ]]; then
  diag=$("${CLAUDE_PLUGIN_ROOT}/scripts/diagnose-state.sh" "$peer_state" | jq -r '.diagnosis')
  case "$diag" in
    healthy|awaiting-handshake)
      echo "channel already active (diagnosis=$diag); run /mission-control:status or end the prior mission first (commands/launch-sequence.md §pre-flight)" >&2
      exit 1
      ;;
    # Other diagnoses (parse-error, not-init, peer-crashed, self-crashed,
    # both-dead, uuid-corrupt) intentionally fall through — they represent
    # recoverable states where re-initialization is the documented remedy.
    # Step 5 will overwrite the existing state.json on the recovery path.
  esac
fi
```

**Refusal 2 — missing Mission Control bootstrap.** If the Mission Control channel
directory does not exist, Mission Control has not yet run
`/mission-control:initialize`:

```bash
if [[ ! -d "$mc_channel_dir" ]]; then
  echo "Mission Control has not initialized channel '$peer' yet (commands/launch-sequence.md §pre-flight) — ask the operator to run /mission-control:initialize $peer \"<message>\" first" >&2
  exit 1
fi
```

## Steps

### Step 1 — Create thoughts directory

```bash
mkdir -p ./thoughts/
```

### Step 2 — Write the peer's outbound channel file

Use a heredoc so bash expands `$peer`, `$Peer`, and `$bootstrapped` at runtime:

```bash
bootstrapped=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
cat > "$to_mc_md" <<EOF
# Channel: $peer
# Self: $Peer ↔ Peer: MissionControl
# Bootstrapped: $bootstrapped
EOF
```

### Step 3 — Symlink peer's outbound into Mission Control's channel directory

This lets Mission Control read our outbound as `from-<Peer>.md`:

```bash
ln -sf "$(pwd)/thoughts/to-MissionControl.md" "$mc_from_peer_md"
```

### Step 4 — Symlink Mission Control's outbound into our project

This lets us read Mission Control's outbound as `from-MissionControl.md`:

```bash
ln -sf "$mc_to_peer_md" "$from_mc_md"
```

### Step 5 — Write peer's initial state.json

Use a heredoc so bash expands `$peer` and `$Peer` at runtime:

```bash
cat > "$peer_state" <<EOF
{
  "schema_version": 1,
  "channel": "$peer",
  "self": "$Peer",
  "peer": "MissionControl",
  "seq": 0,
  "last_read_seq": -1
}
EOF
```

### Step 6 — Read the handshake-init block

Read all blocks since `last_read_seq` (currently -1, so this returns the seq=0
block):

```bash
handshake=$("${CLAUDE_PLUGIN_ROOT}/scripts/read-since-seq.sh" "$from_mc_md" "$peer_state")
```

Parse `MM_PID` and `MM_UUID` from the block header. The header line looks like:

```
## seq=0 intent=handshake-init pid=12345 uuid=abc-123-... timestamp=...
```

Use `grep -oE` (portable on macOS BSD grep and GNU grep) to extract the field
values; this returns nothing on no-match rather than passing the input through:

```bash
header=$(printf '%s\n' "$handshake" | grep -m1 '^## seq=0 ')
MM_PID=$(printf '%s' "$header" | grep -oE 'pid=[0-9]+' | head -n1 | sed 's/^pid=//')
MM_UUID=$(printf '%s' "$header" | grep -oE 'uuid=[^ ]+' | head -n1 | sed 's/^uuid=//')
if [[ -z "$MM_PID" || ! "$MM_PID" =~ ^[0-9]+$ || -z "$MM_UUID" ]]; then
  echo "could not parse MM_PID/MM_UUID from handshake header (commands/launch-sequence.md §steps) — handshake-init block may be malformed" >&2
  exit 1
fi
```

### Step 7 — Inject their_pid / their_uuid / last_read_seq into state.json

```bash
jq --arg p "$MM_PID" --arg u "$MM_UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u, last_read_seq: 0}' \
   "$peer_state" > "$peer_state.tmp.$$" \
   && mv "$peer_state.tmp.$$" "$peer_state"
```

`kill-pid.sh`'s UUID check reads `state.json.their_uuid`; injecting it here
means Step 12's kill will pass the UUID guard without additional setup.

`last_read_seq: 0` records that seq=0 has been consumed so subsequent calls
to `read-since-seq.sh` won't re-emit the handshake-init block.

### Step 8 — Perform the handshake's initial actions (LLM-reasoning step)

**This step is distinct from the mechanical bash steps.** Read the body of
the handshake-init block — everything in `$handshake` after the `## seq=0 ...`
header line — and carry out whatever the operator asked for (e.g., review a
file, answer a question, confirm context). Use your own judgment about what
constitutes an adequate response; proceed to Step 9 once the initial work is
done.

### Step 9 — Spawn the peer's handoff PID

```bash
read OUR_PID OUR_UUID < <("${CLAUDE_PLUGIN_ROOT}/scripts/new-pid.sh" "$peer_state")
```

`new-pid.sh` prints `<pid> <uuid>` on stdout and merges `our_pid` / `our_uuid`
into `$peer_state` atomically.

### Step 10 — Append the handshake-ack block

The body is LLM-determined: write a short summary of what you did in Step 8
in response to the handshake message. Pipe it to `append-message.sh`:

```bash
printf '%s' "<short summary of what you did with the handshake>" | \
  "${CLAUDE_PLUGIN_ROOT}/scripts/append-message.sh" \
  "$to_mc_md" \
  "handshake-ack" \
  "$OUR_PID" \
  "$OUR_UUID" \
  "$peer_state"
```

Replace the `<short summary …>` placeholder with the actual prose you compose
based on Step 8's actions.

### Step 11 — Spawn the background wait

Invoke the **Bash tool** with `run_in_background: true` (NOT a
`&`-backgrounded shell job) and this exact command body:

```bash
wait $OUR_PID ; echo "channel=mission-control event=peer-spoke"
```

Mission Control will kill `$OUR_PID` when it is ready to speak next; the wait
returns and Claude's auto-notification surfaces the event so the operator knows
the channel has incoming traffic.

### Step 12 — Kill MM_PID to signal handshake-ack

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/kill-pid.sh" "$MM_PID" "$MM_UUID" "$peer_state"
```

`kill-pid.sh` confirms that `state.json.their_uuid` matches `$MM_UUID` and
that the process is the canonical sentinel before issuing the kill. Step 7
already injected `their_uuid = MM_UUID`, so the UUID check will pass.

Killing `MM_PID` unblocks the `wait $MPID` (initialize.md's local name for the
same value) that Mission Control's background job is sitting on, surfacing
`event=peer-spoke` on that side and completing the handshake.

### Step 13 — Load the FlightDirector skill

Invoke the Skill tool:

```
skill: "mission-control:FlightDirector"
```

`FlightDirector` is loaded into the session for the remainder of the
mission. It owns the turn-loop dispatch from this point on.

## Notes

- **Plugin required on peer side.** This command relies on the `mission-control`
  plugin being enabled in the peer project's `.claude/settings.json`. The
  `${CLAUDE_PLUGIN_ROOT}` references throughout this body resolve correctly only
  when the plugin is natively installed (reviewer note Q#3 resolution). The
  Mission Control's `/mission-control:initialize` output prints a reminder to that
  effect.
- **Peer state is a single file, not a directory.** `./thoughts/.mission-control-state.json`
  is a single hidden file — per reviewer caveat on the spec's open question #2.
  The peer has at most one active channel (to Mission Control), so a
  per-channel directory would be over-engineered on this side.
- **Slug defaults to `basename "$(pwd)"`.** If the operator wants a different
  slug (because the project directory name differs from the slug Mission Control
  used), they should clarify before running. The pre-flight Refusal 2 on missing
  `$mc_channel_dir` will catch wrong-slug cases and surface the mismatch.
