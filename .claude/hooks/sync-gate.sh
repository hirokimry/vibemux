#!/bin/bash
# git push 前に /sync-check の実行を強制するフック
# sync-check がOK判定を出したスタンプがあればpush許可

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# ブランチ削除はチェック不要
if echo "$COMMAND" | grep -qE '^git push.*--delete|^git push.*-d '; then
  exit 0
fi

if echo "$COMMAND" | grep -qE '^git push'; then
  STAMP_FILE="/tmp/.vibemux-sync-ok"

  if [ -f "$STAMP_FILE" ]; then
    rm -f "$STAMP_FILE"
    exit 0
  fi

  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "push前に /sync-check を実行してください。"
    }
  }'
  exit 0
fi

exit 0
