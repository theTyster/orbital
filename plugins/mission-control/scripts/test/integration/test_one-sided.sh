#!/usr/bin/env bash
# One-sided integration test for mission-control.
#
# Simulates the peer side via direct file writes + kill calls. Exercises:
# - initial state setup
# - new-pid → append-message → wait spawn → kill cycle
# - read-since-seq → state update → response cycle
# - teardown
#
# Does NOT run the actual slash commands (those require a Claude session).
# Does validate that the script ensemble composes correctly.

source "$(dirname "$0")/../lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  skip_test "jq not available"
fi

SCRIPTS="$(dirname "$0")/../.."

test_start "integration: full mind-map ↔ peer cycle via scripts"

# Set up two fake state dirs — one for the mind-map, one for the peer.
MM_ROOT=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$MM_ROOT")
PEER_ROOT=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$PEER_ROOT")
MM_STATE="$MM_ROOT/state.json"
MM_TO="$MM_ROOT/to-Orbital.md"
MM_FROM="$MM_ROOT/from-Orbital.md"   # will be symlinked to peer's to file
PEER_STATE="$PEER_ROOT/.mission-control-state.json"
PEER_TO="$PEER_ROOT/to-MissionControl.md"

# ─── Stage 1: mind-map initialize ───
echo '{"schema_version":1,"channel":"orbital","self":"MissionControl","peer":"Orbital","seq":0,"last_read_seq":-1}' > "$MM_STATE"
echo "# Channel: orbital" > "$MM_TO"
out_mm=$("$SCRIPTS/new-pid.sh" "$MM_STATE")
MM_PID=$(echo "$out_mm" | awk '{print $1}')
MM_UUID=$(echo "$out_mm" | awk '{print $2}')
TEST_PIDS_TO_KILL+=("$MM_PID")
echo "hello orbital" | "$SCRIPTS/append-message.sh" "$MM_TO" handshake-init "$MM_PID" "$MM_UUID" "$MM_STATE"
seq=$(jq -r '.seq' "$MM_STATE")
assert_eq "MM seq after init" "$seq" "1"

# ─── Stage 2: peer launch-sequence ───
echo '{"schema_version":1,"channel":"orbital","self":"Orbital","peer":"MissionControl","seq":0,"last_read_seq":-1}' > "$PEER_STATE"
echo "# Channel: orbital" > "$PEER_TO"
ln -s "$PEER_TO" "$MM_FROM"
PEER_FROM="$PEER_ROOT/from-MissionControl.md"
ln -s "$MM_TO" "$PEER_FROM"
# Peer reads MM's seq=0 block.
peer_input=$("$SCRIPTS/read-since-seq.sh" "$PEER_FROM" "$PEER_STATE")
echo "$peer_input" | grep -q 'handshake-init' || { echo "  ✗ peer didn't read handshake-init"; exit 1; }
printf "  ✓ peer read handshake-init\n"
# Inject MM's pid/uuid as their_* into peer state BEFORE kill-pid call.
jq --arg p "$MM_PID" --arg u "$MM_UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u, last_read_seq: 0}' \
   "$PEER_STATE" > "$PEER_STATE.tmp" && mv "$PEER_STATE.tmp" "$PEER_STATE"
# Peer spawns own PID, appends ack, kills MM_PID.
out_peer=$("$SCRIPTS/new-pid.sh" "$PEER_STATE")
PEER_PID=$(echo "$out_peer" | awk '{print $1}')
PEER_UUID=$(echo "$out_peer" | awk '{print $2}')
TEST_PIDS_TO_KILL+=("$PEER_PID")
echo "handshake acked" | "$SCRIPTS/append-message.sh" "$PEER_TO" handshake-ack "$PEER_PID" "$PEER_UUID" "$PEER_STATE"
"$SCRIPTS/kill-pid.sh" "$MM_PID" "$MM_UUID" "$PEER_STATE"
sleep 0.2
assert_pid_dead "$MM_PID"
printf "  ✓ MM_PID killed (handshake-ack signal)\n"

# ─── Stage 3: mind-map dispatches via FlightDirector — pretend ───
# In a real session, Claude would see the wait return and trigger FlightDirector.
# Here we simulate: MM reads peer's ack, updates state, spawns new PID, sends a turn.
jq --arg p "$PEER_PID" --arg u "$PEER_UUID" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u, last_read_seq: -1}' \
   "$MM_STATE" > "$MM_STATE.tmp" && mv "$MM_STATE.tmp" "$MM_STATE"
mm_input=$("$SCRIPTS/read-since-seq.sh" "$MM_FROM" "$MM_STATE")
echo "$mm_input" | grep -q 'handshake-ack' || { echo "  ✗ MM didn't read handshake-ack"; exit 1; }
printf "  ✓ MM read handshake-ack\n"

out_mm2=$("$SCRIPTS/new-pid.sh" "$MM_STATE")
MM_PID2=$(echo "$out_mm2" | awk '{print $1}')
MM_UUID2=$(echo "$out_mm2" | awk '{print $2}')
TEST_PIDS_TO_KILL+=("$MM_PID2")
echo "turn 1 from MM" | "$SCRIPTS/append-message.sh" "$MM_TO" turn "$MM_PID2" "$MM_UUID2" "$MM_STATE"
# Inject MM's new pid/uuid as their_* into peer state BEFORE kill-pid call.
jq --arg p "$MM_PID2" --arg u "$MM_UUID2" \
   '. + {their_pid: ($p | tonumber), their_uuid: $u}' \
   "$PEER_STATE" > "$PEER_STATE.tmp" && mv "$PEER_STATE.tmp" "$PEER_STATE"
"$SCRIPTS/kill-pid.sh" "$PEER_PID" "$PEER_UUID" "$MM_STATE"
sleep 0.2
assert_pid_dead "$PEER_PID"
printf "  ✓ PEER_PID killed (turn 1 signal)\n"

# ─── Stage 4: final diagnose-state ───
diag=$("$SCRIPTS/diagnose-state.sh" "$MM_STATE")
state_seq=$(echo "$diag" | jq -r '.last_seq_out')
[[ "$state_seq" -ge 2 ]] || { echo "  ✗ MM seq should be >=2 after 2 sends, got $state_seq"; exit 1; }
printf "  ✓ MM seq = %s after init+turn1\n" "$state_seq"

echo "PASS"
