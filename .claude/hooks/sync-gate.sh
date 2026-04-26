#!/bin/bash
# sync-gate.sh — git push 前に /vibecorp:sync-check の実行を強制するフック
# sync-check がOK判定を出したスタンプがあればpush許可

set -euo pipefail

# 共通ユーティリティ読み込み
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../lib/common.sh
source "${HOOK_DIR}/../lib/common.sh"

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# コマンド正規化（共通関数を使用）
CMD_NORMALIZED=$(normalize_command "$COMMAND")
CMD_HEAD=$(echo "$CMD_NORMALIZED" | awk '{print $1, $2}')

if [ "$CMD_HEAD" != "git push" ]; then
  exit 0
fi

# ブランチ削除（--delete / -d）はチェック不要
REST=$(echo "$CMD_NORMALIZED" | awk '{$1=""; $2=""; print}' | sed 's/^ *//')
if echo "$REST" | grep -qE '(^| )(--delete|-d)( |$)'; then
  exit 0
fi

# 対象コマンドの場合のみスタンプパスを解決（早期 exit 後に評価することで
# 無関係コマンドで git rev-parse + shasum を走らせない）
STAMP_FILE="$(vibecorp_stamp_path sync)"

if [ -f "$STAMP_FILE" ]; then
  rm -f "$STAMP_FILE"
  exit 0
fi

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "push前に /vibecorp:sync-check を実行してください。docs/ と knowledge/ の整合性確認が必要です。"
  }
}'
exit 0
