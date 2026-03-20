---
name: pr-review-fix
description: "PRレビュー指摘の修正と返信を自動化。CodeRabbitのレビューコメントを取得し、指摘内容を分析・修正、コミット作成・push後、各コメントに修正コミットへのリンクを返信する。ユーザーが「/pr-review-fix」「レビュー対応して」と言った時に使用。"
---

# PRレビュー指摘修正

PRのレビューコメントを取得し、指摘を修正してコメントに返信する。

## 使用方法

```bash
/pr-review-fix                    # 現在のブランチからPRを自動検出
/pr-review-fix <PR URL>           # PR URLを直接指定
```

## ワークフロー

### 1. PR情報を取得

**PR URLが指定された場合**: URLからowner/repo/PR番号を抽出する。

**PR URLが未指定の場合**: 現在のブランチから自動検出する:

```bash
gh pr view --json number,url,headRefName --jq '.number'
```

PRが見つからない場合はエラー。

取得したPR情報からレビューコメントを取得:

```bash
# PRレビューコメントを取得
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --paginate \
  --jq '.[] | select(.user.login | test("coderabbit"; "i")) | select(.in_reply_to_id == null) | {id: .id, path: .path, line: .line, body: .body, user: .user.login}'
```

```bash
# PR全体のレビューも取得
gh pr view {pr_number} --repo {owner}/{repo} --json reviews,comments
```

### 2. 妥当性検証

`.claude/rules/review-criteria.md` の判定基準に従い、指摘を分類する。
設計方針に関わる大きな変更はユーザーに確認する。

### 3. 修正計画

要修正リストに対して、各指摘の具体的な修正計画を策定する。**このステップではコードの変更は行わない。**

手順:
1. 指摘箇所の実コードと周辺コードを読む
2. 既存の類似実装パターンを確認する
3. 修正による影響範囲を特定する
4. 具体的な修正手順を策定する

各指摘について以下を明記する:

- **修正内容**: 何をどう変更するか
- **影響範囲**: 変更が影響する他のファイル・テスト
- **注意点**: 修正時に気をつけるべきこと

### 4. 修正実行

修正計画に従ってコードを修正する。

- **計画に記載された範囲のみを変更する**
- 修正後、関連するテスト・lint を実行して通過を確認する

各修正について以下を記録する:

- **修正内容**: どのファイルの何を変更したか
- **テスト結果**: 関連するテスト・lint の PASS/FAIL

### 5. コミットを作成

`/commit` を使用してコミットする。

### 6. リモートにpush

コメント返信前に、修正をリモートにpushする:

```bash
git push
```

### 7. 各コメントに返信

まず `git rev-parse HEAD` でコミットSHAを取得する:

```bash
git rev-parse HEAD
```

各コメントに対して、以下の内容で返信する:

- **修正した指摘**: コミットリンク + markdown での可読性の高い修正内容の説明
- **却下した指摘**: markdown での可読性の高い却下理由の説明（判定基準に基づく根拠を含める）

返信コマンド（SHAを直接埋め込む）:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -X POST \
  -f body="{markdown}" \
  -F in_reply_to={comment_id}
```

**重要**: `${COMMIT_SHA}` 等の変数展開は使わない。SHAは事前に取得し、コマンド文字列に直接埋め込むこと。

### 8. 結果報告

修正内容とコメント返信の結果をユーザーに報告:

| ファイル | コメントID | 対応 |
|---------|-----------|------|
| example.ts | 123456 | 修正済み・返信完了 |
| example.ts | 234567 | 却下・理由 |

## 制約

- `--force`、`--hard`、`--no-verify` は使用しない
- 判断に迷う指摘はユーザーに確認する
- 修正前に必ず関連ファイルを読み込む
- **コメント返信には必ずコミットリンクを含める**
