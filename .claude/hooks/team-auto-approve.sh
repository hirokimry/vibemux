#!/bin/bash
# team-auto-approve.sh — チームモードでの安全なツールコールを自動承認するフック
# チームメイトが settings.local.json の allow リストを継承しない問題の回避策
# 参照: anthropics/claude-code#26479

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# --- Write / Edit: 保護対象ファイル以外を自動承認 ---
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

  if [ -z "$FILE_PATH" ]; then
    exit 0
  fi

  # 保護対象ファイルは承認しない（通常フローに委ねる）
  case "$FILE_PATH" in
    *.env|*secrets*|*credentials*|*id_rsa*|*id_ed25519*)
      exit 0
      ;;
    */MVV.md)
      exit 0
      ;;
  esac

  # それ以外は自動承認
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow"
    }
  }'
  exit 0
fi

# --- Read: 機密ファイル以外を自動承認 ---
if [ "$TOOL_NAME" = "Read" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

  if [ -z "$FILE_PATH" ]; then
    exit 0
  fi

  case "$FILE_PATH" in
    *.env|*secrets*|*credentials*|*key*|*token*|*id_rsa*|*id_ed25519*)
      exit 0
      ;;
  esac

  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow"
    }
  }'
  exit 0
fi

# --- Glob / Grep: 常に自動承認 ---
if [ "$TOOL_NAME" = "Glob" ] || [ "$TOOL_NAME" = "Grep" ]; then
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "allow"
    }
  }'
  exit 0
fi

# --- Bash: 安全なコマンドのみ自動承認 ---

# 単一コマンドセグメントの安全性を判定する関数
# 戻り値: 0=安全, 1=安全でない
is_safe_segment() {
  local segment="$1"

  # 前後の空白を除去
  segment=$(echo "$segment" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$segment" ]; then
    return 0
  fi

  # 環境変数プレフィックス・ラッパーコマンドを除去して正規化
  local normalized="$segment"
  while [[ "$normalized" =~ ^[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]](.+)$ ]]; do
    normalized="${BASH_REMATCH[1]}"
  done
  normalized="${normalized#env }"
  normalized="${normalized#command }"

  # ベースコマンドを抽出
  local base_cmd
  base_cmd=$(echo "$normalized" | awk '{print $1}')
  base_cmd=$(basename "$base_cmd")

  # 危険なコマンドは承認しない
  case "$base_cmd" in
    rm|sudo|kill|killall|pkill|reboot|shutdown|dd|mkfs|fdisk)
      return 1
      ;;
  esac

  # 危険なフラグを検出
  if echo "$normalized" | grep -qE '(--force|--hard|-rf|-fr|--no-verify|--delete|--rsh)'; then
    return 1
  fi

  # bash はファイル実行（bash *.sh）のみ許可。-c による任意コード実行はブロック
  if [ "$base_cmd" = "bash" ]; then
    # 複合オプション（-xc, -vc 等）も検出するため -[a-zA-Z]*[cs] にマッチ
    if echo "$normalized" | grep -qE '(^|[[:space:]])-[a-zA-Z]*[cs]'; then
      return 1
    fi
    return 0
  fi

  # 安全なコマンドリスト（任意実行・外部通信不可のコマンドのみ）
  case "$base_cmd" in
    cd|ls|pwd|cat|head|tail|echo|printf|test|true|false|\
    grep|find|awk|sed|sort|uniq|wc|cut|tr|tee|diff|comm|rev|paste|jq|\
    git|gh|cr|coderabbit|shellcheck|\
    basename|dirname|realpath|readlink|stat|file|which|type|id|whoami|hostname|\
    mkdir|cp|mv|touch|chmod|mktemp|rmdir|\
    source|export|set|shopt|for|while|do|done|xargs|\
    npm|npx|\
    rsync|tar|zip|unzip|tree|\
    date|sleep)
      return 0
      ;;
  esac

  # リストにないコマンドは安全でない
  return 1
}

if [ "$TOOL_NAME" = "Bash" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  if [ -z "$COMMAND" ]; then
    exit 0
  fi

  # サブシェル/コマンド置換を含むコマンドは通常フローに委ねる
  if echo "$COMMAND" | grep -qE '\$\(|`'; then
    exit 0
  fi

  # パイプ (|) や OR (||) を含むコマンドは通常フローに委ねる
  if echo "$COMMAND" | grep -qE '\|'; then
    exit 0
  fi

  # && や ; で連結されたコマンドを各セグメントに分割し、全セグメントを検証
  # quote（'...' や "..."）内の ; / && は区切り文字として扱わない。
  # 単純な文字列 split（sed 's/;/\n/g'）だと awk '{print; exit}' のような quote 内の ; を
  # 誤って segment 境界と認識してしまうため、quote 状態を追跡しながら分割する。
  all_safe=true
  while IFS= read -r segment; do
    if ! is_safe_segment "$segment"; then
      all_safe=false
      break
    fi
  done < <(echo "$COMMAND" | awk '
    BEGIN { sq = "\047"; dq = "\042" }
    {
      s = $0
      out = ""
      in_single = 0
      in_double = 0
      i = 1
      len = length(s)
      while (i <= len) {
        c = substr(s, i, 1)
        if (!in_double && c == sq) {
          in_single = !in_single
          out = out c
          i++
          continue
        }
        if (!in_single && c == dq) {
          in_double = !in_double
          out = out c
          i++
          continue
        }
        if (!in_single && !in_double && c == ";") {
          out = out "\n"
          i++
          continue
        }
        if (!in_single && !in_double && c == "&" && substr(s, i+1, 1) == "&") {
          out = out "\n"
          i += 2
          continue
        }
        out = out c
        i++
      }
      print out
    }
  ')

  if [ "$all_safe" = true ]; then
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "allow"
      }
    }'
    exit 0
  fi

  # 安全でないセグメントがある場合は通常フローに委ねる
  exit 0
fi

# その他のツールは通常フローに委ねる
exit 0
