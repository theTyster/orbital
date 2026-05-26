#!/usr/bin/env bash
# append-message.sh — append a seq-numbered timestamped block to the channel's
# to-<Peer>.md and atomically increment state.json[seq].
#
# Usage:  echo "<body>" | append-message.sh <to-file> <intent> <pid> <uuid> <state.json>
#
# Block format:
#   ## seq=N intent=X pid=Y uuid=Z timestamp=ISO8601
#
#   <body>
#
# All failures are infrastructure (exit 1) — no defense class.

set -euo pipefail

TO="${1:?missing to-<Peer>.md path}"
INTENT="${2:?missing intent}"
PID="${3:?missing pid}"
UUID="${4:?missing uuid}"
STATE="${5:?missing state.json path}"

ATTR_PRE='scripts/append-message.sh §pre-flight'

if ! command -v jq >/dev/null 2>&1; then
  echo "append-message.sh: jq not installed (${ATTR_PRE}) — install jq and retry" >&2
  exit 1
fi

if [[ ! -f "$STATE" ]]; then
  echo "append-message.sh: state file does not exist: $STATE (${ATTR_PRE})" >&2
  exit 1
fi

if ! jq -e . "$STATE" >/dev/null 2>&1; then
  echo "append-message.sh: state file is not valid JSON: $STATE (${ATTR_PRE})" >&2
  exit 1
fi

if [[ ! -f "$TO" ]]; then
  echo "append-message.sh: to-file does not exist: $TO (${ATTR_PRE})" >&2
  exit 1
fi

SEQ=$(jq -r '.seq // 0' "$STATE")
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

BODY=$(cat)

if [[ -z "$BODY" ]]; then
  echo "append-message.sh: stdin body is empty — refusing to append a content-less block (${ATTR_PRE})" >&2
  exit 1
fi

# NOTE: >> append is NOT atomic across concurrent writers. The protocol's
# strict turn-taking discipline guarantees only one writer at a time.
{
  printf '\n## seq=%s intent=%s pid=%s uuid=%s timestamp=%s\n\n' \
    "$SEQ" "$INTENT" "$PID" "$UUID" "$TIMESTAMP"
  printf '%s\n' "$BODY"
} >> "$TO"

# Atomically increment seq.
STATE_TMP="${STATE}.tmp.$$"
jq --argjson next "$((SEQ + 1))" '. + {seq: $next}' "$STATE" > "$STATE_TMP"
mv "$STATE_TMP" "$STATE"
