#!/usr/bin/env bash
# lean-validate.sh — PostToolUse hook for Lean 4 proof validation
# Fires on Edit/Write, validates .lean files via lake build.
# Exit 0 = silent success. Exit 2 = diagnostics shown to Claude.

set -euo pipefail

INPUT=$(cat)

# Extract file path from hook JSON input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ti = d.get('tool_input', {})
print(ti.get('file_path', ti.get('path', '')))
")

# Only process .lean files
[[ "$FILE_PATH" != *.lean ]] && exit 0

# Find the Lake project root (directory containing lakefile.lean)
DIR=$(dirname "$FILE_PATH")
while [ "$DIR" != "/" ]; do
  [ -f "$DIR/lakefile.lean" ] && break
  DIR=$(dirname "$DIR")
done
[ ! -f "$DIR/lakefile.lean" ] && exit 0

# Cold cache guard: warn if Mathlib hasn't been built yet
if [ ! -d "$DIR/.lake/build" ]; then
  echo "lean-validate: project at $DIR has no .lake/build/ — run 'cd $DIR && lake build' first (may take 10-20 min for Mathlib)" >&2
  exit 2
fi

# Check lean is available
if ! command -v lean &>/dev/null; then
  echo "lean-validate: lean not found on PATH. Install via: curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh" >&2
  exit 2
fi

# Validate the specific file using lake env lean (checks imports + type-checking)
cd "$DIR"
REL_PATH="${FILE_PATH#$DIR/}"
OUTPUT=$(lake env lean "$REL_PATH" 2>&1) || {
  echo "lean-validate: build failed for $FILE_PATH" >&2
  echo "$OUTPUT" >&2
  exit 2
}

# Success — silent (exit 0). Claude infers success from absence of errors.
exit 0
