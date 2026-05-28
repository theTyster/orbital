---
name: end-mission
description: Global teardown of all mission-control channels — invoked explicitly as `/mission-control:end-mission [--purge]`, or whenever the user asks to tear down, end, close, or wind down all mission-control channels. Default archives; `--purge` deletes.
user-invocable: true
argument-hint: "[--purge]"
allowed-tools: Bash, Read
---

Global teardown of all active mission-control channels (Mission Control side only).
Default behavior: archive every active pair under `.archive/<timestamp>/`.
With `--purge`, skip the archive and delete instead.

## Argument parsing

Detect `--purge` via substring match so it works regardless of position or
surrounding whitespace. Leading/trailing space padding prevents false matches
on `--purgex` or similar tokens:

```bash
case " $ARGUMENTS " in
  *" --purge "*|*" --purge") PURGE=true ;;
  *) PURGE=false ;;
esac
```

## Pre-flight

If the Mission Control channel root does not exist there are no active channels to
tear down. This is not an error — exit cleanly:

```bash
MC_ROOT="${MISSION_CONTROL_ROOT:-$HOME/.mission-control}"
if [[ ! -d "$MC_ROOT" ]]; then
  echo "No active channels."
  exit 0
fi
```

## Timestamp

Compute a single archive timestamp for this entire run (hyphens in the time
component, not colons — colons are rejected by some filesystems):

```bash
TS=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
```

## Per-channel loop

Iterate every non-dot subdirectory directly under `$MC_ROOT`. Skip `.archive/`
and any other dot-prefixed entries; skip non-directories; do not recurse:

```bash
# Accumulators for the summary table
ROWS=""

for D in "$MC_ROOT"/*/; do
  # Strip trailing slash to get the bare path, then basename for the slug
  D="${D%/}"
  channel=$(basename "$D")

  # Skip dot-prefixed entries (.archive/, .git/, etc.)
  case "$channel" in
    .*) continue ;;
  esac

  # Skip anything that is not a directory
  [[ -d "$D" ]] || continue

  STATE="$D/state.json"
  PARSE_OK=false
  OUR_PID=""
  OUR_UUID=""
  SEQ="?"

  # ── (a) Read state.json ──────────────────────────────────────────────────
  if [[ -f "$STATE" ]] && jq -e . "$STATE" >/dev/null 2>&1; then
    OUR_PID=$(jq -r  '.our_pid   // ""' "$STATE")
    OUR_UUID=$(jq -r '.our_uuid  // ""' "$STATE")
    SEQ=$(jq -r      '.seq       // "?"' "$STATE")
    if [[ -n "$OUR_PID" && -n "$OUR_UUID" ]]; then
      PARSE_OK=true
    fi
  fi

  if [[ "$PARSE_OK" = false ]]; then
    echo "(skills/end-mission/SKILL.md §per-channel-loop) — $channel: state corrupt; proceeding with teardown" >&2
  fi

  if [[ "$PARSE_OK" = true ]]; then
    # ── (b) Append farewell block ──────────────────────────────────────────
    # Title-case the channel slug to derive the Peer file name.
    # ${peer^} is Bash 4+ only; use portable awk instead.
    Peer=$(printf '%s' "$channel" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
    TO_PEER="$D/to-${Peer}.md"

    if [[ -f "$TO_PEER" ]]; then
      echo "Mission ending. No further messages on this channel." | \
        "${CLAUDE_PLUGIN_ROOT}/scripts/append-message.sh" \
        "$TO_PEER" \
        "farewell" \
        "$OUR_PID" \
        "$OUR_UUID" \
        "$STATE" \
      || echo "(skills/end-mission/SKILL.md §per-channel-loop) — $channel: farewell append failed (continuing)" >&2
    else
      echo "(skills/end-mission/SKILL.md §per-channel-loop) — $channel: to-${Peer}.md not found; skipping farewell" >&2
    fi

    # ── (c) Best-effort kill our own PID ────────────────────────────────────
    # kill-pid.sh validates against state.json[their_uuid], which is the
    # PEER's UUID — not our own.  Since this is the Mission Control side, state.json
    # was written with our_uuid (not their_uuid), so kill-pid.sh would always
    # reject the call.  Pre-injecting their_uuid = our_uuid would mutate a
    # file we are about to archive/purge and is unnecessary complexity.
    # Instead we issue a plain kill: the process is ours, the "best-effort"
    # contract explicitly accepts failure, and || true absorbs the exit code.
    # The sentinel process will also die naturally when its parent Claude shell
    # exits, so missing this kill has no persistent side-effect.
    kill "$OUR_PID" 2>/dev/null || true
  fi

  # ── (d) Archive or purge ──────────────────────────────────────────────────
  ARCHIVE_PATH="(deleted)"
  ACTION="purged"

  if [[ "$PARSE_OK" = false ]]; then
    ACTION="corrupt"
  fi

  if [[ "$PURGE" = true ]]; then
    rm -rf "$D"
    ARCHIVE_PATH="(deleted)"
    if [[ "$ACTION" != "corrupt" ]]; then
      ACTION="purged"
    fi
  else
    ARCHIVE_DIR="$MC_ROOT/.archive/$TS"
    mkdir -p "$ARCHIVE_DIR"
    mv "$D" "$ARCHIVE_DIR/"
    ARCHIVE_PATH="$ARCHIVE_DIR/$channel"
    if [[ "$ACTION" != "corrupt" ]]; then
      ACTION="archived"
    fi
  fi

  # Accumulate summary row (pipe-delimited, printed after the loop)
  ROWS="${ROWS}${channel} | ${ACTION} | ${SEQ} | ${ARCHIVE_PATH}
"
done
```

## Summary table

Print the results after the loop completes:

```bash
if [[ -z "$ROWS" ]]; then
  echo "No active channels."
else
  printf '%-20s | %-8s | %-9s | %s\n' "Channel" "Action" "Final seq" "Archive path"
  printf '%-20s | %-8s | %-9s | %s\n' "--------------------" "--------" "---------" "--------------------"
  printf '%s' "$ROWS" | while IFS='|' read -r col1 col2 col3 col4; do
    # Skip blank trailing line from the accumulator's trailing newline.
    [[ -z "$col1" ]] && continue
    printf '%-20s | %-8s | %-9s | %s\n' \
      "$(printf '%s' "$col1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" \
      "$(printf '%s' "$col2" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" \
      "$(printf '%s' "$col3" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" \
      "$(printf '%s' "$col4" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  done
fi
```

## Notes

- **Farewell block resolves reviewer Q#4.** The explicit `intent=farewell` block
  written by `append-message.sh` gives the peer an unambiguous shutdown signal on
  its next FlightDirector dispatch, rather than leaving it to infer teardown from
  a broken symlink alone.
- **Peer-side cleanup is NOT performed.** This command only cleans up the
  Mission Control side. The peer notices the broken symlink (or missing channel) on its
  next session and handles its own state accordingly.
- **Mission Control side only.** If invoked from a peer-side project, the pre-flight
  finds no `${MISSION_CONTROL_ROOT:-$HOME/.mission-control}/` and exits cleanly with
  `No active channels.` — no error, no partial work.
- **Why `kill` directly instead of `kill-pid.sh`.** `kill-pid.sh` validates
  against `state.json[their_uuid]` (the peer's UUID). On the Mission Control side,
  state.json holds `.our_uuid` but not `.their_uuid`, so `kill-pid.sh` would
  always refuse. Pre-injecting `their_uuid = our_uuid` would mutate state
  immediately before archiving/purging it — unnecessary and confusing. A plain
  `kill $OUR_PID 2>/dev/null || true` achieves the same "best-effort" intent
  without side effects. The sentinel dies naturally when the Claude shell exits
  regardless.
- **Per-pair fault isolation.** A corrupt or missing `state.json` is logged to
  stderr and the channel is still archived/purged (step d runs unconditionally).
  One bad channel never aborts the sweep.
- **Timestamp uses hyphens in time component.** `%H-%M-%S` rather than
  `%H:%M:%S` because colons are disallowed in filenames on some filesystems
  (notably APFS case-insensitive volumes mounted on external drives).
