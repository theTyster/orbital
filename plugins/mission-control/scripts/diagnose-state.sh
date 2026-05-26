#!/usr/bin/env bash
# diagnose-state.sh — aggregate a channel's state into a single JSON report.
#
# Usage: diagnose-state.sh <state-json-path>
#
# Always emits exactly one JSON object on stdout describing the channel's
# health. Failure modes (missing state file, parse failure, jq absent) are
# reported as diagnosis values, NOT as exit-1 errors — the contract is
# "always emit a diagnosis". Exit codes:
#   0 — JSON emitted (regardless of the diagnosis value)
#   non-zero — only if invoked with no args (handled by ${1:?})
#
# Diagnosis enum:
#   not-init           — state file does not exist
#   awaiting-handshake — our_pid alive, no their_pid yet (post-bootstrap,
#                        pre-peer-launch-sequence)
#   healthy            — both PIDs alive AND both pass canonical-sentinel check
#   peer-crashed       — our_pid alive, their_pid dead
#   self-crashed       — our_pid dead, their_pid alive (or absent)
#   both-dead          — neither PID alive (their_pid present but dead)
#   uuid-corrupt       — alive PID's ps command is not the canonical sentinel
#   parse-error        — state file is not valid JSON OR jq is absent

set -euo pipefail

STATE="${1:?missing state.json path}"

emit() {
  printf '%s\n' "$1"
  exit 0
}

# Helper: is pid alive?
alive() {
  local pid="$1"
  [[ -n "$pid" && "$pid" != "null" ]] && kill -0 "$pid" 2>/dev/null
}

# Helper: ps-command matches the canonical sentinel (`sleep 2147483647`).
# The sentinel string is set by scripts/new-pid.sh; see CANONICAL SENTINEL
# block in new-pid.sh for the contract. Must stay in sync.
is_canonical_sentinel() {
  local pid="$1"
  [[ -n "$pid" && "$pid" != "null" ]] || return 1
  command -v ps >/dev/null 2>&1 || return 1
  local cmd
  cmd=$(ps -p "$pid" -o command= 2>/dev/null || true)
  echo "$cmd" | grep -q 'sleep 2147483647'
}

# Missing state file → not-init (exit 0, not an error).
if [[ ! -e "$STATE" ]]; then
  emit '{"state_exists":false,"diagnosis":"not-init","suggested_action":"initialize"}'
fi

# jq absent → cannot parse; report parse-error.
if ! command -v jq >/dev/null 2>&1; then
  emit '{"state_exists":true,"state_parses":false,"diagnosis":"parse-error","suggested_action":"install jq and retry"}'
fi

# Malformed JSON → parse-error.
if ! jq -e . "$STATE" >/dev/null 2>&1; then
  emit '{"state_exists":true,"state_parses":false,"diagnosis":"parse-error","suggested_action":"resync"}'
fi

# Extract fields.
CHAN=$(jq -r '.channel // empty' "$STATE")
SV=$(jq -r '.schema_version // 0' "$STATE")
OUR_PID=$(jq -r '.our_pid // empty' "$STATE")
THEIR_PID=$(jq -r '.their_pid // empty' "$STATE")
LAST_IN=$(jq -r '.last_read_seq // -1' "$STATE")
LAST_OUT=$(jq -r '.seq // 0' "$STATE")

OUR_ALIVE=false; THEIR_ALIVE=false
OUR_UUID_OK=false; THEIR_UUID_OK=false

if alive "$OUR_PID"; then OUR_ALIVE=true; fi
if alive "$THEIR_PID"; then THEIR_ALIVE=true; fi

if [[ "$OUR_ALIVE" == "true" ]] && is_canonical_sentinel "$OUR_PID"; then OUR_UUID_OK=true; fi
if [[ "$THEIR_ALIVE" == "true" ]] && is_canonical_sentinel "$THEIR_PID"; then THEIR_UUID_OK=true; fi

# Diagnose: start with pid-liveness logic, then apply uuid-corruption override.

# Pre-handshake: no peer pid yet, our side may or may not be alive.
if [[ -z "$THEIR_PID" || "$THEIR_PID" == "null" ]]; then
  if [[ "$OUR_ALIVE" == "true" ]]; then
    DIAG="awaiting-handshake"; ACT="wait for peer"
  else
    DIAG="self-crashed"; ACT="resync"
  fi
else
  # Both pids known — classify by liveness.
  if [[ "$OUR_ALIVE" == "true" && "$THEIR_ALIVE" == "true" ]]; then
    DIAG="healthy"; ACT="continue"
  elif [[ "$OUR_ALIVE" == "true" && "$THEIR_ALIVE" != "true" ]]; then
    DIAG="peer-crashed"; ACT="resync"
  elif [[ "$OUR_ALIVE" != "true" && "$THEIR_ALIVE" == "true" ]]; then
    DIAG="self-crashed"; ACT="resync"
  else
    DIAG="both-dead"; ACT="resync or end-mission"
  fi
fi

# UUID corruption override: if a pid is alive but not the canonical sentinel,
# it means the state file is pointing at an unrelated process — corrupt.
if [[ "$OUR_ALIVE" == "true" && "$OUR_UUID_OK" != "true" ]]; then
  DIAG="uuid-corrupt"; ACT="resync"
fi
if [[ "$THEIR_ALIVE" == "true" && "$THEIR_UUID_OK" != "true" ]]; then
  DIAG="uuid-corrupt"; ACT="resync"
fi

jq -n \
  --arg ch "$CHAN" \
  --argjson sv "$SV" \
  --argjson oa "$([[ $OUR_ALIVE == true ]] && echo true || echo false)" \
  --argjson ta "$([[ $THEIR_ALIVE == true ]] && echo true || echo false)" \
  --argjson ou "$([[ $OUR_UUID_OK == true ]] && echo true || echo false)" \
  --argjson tu "$([[ $THEIR_UUID_OK == true ]] && echo true || echo false)" \
  --argjson li "$LAST_IN" \
  --argjson lo "$LAST_OUT" \
  --arg di "$DIAG" \
  --arg ac "$ACT" \
  '{
    channel: $ch,
    schema_version: $sv,
    state_exists: true,
    state_parses: true,
    our_pid_alive: $oa,
    their_pid_alive: $ta,
    our_pid_uuid_ok: $ou,
    their_pid_uuid_ok: $tu,
    last_seq_in: $li,
    last_seq_out: $lo,
    diagnosis: $di,
    suggested_action: $ac
  }'
