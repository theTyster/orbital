#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  skip_test "jq not available"
fi

SCRIPT="$(dirname "$0")/../diagnose-state.sh"
NEWPID="$(dirname "$0")/../new-pid.sh"

# ─── Scenario 1: state file missing → diagnosis = "not-init" ───
test_start "diagnose-state.sh reports not-init when state file absent"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
output=$("$SCRIPT" "$TMP/state.json")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (missing state)" "$diag" "not-init"

# ─── Scenario 2: healthy two-side state ───
test_start "diagnose-state.sh reports healthy when both PIDs alive"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1,"channel":"orbital","seq":0}' > "$STATE"
out_me=$("$NEWPID" "$STATE")
ME_PID=$(echo "$out_me" | awk '{print $1}')
TEST_PIDS_TO_KILL+=("$ME_PID")
# Spawn a "peer" canonical sentinel and inject its pid+uuid as their_*.
# Uses the same `sleep 2147483647` shape as scripts/new-pid.sh.
sleep 2147483647 </dev/null >/dev/null 2>&1 & PEER_PID=$!
disown "$PEER_PID" 2>/dev/null || true
TEST_PIDS_TO_KILL+=("$PEER_PID")
PEER_UUID="peer-uuid-fake"
jq --arg p "$PEER_PID" --arg u "$PEER_UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u}' \
   "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
output=$("$SCRIPT" "$STATE")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (both alive)" "$diag" "healthy"

# ─── Scenario 3: peer-crashed ───
test_start "diagnose-state.sh reports peer-crashed when their_pid dead"
kill "$PEER_PID" 2>/dev/null || true
sleep 0.2
output=$("$SCRIPT" "$STATE")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (peer dead)" "$diag" "peer-crashed"

# ─── Scenario 4: both-dead ───
test_start "diagnose-state.sh reports both-dead when neither PID alive"
kill "$ME_PID" 2>/dev/null || true
sleep 0.2
output=$("$SCRIPT" "$STATE")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (both dead)" "$diag" "both-dead"

# ─── Scenario 5: parse-error ───
test_start "diagnose-state.sh reports parse-error on malformed JSON"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo 'not-json-at-all' > "$STATE"
output=$("$SCRIPT" "$STATE")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (bad json)" "$diag" "parse-error"

# ─── Scenario 6: awaiting-handshake (post-bootstrap, pre-peer-launch) ───
test_start "diagnose-state.sh reports awaiting-handshake when our_pid alive but no their_pid"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1,"channel":"orbital","seq":0}' > "$STATE"
out_me=$("$NEWPID" "$STATE")
ME_PID=$(echo "$out_me" | awk '{print $1}')
TEST_PIDS_TO_KILL+=("$ME_PID")
# Do NOT inject their_pid/their_uuid — simulates pre-handshake state.
output=$("$SCRIPT" "$STATE")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (pre-handshake)" "$diag" "awaiting-handshake"
kill "$ME_PID" 2>/dev/null || true

# ─── Scenario 7: uuid-corrupt (our_pid alive but not the canonical sentinel) ───
test_start "diagnose-state.sh reports uuid-corrupt when our_pid is alive but not canonical sentinel"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
# Spawn a non-canonical sleep, register it as our_pid.
sleep 30 </dev/null >/dev/null 2>&1 & FAKE_PID=$!
disown "$FAKE_PID" 2>/dev/null || true
TEST_PIDS_TO_KILL+=("$FAKE_PID")
echo "{\"schema_version\":1,\"our_pid\":$FAKE_PID,\"our_uuid\":\"fake\"}" > "$STATE"
output=$("$SCRIPT" "$STATE")
diag=$(echo "$output" | jq -r '.diagnosis')
assert_eq "diagnosis (uuid-corrupt)" "$diag" "uuid-corrupt"

echo "PASS"
