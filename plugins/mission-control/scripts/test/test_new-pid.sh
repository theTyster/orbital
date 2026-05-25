#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  skip_test "jq not available"
fi

SCRIPT="$(dirname "$0")/../new-pid.sh"

test_start "new-pid.sh writes pid + uuid into state.json atomically"

TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1,"channel":"orbital","seq":0}' > "$STATE"

output=$("$SCRIPT" "$STATE")

pid=$(echo "$output" | awk '{print $1}')
uuid=$(echo "$output" | awk '{print $2}')

TEST_PIDS_TO_KILL+=("$pid")

assert_pid_alive "$pid"

# uuid must be non-empty
[[ -n "$uuid" ]] || { echo "  ✗ uuid empty"; exit 1; }
printf "  ✓ uuid non-empty: %s\n" "$uuid"

[[ "$uuid" =~ ^[0-9a-f-]{32,36}$ ]] || { printf "  ✗ uuid malformed: %s\n" "$uuid"; exit 1; }
printf "  ✓ uuid format valid\n"

# state.json must now contain our_pid and our_uuid
stored_pid=$(jq -r '.our_pid' "$STATE")
stored_uuid=$(jq -r '.our_uuid' "$STATE")
assert_eq "stored our_pid" "$stored_pid" "$pid"
assert_eq "stored our_uuid" "$stored_uuid" "$uuid"

# Pre-existing fields must be preserved
preserved=$(jq -r '.channel' "$STATE")
assert_eq "preserved channel" "$preserved" "orbital"

echo "PASS"
