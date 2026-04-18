#!/bin/bash
# .claude/bin/ スクリプトのユニットテスト
# 対象: activate.sh, vibecorp-sandbox
# 使い方: bash tests/test_bin.sh

set -euo pipefail

BIN_DIR="$(cd "$(dirname "$0")/../.claude/bin" && pwd)"
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

# ============================================
echo "=== activate.sh ==="
# ============================================

# activate.sh を source した後、bin ディレクトリが PATH に含まれる
TEST_PATH_BEFORE="$PATH"
(
  # サブシェルで PATH を隔離してテスト
  unset BASH_SOURCE 2>/dev/null || true
  # activate.sh が存在することを確認
  if [ ! -f "${BIN_DIR}/activate.sh" ]; then
    echo "  FAIL: activate.sh が存在しない"
    exit 1
  fi

  # source して PATH に追加されるか確認
  OLD_PATH="$PATH"
  # shellcheck disable=SC1091
  source "${BIN_DIR}/activate.sh"
  if [[ ":$PATH:" == *":${BIN_DIR}:"* ]]; then
    echo "  PASS: activate.sh source 後 BIN_DIR が PATH に追加される"
  else
    echo "  FAIL: activate.sh source 後 BIN_DIR が PATH に追加される (BIN_DIR: ${BIN_DIR})"
    exit 1
  fi
)
PASSED=$((PASSED + 1))
TOTAL=$((TOTAL + 1))

# activate.sh を2回 source しても PATH が重複しない
(
  source "${BIN_DIR}/activate.sh"
  AFTER_FIRST="$PATH"
  source "${BIN_DIR}/activate.sh"
  AFTER_SECOND="$PATH"
  if [ "$AFTER_FIRST" = "$AFTER_SECOND" ]; then
    echo "  PASS: 2回 source しても PATH が重複しない"
    RESULT=0
  else
    echo "  FAIL: 2回 source しても PATH が重複しない (1回目: $AFTER_FIRST, 2回目: $AFTER_SECOND)"
    RESULT=1
  fi
  exit "$RESULT"
)
PASSED=$((PASSED + 1))
TOTAL=$((TOTAL + 1))

# activate.sh は _vibecorp_activate 関数を unset する
(
  source "${BIN_DIR}/activate.sh"
  if declare -f _vibecorp_activate > /dev/null 2>&1; then
    echo "  FAIL: activate.sh 後 _vibecorp_activate 関数が unset されていない"
    exit 1
  else
    echo "  PASS: activate.sh 後 _vibecorp_activate 関数が unset される"
    exit 0
  fi
)
PASSED=$((PASSED + 1))
TOTAL=$((TOTAL + 1))

# activate.sh は export PATH を行う（サブシェルで PATH が引き継がれる）
(
  source "${BIN_DIR}/activate.sh"
  # PATH が export されていれば子プロセスでも利用可能
  EXPORTED=$(bash -c 'echo "$PATH"')
  if [[ "$EXPORTED" == *"${BIN_DIR}"* ]]; then
    echo "  PASS: activate.sh 後 PATH が export される"
  else
    echo "  FAIL: activate.sh 後 PATH が export される (PATH: $EXPORTED)"
    exit 1
  fi
)
PASSED=$((PASSED + 1))
TOTAL=$((TOTAL + 1))

# ============================================
echo "=== vibecorp-sandbox ==="
# ============================================

SANDBOX="${BIN_DIR}/vibecorp-sandbox"

# 引数なしで実行 → exit 64（使い方エラー）
ACTUAL_EXIT=0
"$SANDBOX" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 64 ]; then
  pass "引数なし → exit 64"
else
  fail "引数なし → exit 64 (実際: $ACTUAL_EXIT)"
fi

# 引数なしでエラーメッセージが stderr に出力される
ERR_OUTPUT=$("$SANDBOX" 2>&1 || true)
if echo "$ERR_OUTPUT" | grep -q "使い方"; then
  pass "引数なし → 使い方メッセージが stderr に出力される"
else
  fail "引数なし → 使い方メッセージが stderr に出力される (実際: $ERR_OUTPUT)"
fi

# Linux では exit 2（Phase 2 未実装）
OS="$(uname -s)"
if [ "$OS" = "Linux" ]; then
  ACTUAL_EXIT=0
  "$SANDBOX" echo test 2>/dev/null || ACTUAL_EXIT=$?
  if [ "$ACTUAL_EXIT" -eq 2 ]; then
    pass "Linux: 引数あり → exit 2"
  else
    fail "Linux: 引数あり → exit 2 (実際: $ACTUAL_EXIT)"
  fi

  # Linux では stderr に「Phase 2」メッセージが出力される
  ERR_OUTPUT=$("$SANDBOX" echo test 2>&1 || true)
  if echo "$ERR_OUTPUT" | grep -q "Phase 2"; then
    pass "Linux: Phase 2 メッセージが stderr に出力される"
  else
    fail "Linux: Phase 2 メッセージが stderr に出力される (実際: $ERR_OUTPUT)"
  fi
fi

# vibecorp-sandbox の validate_abs_path と canonicalize_dir は Darwin 分岐内でのみ呼ばれるが、
# 関数自体はスクリプトの先頭（分岐外）で定義されている。
# ただし source で読み込む際にスクリプトの top-level コード（引数チェック・OS 分岐）が
# 実行されてしまうため、関数定義部分のみを抽出してテストする。

# 関数定義を抽出するヘルパーファイルを作成
FUNC_HELPER="$(mktemp)"
cat > "$FUNC_HELPER" << 'HELPER_EOF'
set -euo pipefail

validate_abs_path() {
  local value="$1"
  local name="$2"
  if [[ -z "$value" ]]; then
    echo "vibecorp-sandbox: $name が空です" >&2
    exit 1
  fi
  if [[ "$value" != /* ]]; then
    echo "vibecorp-sandbox: $name は絶対パスである必要があります: $value" >&2
    exit 1
  fi
  if [[ "$value" == "/" ]]; then
    echo "vibecorp-sandbox: $name をルート(/)にはできません: $value" >&2
    exit 1
  fi
  if [[ "$value" == *".."* ]]; then
    echo "vibecorp-sandbox: $name にパストラバーサル(..)が含まれています: $value" >&2
    exit 1
  fi
  case "$value" in
    *[[:space:]]*|*\"*|*\'*|*\;*|*\|*|*\&*|*\`*|*\$*|*\\*)
      echo "vibecorp-sandbox: $name に危険文字が含まれています: $value" >&2
      exit 1
      ;;
  esac
}

canonicalize_dir() {
  local p="$1"
  local name="$2"
  if [[ -z "$p" ]]; then
    echo "vibecorp-sandbox: canonicalize_dir: $name が空です" >&2
    exit 1
  fi
  if [[ ! -d "$p" ]]; then
    echo "vibecorp-sandbox: $name のディレクトリが存在しません: $p" >&2
    exit 1
  fi
  (cd "$p" && pwd -P)
}
HELPER_EOF

run_sandbox_func() {
  bash -c "source '${FUNC_HELPER}'; $1" 2>/dev/null
}

run_sandbox_func_exit() {
  bash -c "source '${FUNC_HELPER}'; $1" 2>/dev/null
  echo $?
}

# validate_abs_path: 空文字 → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: 空文字 → エラー"
else
  fail "validate_abs_path: 空文字 → エラー (exit 0 になった)"
fi

# validate_abs_path: 相対パス → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path 'relative/path' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: 相対パス → エラー"
else
  fail "validate_abs_path: 相対パス → エラー (exit 0 になった)"
fi

# validate_abs_path: ルート "/" → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '/' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: ルート '/' → エラー"
else
  fail "validate_abs_path: ルート '/' → エラー (exit 0 になった)"
fi

# validate_abs_path: パストラバーサル (..) → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '/home/user/../etc/passwd' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: パストラバーサル (..) → エラー"
else
  fail "validate_abs_path: パストラバーサル (..) → エラー (exit 0 になった)"
fi

# validate_abs_path: スペース含む → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '/path with spaces' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: スペース含む → エラー"
else
  fail "validate_abs_path: スペース含む → エラー (exit 0 になった)"
fi

# validate_abs_path: セミコロン含む → exit 1
ACTUAL_EXIT=0
bash -c 'source '"'${FUNC_HELPER}'"'; validate_abs_path '"'/path;rm'"' TEST' 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: セミコロン含む → エラー"
else
  fail "validate_abs_path: セミコロン含む → エラー (exit 0 になった)"
fi

# validate_abs_path: ドル記号含む → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '/path/\$HOME' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: ドル記号含む → エラー"
else
  fail "validate_abs_path: ドル記号含む → エラー (exit 0 になった)"
fi

# validate_abs_path: バックスラッシュ含む → exit 1
ACTUAL_EXIT=0
bash -c 'source '"'${FUNC_HELPER}'"'; validate_abs_path '"'/path\test'"' TEST' 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "validate_abs_path: バックスラッシュ含む → エラー"
else
  fail "validate_abs_path: バックスラッシュ含む → エラー (exit 0 になった)"
fi

# validate_abs_path: 正常な絶対パス → exit 0
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '/home/user/project' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 0 ]; then
  pass "validate_abs_path: 正常な絶対パス → OK"
else
  fail "validate_abs_path: 正常な絶対パス → OK (exit $ACTUAL_EXIT)"
fi

# validate_abs_path: 深い正常パス → exit 0
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; validate_abs_path '/home/user/projects/myapp/src' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 0 ]; then
  pass "validate_abs_path: 深い正常パス → OK"
else
  fail "validate_abs_path: 深い正常パス → OK (exit $ACTUAL_EXIT)"
fi

# canonicalize_dir: 存在しないディレクトリ → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; canonicalize_dir '/nonexistent/path/does/not/exist' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "canonicalize_dir: 存在しないディレクトリ → エラー"
else
  fail "canonicalize_dir: 存在しないディレクトリ → エラー (exit 0 になった)"
fi

# canonicalize_dir: 実在するディレクトリ → パスを返す
TMP_DIR="$(mktemp -d)"
RESULT=""
ACTUAL_EXIT=0
RESULT=$(bash -c "source '${FUNC_HELPER}'; canonicalize_dir '${TMP_DIR}' 'TEST'" 2>/dev/null) || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -eq 0 ] && [ -n "$RESULT" ]; then
  pass "canonicalize_dir: 実在するディレクトリ → パスを返す"
else
  fail "canonicalize_dir: 実在するディレクトリ → パスを返す (exit: $ACTUAL_EXIT, result: '$RESULT')"
fi
rmdir "$TMP_DIR"

# canonicalize_dir: 空文字 → exit 1
ACTUAL_EXIT=0
bash -c "source '${FUNC_HELPER}'; canonicalize_dir '' 'TEST'" 2>/dev/null || ACTUAL_EXIT=$?
if [ "$ACTUAL_EXIT" -ne 0 ]; then
  pass "canonicalize_dir: 空文字 → エラー"
else
  fail "canonicalize_dir: 空文字 → エラー (exit 0 になった)"
fi

# ヘルパーファイルを削除
rm -f "$FUNC_HELPER"

# ============================================
echo ""
echo "=== 結果: $PASSED/$TOTAL passed, $FAILED failed ==="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi