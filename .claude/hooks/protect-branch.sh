#!/bin/bash
# protect-branch.sh — メインブランチでの直接作業をブロックするフック
# vibecorp.yml の base_branch で設定されたブランチ上での Edit/Write/git commit を防止する

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# vibecorp.yml から base_branch を取得（デフォルト: main）
VIBECORP_YML="${CLAUDE_PROJECT_DIR:-.}/.claude/vibecorp.yml"
BASE_BRANCH="main"
if [ -f "$VIBECORP_YML" ]; then
  RAW_BRANCH=$(awk '/^base_branch:[[:space:]]*/ { sub(/^base_branch:[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit }' "$VIBECORP_YML")
  if [ -n "${RAW_BRANCH:-}" ]; then
    BASE_BRANCH="$RAW_BRANCH"
  fi
fi

# 現在のブランチを取得
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -z "$CURRENT_BRANCH" ]; then
  # detached HEAD 等 → スキップ
  exit 0
fi

# メインブランチでなければ許可
if [ "$CURRENT_BRANCH" != "$BASE_BRANCH" ]; then
  exit 0
fi

# deny を出力して終了する関数
deny() {
  jq -n --arg branch "$BASE_BRANCH" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": ($branch + " ブランチでは直接作業できません。フィーチャーブランチを作成してください。")
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
