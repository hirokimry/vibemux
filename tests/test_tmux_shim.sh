#!/bin/bash
# tmux PATH shim test suite
#
# 実 tmux を呼ばずに動かすため、tests/fixtures/fake-tmux を実体 tmux 役として
# PATH から shim ディレクトリだけを除いたパスに置く。
#
# - テストごとにログディレクトリ・PATH を制御
# - 環境変数依存テストはサブシェルで制御（.claude/rules/testing.md）

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM="${REPO_ROOT}/.claude/bin/tmux"
FIXTURE_DIR="${REPO_ROOT}/tests/fixtures"
FAKE_TMUX="${FIXTURE_DIR}/fake-tmux"

passed=0
failed=0

pass() { echo "  PASS: $1"; passed=$((passed + 1)); }
fail() { echo "  FAIL: $1"; failed=$((failed + 1)); }

setup_tmpdir() {
  TMP_DIR=$(mktemp -d)
  TMP_LOG_DIR="${TMP_DIR}/log"
  TMP_BIN_DIR="${TMP_DIR}/bin"
  mkdir -p "$TMP_BIN_DIR"
  ln -sf "$FAKE_TMUX" "${TMP_BIN_DIR}/tmux"
  # XDG_CACHE_HOME を tmp に向けてフォールバックパスにログを出させる
  export XDG_CACHE_HOME="${TMP_DIR}/cache"
  # CLAUDE_PROJECT_DIR は worktree を指すと common.sh フォールバック判定で stamp_dir 経由
  # になるので、フォールバック動作をテストするときは VIBEMUX_SHIM_FORCE_FALLBACK=1 を使う
  export VIBEMUX_SHIM_FORCE_FALLBACK=1
}

cleanup_tmpdir() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    rm -rf "$TMP_DIR"
  fi
  unset XDG_CACHE_HOME VIBEMUX_SHIM_FORCE_FALLBACK
}

# shim を実行する。SHIM_DIR を PATH 先頭、TMP_BIN_DIR を次に置くことで
# resolve_real_tmux が fake-tmux を見つけられるようにする
run_shim() {
  local out
  out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" "$@" 2>&1)
  printf '%s' "$out"
}

run_shim_status() {
  local rc=0
  PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" "$@" >/dev/null 2>&1 || rc=$?
  printf '%d' "$rc"
}

assert_denied() {
  local desc="$1" expected_pattern="$2"
  shift 2
  local out rc
  out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" "$@" 2>&1)
  rc=$?
  if [ "$rc" -ne 1 ]; then
    fail "$desc (期待: exit 1、実際: exit $rc, output: $out)"
    return
  fi
  if echo "$out" | grep -qE "拒否しました"; then
    if [ -z "$expected_pattern" ] || echo "$out" | grep -qE "$expected_pattern"; then
      pass "$desc"
    else
      fail "$desc (拒否は出たがパターン '$expected_pattern' 不在: $out)"
    fi
  else
    fail "$desc (拒否メッセージなし: $out)"
  fi
}

assert_allowed_to_fake() {
  local desc="$1"
  shift
  local out rc
  out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" "$@" 2>&1)
  rc=$?
  if [ "$rc" -eq 0 ] && echo "$out" | grep -q "^fake-tmux:"; then
    pass "$desc"
  else
    fail "$desc (期待: fake-tmux 実行、実際: rc=$rc, output: $out)"
  fi
}

assert_subcommand_extracted() {
  # shim を debug 動作させる代わりに、fake-tmux が受け取った引数を検証する。
  # extract_subcommand が正しく動けば、許可コマンドはそのまま実体に渡る。
  local desc="$1" expected_args="$2"
  shift 2
  local out
  out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" "$@" 2>&1)
  if echo "$out" | grep -qF "fake-tmux: ${expected_args}"; then
    pass "$desc"
  else
    fail "$desc (期待: 'fake-tmux: ${expected_args}'、実際: $out)"
  fi
}

echo "=== tmux shim test suite ==="
echo

# 前提ファイル確認
if [ ! -x "$SHIM" ]; then
  fail "shim が実行可能でない: $SHIM"
  exit 1
fi
if [ ! -x "$FAKE_TMUX" ]; then
  fail "fake-tmux fixture が実行可能でない: $FAKE_TMUX"
  exit 1
fi

setup_tmpdir
trap cleanup_tmpdir EXIT

# ── Phase 1.2: extract_subcommand 境界値 ──
echo "[extract_subcommand 境界値]"
assert_subcommand_extracted "tmux ls → ls" "ls" ls
assert_subcommand_extracted "tmux -2 ls → ls (グローバルフラグスキップ)" "-2 ls" -2 ls
assert_subcommand_extracted "tmux -L sock attach → attach (-L 値スキップ)" "-L sock attach" -L sock attach
assert_subcommand_extracted "tmux -L kill-server attach → attach (-L 値が禁止コマンド名でも値として消費)" "-L kill-server attach" -L kill-server attach
assert_subcommand_extracted "tmux -L sock -f file new-session (連続値オプション)" "-L sock -f file new-session" -L sock -f file new-session
assert_subcommand_extracted "tmux (no-command) → 実体に丸投げ" ""
assert_subcommand_extracted "tmux -- ls (-- 後がサブコマンド)" "-- ls" -- ls
echo

# ── Phase 1.3: 絶対禁止コマンド（本体名 + 別名） ──
echo "[absolute forbidden subcommands]"
assert_denied "kill-server" "kill-server" kill-server
assert_denied "set-hook" "set-hook" set-hook key1 cmd1
assert_denied "bind-key" "bind-key" bind-key x send-keys
assert_denied "bind (別名)" "bind" bind x send-keys
assert_denied "unbind-key" "unbind-key" unbind-key x
assert_denied "unbind (別名)" "unbind" unbind x
assert_denied "switch-client" "switch-client" switch-client -t target
assert_denied "switchc (別名)" "switchc" switchc -t target
assert_denied "detach-client" "detach-client" detach-client -t target
assert_denied "detach (別名)" "detach" detach
echo

# ── Phase 1.4: set-option / set-window-option / set-environment の -g/-s ──
echo "[set-option global flags]"
assert_denied "set -g status off" "グローバル/サーバー設定" set -g status off
assert_denied "set-option -g status off" "グローバル/サーバー設定" set-option -g status off
assert_denied "set -ga status off (結合フラグ)" "グローバル/サーバー設定" set -ga status off
assert_denied "set -gq status off (結合フラグ)" "グローバル/サーバー設定" set -gq status off
assert_denied "set -s exit-empty off" "グローバル/サーバー設定" set -s exit-empty off
assert_denied "setw -g x off" "グローバル/サーバー設定" setw -g x off
assert_denied "set-window-option -g x off" "グローバル/サーバー設定" set-window-option -g x off
assert_denied "setenv -g X 1" "グローバル/サーバー設定" setenv -g X 1
assert_denied "set-environment -g X 1" "グローバル/サーバー設定" set-environment -g X 1
assert_allowed_to_fake "set status off (ローカル)" set status off
assert_allowed_to_fake "set -- -g status off (-- 後はフラグ扱いしない)" set -- -g status off
echo

# ── Phase 1.5: synchronize-panes ON 検出 ──
echo "[synchronize-panes ON detection]"
assert_denied "setw synchronize-panes on" "synchronize-panes" setw synchronize-panes on
assert_denied "setw synchronize-panes ON (大文字)" "synchronize-panes" setw synchronize-panes ON
assert_denied "setw synchronize-panes True" "synchronize-panes" setw synchronize-panes True
assert_denied "setw synchronize-panes 1" "synchronize-panes" setw synchronize-panes 1
assert_denied "set-window-option synchronize-panes on" "synchronize-panes" set-window-option synchronize-panes on
assert_denied "set -w synchronize-panes on (set-option -w 経由)" "synchronize-panes" set -w synchronize-panes on
assert_allowed_to_fake "setw synchronize-panes off" setw synchronize-panes off
assert_allowed_to_fake "setw synchronize-panes 0" setw synchronize-panes 0
echo

# ── Phase 2.1-2.4: kill-session 引数構文 ──
echo "[kill-session argument syntax]"
desc="kill-session（引数なし）→ target-required"
out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q "セッション名"; then
  pass "$desc"
else
  fail "$desc (rc=$rc, out=$out)"
fi

assert_denied "kill-session -a → blanket" "全セッション削除" kill-session -a
assert_denied "kill-session -t :0 → non-name-target" "セッション名ではありません" kill-session -t :0
assert_denied "kill-session -t \$1 → non-name-target" "セッション名ではありません" kill-session -t '$1'
assert_denied "kill-session -t =foo → non-name-target" "セッション名ではありません" kill-session -t =foo
assert_denied "kill-session -t a -t b → -t 複数" "複数指定" kill-session -t a -t b
echo

# ── Phase 2.2: prefix 一致/不一致 ──
echo "[kill-session prefix matching]"
assert_denied "kill-session -t foo → mismatch" "プレフィックス不一致" kill-session -t foo
assert_allowed_to_fake "kill-session -t vbx-x → 許可" kill-session -t vbx-x
echo

# ── Phase 2.5: VIBEMUX_AI_SESSION_PREFIX カスタム ──
echo "[VIBEMUX_AI_SESSION_PREFIX custom]"
desc="VIBEMUX_AI_SESSION_PREFIX=foo- で foo-x → 許可"
out=$(VIBEMUX_AI_SESSION_PREFIX=foo- PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t foo-x 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "^fake-tmux:"; then
  pass "$desc"
else
  fail "$desc (rc=$rc, out=$out)"
fi

desc="VIBEMUX_AI_SESSION_PREFIX 未設定でデフォルト vbx- 適用"
out=$(unset VIBEMUX_AI_SESSION_PREFIX; PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t vbx-y 2>&1)
rc=$?
if [ "$rc" -eq 0 ] && echo "$out" | grep -q "^fake-tmux:"; then
  pass "$desc"
else
  fail "$desc (rc=$rc, out=$out)"
fi
echo

# ── Phase 2.6: グロブ展開対策 ──
echo "[prefix glob safety]"
desc="VIBEMUX_AI_SESSION_PREFIX='*' で random → 拒否（グロブ展開しない）"
out=$(VIBEMUX_AI_SESSION_PREFIX='*' PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t random 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q "プレフィックス不一致"; then
  pass "$desc"
else
  fail "$desc (rc=$rc, out=$out)"
fi

desc="VIBEMUX_AI_SESSION_PREFIX='[abc]' で a → 拒否"
out=$(VIBEMUX_AI_SESSION_PREFIX='[abc]' PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t a 2>&1)
rc=$?
if [ "$rc" -eq 1 ] && echo "$out" | grep -q "プレフィックス不一致"; then
  pass "$desc"
else
  fail "$desc (rc=$rc, out=$out)"
fi
echo

# ── Phase 2.7: WARN 出力と VIBEMUX_SHIM_QUIET_PHASE_A ──
echo "[Phase A WARN output]"
desc="WARN 出力（デフォルト）"
out=$(unset VIBEMUX_SHIM_QUIET_PHASE_A; PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t vbx-x 2>&1)
if echo "$out" | grep -q "Phase AB 未実装"; then
  pass "$desc"
else
  fail "$desc (期待: 'Phase AB 未実装' WARN、実際: $out)"
fi

desc="VIBEMUX_SHIM_QUIET_PHASE_A=1 で WARN 抑制"
out=$(VIBEMUX_SHIM_QUIET_PHASE_A=1 PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t vbx-x 2>&1)
if echo "$out" | grep -q "Phase AB 未実装"; then
  fail "$desc (WARN が抑制されていない: $out)"
else
  pass "$desc"
fi
echo

# ── Phase 2.8: workaround ヒント ──
echo "[workaround hint on prefix-mismatch]"
desc="prefix-mismatch 時に workaround ヒント"
out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t foo 2>&1)
if echo "$out" | grep -q "ヒント:"; then
  pass "$desc"
else
  fail "$desc (期待: 'ヒント:'、実際: $out)"
fi

desc="kill-session -a (blanket) では workaround を出さない"
out=$(PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -a 2>&1)
if echo "$out" | grep -q "ヒント:"; then
  fail "$desc (blanket でヒントが出てしまった: $out)"
else
  pass "$desc"
fi
echo

# ── Phase 3.1-3.6: ログ出力 ──
echo "[log output]"
LOG_PATH=$(find "${XDG_CACHE_HOME}/vibecorp/state/" -name 'tmux-direct-exec.log' 2>/dev/null | head -1)
if [ -z "$LOG_PATH" ] || [ ! -f "$LOG_PATH" ]; then
  fail "ログファイルが作成されていない（XDG_CACHE_HOME=$XDG_CACHE_HOME 配下に tmux-direct-exec.log なし）"
  exit 1
fi

desc="ログに event=kill-session-denied を含む"
if grep -q 'event=kill-session-denied' "$LOG_PATH"; then
  pass "$desc"
else
  fail "$desc"
fi

desc="ログに event=forbidden-denied を含む"
if grep -q 'event=forbidden-denied' "$LOG_PATH"; then
  pass "$desc"
else
  fail "$desc"
fi

desc="ログに route= フィールドを含む"
if grep -q 'route=' "$LOG_PATH"; then
  pass "$desc"
else
  fail "$desc"
fi

desc="ログに target= フィールドを含む"
if grep -q 'target=' "$LOG_PATH"; then
  pass "$desc"
else
  fail "$desc"
fi

desc="ログに command= フィールドを含む"
if grep -q 'command=' "$LOG_PATH"; then
  pass "$desc"
else
  fail "$desc"
fi

# ── Phase 3.4: タブ・改行サニタイズ ──
desc="セッション名にタブを含むケースで 1 レコードが 1 行に収まる"
before_lines=$(wc -l < "$LOG_PATH")
PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-session -t $'tab\there' >/dev/null 2>&1 || true
after_lines=$(wc -l < "$LOG_PATH")
diff_lines=$((after_lines - before_lines))
if [ "$diff_lines" -eq 1 ]; then
  pass "$desc"
else
  fail "$desc (1 行追加されるべきが ${diff_lines} 行追加された)"
fi

# ── Phase 3.6: 追記モード ──
desc="拒否2回でログ行数が2増加"
before_lines=$(wc -l < "$LOG_PATH")
PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-server >/dev/null 2>&1 || true
PATH="$(dirname "$SHIM"):${TMP_BIN_DIR}:${PATH}" "$SHIM" kill-server >/dev/null 2>&1 || true
after_lines=$(wc -l < "$LOG_PATH")
diff_lines=$((after_lines - before_lines))
if [ "$diff_lines" -eq 2 ]; then
  pass "$desc"
else
  fail "$desc (2 行追加されるべきが ${diff_lines} 行追加された)"
fi
echo

# ── Phase 3.2: common.sh 不在時のフォールバック ──
echo "[common.sh fallback]"
# VIBEMUX_SHIM_FORCE_FALLBACK は setup_tmpdir で常にセット済みなので、
# 既にこのテストは XDG_CACHE_HOME 配下にログが書けていることで間接検証される。
# 明示的にもう一度確認:
desc="フォールバック動作で <XDG_CACHE_HOME>/vibecorp/state/<repo-id>/ にログが書かれる"
if [[ "$LOG_PATH" == "$XDG_CACHE_HOME"/vibecorp/state/*/tmux-direct-exec.log ]]; then
  pass "$desc"
else
  fail "$desc (実際のパス: $LOG_PATH)"
fi
echo

# ── Phase 1.1: 不明サブコマンド（pass-through） ──
echo "[unknown subcommand pass-through]"
assert_allowed_to_fake "list-sessions（許可コマンド）→ pass-through" list-sessions
assert_allowed_to_fake "new-session -d -s foo（許可コマンド）→ pass-through" new-session -d -s foo
echo

echo "=== Results: $passed passed, $failed failed ==="
[ "$failed" -eq 0 ]
