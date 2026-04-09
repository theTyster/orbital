#!/usr/bin/env bash
# run-query.sh — Wrapper around swipl that logs every query and its output
#
# Usage: run-query.sh <facts_file> <command> [args...]
#
# Runs the Prolog runner with the given arguments and appends a timestamped
# log entry (command + full output) to <facts_basename>_queries.md alongside
# the facts file. Output is still printed to stdout normally.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="${SKILL_DIR}/prolog/run.pl"

if [[ $# -lt 1 ]]; then
  echo "Usage: run-query.sh <facts_file> [command] [args...]" >&2
  exit 1
fi

FACTS_FILE="$1"
shift
COMMAND="${*:-full}"

# Derive log file path: /path/to/facts_queries.md
FACTS_DIR="$(dirname "$FACTS_FILE")"
FACTS_BASE="$(basename "$FACTS_FILE" .pl)"
LOG_FILE="${FACTS_DIR}/${FACTS_BASE}_queries.md"

# Create log header on first use
if [[ ! -f "$LOG_FILE" ]]; then
  cat > "$LOG_FILE" <<EOF
# Prolog Query Log

Facts file: \`${FACTS_FILE}\`

---

EOF
fi

# Build the swipl command
SWIPL_CMD=(swipl -g "consult('${RUNNER}')" -- "$FACTS_FILE" $COMMAND)

# Capture output while still printing to stdout
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
OUTPUT="$("${SWIPL_CMD[@]}" 2>&1)" || true

# Print to stdout
echo "$OUTPUT"

# Append to log
cat >> "$LOG_FILE" <<EOF
### ${TIMESTAMP} — ${COMMAND}

\`\`\`
${SWIPL_CMD[*]}
\`\`\`

\`\`\`
${OUTPUT}
\`\`\`

---

EOF
