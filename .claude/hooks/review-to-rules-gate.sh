#!/bin/bash
# gh pr merge 前に /review-to-rules の実行を強制するフック
# review-to-rules がOK判定を出したスタンプがあればmerge許可

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

CMD_HEAD=$(echo "$COMMAND" | sed 's/^[[:space:]]*//' | sed -E 's/^([A-Za-z_][A-Za-z0-9_]*=[^ ]* +)*//' | awk '{print $1, $2, $3}')
if [ "$CMD_HEAD" = "gh pr merge" ]; then
  STAMP_FILE="/tmp/.vibemux-review-to-rules-ok"

  if [ -f "$STAMP_FILE" ]; then
    rm -f "$STAMP_FILE"
    exit 0
  fi

  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "マージ前に /review-to-rules を実行してください。レビュー指摘の規約・ナレッジ反映が必要です。"
    }
  }'
  exit 0
fi

exit 0
