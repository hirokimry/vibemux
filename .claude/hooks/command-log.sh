#!/bin/bash
# command-log.sh — 全 Bash コマンドをログファイルに記録する PreToolUse フック
# ログは $CLAUDE_PROJECT_DIR/.claude/state/command-log に追記される
# 判定は返さない（ログ記録のみ）

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Bash 以外は記録しない
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if [ -z "$COMMAND" ]; then
  exit 0
fi

# state ディレクトリを作成してログファイルに追記
STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/state"
mkdir -p "$STATE_DIR"
LOG_FILE="${STATE_DIR}/command-log"

# タイムスタンプ + コマンドをログに追記
printf '%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$COMMAND" >> "$LOG_FILE"

exit 0
