#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  skip_test "jq not available"
fi

SCRIPT="$(dirname "$0")/../kill-pid.sh"
NEWPID="$(dirname "$0")/../new-pid.sh"

# ─── Scenario 1: valid UUID + canonical sentinel → kills ───
test_start "kill-pid.sh kills when UUID matches AND ps shows canonical sentinel"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1}' > "$STATE"
output=$("$NEWPID" "$STATE")
PID=$(echo "$output" | awk '{print $1}')
UUID=$(echo "$output" | awk '{print $2}')
# Confirm new-pid.sh produced the canonical sentinel — guards against silent
# drift if new-pid.sh's sentinel command ever changes again.
ps -p "$PID" -o command= 2>/dev/null | grep -q 'sleep 2147483647' \
  || { echo "  ✗ new-pid.sh did not spawn canonical sentinel (Task 2 drift)"; exit 1; }
printf "  ✓ new-pid.sh spawned canonical sentinel (sleep 2147483647)\n"
# Rename our_* to their_* to match the kill-pid contract.
jq --arg p "$PID" --arg u "$UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u}' \
   "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
TEST_PIDS_TO_KILL+=("$PID")
"$SCRIPT" "$PID" "$UUID" "$STATE"
sleep 0.2
assert_pid_dead "$PID"

# ─── Scenario 2: UUID mismatch → refuses ───
test_start "kill-pid.sh refuses when UUID mismatches"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1}' > "$STATE"
output=$("$NEWPID" "$STATE")
PID=$(echo "$output" | awk '{print $1}')
UUID=$(echo "$output" | awk '{print $2}')
jq --arg p "$PID" --arg u "$UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u}' \
   "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
TEST_PIDS_TO_KILL+=("$PID")
set +e
"$SCRIPT" "$PID" "WRONG-UUID" "$STATE" 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || { printf "  ✗ expected exit 2 (refusal), got %s\n" "$rc"; exit 1; }
printf "  ✓ script exited 2 (refusal) on UUID mismatch\n"
assert_pid_alive "$PID"

# ─── Scenario 3: command-mismatch (non-canonical sentinel) → refuses ───
test_start "kill-pid.sh refuses when ps shows a different command"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1}' > "$STATE"
# Spawn a non-canonical-sentinel process (a sleep with a short duration).
sleep 30 </dev/null >/dev/null 2>&1 &
BAD_PID=$!
disown "$BAD_PID" 2>/dev/null || true
TEST_PIDS_TO_KILL+=("$BAD_PID")
UUID="fake-uuid-1234"
jq --arg p "$BAD_PID" --arg u "$UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u}' \
   "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
set +e
"$SCRIPT" "$BAD_PID" "$UUID" "$STATE" 2>&1
rc=$?
set -e
[[ "$rc" -eq 2 ]] || { printf "  ✗ expected exit 2 (refusal), got %s\n" "$rc"; exit 1; }
printf "  ✓ script exited 2 (refusal) on command mismatch\n"
assert_pid_alive "$BAD_PID"

echo "PASS"
