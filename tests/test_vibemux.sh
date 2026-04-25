#!/bin/bash
set -uo pipefail

# vibemux test suite
# Runs without an active tmux server where possible

VIBEMUX="$(cd "$(dirname "$0")/.." && pwd)/vibemux"
passed=0
failed=0

run_cmd() {
  "$@" >/dev/null 2>&1
}

assert_exit() {
  local desc="$1" expected="$2"
  shift 2
  local actual=0
  run_cmd "$@" || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "  PASS: $desc"
    ((passed++))
  else
    echo "  FAIL: $desc (expected exit $expected, got $actual)"
    ((failed++))
  fi
}

assert_output_contains() {
  local desc="$1" pattern="$2"
  shift 2
  local output
  output=$("$@" 2>&1) || true
  if echo "$output" | grep -qE "$pattern"; then
    echo "  PASS: $desc"
    ((passed++))
  else
    echo "  FAIL: $desc (expected pattern '$pattern' not found in output)"
    ((failed++))
  fi
}

assert_output_not_contains() {
  local desc="$1" pattern="$2"
  shift 2
  local output
  output=$("$@" 2>&1) || true
  if echo "$output" | grep -qE "$pattern"; then
    echo "  FAIL: $desc (unexpected pattern '$pattern' found in output)"
    ((failed++))
  else
    echo "  PASS: $desc"
    ((passed++))
  fi
}

echo "=== vibemux test suite ==="
echo

# ── Usage / Help ─────────────────────────────────────────────
echo "[no args / help]"
assert_exit "no args shows usage and exits 0" 0 "$VIBEMUX"
assert_output_contains "no args prints usage text" "Usage:" "$VIBEMUX"
assert_exit "help exits 0" 0 "$VIBEMUX" help
assert_output_contains "help prints usage text" "Usage:" "$VIBEMUX" help
assert_exit "--help exits 0" 0 "$VIBEMUX" --help
assert_exit "-h exits 0" 0 "$VIBEMUX" -h
echo

# ── Version ──────────────────────────────────────────────────
echo "[version]"
assert_exit "version exits 0" 0 "$VIBEMUX" version
assert_output_contains "version prints version string" "^vibemux [0-9]+\.[0-9]+\.[0-9]+" "$VIBEMUX" version
assert_exit "--version exits 0" 0 "$VIBEMUX" --version
assert_exit "-v exits 0" 0 "$VIBEMUX" -v
echo

# ── Argument Validation ─────────────────────────────────────
echo "[argument validation]"
assert_exit "new without session name exits 1" 1 "$VIBEMUX" new
assert_output_contains "new without session name shows usage" "usage: vibemux new" "$VIBEMUX" new
assert_exit "attach without session name exits 1" 1 "$VIBEMUX" attach
assert_output_contains "attach without session name shows usage" "usage: vibemux attach" "$VIBEMUX" attach
echo

# ── Invalid Directory ────────────────────────────────────────
echo "[invalid directory]"

# Unset TMUX to bypass the nested session check and test directory validation
desc="new with nonexistent directory exits 1"
actual=0
(unset TMUX; "$VIBEMUX" new testsession /nonexistent/path) >/dev/null 2>&1 || actual=$?
if [[ "$actual" -eq 1 ]]; then
  echo "  PASS: $desc"
  ((passed++))
else
  echo "  FAIL: $desc (expected exit 1, got $actual)"
  ((failed++))
fi

desc="new with nonexistent dir shows error"
output=$(unset TMUX; "$VIBEMUX" new testsession /nonexistent/path 2>&1) || true
if echo "$output" | grep -qE "directory not found"; then
  echo "  PASS: $desc"
  ((passed++))
else
  echo "  FAIL: $desc (expected pattern 'directory not found' not found in output)"
  ((failed++))
fi
echo

# ── Attach Nonexistent Session ───────────────────────────────
echo "[attach nonexistent session]"
assert_output_contains "attach nonexistent session shows error" "not found" "$VIBEMUX" attach nonexistent_session_xyz
echo

# ── Environment Variable Defaults ────────────────────────────
echo "[env var defaults]"
assert_output_contains "usage shows VIBEMUX_PANE_LEFT" "VIBEMUX_PANE_LEFT" "$VIBEMUX" help
assert_output_contains "usage shows VIBEMUX_PANE_RIGHT" "VIBEMUX_PANE_RIGHT" "$VIBEMUX" help
assert_output_contains "usage shows VIBEMUX_CONFIG" "VIBEMUX_CONFIG" "$VIBEMUX" help
assert_output_not_contains "usage does not show VIBEMUX_PANE_TOP_LEFT" "VIBEMUX_PANE_TOP_LEFT" "$VIBEMUX" help
assert_output_not_contains "usage does not show VIBEMUX_PANE_BOTTOM_LEFT" "VIBEMUX_PANE_BOTTOM_LEFT" "$VIBEMUX" help
echo

# ── Nested tmux session detection ────────────────────────────
echo "[nested tmux detection]"

# Test: TMUX set → new should fail with exit 1
desc="new inside tmux session exits 1"
actual=0
TMUX=fake_tmux_session "$VIBEMUX" new testsession >/dev/null 2>&1 || actual=$?
if [[ "$actual" -eq 1 ]]; then
  echo "  PASS: $desc"
  ((passed++))
else
  echo "  FAIL: $desc (expected exit 1, got $actual)"
  ((failed++))
fi

# Test: TMUX set → new should show error message
desc="new inside tmux session shows error message"
output=$(TMUX=fake_tmux_session "$VIBEMUX" new testsession 2>&1) || true
if echo "$output" | grep -q "already inside a tmux session"; then
  echo "  PASS: $desc"
  ((passed++))
else
  echo "  FAIL: $desc (expected 'already inside a tmux session' in output)"
  ((failed++))
fi

# Test: TMUX unset → new should not fail due to TMUX check
# (it will fail for other reasons like no tmux server, but not the TMUX check)
desc="new without TMUX does not show nested session error"
output=$(unset TMUX; "$VIBEMUX" new testsession 2>&1) || true
if echo "$output" | grep -q "already inside a tmux session"; then
  echo "  FAIL: $desc (got nested session error when TMUX is unset)"
  ((failed++))
else
  echo "  PASS: $desc"
  ((passed++))
fi
echo

# ── Unknown Subcommand ───────────────────────────────────────
echo "[unknown subcommand]"
assert_exit "unknown subcommand exits 0 (shows usage)" 0 "$VIBEMUX" unknowncmd
assert_output_contains "unknown subcommand shows usage" "Usage:" "$VIBEMUX" unknowncmd
echo

# ── Results ──────────────────────────────────────────────────
echo "=== Results: $passed passed, $failed failed ==="
[[ "$failed" -eq 0 ]]
