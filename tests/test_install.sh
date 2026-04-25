#!/bin/bash
set -uo pipefail

# Tests for `make install` target.
# Uses a temporary HOME so the user's real ~/.local/bin is not touched.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
passed=0
failed=0

pass() { echo "  PASS: $1"; ((passed++)); }
fail() { echo "  FAIL: $1"; ((failed++)); }

echo "=== install test suite ==="
echo

if ! command -v make >/dev/null 2>&1; then
  echo "  SKIP: make not available"
  exit 0
fi

if [[ ! -f "$REPO_ROOT/Makefile" ]]; then
  fail "Makefile not found at repo root"
  exit 1
fi

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT

# Run install with isolated HOME (and a PATH that lacks ~/.local/bin).
install_output="$(HOME="$TMPHOME" PATH="/usr/bin:/bin" make -C "$REPO_ROOT" install 2>&1)" || {
  fail "make install exited non-zero"
  echo "$install_output"
  exit 1
}

# 1. Symlink exists.
symlink="$TMPHOME/.local/bin/vibemux"
if [[ -L "$symlink" ]]; then
  pass "symlink created at \$HOME/.local/bin/vibemux"
else
  fail "symlink not created at \$HOME/.local/bin/vibemux"
  echo "$install_output"
  exit 1
fi

# 2. Symlink target is an absolute path.
target="$(readlink "$symlink")"
if [[ "$target" = /* ]]; then
  pass "symlink target is an absolute path"
else
  fail "symlink target is relative: $target"
fi

# 3. Symlink points to the repo's vibemux script.
if [[ "$target" = "$REPO_ROOT/vibemux" ]]; then
  pass "symlink resolves to repo's vibemux script"
else
  fail "symlink target mismatch: got '$target', want '$REPO_ROOT/vibemux'"
fi

# 4. The symlink is executable end-to-end.
if "$symlink" help >/dev/null 2>&1; then
  pass "vibemux runs through the installed symlink"
else
  fail "vibemux help exited non-zero through the symlink"
fi

# 5. PATH warning is printed when ~/.local/bin is missing from PATH.
if echo "$install_output" | grep -q "WARNING: ~/.local/bin is not in"; then
  pass "warns when ~/.local/bin is not in PATH"
else
  fail "missing PATH warning when ~/.local/bin not in PATH"
fi

# 6. Idempotency: running install again should still leave a working symlink.
HOME="$TMPHOME" PATH="/usr/bin:/bin" make -C "$REPO_ROOT" install >/dev/null 2>&1 || {
  fail "second make install failed"
  exit 1
}
if [[ -L "$symlink" ]] && [[ "$(readlink "$symlink")" = "$REPO_ROOT/vibemux" ]]; then
  pass "install is idempotent"
else
  fail "install is not idempotent"
fi

# 7. PATH-included branch reports ready.
ready_output="$(HOME="$TMPHOME" PATH="$TMPHOME/.local/bin:/usr/bin:/bin" make -C "$REPO_ROOT" install 2>&1)" || {
  fail "make install exited non-zero with PATH set"
  exit 1
}
if echo "$ready_output" | grep -q "Ready: run 'vibemux' from anywhere"; then
  pass "reports ready when ~/.local/bin is in PATH"
else
  fail "missing ready message when ~/.local/bin is in PATH"
fi

echo
echo "Result: $passed passed, $failed failed"
[[ "$failed" -eq 0 ]]
