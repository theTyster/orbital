#!/usr/bin/env bash
# new-pid.sh — spawn a sleep-infinity PID, generate a UUID, record both into
# the given state.json atomically. Prints "<pid> <uuid>" to stdout.
#
# Usage: new-pid.sh <state-json-path>
#
# Contract: see plugins/mission-control/docs/2026-05-25-design.md §Scripts.

set -euo pipefail

STATE="${1:?missing state.json path}"

if [[ ! -f "$STATE" ]]; then
  echo "new-pid.sh: state file does not exist: $STATE" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "new-pid.sh: jq not installed (scripts/new-pid.sh §jq-check) — install jq and retry" >&2
  exit 1
fi

# Generate UUID: prefer uuidgen, fall back to /dev/urandom.
if command -v uuidgen >/dev/null 2>&1; then
  UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
else
  UUID=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null \
    | od -An -tx1 \
    | tr -d ' \n' \
    | head -c 32)
fi

# Spawn the long-lived sentinel. BSD sleep (macOS) does not accept "infinity";
# use a large integer (~68 years) that works on both BSD and GNU userland.
# Redirect to /dev/null so the spawned process does not hold the command-
# substitution subshell's file descriptors open (which would cause callers
# using $(...) to hang). Disown so it survives the parent shell's exit.
#
# CANONICAL SENTINEL: ps -p <pid> -o command= will show exactly
#   sleep 2147483647
# kill-pid.sh §ps-command-check (Task 3) and diagnose-state.sh's
# is_canonical_sentinel helper (Task 6) MUST grep for the string above,
# NOT 'sleep infinity'.
sleep 2147483647 </dev/null >/dev/null 2>&1 &
PID=$!
disown "$PID" 2>/dev/null || true

# Atomically merge into state.json.
STATE_TMP="${STATE}.tmp.$$"
jq --arg pid "$PID" --arg uuid "$UUID" \
   '. + {our_pid: ($pid | tonumber), our_uuid: $uuid}' \
   "$STATE" > "$STATE_TMP"
mv "$STATE_TMP" "$STATE"

echo "$PID $UUID"
