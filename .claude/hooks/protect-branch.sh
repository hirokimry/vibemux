#!/bin/bash
# protect-branch.sh — メインブランチでの直接作業をブロックするフック
# vibecorp.yml の base_branch で設定されたブランチ上での Edit/Write/git commit を防止する
#
# 既知制限: Bash ツールは tool_input.command に対象ファイルパスを含まないため、
# worktree 判定不能 → cwd 基準で判定される。teammate が worktree 内で素の git commit を
# 直叩きすると main repo の cwd を見て deny される。`/commit` スキル経由で
# `cd <worktree> && git commit` 形式で呼ぶこと。詳細は docs/known-limitations.md を参照。

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# vibecorp.yml から base_branch を取得（デフォルト: main）
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
VIBECORP_YML="${PROJECT_DIR}/.claude/vibecorp.yml"
BASE_BRANCH="main"
if [ -f "$VIBECORP_YML" ]; then
  RAW_BRANCH=$(awk '/^base_branch:[[:space:]]*/ { sub(/^base_branch:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$VIBECORP_YML")
  if [ -n "${RAW_BRANCH:-}" ]; then
    BASE_BRANCH="$RAW_BRANCH"
  fi
fi

# realpath の可搬性ラッパー: realpath 不在環境では cd && pwd -P で代替
resolve_realpath() {
  local target="$1"
  if command -v realpath >/dev/null 2>&1; then
    realpath "$target" 2>/dev/null || echo ""
  elif [ -d "$target" ]; then
    ( cd "$target" 2>/dev/null && pwd -P ) || echo ""
  else
    echo ""
  fi
}

# パストラバーサル対策: file_path から worktree を引く際の許可ルート
# CLAUDE_PROJECT_DIR の親ディレクトリ配下のみ許可（worktree は通常 <project>.worktrees/ として
# 親ディレクトリの兄弟に配置される想定）
ALLOWED_ROOT=$(resolve_realpath "${PROJECT_DIR}/..")

# Edit/Write の場合、対象ファイルパスから worktree を判定する。
# Bash や ALLOWED_ROOT が空/"/"のときは安全側で cwd 基準（CHECK_DIR=".")
CHECK_DIR="."
if [ -n "$ALLOWED_ROOT" ] && [ "$ALLOWED_ROOT" != "/" ]; then
  if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    TARGET_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

    # 空文字 / null / ~ 始まり は安全側にフォールバック（CHECK_DIR="." のまま）
    # 注意: Claude は通常解決後の絶対パスを送る前提のため ~ 先頭のみ判定する。
    # 未展開の $VAR や $(...) を含む file_path が来た場合は realpath が失敗する → 後続の
    # ALLOWED_ROOT 判定で安全側 deny にフォールバックされる。
    if [ -n "$TARGET_PATH" ] && [ "${TARGET_PATH#\~}" = "$TARGET_PATH" ]; then
      # 親ディレクトリを最大 10 階層遡って実在ディレクトリを探す
      PARENT_DIR=$(dirname "$TARGET_PATH")
      DEPTH=0
      while [ ! -d "$PARENT_DIR" ] && [ "$PARENT_DIR" != "/" ] && [ "$PARENT_DIR" != "." ] && [ "$DEPTH" -lt 10 ]; do
        PARENT_DIR=$(dirname "$PARENT_DIR")
        DEPTH=$((DEPTH + 1))
      done

      if [ -d "$PARENT_DIR" ]; then
        # realpath で正規化し、ALLOWED_ROOT 配下にあることを検証
        RESOLVED=$(resolve_realpath "$PARENT_DIR")
        if [ -n "$RESOLVED" ]; then
          case "$RESOLVED/" in
            "$ALLOWED_ROOT"/*) CHECK_DIR="$RESOLVED" ;;
            *) CHECK_DIR="." ;;  # repo 外 → 安全側 deny
          esac
        fi
      fi
    fi
  fi
fi

# 現在のブランチを取得（CHECK_DIR を基準に）
CURRENT_BRANCH=$(git -C "$CHECK_DIR" branch --show-current 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ]; then
  # detached HEAD 等 → スキップ
  exit 0
fi

# メインブランチでなければ許可
if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
  exit 0
fi

# deny を出力して終了する関数
# tool 名と check_dir を reason に含めることで、worktree 判定の失敗（check_dir=.）と
# 正当な main 判定の区別を可能にする。
deny() {
  local tool="${TOOL_NAME:-unknown}"
  local check_dir="${CHECK_DIR:-.}"
  jq -n \
    --arg branch "$BASE_BRANCH" \
    --arg tool "$tool" \
    --arg check_dir "$check_dir" \
    '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ($branch + " ブランチでは直接作業できません。フィーチャーブランチを作成してください。 [tool=" + $tool + ", check_dir=" + $check_dir + "]")
      }
    }'
  exit 0
}

# Edit / Write → deny
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  deny
fi

# Bash → git commit のみ deny
if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
  if [ -z "$COMMAND" ]; then
    exit 0
  fi

  # &&, ||, ; でセグメント分割して各セグメントを検査
  # here-string で読み込むことでサブシェルを回避
  # TODO: 下記の sed による分割は quote-aware ではなく shell.md 違反（quote 内の && / ; を
  # 誤分割する）。git commit -m "msg; with semicolon" 等でガードがすり抜ける既知バイパス経路。
  # 別 Issue として後続化する（awk による quote-aware 分割への置換）。
  FOUND_COMMIT=false
  while IFS= read -r segment; do
    segment=$(echo "$segment" | sed 's/^[[:space:]]*//')
    if [ -z "$segment" ]; then
      continue
    fi

    # コマンド正規化（sync-gate.sh パターン準拠）
    # 1. 環境変数プレフィックス (KEY=VALUE ...) を除去
    CMD_NORMALIZED=$(echo "$segment" | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*//')
    # 2. ラッパーコマンド (env, command) を除去
    while true; do
      FIRST_TOKEN=$(echo "$CMD_NORMALIZED" | awk '{print $1}')
      case "$FIRST_TOKEN" in
        env|command) CMD_NORMALIZED=$(echo "$CMD_NORMALIZED" | sed -E 's/^[^ ]+ +//') ;;
        *) break ;;
      esac
    done
    # 3. 絶対パス/相対パスを basename に正規化
    FIRST_TOKEN=$(echo "$CMD_NORMALIZED" | awk '{print $1}')
    if [[ "$FIRST_TOKEN" == */* ]]; then
      BASE_CMD=$(basename "$FIRST_TOKEN")
      CMD_NORMALIZED="$BASE_CMD $(echo "$CMD_NORMALIZED" | awk '{$1=""; print}' | sed 's/^ *//')"
    fi
    # 4. 先頭2トークンを取得
    CMD_HEAD=$(echo "$CMD_NORMALIZED" | awk '{print $1, $2}')

    if [ "$CMD_HEAD" = "git commit" ]; then
      FOUND_COMMIT=true
      break
    fi
  done <<< "$(echo "$COMMAND" | sed 's/&&/\n/g; s/||/\n/g; s/;/\n/g')"

  if [ "$FOUND_COMMIT" = "true" ]; then
    deny
  fi
fi

exit 0
