#!/usr/bin/env bash
# kill-pid.sh — defensively kill a peer's canonical-sentinel PID.
#
# Two checks must pass before any kill is attempted:
#   1. UUID at state.json[their_uuid] equals the supplied UUID.
#   2. `ps -p <pid> -o command=` substring-matches "sleep 2147483647"
#      (the canonical sentinel; see scripts/new-pid.sh §CANONICAL SENTINEL).
#
# Either failing halts loud with attribution. Per design §Error handling 2.
#
# Usage: kill-pid.sh <pid> <uuid> <state-json-path>

set -euo pipefail

PID="${1:?missing pid}"
UUID="${2:?missing uuid}"
STATE="${3:?missing state.json path}"

ATTR_PRE='scripts/kill-pid.sh §pre-flight'
ATTR_UUID='scripts/kill-pid.sh §uuid-check'
ATTR_PS='scripts/kill-pid.sh §ps-command-check'

if ! command -v jq >/dev/null 2>&1; then
  echo "kill-pid.sh: jq not installed (${ATTR_PRE}) — install jq and retry" >&2
  exit 1
fi

if [[ ! -f "$STATE" ]]; then
  echo "kill-pid.sh: state file does not exist: $STATE (${ATTR_PRE})" >&2
  exit 1
fi

# Check 1: UUID match.
expected=$(jq -r '.their_uuid // empty' "$STATE")
if [[ -z "$expected" ]]; then
  echo "kill-pid.sh: state.json has no .their_uuid field (${ATTR_UUID})" >&2
  exit 2
fi
if [[ "$expected" != "$UUID" ]]; then
  echo "kill-pid.sh: UUID mismatch — expected $expected, got $UUID (${ATTR_UUID})" >&2
  exit 2
fi

# Check 2: ps command match. macOS BSD ps and Linux procps both support
# `-p <pid> -o command=`; the trailing `=` suppresses the header. The
# substring we match for is the canonical sentinel set by new-pid.sh.
if ! command -v ps >/dev/null 2>&1; then
  echo "kill-pid.sh: ps not available (${ATTR_PS})" >&2
  exit 1
fi
cmdline=$(ps -p "$PID" -o command= 2>/dev/null || true)
if [[ -z "$cmdline" ]]; then
  echo "kill-pid.sh: pid $PID not running (${ATTR_PS})" >&2
  exit 2
fi
if ! echo "$cmdline" | grep -q 'sleep 2147483647'; then
  echo "kill-pid.sh: pid $PID is not the canonical sentinel — actual: $cmdline (${ATTR_PS})" >&2
  exit 2
fi

# Both checks passed. Kill.
kill "$PID"
