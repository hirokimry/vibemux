---
name: review
description: "コードレビューを実行する。shellcheck + security-reviewer + docs-reviewer を並列で呼び出す。ユーザーが「/review」「レビューして」と言った時に使用。"
---

変更差分をレビューします。以下の手順で実行してください。

## 1. 変更ファイルの確認

```bash
git diff --name-only HEAD
```

```bash
git diff --name-only --cached
```

## 2. レビュー実行

以下を**並列で**実行する（Agent ツールで複数エージェントを同時起動）。

### 2.1 shellcheck（常に実行）

変更対象のシェルスクリプトに対して shellcheck を実行する:

```bash
shellcheck vibemux .githooks/pre-commit .githooks/pre-push
```

変更ファイルに `*.sh` が含まれる場合はそれも対象に追加する。

### 2.2 security-reviewer エージェント（常に実行）

`.claude/agents/security-reviewer.md` に定義されたエージェントを Agent ツールで起動する。
変更差分を渡し、シークレット・脆弱性・個人情報のチェックを依頼する。

### 2.3 docs-reviewer エージェント（条件付き）

`*.md`、`docs/`、`README*` の変更がある場合のみ:
`.claude/agents/docs-reviewer.md` に定義されたエージェントを Agent ツールで起動する。
ドキュメントとコードの整合性チェックを依頼する。

## 3. 結果報告

全レビュー結果を統合して報告する。
