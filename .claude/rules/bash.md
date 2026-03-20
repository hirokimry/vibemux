---
globs: ["vibemux", "**/*.sh", ".githooks/*"]
---

# Bash コーディングルール

- `set -euo pipefail` をスクリプト先頭に記述すること
- すべてのスクリプトは `shellcheck` を通過すること
- 変数展開はダブルクォートで囲む: `"$var"` not `$var`
- 環境変数のプレフィックスは `VIBEMUX_`
- `local` で関数内変数を宣言する
- コマンド置換は `$()` を使う（バッククォート禁止）
