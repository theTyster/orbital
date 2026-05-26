#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  skip_test "jq not available"
fi

SCRIPT="$(dirname "$0")/../read-since-seq.sh"

test_start "read-since-seq.sh returns only blocks newer than last_read_seq"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
FROM="$TMP/from-MissionControl.md"
STATE="$TMP/state.json"
echo '{"schema_version":1,"last_read_seq":1}' > "$STATE"

cat > "$FROM" <<'EOF'
# Channel: orbital

## seq=0 intent=handshake-init pid=100 uuid=u0 timestamp=2026-05-25T00:00:00Z

first block body
spanning two lines

## seq=1 intent=turn pid=101 uuid=u1 timestamp=2026-05-25T00:01:00Z

second block body

## seq=2 intent=turn pid=102 uuid=u2 timestamp=2026-05-25T00:02:00Z

third block body

## seq=3 intent=turn pid=103 uuid=u3 timestamp=2026-05-25T00:03:00Z

fourth block body
EOF

output=$("$SCRIPT" "$FROM" "$STATE")

# Should NOT contain seq=0 or seq=1 (already read).
echo "$output" | grep -q 'seq=0 ' && { echo "  ✗ returned old seq=0 block"; exit 1; }
echo "$output" | grep -q 'seq=1 ' && { echo "  ✗ returned old seq=1 block"; exit 1; }
printf "  ✓ excluded already-read blocks (seq <= 1)\n"

# Should contain seq=2 and seq=3.
echo "$output" | grep -q 'seq=2 ' || { echo "  ✗ missing seq=2 block"; exit 1; }
echo "$output" | grep -q 'seq=3 ' || { echo "  ✗ missing seq=3 block"; exit 1; }
printf "  ✓ included new blocks (seq > 1)\n"

# Bodies should be preserved.
echo "$output" | grep -q 'third block body' || { echo "  ✗ third body missing"; exit 1; }
echo "$output" | grep -q 'fourth block body' || { echo "  ✗ fourth body missing"; exit 1; }
printf "  ✓ block bodies preserved\n"

# state.json should NOT have been modified.
last=$(jq -r '.last_read_seq' "$STATE")
assert_eq "state.last_read_seq unchanged" "$last" "1"

# Initial fresh-read case: last_read_seq = -1 (or absent) returns all blocks.
test_start "read-since-seq.sh returns all blocks when last_read_seq is -1"
echo '{"schema_version":1,"last_read_seq":-1}' > "$STATE"
output=$("$SCRIPT" "$FROM" "$STATE")
echo "$output" | grep -q 'seq=0 ' || { echo "  ✗ should include seq=0"; exit 1; }
echo "$output" | grep -q 'seq=3 ' || { echo "  ✗ should include seq=3"; exit 1; }
printf "  ✓ all four blocks returned\n"

# Saturated-read case: last_read_seq equals max seq returns empty.
test_start "read-since-seq.sh returns empty when last_read_seq equals max seq"
echo '{"schema_version":1,"last_read_seq":3}' > "$STATE"
output=$("$SCRIPT" "$FROM" "$STATE")
[[ -z "$output" ]] || { echo "  ✗ should return empty when all blocks read"; exit 1; }
printf "  ✓ empty output when no new blocks\n"

# Pre-flight guard: refuses non-parseable state.json (per Task 4 C1 pattern).
test_start "read-since-seq.sh refuses non-parseable state.json"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
FROM="$TMP/from-MissionControl.md"
STATE="$TMP/state.json"
echo "# Channel: orbital" > "$FROM"
echo 'not-json-at-all' > "$STATE"
set +e
"$SCRIPT" "$FROM" "$STATE" 2>&1 >/dev/null
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { printf "  ✗ expected exit 1 (parse-guard refusal), got %s\n" "$rc"; exit 1; }
printf "  ✓ refused non-parseable state.json with exit 1\n"

# Pre-flight guard: refuses missing from-file.
test_start "read-since-seq.sh refuses missing from-file"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
STATE="$TMP/state.json"
echo '{"schema_version":1,"last_read_seq":-1}' > "$STATE"
set +e
"$SCRIPT" "$TMP/nonexistent.md" "$STATE" 2>&1 >/dev/null
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { printf "  ✗ expected exit 1 (missing-file refusal), got %s\n" "$rc"; exit 1; }
printf "  ✓ refused missing from-file with exit 1\n"

echo "PASS"
