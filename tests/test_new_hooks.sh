#!/bin/bash
# 新規追加フックのユニットテスト
# 対象: block-api-bypass.sh, command-log.sh, diagnose-guard.sh,
#        protect-branch.sh, review-gate.sh, sync-gate.sh（改修版）
# 使い方: bash tests/test_new_hooks.sh

set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "$0")/../.claude/hooks" && pwd)"
LIB_DIR="$(cd "$(dirname "$0")/../.claude" && pwd)/lib"
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
    fail "$desc (expected: deny, got: allow/empty)"
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

assert_exit_code() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" -eq "$expected" ]; then
    pass "$desc"
  else
    fail "$desc (expected exit $expected, got $actual)"
  fi
}

assert_file_contains() {
  local desc="$1"
  local file="$2"
  local pattern="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc (パターン '$pattern' がファイルに見つかりません: $file)"
  fi
}

assert_file_not_exists() {
  local desc="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    pass "$desc"
  else
    fail "$desc (ファイルが存在します: $file)"
  fi
}

# テスト用一時ディレクトリ
TEST_TMPDIR="$(mktemp -d)"
# スタンプファイル用ディレクトリ（review-gate / sync-gate テスト用）
STAMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEST_TMPDIR"
  rm -rf "$STAMP_DIR"
  # lib/common.sh スタブのクリーンアップ
  if [ -d "$LIB_DIR" ] && [ -f "$LIB_DIR/common.sh" ]; then
    rm -f "$LIB_DIR/common.sh"
    rmdir "$LIB_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT
# mktemp で一意なディレクトリを作成しているため初期クリーンアップは不要
# STAMP_DIR が確実に存在することを保証
mkdir -p "$STAMP_DIR"

# lib/common.sh スタブを作成（review-gate.sh / sync-gate.sh 用）
setup_common_sh_stub() {
  mkdir -p "$LIB_DIR"
  cat > "$LIB_DIR/common.sh" << COMMON_SH_EOF
#!/bin/bash
# テスト用 common.sh スタブ
# vibecorp_stamp_path: テスト専用スタンプディレクトリを返す
vibecorp_stamp_path() {
  local name="\$1"
  echo "${STAMP_DIR}/\${name}-ok"
}

# normalize_command: sync-gate.sh が使用するコマンド正規化関数
# 実際の common.sh の実装に準拠
normalize_command() {
  local cmd="\$1"
  # 先頭空白除去
  cmd=\$(echo "\$cmd" | sed 's/^[[:space:]]*//')
  # 環境変数プレフィックス除去
  cmd=\$(echo "\$cmd" | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*//')
  # ラッパーコマンド除去
  while true; do
    local first
    first=\$(echo "\$cmd" | awk '{print \$1}')
    case "\$first" in
      env|command) cmd=\$(echo "\$cmd" | sed -E 's/^[^ ]+ +//') ;;
      *) break ;;
    esac
  done
  # 絶対パス/相対パスを basename に正規化
  local first_token
  first_token=\$(echo "\$cmd" | awk '{print \$1}')
  if [[ "\$first_token" == */* ]]; then
    local base
    base=\$(basename "\$first_token")
    cmd="\$base \$(echo "\$cmd" | awk '{\$1=""; print}' | sed 's/^ *//')"
  fi
  echo "\$cmd"
}
COMMON_SH_EOF
  chmod +x "$LIB_DIR/common.sh"
}

setup_common_sh_stub

# ============================================
echo "=== block-api-bypass.sh ==="
# ============================================

# Bash 以外のツール → スキップ（allow）
OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"command":"gh api repos/owner/repo/pulls/1/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "Read ツール → スキップ（Bash 以外は対象外）" "$OUTPUT"

OUTPUT=$(echo '{"tool_name":"Edit","tool_input":{"command":"gh api repos/owner/repo/pulls/1/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "Edit ツール → スキップ（Bash 以外は対象外）" "$OUTPUT"

# gh api pulls/N/merge → deny
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api repos/owner/repo/pulls/123/merge -X PUT"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "gh api pulls/123/merge → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api /repos/owner/repo/pulls/999/merge --method PUT"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "gh api /repos/.../pulls/999/merge → ブロック" "$OUTPUT"

# gh pr merge は対象外（block-api-bypass は gh api のみをブロック）
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr merge 80 --squash"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "gh pr merge → スキップ（gh api ではない）" "$OUTPUT"

# gh api の他エンドポイント → allow
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api repos/owner/repo/issues"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "gh api issues エンドポイント → スキップ" "$OUTPUT"

# @coderabbitai approve → deny
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 5 --body \"@coderabbitai approve\""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "@coderabbitai approve コメント投稿 → ブロック" "$OUTPUT"

# @coderabbitai APPROVE（大文字）→ deny（大文字小文字無視）
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh pr comment 5 --body \"@coderabbitai APPROVE\""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "@coderabbitai APPROVE（大文字）→ ブロック" "$OUTPUT"

# 環境変数プレフィックス付き gh api merge → deny
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"GH_TOKEN=secret gh api repos/owner/repo/pulls/10/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "環境変数プレフィックス付き gh api merge → ブロック" "$OUTPUT"

# env コマンド付き gh api merge → deny
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"env GH_TOKEN=secret gh api repos/owner/repo/pulls/10/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "env プレフィックス付き gh api merge → ブロック" "$OUTPUT"

# command prefix + gh api → deny（command は除去される）
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"command gh api repos/owner/repo/pulls/5/merge"}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_blocked "command プレフィックス付き gh api merge → ブロック" "$OUTPUT"

# 空コマンド → allow
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "空コマンド → スキップ" "$OUTPUT"

# pulls/N/merge を含まない gh api → allow
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"gh api graphql -f query=\"{viewer{login}}\""}}' | "$HOOKS_DIR/block-api-bypass.sh")
assert_allowed "gh api graphql → スキップ（merge エンドポイントではない）" "$OUTPUT"

# ============================================
echo "=== command-log.sh ==="
# ============================================

COMMAND_LOG_STATE_DIR="$TEST_TMPDIR/command-log-state"
rm -rf "$COMMAND_LOG_STATE_DIR"

# Bash ツール → ログファイルに記録される
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_TMPDIR" echo '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' | \
  CLAUDE_PROJECT_DIR="$TEST_TMPDIR" "$HOOKS_DIR/command-log.sh")
LOG_FILE="$TEST_TMPDIR/.claude/state/command-log"
if [ -f "$LOG_FILE" ]; then
  pass "Bash コマンド実行後にログファイルが作成される"
else
  fail "Bash コマンド実行後にログファイルが作成される (ファイルが見つかりません: $LOG_FILE)"
fi
assert_file_contains "ログにコマンドが記録される" "$LOG_FILE" "ls -la"

# ログエントリのフォーマット確認（タイムスタンプ\tコマンド）
if grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}	ls -la$' "$LOG_FILE" 2>/dev/null; then
  pass "ログエントリのフォーマットが正しい（ISO 8601 タイムスタンプ + タブ + コマンド）"
else
  fail "ログエントリのフォーマットが正しい（ISO 8601 タイムスタンプ + タブ + コマンド）"
fi

# Bash 以外のツール → ログに追記されない（ファイルが更新されない）
BEFORE_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
CLAUDE_PROJECT_DIR="$TEST_TMPDIR" echo '{"tool_name":"Read","tool_input":{"command":"ls -la"}}' | \
  CLAUDE_PROJECT_DIR="$TEST_TMPDIR" "$HOOKS_DIR/command-log.sh"
AFTER_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$BEFORE_SIZE" -eq "$AFTER_SIZE" ]; then
  pass "Read ツール → ログに追記されない"
else
  fail "Read ツール → ログに追記されない (サイズが変化: $BEFORE_SIZE → $AFTER_SIZE)"
fi

# 空コマンド → ログに追記されない
BEFORE_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
CLAUDE_PROJECT_DIR="$TEST_TMPDIR" echo '{"tool_name":"Bash","tool_input":{"command":""}}' | \
  CLAUDE_PROJECT_DIR="$TEST_TMPDIR" "$HOOKS_DIR/command-log.sh"
AFTER_SIZE=$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$BEFORE_SIZE" -eq "$AFTER_SIZE" ]; then
  pass "空コマンド → ログに追記されない"
else
  fail "空コマンド → ログに追記されない (サイズが変化)"
fi

# 複数コマンドの記録
CLAUDE_PROJECT_DIR="$TEST_TMPDIR" echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | \
  CLAUDE_PROJECT_DIR="$TEST_TMPDIR" "$HOOKS_DIR/command-log.sh"
ENTRY_COUNT=$(grep -c '' "$LOG_FILE" 2>/dev/null || echo 0)
if [ "$ENTRY_COUNT" -ge 2 ]; then
  pass "複数コマンドが複数行としてログに記録される"
else
  fail "複数コマンドが複数行としてログに記録される (行数: $ENTRY_COUNT)"
fi

# command-log.sh は判定を返さない（deny を出力しない）
OUTPUT=$(CLAUDE_PROJECT_DIR="$TEST_TMPDIR" echo '{"tool_name":"Bash","tool_input":{"command":"echo test"}}' | \
  CLAUDE_PROJECT_DIR="$TEST_TMPDIR" "$HOOKS_DIR/command-log.sh")
assert_allowed "command-log.sh は常に許可（判定を返さない）" "$OUTPUT"

# ============================================
echo "=== diagnose-guard.sh ==="
# ============================================

DIAGNOSE_PROJECT_DIR="$TEST_TMPDIR/diagnose-project"
mkdir -p "$DIAGNOSE_PROJECT_DIR/.claude/state"
DIAGNOSE_STAMP="$DIAGNOSE_PROJECT_DIR/.claude/state/diagnose-active"

# スタンプなし → 何もしない（allow）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/protect-mvv.sh"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "diagnose-active スタンプなし → スキップ" "$OUTPUT"

# スタンプを作成
touch "$DIAGNOSE_STAMP"

# スタンプあり + file_path なし → allow
OUTPUT=$(echo '{"tool_input":{}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "スタンプあり + file_path なし → スキップ" "$OUTPUT"

# スタンプあり + diagnose-guard.sh 自体 → deny（常に保護）
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/diagnose-guard.sh"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に diagnose-guard.sh 自体を編集 → ブロック" "$OUTPUT"

# スタンプあり + hooks/protect-mvv.sh（ワイルドカード hooks/*.sh）→ deny
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/protect-mvv.sh"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に hooks/protect-mvv.sh → ブロック（hooks/*.sh パターン）" "$OUTPUT"

# スタンプあり + hooks/block-api-bypass.sh → deny
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/block-api-bypass.sh"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に hooks/block-api-bypass.sh → ブロック（hooks/*.sh パターン）" "$OUTPUT"

# スタンプあり + vibecorp.yml → deny
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/vibecorp.yml"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に vibecorp.yml → ブロック" "$OUTPUT"

# スタンプあり + MVV.md → deny
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/MVV.md"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に MVV.md → ブロック" "$OUTPUT"

# スタンプあり + SECURITY.md → deny
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/docs/SECURITY.md"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に SECURITY.md → ブロック" "$OUTPUT"

# スタンプあり + POLICY.md → deny
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/docs/POLICY.md"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "diagnose-active 時に POLICY.md → ブロック" "$OUTPUT"

# スタンプあり + 通常ファイル → allow
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/src/main.py"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "diagnose-active 時に通常ファイル(src/main.py) → 許可" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/README.md"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "diagnose-active 時に README.md → 許可" "$OUTPUT"

# カスタム forbidden_targets（vibecorp.yml の diagnose セクション）
CUSTOM_PROJECT_DIR="$TEST_TMPDIR/custom-diagnose-project"
mkdir -p "$CUSTOM_PROJECT_DIR/.claude/state"
touch "$CUSTOM_PROJECT_DIR/.claude/state/diagnose-active"
# カスタム vibecorp.yml を作成
cat > "$CUSTOM_PROJECT_DIR/.claude/vibecorp.yml" << 'YAML_EOF'
name: testproject
preset: standard
base_branch: main
diagnose:
  forbidden_targets:
    - custom-protected.md
    - config/*.json
YAML_EOF

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/custom-protected.md"}}' | \
  CLAUDE_PROJECT_DIR="$CUSTOM_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "カスタム forbidden_targets の custom-protected.md → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/config/settings.json"}}' | \
  CLAUDE_PROJECT_DIR="$CUSTOM_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "カスタム forbidden_targets の config/*.json → ブロック" "$OUTPUT"

OUTPUT=$(echo '{"tool_input":{"file_path":"/project/docs/unprotected.md"}}' | \
  CLAUDE_PROJECT_DIR="$CUSTOM_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "カスタム forbidden_targets にない docs/unprotected.md → 許可" "$OUTPUT"

# diagnose-guard.sh 自体はカスタム設定に関係なく常に保護される
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/diagnose-guard.sh"}}' | \
  CLAUDE_PROJECT_DIR="$CUSTOM_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_blocked "カスタム設定時でも diagnose-guard.sh 自体は常にブロック" "$OUTPUT"

# スタンプ削除後は通常ファイルも編集可能になる
rm -f "$DIAGNOSE_STAMP"
OUTPUT=$(echo '{"tool_input":{"file_path":"/project/.claude/hooks/protect-mvv.sh"}}' | \
  CLAUDE_PROJECT_DIR="$DIAGNOSE_PROJECT_DIR" "$HOOKS_DIR/diagnose-guard.sh")
assert_allowed "スタンプ削除後 → hooks ファイルも許可" "$OUTPUT"

# ============================================
echo "=== protect-branch.sh ==="
# ============================================

# Bash / Edit / Write 以外のツールはブランチに関係なく通過
OUTPUT=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/project/src/main.py"}}' | \
  "$HOOKS_DIR/protect-branch.sh")
assert_allowed "Read ツール → ブランチチェックなし・スキップ" "$OUTPUT"

OUTPUT=$(echo '{"tool_name":"Glob","tool_input":{}}' | \
  "$HOOKS_DIR/protect-branch.sh")
assert_allowed "Glob ツール → ブランチチェックなし・スキップ" "$OUTPUT"

OUTPUT=$(echo '{"tool_name":"Grep","tool_input":{}}' | \
  "$HOOKS_DIR/protect-branch.sh")
assert_allowed "Grep ツール → ブランチチェックなし・スキップ" "$OUTPUT"

# Bash で git commit 以外のコマンド → main ブランチでも制約しない対象（コマンドはパスするが git 判定へ）
# ただし現在の HEAD が detached の場合は git branch --show-current が空 → exit 0
# ここでは detached HEAD 環境のため git status を渡してもスキップされることを確認
OUTPUT=$(echo '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | \
  "$HOOKS_DIR/protect-branch.sh")
assert_allowed "Bash git status → git commit ではないのでスキップ" "$OUTPUT"

# protect-branch.sh: フィーチャーブランチでの Edit は通過する
# テスト用 git リポジトリを作成してフィーチャーブランチをチェックアウト
FEATURE_REPO="$TEST_TMPDIR/feature-repo"
mkdir -p "$FEATURE_REPO"
git init "$FEATURE_REPO" -q
git -C "$FEATURE_REPO" config user.email "test@example.com"
git -C "$FEATURE_REPO" config user.name "Test"
touch "$FEATURE_REPO/dummy.txt"
git -C "$FEATURE_REPO" add dummy.txt
git -C "$FEATURE_REPO" commit -m "initial" -q
git -C "$FEATURE_REPO" checkout -b dev/123_feature -q

# フィーチャーブランチ上での Edit → 許可
OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$FEATURE_REPO/dummy.txt\"}}" | \
  CLAUDE_PROJECT_DIR="$FEATURE_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_allowed "フィーチャーブランチ上での Edit → 許可" "$OUTPUT"

# フィーチャーブランチ上での git commit → 許可
# Bash ツールは CHECK_DIR="." (CWD基準) のため、cd で作業ディレクトリを設定する
OUTPUT=$( cd "$FEATURE_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"feat: add feature\""}}' | \
  CLAUDE_PROJECT_DIR="$FEATURE_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_allowed "フィーチャーブランチ上での git commit → 許可" "$OUTPUT"

# メインブランチでの Edit → deny
MAIN_REPO="$TEST_TMPDIR/main-repo"
mkdir -p "$MAIN_REPO"
git init "$MAIN_REPO" -q
git -C "$MAIN_REPO" config user.email "test@example.com"
git -C "$MAIN_REPO" config user.name "Test"
touch "$MAIN_REPO/file.txt"
git -C "$MAIN_REPO" add file.txt
git -C "$MAIN_REPO" commit -m "initial" -q
# main ブランチ（git init のデフォルトが master の場合に対処）
DEFAULT_BRANCH=$(git -C "$MAIN_REPO" branch --show-current)
if [ "$DEFAULT_BRANCH" != "main" ]; then
  git -C "$MAIN_REPO" branch -m "$DEFAULT_BRANCH" main -q 2>/dev/null || true
fi

OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$MAIN_REPO/file.txt\"}}" | \
  CLAUDE_PROJECT_DIR="$MAIN_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチ上での Edit → ブロック" "$OUTPUT"

# メインブランチでの Write → deny
OUTPUT=$(echo "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$MAIN_REPO/new_file.txt\"}}" | \
  CLAUDE_PROJECT_DIR="$MAIN_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチ上での Write → ブロック" "$OUTPUT"

# メインブランチでの git commit → deny
# Bash ツールは CHECK_DIR="." (CWD基準) のため、cd で作業ディレクトリを設定する
OUTPUT=$( cd "$MAIN_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m \"fix: something\""}}' | \
  CLAUDE_PROJECT_DIR="$MAIN_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチ上での git commit → ブロック" "$OUTPUT"

# メインブランチでの Bash + git commit（env プレフィックス付き）→ deny
OUTPUT=$( cd "$MAIN_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"GIT_AUTHOR_NAME=bot git commit -m \"fix\""}}' | \
  CLAUDE_PROJECT_DIR="$MAIN_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチ上での 環境変数プレフィックス付き git commit → ブロック" "$OUTPUT"

# メインブランチでの git commit（チェーン && パターン）→ deny
OUTPUT=$( cd "$MAIN_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git add . && git commit -m \"add files\""}}' | \
  CLAUDE_PROJECT_DIR="$MAIN_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_blocked "main ブランチ上での git add && git commit → ブロック" "$OUTPUT"

# メインブランチでの git push（commit ではない）→ allow（protect-branch は commit のみ deny）
OUTPUT=$( cd "$MAIN_REPO" && echo '{"tool_name":"Bash","tool_input":{"command":"git push origin main"}}' | \
  CLAUDE_PROJECT_DIR="$MAIN_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_allowed "main ブランチ上での git push → 許可（protect-branch の対象外）" "$OUTPUT"

# vibecorp.yml の base_branch カスタム設定テスト
CUSTOM_BRANCH_REPO="$TEST_TMPDIR/custom-branch-repo"
mkdir -p "$CUSTOM_BRANCH_REPO/.claude"
mkdir -p "$CUSTOM_BRANCH_REPO"
git init "$CUSTOM_BRANCH_REPO" -q
git -C "$CUSTOM_BRANCH_REPO" config user.email "test@example.com"
git -C "$CUSTOM_BRANCH_REPO" config user.name "Test"
touch "$CUSTOM_BRANCH_REPO/file.txt"
git -C "$CUSTOM_BRANCH_REPO" add file.txt
git -C "$CUSTOM_BRANCH_REPO" commit -m "initial" -q
# develop ブランチに移行
git -C "$CUSTOM_BRANCH_REPO" branch -m "$(git -C "$CUSTOM_BRANCH_REPO" branch --show-current)" develop -q 2>/dev/null || \
  git -C "$CUSTOM_BRANCH_REPO" checkout -b develop -q
echo "base_branch: develop" > "$CUSTOM_BRANCH_REPO/.claude/vibecorp.yml"

OUTPUT=$(echo "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$CUSTOM_BRANCH_REPO/file.txt\"}}" | \
  CLAUDE_PROJECT_DIR="$CUSTOM_BRANCH_REPO" "$HOOKS_DIR/protect-branch.sh")
assert_blocked "カスタム base_branch(develop)上での Edit → ブロック" "$OUTPUT"

# ============================================
echo "=== review-gate.sh ==="
# ============================================

# スタンプなし + gh pr create → deny
rm -f "$STAMP_DIR/review-ok"
OUTPUT=$(echo '{"tool_input":{"command":"gh pr create --title \"test\" --body \"body\""}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_blocked "スタンプなしで gh pr create → ブロック" "$OUTPUT"

# スタンプあり + gh pr create → allow（スタンプ削除）
touch "$STAMP_DIR/review-ok"
OUTPUT=$(echo '{"tool_input":{"command":"gh pr create --title \"test\" --body \"body\""}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_allowed "スタンプありで gh pr create → 許可" "$OUTPUT"

if [ ! -f "$STAMP_DIR/review-ok" ]; then
  pass "gh pr create 後にスタンプが削除される"
else
  fail "gh pr create 後にスタンプが削除される（ファイルが残っている）"
fi

# gh pr view → allow（対象外コマンド）
OUTPUT=$(echo '{"tool_input":{"command":"gh pr view 80"}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_allowed "gh pr view → スキップ（gh pr create ではない）" "$OUTPUT"

# gh pr list → allow
OUTPUT=$(echo '{"tool_input":{"command":"gh pr list"}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_allowed "gh pr list → スキップ" "$OUTPUT"

# 先頭スペース付き gh pr create → deny
rm -f "$STAMP_DIR/review-ok"
OUTPUT=$(echo '{"tool_input":{"command":" gh pr create --title \"test\""}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_blocked "先頭スペース付き gh pr create → ブロック" "$OUTPUT"

# 環境変数プレフィックス付き gh pr create → deny
rm -f "$STAMP_DIR/review-ok"
OUTPUT=$(echo '{"tool_input":{"command":"GH_TOKEN=dummy gh pr create --title \"test\""}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_blocked "環境変数プレフィックス付き gh pr create → ブロック" "$OUTPUT"

# env ラッパー付き gh pr create の挙動確認
# review-gate.sh の正規化: env を除去後に KEY=VALUE が先頭に残るため gh pr create と一致しない
# これは既知の制限（normalize_command 使用前の独自実装）
rm -f "$STAMP_DIR/review-ok"
OUTPUT=$(echo '{"tool_input":{"command":"env GH_TOKEN=dummy gh pr create --title \"test\""}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_allowed "env + env変数 + gh pr create → スキップ（review-gate の正規化制限）" "$OUTPUT"

# gh pr merge（review-gate の対象外）→ allow
rm -f "$STAMP_DIR/review-ok"
OUTPUT=$(echo '{"tool_input":{"command":"gh pr merge 80 --squash"}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_allowed "gh pr merge → スキップ（review-gate の対象外）" "$OUTPUT"

# 空コマンド → allow
OUTPUT=$(echo '{"tool_input":{"command":""}}' | \
  "$HOOKS_DIR/review-gate.sh")
assert_allowed "空コマンド → スキップ" "$OUTPUT"

# ============================================
echo "=== sync-gate.sh （改修版）==="
# ============================================

# スタンプなし + git push → deny
rm -f "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":"git push origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_blocked "スタンプなしで git push → ブロック" "$OUTPUT"

# スタンプあり + git push → allow（スタンプ削除）
touch "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":"git push origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_allowed "スタンプありで git push → 許可" "$OUTPUT"

if [ ! -f "$STAMP_DIR/sync-ok" ]; then
  pass "git push 後にスタンプが削除される"
else
  fail "git push 後にスタンプが削除される（ファイルが残っている）"
fi

# git status → allow（git push ではない）
OUTPUT=$(echo '{"tool_input":{"command":"git status"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git status → スキップ（git push ではない）" "$OUTPUT"

# git pull → allow
OUTPUT=$(echo '{"tool_input":{"command":"git pull origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git pull → スキップ" "$OUTPUT"

# git push --force → deny
rm -f "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":"git push --force origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_blocked "スタンプなしで git push --force → ブロック" "$OUTPUT"

# git push -u origin feature → deny
rm -f "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":"git push -u origin feature"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_blocked "スタンプなしで git push -u → ブロック" "$OUTPUT"

# git push --delete → allow（ブランチ削除は対象外）
OUTPUT=$(echo '{"tool_input":{"command":"git push origin --delete dev/old-branch"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git push --delete → スキップ（ブランチ削除）" "$OUTPUT"

# git push -d → allow
OUTPUT=$(echo '{"tool_input":{"command":"git push origin -d dev/old-branch"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_allowed "git push -d → スキップ（ブランチ削除）" "$OUTPUT"

# 環境変数プレフィックス付き git push → deny（normalize_command で除去される）
rm -f "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":"GIT_SSH_COMMAND=ssh git push origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_blocked "環境変数プレフィックス付き git push → ブロック" "$OUTPUT"

# 先頭スペース付き git push → deny
rm -f "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":" git push origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
assert_blocked "先頭スペース付き git push → ブロック" "$OUTPUT"

# エラーメッセージに新しい説明文が含まれているか確認
rm -f "$STAMP_DIR/sync-ok"
OUTPUT=$(echo '{"tool_input":{"command":"git push origin main"}}' | \
  "$HOOKS_DIR/sync-gate.sh")
if echo "$OUTPUT" | grep -q "docs/"; then
  pass "新 sync-gate のエラーメッセージに docs/ の言及が含まれている"
else
  fail "新 sync-gate のエラーメッセージに docs/ の言及が含まれている"
fi

# ============================================
echo ""
echo "=== 結果: $PASSED/$TOTAL passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi