#!/usr/bin/env bash
# Hook script: auto-validate Prolog facts files after Write/Edit
#
# Called by Claude Code PostToolUse hook when a .pl file is written.
# Reads the tool result from stdin as JSON, extracts the file path,
# and runs swipl validation if it looks like a facts file.
#
# Exit 0 = allow (with feedback), non-zero = block the tool use.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUNNER="${SKILL_DIR}/prolog/run.pl"

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from the hook JSON
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
# PostToolUse for Write/Edit provides tool_input.file_path
fp = data.get('tool_input', {}).get('file_path', '')
print(fp)
" 2>/dev/null || echo "")

# Skip if not a .pl file
[[ "$FILE_PATH" != *.pl ]] && exit 0

# Skip ontology/reasoning/run modules — only validate facts files
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
    ontology.pl|reasoning.pl|run.pl) exit 0 ;;
esac

# Skip if file doesn't exist
[[ ! -f "$FILE_PATH" ]] && exit 0

# Run validation
echo "--- Auto-validating: ${FILE_PATH} ---"
swipl -g "consult('${RUNNER}')" -- "$FILE_PATH" validate 2>&1 || true

exit 0
