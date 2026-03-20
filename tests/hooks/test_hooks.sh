#!/bin/bash
# hooks のユニットテスト
# 使い方: bash tests/hooks/test_hooks.sh

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/../../.claude/hooks" && pwd)"
PASSED=0
FAILED=0
TOTAL=0

pass() {
  PASSED=$((PASSED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  PASS: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  TOTAL=$((TOTAL + 1))
  echo "  FAIL: $1"
}

assert_blocked() {
  local desc="$1"
  local output="$2"
  if echo "$output" | grep -q '"permissionDecision": "deny"'; then
    pass "$desc"
  else
    fail "$desc (expected: deny, got: allow)"
  fi
}

assert_allowed() {
  local desc="$1"
  local output="$2"
  if echo "$output" | grep -q '"permissionDecision": "deny"'; then
    fail "$desc (expected: allow, got: deny)"
  else
    pass "$desc"
  fi
}

cleanup() {
  rm -f /tmp/.vibemux-sync-ok
  rm -f /tmp/.vibemux-review-to-rules-ok
}
trap cleanup EXIT
cleanup

# ============================================
echo "=== protect-mvv.sh ==="
# ============================================

OUTPUT=$(echo '{"tool_input":{"file_path":"/any/path/MVV.md"}}' | "$HOOKS_DIR/protect-mvv.sh")
assert_blocked "MVV.md の編集 → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/any/path/README.md"}}' | "$HOOKS_DIR/protect-mvv.sh")
assert_allowed "README.md の編集 → 許可" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/any/path/mvv-notes.md"}}' | "$HOOKS_DIR/protect-mvv.sh")
assert_allowed "mvv-notes.md の編集 → 許可（部分一致しない）" "$OUTPUT"

# ============================================
echo "=== sync-gate.sh ==="
# ============================================

OUTPUT=$(echo '{"tool_input":{"command":"git push origin main"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_blocked "スタンプなしでpush → ブロック" "$OUTPUT"

touch /tmp/.vibemux-sync-ok
OUTPUT=$(echo '{"tool_input":{"command":"git push origin main"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_allowed "スタンプありでpush → 許可" "$OUTPUT"

if [ ! -f /tmp/.vibemux-sync-ok ]; then
  pass "push後にスタンプが削除される"
else
  fail "push後にスタンプが削除される (ファイルが残っている)"
fi

OUTPUT=$(echo '{"tool_input":{"command":"git status"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git status → スキップ" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"command":"git push --force origin main"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_blocked "git push --force → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"command":"git push -u origin feature"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_blocked "git push -u → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"command":"git pull origin main"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git pull → スキップ" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"command":"git push origin --delete dev/old-branch"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git push --delete → スキップ" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"command":"git push origin -d dev/old-branch"}}' | "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git push -d → スキップ" "$OUTPUT"

# ============================================
echo "=== review-to-rules-gate.sh ==="
# ============================================

rm -f /tmp/.vibemux-review-to-rules-ok
OUTPUT=$(echo '{"tool_input":{"command":"gh pr merge 80 --squash --delete-branch"}}' | "$HOOKS_DIR/review-to-rules-gate.sh")
assert_blocked "スタンプなしでmerge → ブロック" "$OUTPUT"

touch /tmp/.vibemux-review-to-rules-ok
OUTPUT=$(echo '{"tool_input":{"command":"gh pr merge 80 --squash --delete-branch"}}' | "$HOOKS_DIR/review-to-rules-gate.sh")
assert_allowed "スタンプありでmerge → 許可" "$OUTPUT"

if [ ! -f /tmp/.vibemux-review-to-rules-ok ]; then
  pass "merge後にスタンプが削除される"
else
  fail "merge後にスタンプが削除される (ファイルが残っている)"
fi

OUTPUT=$(echo '{"tool_input":{"command":"gh pr view 80"}}' | "$HOOKS_DIR/review-to-rules-gate.sh")
assert_allowed "gh pr view → スキップ" "$OUTPUT"

rm -f /tmp/.vibemux-review-to-rules-ok
OUTPUT=$(echo '{"tool_input":{"command":" gh pr merge 80 --squash"}}' | "$HOOKS_DIR/review-to-rules-gate.sh")
assert_blocked "先頭スペース付きmerge → ブロック" "$OUTPUT"

rm -f /tmp/.vibemux-review-to-rules-ok
OUTPUT=$(echo '{"tool_input":{"command":"GH_TOKEN=dummy gh pr merge 80"}}' | "$HOOKS_DIR/review-to-rules-gate.sh")
assert_blocked "環境変数プレフィックス付きmerge → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"command":"gh pr create --title \"test\" --body \"gh pr merge pattern\""}}' | "$HOOKS_DIR/review-to-rules-gate.sh")
assert_allowed "gh pr create (bodyにmerge含む) → スキップ" "$OUTPUT"

# ============================================
echo ""
echo "=== 結果: $PASSED/$TOTAL passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
