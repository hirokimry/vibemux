#!/bin/bash
# 新規フックのユニットテスト
# 対象: block-api-bypass.sh, command-log.sh, diagnose-guard.sh, protect-branch.sh
# 使い方: bash tests/test_hooks_new.sh

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/../.claude/hooks" && pwd)"
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

# テスト用一時ディレクトリ
TEST_TMP="$(mktemp -d)"
# テスト用 git リポジトリ
TEST_REPO="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMP"
  rm -rf "$TEST_REPO"
}
trap cleanup EXIT

# ============================================
echo "=== block-api-bypass.sh ==="
# ============================================

# Bash 以外のツールはスキップ
OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"command":"gh api repos/owner/repo/pulls/1/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "Bash以外のツール → スキップ" "$OUTPUT"

# 空コマンドはスキップ
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "空コマンド → スキップ" "$OUTPUT"

# gh api で pulls/{n}/merge を直接呼び出し → ブロック
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api repos/owner/repo/pulls/123/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "gh api pulls/123/merge → ブロック" "$OUTPUT"

# gh api で別エンドポイント → 許可
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api repos/owner/repo/pulls/123"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "gh api pulls/123 (mergeなし) → 許可" "$OUTPUT"

# gh pr merge (api 経由でない) → 許可
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 123 --squash"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "gh pr merge → 許可（api 直接呼び出しではない）" "$OUTPUT"

# @coderabbitai approve → ブロック
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 123 --body \"@coderabbitai approve\""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "@coderabbitai approve → ブロック" "$OUTPUT"

# @coderabbitai review (approve でない) → 許可
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 123 --body \"@coderabbitai review\""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "@coderabbitai review → 許可（approve でない）" "$OUTPUT"

# @CODERABBITAI APPROVE (大文字) → ブロック（大文字小文字を区別しない）
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 1 --body \"@CODERABBITAI APPROVE\""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "@CODERABBITAI APPROVE (大文字) → ブロック" "$OUTPUT"

# 環境変数プレフィックス付き gh api merge → ブロック
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"GH_TOKEN=xxx gh api repos/owner/repo/pulls/42/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "環境変数プレフィックス付き gh api merge → ブロック" "$OUTPUT"

# gh api (サブコマンドなし) → 許可
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api rate_limit"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "gh api rate_limit → 許可" "$OUTPUT"

# tool_input.command が null の場合 → スキップ
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "command フィールドなし → スキップ" "$OUTPUT"

# ============================================
echo "=== command-log.sh ==="
# ============================================

export CLAUDE_PROJECT_DIR="$TEST_TMP"
LOG_FILE="${TEST_TMP}/.claude/state/command-log"

# Bash 以外のツールはログを記録しない
OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"command":"ls"}}' | "$HOOKS_DIR/command-log.sh")
if [ ! -f "$LOG_FILE" ]; then
  pass "Bash 以外のツール → ログ記録なし"
else
  fail "Bash 以外のツール → ログ記録なし (ファイルが作成された)"
fi

# Bash ツールでコマンドを記録する
echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | "$HOOKS_DIR/command-log.sh"
if [ -f "$LOG_FILE" ]; then
  pass "Bash ツール → ログファイル作成"
else
  fail "Bash ツール → ログファイル作成 (ファイルが存在しない)"
fi

# ログに正しいコマンドが記録される
if grep -q "git status" "$LOG_FILE"; then
  pass "ログにコマンド内容が記録される"
else
  fail "ログにコマンド内容が記録される (コマンドが記録されていない)"
fi

# タイムスタンプ形式の確認（ISO 8601 形式: YYYY-MM-DDTHH:MM:SS）
if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' "$LOG_FILE"; then
  pass "ログにタイムスタンプが記録される"
else
  fail "ログにタイムスタンプが記録される (タイムスタンプ形式が不正)"
fi

# 複数のコマンドが追記される
echo '{"tool_name":"Bash","tool_input":{"command":"git diff"}}' | "$HOOKS_DIR/command-log.sh"
LINE_COUNT=$(wc -l < "$LOG_FILE")
if [ "$LINE_COUNT" -ge 2 ]; then
  pass "複数コマンドが追記される"
else
  fail "複数コマンドが追記される (行数: $LINE_COUNT)"
fi

# 空コマンドはログに記録しない
BEFORE=$(wc -l < "$LOG_FILE")
echo '{"tool_name":"Bash","tool_input":{"command":""}}' | "$HOOKS_DIR/command-log.sh"
AFTER=$(wc -l < "$LOG_FILE")
if [ "$BEFORE" -eq "$AFTER" ]; then
  pass "空コマンドはログに記録しない"
else
  fail "空コマンドはログに記録しない (行数が増えた)"
fi

# command-log.sh は判定を返さない（permissionDecision なし）
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' | "$HOOKS_DIR/command-log.sh")
assert_allowed "command-log.sh は判定を返さない" "$OUTPUT"

# CLAUDE_PROJECT_DIR 未設定時は cwd/.claude/state に記録
(
  unset CLAUDE_PROJECT_DIR
  cd "$TEST_TMP"
  echo '{"tool_name":"Bash","tool_input":{"command":"pwd"}}' | "$HOOKS_DIR/command-log.sh"
  if [ -f ".claude/state/command-log" ]; then
    pass "CLAUDE_PROJECT_DIR 未設定時は cwd 基準でログ記録"
  else
    fail "CLAUDE_PROJECT_DIR 未設定時は cwd 基準でログ記録 (ファイルが存在しない)"
  fi
)

# ============================================
echo "=== diagnose-guard.sh ==="
# ============================================

DIAGNOSE_STATE_DIR="${TEST_TMP}/.claude/state"
STAMP_FILE="${DIAGNOSE_STATE_DIR}/diagnose-active"
export CLAUDE_PROJECT_DIR="$TEST_TMP"

mkdir -p "$DIAGNOSE_STATE_DIR"

# スタンプファイルが存在しない場合は何もしない
rm -f "$STAMP_FILE"
OUTPUT=$(echo '{"tool_input":{"file_path":"/any/path/hooks/sync-gate.sh"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "スタンプなし → 許可" "$OUTPUT"

# スタンプファイルが存在する場合、hooks/*.sh はブロック
touch "$STAMP_FILE"

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/sync-gate.sh"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + hooks/*.sh → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/protect-branch.sh"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + hooks/protect-branch.sh → ブロック" "$OUTPUT"

# スタンプあり + diagnose-guard.sh 自体はブロック（常に保護）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/diagnose-guard.sh"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + diagnose-guard.sh → ブロック（常に保護）" "$OUTPUT"

# スタンプあり + vibecorp.yml はブロック（デフォルト forbidden_targets）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/vibecorp.yml"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + vibecorp.yml → ブロック" "$OUTPUT"

# スタンプあり + MVV.md はブロック（デフォルト forbidden_targets）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/MVV.md"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + MVV.md → ブロック" "$OUTPUT"

# スタンプあり + SECURITY.md はブロック（デフォルト forbidden_targets）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/docs/SECURITY.md"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + SECURITY.md → ブロック" "$OUTPUT"

# スタンプあり + POLICY.md はブロック（デフォルト forbidden_targets）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/docs/POLICY.md"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "スタンプあり + POLICY.md → ブロック" "$OUTPUT"

# スタンプあり + 通常ファイルは許可
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/src/main.ts"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "スタンプあり + 通常ファイル → 許可" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/docs/specification.md"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "スタンプあり + docs/specification.md → 許可" "$OUTPUT"

# file_path が空の場合はスキップ
OUTPUT=$(echo '{"tool_input":{}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "file_path なし → スキップ" "$OUTPUT"

# スタンプ削除後は許可される
rm -f "$STAMP_FILE"
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/sync-gate.sh"}}' | "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "スタンプ削除後 → 許可" "$OUTPUT"

# ============================================
echo "=== protect-branch.sh ==="
# ============================================

# テスト用 git リポジトリを作成
git -C "$TEST_REPO" init -b main --quiet
git -C "$TEST_REPO" config user.email "test@example.com"
git -C "$TEST_REPO" config user.name "Test User"
touch "$TEST_REPO/README.md"
git -C "$TEST_REPO" add .
git -C "$TEST_REPO" commit -m "init" --quiet

# CLAUDE_PROJECT_DIR を設定（vibecorp.yml の読み込みに使用）
export CLAUDE_PROJECT_DIR="$TEST_REPO"
# テスト用 vibecorp.yml は作成しない（デフォルトの base_branch=main を使用）

# main ブランチで Edit → ブロック
OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TEST_REPO}/README.md\"}}" | "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチで Edit → ブロック" "$OUTPUT"

# main ブランチで Write → ブロック
OUTPUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"${TEST_REPO}/new-file.md\"}}" | "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチで Write → ブロック" "$OUTPUT"

# main ブランチで git commit → ブロック
OUTPUT=$(cd "$TEST_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}' | "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチで git commit → ブロック" "$OUTPUT"

# main ブランチで git status → 許可
OUTPUT=$(cd "$TEST_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | "$HOOKS_DIR/protect-branch.sh")
assert_allowed "main ブランチで git status → 許可（commit でない）" "$OUTPUT"

# main ブランチで git push → 許可（commit 以外は制御外）
OUTPUT=$(cd "$TEST_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | "$HOOKS_DIR/protect-branch.sh")
assert_allowed "main ブランチで git push → 許可（commit でない）" "$OUTPUT"

# フィーチャーブランチでは Edit → 許可
git -C "$TEST_REPO" checkout -b feature/test --quiet
OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${TEST_REPO}/README.md\"}}" | "$HOOKS_DIR/protect-branch.sh")
assert_allowed "feature ブランチで Edit → 許可" "$OUTPUT"

# フィーチャーブランチでは Write → 許可
OUTPUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"${TEST_REPO}/new.md\"}}" | "$HOOKS_DIR/protect-branch.sh")
assert_allowed "feature ブランチで Write → 許可" "$OUTPUT"

# フィーチャーブランチでは git commit → 許可
OUTPUT=$(cd "$TEST_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"test\""}}' | "$HOOKS_DIR/protect-branch.sh")
assert_allowed "feature ブランチで git commit → 許可" "$OUTPUT"

# main に戻す
git -C "$TEST_REPO" checkout main --quiet

# 環境変数プレフィックス付き git commit → ブロック
OUTPUT=$(cd "$TEST_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"GIT_AUTHOR_NAME=x git commit -m \"test\""}}' | "$HOOKS_DIR/protect-branch.sh")
assert_blocked "環境変数プレフィックス付き git commit → ブロック" "$OUTPUT"

# "git add && git commit" → ブロック（commit セグメントを検出）
OUTPUT=$(cd "$TEST_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git add . && git commit -m \"test\""}}' | "$HOOKS_DIR/protect-branch.sh")
assert_blocked "git add && git commit → ブロック（commit を含む）" "$OUTPUT"

# Bash 以外の tool で Read → 許可
OUTPUT=$(echo "{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"${TEST_REPO}/README.md\"}}" | "$HOOKS_DIR/protect-branch.sh")
assert_allowed "Read ツール → 許可" "$OUTPUT"

# カスタム base_branch のテスト
CUSTOM_REPO="$(mktemp -d)"
git -C "$CUSTOM_REPO" init -b develop --quiet
git -C "$CUSTOM_REPO" config user.email "test@example.com"
git -C "$CUSTOM_REPO" config user.name "Test User"
touch "$CUSTOM_REPO/README.md"
git -C "$CUSTOM_REPO" add .
git -C "$CUSTOM_REPO" commit -m "init" --quiet

mkdir -p "${CUSTOM_REPO}/.claude"
printf 'name: test\nbase_branch: develop\n' > "${CUSTOM_REPO}/.claude/vibecorp.yml"
export CLAUDE_PROJECT_DIR="$CUSTOM_REPO"

OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"${CUSTOM_REPO}/README.md\"}}" | "$HOOKS_DIR/protect-branch.sh")
assert_blocked "カスタム base_branch (develop) で Edit → ブロック" "$OUTPUT"

rm -rf "$CUSTOM_REPO"

# CLAUDE_PROJECT_DIR をリセット
export CLAUDE_PROJECT_DIR="$TEST_TMP"

# ============================================
echo ""
echo "=== 結果: $PASSED/$TOTAL passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi