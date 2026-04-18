#!/bin/bash
# role-gate.sh — エージェントが管轄外のファイルを編集することをブロックするフック
# ロールファイル($CLAUDE_PROJECT_DIR/.claude/state/agent-role)にロール名が書かれている場合のみ動作
# ロールファイルが存在しなければスキップ（通常セッション＝人間操作時は制約なし）

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# ロールファイルからロール名を読み取る
ROLE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/state/agent-role"
if [ ! -f "$ROLE_FILE" ]; then
  exit 0
fi

ROLE=$(cat "$ROLE_FILE" | tr -d '[:space:]')
if [ -z "$ROLE" ]; then
  exit 0
fi

# knowledge/ 配下は全ロール編集可
if [[ "$FILE_PATH" == */knowledge/* ]] || [[ "$FILE_PATH" == knowledge/* ]]; then
  exit 0
fi

# docs/ 配下以外はチェック対象外（許可）
IS_DOCS=false
if [[ "$FILE_PATH" == */docs/* ]] || [[ "$FILE_PATH" == docs/* ]]; then
  IS_DOCS=true
fi

if [ "$IS_DOCS" = false ]; then
  exit 0
fi

# 管轄マッピング: ロール → 編集可能なファイルパターン（docs/ 配下のみ）
is_allowed() {
  local role="$1"
  local path="$2"

  case "$role" in
    cpo)
      [[ "$path" == *docs/specification.md ]] && return 0
      [[ "$path" == *docs/screen-flow.md ]] && return 0
      ;;
    cto)
      [[ "$path" == *docs/specification.md ]] && return 0
      [[ "$path" == *docs/design-philosophy.md ]] && return 0
      ;;
    legal)
      [[ "$path" == *docs/POLICY.md ]] && return 0
      ;;
    accounting)
      [[ "$path" == *docs/cost-analysis.md ]] && return 0
      ;;
    security)
      [[ "$path" == *docs/SECURITY.md ]] && return 0
      ;;
    sm)
      [[ "$path" == *docs/ai-organization.md ]] && return 0
      ;;
    # 統括職（cfo/clo/ciso）は docs/ 配下の直接編集権限なし
    # 未知のロールも docs/ 配下はブロック
  esac

  return 1
}

if is_allowed "$ROLE" "$FILE_PATH"; then
  exit 0
fi

# 管轄外 → deny
jq -n --arg role "$ROLE" --arg file "$FILE_PATH" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": ("ロール [" + $role + "] は " + $file + " の編集権限がありません。管轄外のファイルは編集できません。")
  }
}'
exit 0
