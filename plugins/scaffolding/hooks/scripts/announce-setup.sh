#!/bin/bash
# Scaffolding plugin: SessionStart marker announcer.
#
# Reads `.claude/orbital-setup.json` if it exists and emits a JSON hook
# response that injects a one-line summary into Claude's session context.
# This lets downstream skills know whether `scaffolding:setup` has been run
# (and what was provisioned) without anyone shelling out to detect it.
#
# Output protocol (per Claude Code SessionStart hooks):
#   { "additionalContext": "<one-line status string>" }
# emitted on stdout, exit 0.
#
# Fail-open posture: every error path returns "" (no additionalContext) and
# exits 0 so a misconfigured environment cannot block a session from starting.

set -e

CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$CWD/.claude/orbital-setup.json"

emit() {
  # $1 = context string. Empty string -> no field emitted (cheaper).
  if [ -z "$1" ]; then
    printf '{}\n'
  else
    if command -v jq >/dev/null 2>&1; then
      jq -nc --arg ctx "$1" '{additionalContext: $ctx}'
    else
      # Escape backslashes and quotes for raw JSON output without jq.
      esc=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')
      printf '{"additionalContext":"%s"}\n' "$esc"
    fi
  fi
}

# Opt-out: ORBITAL_SETUP_ANNOUNCE=off silences the hook entirely.
if [ "${ORBITAL_SETUP_ANNOUNCE:-on}" = "off" ]; then
  emit ""
  exit 0
fi

if [ ! -f "$MARKER" ]; then
  emit "orbital: setup marker not found at .claude/orbital-setup.json — run /setup to provision the marketplace's quiet dependencies (thoughts/, .gitignore, swipl/elan/lean as needed)."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  emit "orbital: setup marker present at .claude/orbital-setup.json (jq absent, detail unavailable)."
  exit 0
fi

completed=$(jq -r '.completed_at // "unknown"' "$MARKER" 2>/dev/null || echo "unknown")
plugins=$(jq -r '.plugins_selected // [] | join(",")' "$MARKER" 2>/dev/null || echo "")
lean=$(jq -r '.lean_backend // false' "$MARKER" 2>/dev/null || echo "false")

# Build the prereq summary as "key=value, key=value, ..." for the relevant keys.
prereqs=$(jq -r '
  .prereqs // {} |
  to_entries |
  map(select(.value != null and .value != "skipped")) |
  map("\(.key)=\(.value)") |
  join(", ")
' "$MARKER" 2>/dev/null || echo "")

summary="orbital: setup verified $completed; plugins=[$plugins]; lean_backend=$lean"
if [ -n "$prereqs" ]; then
  summary="$summary; prereqs={$prereqs}"
fi
summary="$summary. Skills should consult \`\${CLAUDE_PLUGIN_ROOT}/skills/setup/scripts/check-setup.sh\` instead of re-probing."

emit "$summary"
exit 0
