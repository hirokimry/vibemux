#!/bin/bash
# MVV.md への編集をブロックするフック
# MVVはファウンダーのみが変更可能な最上位方針ドキュメント

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ "$FILE_PATH" == */MVV.md ]]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "MVV.md はファウンダーのみが編集可能です。いかなるエージェント・プロセスも編集できません。"
    }
  }'
  exit 0
fi

exit 0
