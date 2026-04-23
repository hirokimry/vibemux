#!/bin/bash
# diagnose-guard.sh — /diagnose 実行中に保護ファイルへの編集をブロックするフック
# diagnose-active スタンプ存在時に hooks/*.sh, vibecorp.yml, MVV.md, diagnose-guard.sh への変更を deny

set -euo pipefail

# shellcheck source=../lib/common.sh
source "${CLAUDE_PROJECT_DIR:-.}/.claude/lib/common.sh"

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

STAMP_FILE="$(vibecorp_state_path diagnose-active)"

# diagnose-active スタンプが存在しない場合は何もしない
if [ ! -f "$STAMP_FILE" ]; then
  exit 0
fi

# vibecorp.yml の diagnose.forbidden_targets を読み取る（デフォルト値あり）
VIBECORP_YML="${CLAUDE_PROJECT_DIR:-.}/.claude/vibecorp.yml"
FORBIDDEN_PATTERNS=""
if [ -f "$VIBECORP_YML" ]; then
  FORBIDDEN_PATTERNS=$(awk '
    /^diagnose:/ { in_diagnose = 1; next }
    in_diagnose && /^[^ #]/ { exit }
    in_diagnose && /^  forbidden_targets:/ { in_targets = 1; next }
    in_diagnose && in_targets && /^  [^ -]/ { exit }
    in_diagnose && in_targets && /^    - / {
      sub(/^    - /, "")
      sub(/[[:space:]]*$/, "")
      # クォートを除去
      gsub(/"/, "")
      gsub(/'\''/, "")
      print
    }
  ' "$VIBECORP_YML")
fi

# forbidden_targets が空の場合はデフォルト値を使用
if [ -z "$FORBIDDEN_PATTERNS" ]; then
  FORBIDDEN_PATTERNS="hooks/*.sh
vibecorp.yml
MVV.md
SECURITY.md
POLICY.md"
fi

# diagnose-guard.sh 自体は常に保護（forbidden_targets に関係なく）
if echo "$FILE_PATH" | grep -q 'diagnose-guard\.sh$'; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "/diagnose 実行中は diagnose-guard.sh を変更できません。自己制約の緩和は禁止されています。"
    }
  }'
  exit 0
fi

# forbidden_targets のパターンマッチ
while IFS= read -r pattern; do
  [ -z "$pattern" ] && continue

  # ワイルドカードパターン（例: hooks/*.sh）
  if echo "$pattern" | grep -q '\*'; then
    # glob パターンを正規表現に変換
    REGEX_PATTERN=$(printf '%s' "$pattern" | sed 's/\./\\./g' | sed 's/\*/[^\/]*/g')
    if echo "$FILE_PATH" | grep -qE "$REGEX_PATTERN"; then
      jq -n --arg pattern "$pattern" '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "deny",
          "permissionDecisionReason": ("/diagnose 実行中は " + $pattern + " に一致するファイルを変更できません。暴走防止のため保護されています。")
        }
      }'
      exit 0
    fi
  else
    # 完全一致（パス末尾比較）
    if [[ "$FILE_PATH" == *"$pattern" ]]; then
      jq -n --arg pattern "$pattern" '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "deny",
          "permissionDecisionReason": ("/diagnose 実行中は " + $pattern + " を変更できません。暴走防止のため保護されています。")
        }
      }'
      exit 0
    fi
  fi
done <<< "$FORBIDDEN_PATTERNS"

exit 0
