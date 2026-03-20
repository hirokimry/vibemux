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

以下を**並列で**実行する。

### 常に実行

- `shellcheck` を変更対象のシェルスクリプトに実行
- `security-reviewer` エージェントを起動

### 変更内容に応じて選択

- `*.md`、`docs/`、`README*` の変更がある場合: `docs-reviewer` エージェントを起動

## 3. 結果報告

全レビュー結果を統合して報告する。
