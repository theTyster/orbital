#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"

if ! command -v jq >/dev/null 2>&1; then
  skip_test "jq not available"
fi

SCRIPT="$(dirname "$0")/../append-message.sh"

test_start "append-message.sh appends a seq-numbered block and increments seq"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
TO="$TMP/to-Orbital.md"
STATE="$TMP/state.json"
echo "# Channel: orbital" > "$TO"
echo '{"schema_version":1,"seq":0}' > "$STATE"

echo "hello orbital" | "$SCRIPT" "$TO" "handshake-init" 12345 "abc-uuid" "$STATE"

# Block header should be present.
grep -q '^## seq=0 intent=handshake-init pid=12345 uuid=abc-uuid' "$TO" \
  && printf "  ✓ block header written\n" \
  || { echo "  ✗ block header missing"; cat "$TO"; exit 1; }

# Body should be present.
grep -q '^hello orbital$' "$TO" \
  && printf "  ✓ body written\n" \
  || { echo "  ✗ body missing"; exit 1; }

# State.seq should be incremented.
new_seq=$(jq -r '.seq' "$STATE")
assert_eq "state.seq after append" "$new_seq" "1"

# A second append should pick up seq=1.
echo "second block" | "$SCRIPT" "$TO" "turn-response" 99999 "def-uuid" "$STATE"
grep -q '^## seq=1 intent=turn-response pid=99999 uuid=def-uuid' "$TO" \
  && printf "  ✓ second block header at seq=1\n" \
  || { echo "  ✗ second block header wrong"; cat "$TO"; exit 1; }

new_seq=$(jq -r '.seq' "$STATE")
assert_eq "state.seq after 2nd append" "$new_seq" "2"

test_start "append-message.sh handles explicit null seq via jq // fallback"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
TO="$TMP/to-Orbital.md"
STATE="$TMP/state.json"
echo "# Channel: orbital" > "$TO"
echo '{"schema_version":1,"seq":null}' > "$STATE"

echo "null-seq body" | "$SCRIPT" "$TO" "intent" 1 "uuid" "$STATE"

grep -q '^## seq=0 intent=intent pid=1 uuid=uuid' "$TO" \
  && printf "  ✓ null-seq fell back to 0\n" \
  || { echo "  ✗ null seq did not fall back to 0"; cat "$TO"; exit 1; }
new_seq=$(jq -r '.seq' "$STATE")
assert_eq "state.seq after null-seq append" "$new_seq" "1"

test_start "append-message.sh refuses empty stdin body"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
TO="$TMP/to-Orbital.md"
STATE="$TMP/state.json"
echo "# Channel: orbital" > "$TO"
echo '{"schema_version":1,"seq":0}' > "$STATE"

set +e
echo -n "" | "$SCRIPT" "$TO" "intent" 1 "uuid" "$STATE" 2>&1 >/dev/null
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { printf "  ✗ expected exit 1 (refusal), got %s\n" "$rc"; exit 1; }
printf "  ✓ refused empty body with exit 1\n"

# Confirm state.seq did NOT increment (refusal happens before the increment).
seq_after=$(jq -r '.seq' "$STATE")
assert_eq "state.seq unchanged after refusal" "$seq_after" "0"

test_start "append-message.sh refuses non-parseable state.json"
TMP=$(make_tmpdir)
TEST_TMPDIRS_TO_CLEAN+=("$TMP")
TO="$TMP/to-Orbital.md"
STATE="$TMP/state.json"
echo "# Channel: orbital" > "$TO"
echo 'not-json-at-all' > "$STATE"

set +e
echo "body" | "$SCRIPT" "$TO" "intent" 1 "uuid" "$STATE" 2>&1 >/dev/null
rc=$?
set -e
[[ "$rc" -eq 1 ]] || { printf "  ✗ expected exit 1 (parse-guard refusal), got %s\n" "$rc"; exit 1; }
printf "  ✓ refused non-parseable state.json with exit 1\n"

echo "PASS"
