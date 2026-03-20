---
name: pr-merge-loop
description: "PR作成後、CodeRabbitレビュー待ち→指摘修正→CI待ち→マージまでを全自動で行う。「/pr-merge-loop」「PRマージまでやって」と言った時に使用。"
---

# PR自動マージループ

PR作成後、「CI パス + 未解決コメント0件」になるまでレビュー修正を繰り返し、達成したらマージする。

## 使用方法

```bash
/pr-merge-loop                    # 現在のブランチのPRを自動検出
/pr-merge-loop <PR URL>           # PR URLを直接指定
```

## 前提条件

- PRが既に作成されていること
- 現在のブランチがPRのheadブランチであること

## ワークフロー

### 1. PR情報を取得

```bash
gh pr view --json number,url,headRefName,baseRefName --jq '{number, url, headRefName, baseRefName}'
```

### 2. ループ開始

以下を終了条件を満たすまで繰り返す。

#### 2.1 CodeRabbitレビュー待ち

最大10分、30秒間隔でポーリング。コメント数が安定したらレビュー完了と判断。

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | select(.user.login | test("coderabbit"; "i"))] | length'
```

#### 2.2 CI 状態の確認

```bash
gh pr checks {pr_number} --json name,state --jq '.[] | {name, state}'
```

#### 2.3 終了条件の判定

- CI パス + 未解決コメント0件 → **ループ終了、規約反映へ**
- それ以外 → 2.4 へ

#### 2.4 レビュー指摘の修正

`/pr-review-fix` を実行。修正後 push し、ループ先頭に戻る。

### 3. レビュー指摘の規約・ナレッジ反映

マージ前に `/review-to-rules` を実行する。

変更があればコミット → push → ループ先頭に戻る。
変更なければマージへ。

### 4. マージ

```bash
gh pr merge {pr_number} --squash --delete-branch
```

### 5. ローカルブランチの切り替え

```bash
git checkout main && git pull
```

### 6. 結果報告

```text
## PR自動マージ完了

- PR: #{pr_number}
- レビュー修正: {n}回
- CI: パス
- マージ: 完了
```

## エラー時の挙動

| 状況 | 対応 |
|------|------|
| CodeRabbitタイムアウト | コメント0件ならそのまま進行 |
| CI失敗 | ユーザーに報告して停止 |
| マージコンフリクト | ユーザーに報告して停止 |

## 注意事項

- `--force`、`--hard`、`--no-verify`は使用しない
- マージ先はPRの baseRefName
