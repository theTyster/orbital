#!/usr/bin/env bash
# check-setup.sh — query the orbital setup marker
#
# Usage:
#   check-setup.sh                       # exits 0 if marker exists, 1 if not
#   check-setup.sh <prereq>              # exits 0 if marker exists AND <prereq> is "ok"
#   check-setup.sh --print               # prints the marker JSON to stdout
#   check-setup.sh --summary             # prints a one-line human summary
#
# Prereq names match the keys under .prereqs in .claude/orbital-setup.json:
#   thoughts_dir | gitignore | swipl | elan | lean | python3 | jq |
#   mathlib_clone | lean_project
#
# Skills should call this BEFORE running their own detection probes. If it
# returns 0, the user has run `scaffolding:setup` and the named prereq is
# provisioned — skip probing. If it returns 1, either run `scaffolding:setup`
# or fall back to inline probing (skills decide).
#
# This script is the single source of truth for "is setup done?" — do not
# duplicate its logic. If you find yourself writing `command -v swipl` in a
# skill, replace it with `check-setup.sh swipl`.

set -e

MARKER=".claude/orbital-setup.json"

print_marker() {
  [ -f "$MARKER" ] || { echo "{}"; return; }
  cat "$MARKER"
}

print_summary() {
  if [ ! -f "$MARKER" ]; then
    echo "orbital: not set up (run /setup)"
    return
  fi
  if command -v jq >/dev/null 2>&1; then
    local completed plugins
    completed=$(jq -r '.completed_at // "unknown"' "$MARKER")
    plugins=$(jq -r '.plugins_selected // [] | join(",")' "$MARKER")
    echo "orbital: set up $completed ($plugins)"
  else
    # Fail-open without jq — just confirm presence
    echo "orbital: set up (jq absent, no detail)"
  fi
}

check_prereq() {
  local key="$1"
  [ -f "$MARKER" ] || return 1
  if command -v jq >/dev/null 2>&1; then
    local val
    val=$(jq -r --arg k "$key" '.prereqs[$k] // empty' "$MARKER")
    [ "$val" = "ok" ] && return 0
    # Non-empty non-"ok" values (e.g., a path for mathlib_clone) also count
    # as "provisioned" — treat any non-empty value as success.
    [ -n "$val" ] && return 0
    return 1
  else
    # Without jq, fall back to a grep that's good enough for the canonical schema.
    grep -qE "\"$key\"[[:space:]]*:[[:space:]]*\"(ok|[^\"]+)\"" "$MARKER"
  fi
}

case "${1:-}" in
  ""|"--check")
    [ -f "$MARKER" ]
    ;;
  --print)
    print_marker
    ;;
  --summary)
    print_summary
    ;;
  --*)
    echo "check-setup.sh: unknown flag: $1" >&2
    exit 2
    ;;
  *)
    check_prereq "$1"
    ;;
esac
