#!/bin/bash
# protect-files.sh — 保護ファイルへの編集をブロックするフック
# vibecorp.yml の protected_files で指定されたファイルを保護する

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# vibecorp.yml から protected_files を読み取る
VIBECORP_YML="${CLAUDE_PROJECT_DIR:-.}/.claude/vibecorp.yml"
if [ ! -f "$VIBECORP_YML" ]; then
  exit 0
fi

# protected_files 配列を1行ずつ取得（YAMLパース: awk でブロック単位抽出）
while IFS= read -r protected; do
  # 末尾が一致するかチェック（パス末尾比較で /MVV.md も MVV.md も対応）
  if [[ "$FILE_PATH" == *"$protected" ]]; then
    jq -n --arg file "$protected" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": ("\($file) はファウンダーが管理する保護ファイルです。いかなるエージェント・プロセスも編集できません。")
      }
    }'
    exit 0
  fi
done < <(
  awk '
    /^protected_files:[[:space:]]*$/ { in_list = 1; next }
    in_list && /^[^[:space:]-]/ { exit }
    in_list && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "", $0)
      sub(/[[:space:]]*$/, "", $0)
      print
    }
  ' "$VIBECORP_YML"
)

exit 0
