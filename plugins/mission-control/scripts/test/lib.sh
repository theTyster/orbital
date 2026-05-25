#!/usr/bin/env bash
# Shared test helpers for mission-control script tests.
# Source from each test_*.sh: source "$(dirname "$0")/lib.sh"

set -euo pipefail

# Print a heading for the test under run.
test_start() {
  local name="$1"
  printf "▶ %s\n" "$name"
}

# Assert two strings equal. Fails the test on mismatch.
assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" != "$expected" ]]; then
    printf "  ✗ %s: expected %q, got %q\n" "$label" "$expected" "$actual" >&2
    exit 1
  fi
  printf "  ✓ %s\n" "$label"
}

# Assert a process is alive.
assert_pid_alive() {
  local pid="$1"
  if ! kill -0 "$pid" 2>/dev/null; then
    printf "  ✗ pid %s not alive\n" "$pid" >&2
    exit 1
  fi
  printf "  ✓ pid %s alive\n" "$pid"
}

# Assert a process is NOT alive.
assert_pid_dead() {
  local pid="$1"
  if kill -0 "$pid" 2>/dev/null; then
    printf "  ✗ pid %s still alive\n" "$pid" >&2
    exit 1
  fi
  printf "  ✓ pid %s dead\n" "$pid"
}

# Assert a file exists (follows symlinks).
assert_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf "  ✗ file missing: %s\n" "$path" >&2
    exit 1
  fi
  printf "  ✓ file present: %s\n" "$path"
}

# Skip the test with a reason (exit 0 with marker).
skip_test() {
  printf "  ⊝ SKIP: %s\n" "$*"
  exit 0
}

# Cleanup helper arrays — populated at test runtime.
declare -a TEST_PIDS_TO_KILL=()
declare -a TEST_TMPDIRS_TO_CLEAN=()

# Set up a temp working dir. NOTE: callers must explicitly register the
# returned path for cleanup because `$(make_tmpdir)` runs in a subshell
# in bash 3.2 — any array mutation inside the function is lost on return.
# Convention:
#     TMP=$(make_tmpdir)
#     TEST_TMPDIRS_TO_CLEAN+=("$TMP")
make_tmpdir() {
  mktemp -d 2>/dev/null || mktemp -d -t 'mctest'
}

# Cleanup helper — kill PIDs and remove temp dirs on exit.
cleanup_test_state() {
  if [[ "${#TEST_PIDS_TO_KILL[@]}" -gt 0 ]]; then
    for pid in "${TEST_PIDS_TO_KILL[@]}"; do
      [[ -z "$pid" ]] && continue
      kill -9 "$pid" 2>/dev/null || true
    done
  fi
  if [[ "${#TEST_TMPDIRS_TO_CLEAN[@]}" -gt 0 ]]; then
    for d in "${TEST_TMPDIRS_TO_CLEAN[@]}"; do
      [[ -z "$d" ]] && continue
      rm -rf "$d" 2>/dev/null || true
    done
  fi
}
trap cleanup_test_state EXIT
