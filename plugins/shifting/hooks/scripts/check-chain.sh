#!/bin/bash
# Shifting plugin pipeline-artifact gatekeeper.
#
# PreToolUse hook (Read|Bash). Blocks reads of pipeline artifacts whose
# upstream chain is stale relative to the artifact being read. The gate
# checks the immediate upstreams of the artifact-being-read, NOT recursively.
# A stale link further up the chain will trip its own gate on next access.
#
# Opt-out:
#   SHIFTING_GATEKEEPER=off          (canonical, post-rename)
#   LOGIC_FOCUSED_GATEKEEPER=off     (legacy, accepted for migration)
#
# Input: tool-input JSON on stdin (per Claude Code hook protocol).
# Output:
#   - silent permit (exit 0, no stdout) when the chain is intact or no artifact is touched
#   - structured JSON to stderr + exit 2 on the FIRST detected staleness
#
# Fail-open posture: if jq is missing or artifact-chain.json is unreadable,
# emit a stderr warning and permit. The gate is a safety net, not a hard lock,
# and a misconfigured env should not block the user.

set -euo pipefail

# --- opt-out short-circuit ------------------------------------------------
if [ "${SHIFTING_GATEKEEPER:-on}" = "off" ] \
  || [ "${LOGIC_FOCUSED_GATEKEEPER:-on}" = "off" ]; then
  exit 0
fi

# --- dependency check -----------------------------------------------------
if ! command -v jq >/dev/null 2>&1; then
  echo "shifting-gatekeeper: jq not found in PATH; permitting (fail-open)." >&2
  exit 0
fi

# --- locate the artifact-chain table --------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHAIN_FILE="${SCRIPT_DIR}/artifact-chain.json"

if [ ! -r "$CHAIN_FILE" ]; then
  echo "shifting-gatekeeper: artifact-chain.json unreadable at ${CHAIN_FILE}; permitting." >&2
  exit 0
fi

# --- read tool input ------------------------------------------------------
input="$(cat)"

# tool_name not strictly needed (matcher already filters Read|Bash), but
# we use it to pick the right extraction strategy.
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty')"

# Canonical pipeline-artifact regex.
ARTIFACT_RE='thoughts/(existing-world|hypothesis|target-world|model_results|lean_proof_results|adherence_facts)\.pl'

# Collect matched artifact paths into an array.
matches=()

case "$tool_name" in
  Read)
    file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
    if [ -n "$file_path" ]; then
      # Normalize: extract the canonical relative path if the file_path
      # contains the regex anywhere (handles absolute paths to a project).
      if [[ "$file_path" =~ $ARTIFACT_RE ]]; then
        matches+=("thoughts/${BASH_REMATCH[1]}.pl")
      fi
    fi
    ;;
  Bash)
    command_str="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
    if [ -n "$command_str" ]; then
      # Extract every occurrence of the canonical artifact path from the
      # command string. `grep -oE` returns one match per line.
      while IFS= read -r m; do
        [ -n "$m" ] && matches+=("$m")
      done < <(printf '%s' "$command_str" \
                 | grep -oE "$ARTIFACT_RE" \
                 | sort -u || true)
    fi
    ;;
  *)
    # Unknown tool — silent permit. The matcher should have filtered.
    exit 0
    ;;
esac

# No artifact touched → silent permit.
if [ "${#matches[@]}" -eq 0 ]; then
  exit 0
fi

# --- helper: mtime in seconds (portable across macOS/BSD and Linux) ------
mtime_of() {
  local f="$1"
  if [ ! -e "$f" ]; then
    echo ""
    return 0
  fi
  # macOS / BSD stat
  if stat -f '%m' "$f" >/dev/null 2>&1; then
    stat -f '%m' "$f"
    return 0
  fi
  # GNU stat
  if stat -c '%Y' "$f" >/dev/null 2>&1; then
    stat -c '%Y' "$f"
    return 0
  fi
  echo ""
}

# --- helper: emit block decision and exit non-zero -----------------------
emit_block() {
  local artifact="$1"
  local upstream="$2"
  local reason="$3"     # "MISSING" | "STALE"
  local producer="$4"

  # Build the systemMessage. Multi-line via \n is fine inside a JSON string.
  local msg
  msg="Pipeline gatekeeper: ${artifact} access blocked."
  msg="${msg}\n  - upstream ${upstream} is ${reason}"
  msg="${msg}\n  - re-run ${producer} to refresh ${upstream}"
  msg="${msg}\n  - or set SHIFTING_GATEKEEPER=off to bypass"

  # Use jq to produce well-formed JSON (handles escaping).
  jq -nc \
    --arg msg "$(printf '%b' "$msg")" \
    '{
       hookSpecificOutput: { permissionDecision: "deny" },
       systemMessage: $msg
     }' >&2

  exit 2
}

# --- main check loop ------------------------------------------------------
for artifact in "${matches[@]}"; do
  # Look up artifact metadata in the chain table.
  meta="$(jq -c --arg k "$artifact" '.[$k] // empty' "$CHAIN_FILE")"
  if [ -z "$meta" ]; then
    # Artifact not in the chain table — nothing to gate. (Shouldn't happen
    # given the regex, but defensive.)
    continue
  fi

  artifact_mtime="$(mtime_of "$artifact")"

  # If the artifact-being-read doesn't exist, this is a cold-start /
  # producing-skill read; there's no consumption to gate. The producing
  # skill will create it; downstream gates will fire later if needed.
  if [ -z "$artifact_mtime" ]; then
    continue
  fi

  # Walk the upstream list.
  while IFS= read -r upstream; do
    [ -z "$upstream" ] && continue

    upstream_producer="$(jq -r --arg k "$upstream" '.[$k].produced_by // "the producing skill"' "$CHAIN_FILE")"
    upstream_mtime="$(mtime_of "$upstream")"

    if [ -z "$upstream_mtime" ]; then
      # Upstream is referenced by the chain but missing on disk. The
      # downstream artifact exists, so something has been consumed without
      # its source — block.
      emit_block "$artifact" "$upstream" "MISSING" "$upstream_producer"
    fi

    # Staleness: downstream must not predate its upstream.
    # i.e. upstream_mtime > artifact_mtime → STALE.
    if [ "$upstream_mtime" -gt "$artifact_mtime" ]; then
      emit_block "$artifact" "$upstream" "STALE" "$upstream_producer"
    fi
  done < <(printf '%s' "$meta" | jq -r '.upstream[]?')
done

# Chain intact for every touched artifact → silent permit.
exit 0
