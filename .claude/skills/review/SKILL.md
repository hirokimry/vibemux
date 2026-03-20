---
name: review
description: "実装レビューを実行する。CodeRabbit CLI とカスタムレビュアーを並列で呼び出す。ユーザーが「/review」「レビューして」と言った時に使用。"
---

**ultrathink**
変更差分をレビューします。以下の手順で実行してください。

## 1. 変更ファイルの確認

**各コマンドは個別に実行すること。`&&` で連結しない。**

```bash
git diff --name-only HEAD
```

```bash
git diff --name-only --cached
```

## 2. レビュー実行

### CodeRabbit CLI（常に実行）

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

## 3. 結果報告

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
