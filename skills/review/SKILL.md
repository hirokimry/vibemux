---
name: review
description: "実装レビューを実行する。CodeRabbit CLI とカスタムレビュアーを並列で呼び出す。ユーザーが「/review」「レビューして」と言った時に使用。"
---

**ultrathink**
変更差分をレビューします。以下の手順で実行してください。

## worktree モード

`--worktree <path>` が指定された場合、全操作を指定パス内で実行する。

- **Bash**: 全コマンドを `cd <path> && command` で実行する
- **Read/Write/Edit**: `<path>/` を基準とした絶対パスを使用する
- **サブスキル呼び出し**: `--worktree <path>` を引き継ぐ
- 未指定時は従来通り CWD で実行する（後方互換）
- **`$CLAUDE_PROJECT_DIR`**: worktree モードでは `<path>` に置き換える

## 1. 変更ファイルの確認

**各コマンドは個別に実行すること。`&&` で連結しない。**

```bash
git diff --name-only HEAD
```

```bash
git diff --name-only --cached
```

## 2. レビュー実行

### CodeRabbit CLI

**まず `vibecorp.yml` の `coderabbit.enabled` を確認する:**

```bash
awk '/^coderabbit:/{found=1; next} found && /^[^ ]/{exit} found && /enabled:/{print $2}' \
  "$CLAUDE_PROJECT_DIR"/.claude/vibecorp.yml
```

- 結果が `false` → **CodeRabbit CLI セクション全体をスキップ**し、レポートに「CodeRabbit: 無効（vibecorp.yml で coderabbit.enabled: false）」と記載する
- 結果が `true` または空（未定義）→ 以下を実行

```bash
cr review --plain
```

`cr` が利用できない場合はスキップし、レポートにその旨を記載する。

### カスタムレビュアー

`.claude/vibecorp.yml` の `review.custom_commands` を確認する。定義がある場合、各コマンドを並列で実行する:

```yaml
review:
  custom_commands:
    - name: shellcheck
      command: "shellcheck **/*.sh"
```

各カスタムコマンドを実行し、結果を収集する。

## 3. レビュー完了スタンプの生成

レビューが完了したら、PR 作成を許可するスタンプを生成する。スタンプは `~/.cache/vibecorp/state/<repo-id>/` 配下に作成される（`.claude/` 配下への書込確認プロンプトを回避）。

```bash
. "$CLAUDE_PROJECT_DIR/.claude/lib/common.sh"
STAMP_DIR="$(vibecorp_stamp_mkdir)"
touch "${STAMP_DIR}/review-ok"
```

worktree モードの場合:

```bash
. "<path>/.claude/lib/common.sh"
STAMP_DIR="$(vibecorp_stamp_mkdir)"
touch "${STAMP_DIR}/review-ok"
```

## 4. 結果報告

全レビュー結果を統合して報告する:

```text
## レビュー結果

### CodeRabbit
- {指摘サマリ}

### {カスタムレビュアー名}
- {指摘サマリ}

### サマリ
- 指摘総数: {件数}
- 重大: {件数}
- 提案: {件数}
```
