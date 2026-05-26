#!/usr/bin/env bash
# read-since-seq.sh — return blocks in <from-file> whose seq > last_read_seq.
#
# Block delimiter: lines matching `^## seq=N ` start a new block. The block
# extends through (but not including) the next `^## seq=` line, or EOF.
#
# Does NOT update state.json — caller is responsible.
#
# All failures are infrastructure (exit 1) — no defense class.
#
# Usage: read-since-seq.sh <from-file> <state.json>

set -euo pipefail

FROM="${1:?missing from-<Peer>.md path}"
STATE="${2:?missing state.json path}"

ATTR_PRE='scripts/read-since-seq.sh §pre-flight'

if ! command -v jq >/dev/null 2>&1; then
  echo "read-since-seq.sh: jq not installed (${ATTR_PRE}) — install jq and retry" >&2
  exit 1
fi

if [[ ! -f "$FROM" ]]; then
  echo "read-since-seq.sh: from-file does not exist: $FROM (${ATTR_PRE})" >&2
  exit 1
fi

if [[ ! -f "$STATE" ]]; then
  echo "read-since-seq.sh: state file does not exist: $STATE (${ATTR_PRE})" >&2
  exit 1
fi

if ! jq -e . "$STATE" >/dev/null 2>&1; then
  echo "read-since-seq.sh: state file is not valid JSON: $STATE (${ATTR_PRE})" >&2
  exit 1
fi

LAST=$(jq -r '.last_read_seq // -1' "$STATE")

# Use awk to split on `^## seq=N ` headers, emit blocks whose N > LAST.
awk -v last="$LAST" '
  BEGIN { keep = 0; buf = "" }
  /^## seq=[0-9]+ / {
    if (keep && buf != "") { print buf }
    buf = ""
    match($0, /seq=[0-9]+/)
    n = substr($0, RSTART+4, RLENGTH-4) + 0
    if (n > last) { keep = 1; buf = $0 } else { keep = 0 }
    next
  }
  { if (keep) { buf = buf "\n" $0 } }
  END { if (keep && buf != "") { print buf } }
' "$FROM"
