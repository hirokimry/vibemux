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

- PRが既に作成されていること（未作成なら `/pr` を先に実行すること）
- 現在のブランチがPRのheadブランチであること

## 終了条件

以下の **両方** を満たしたらマージに進む:
1. CI が全てパスしている
2. CodeRabbit の未解決コメントが0件

終了条件を満たすまでループを回し続ける。上限はない。

## ワークフロー

### 1. PR情報を取得

```bash
gh pr view --json number,url,headRefName,baseRefName --jq '{number, url, headRefName, baseRefName}'
```

### 2. ループ開始

以下を終了条件を満たすまで繰り返す。

#### 2.1 CodeRabbitレビュー待ち

CodeRabbitがレビューを完了するまで待機する。最大10分。

```bash
# 30秒間隔でレビューコメントをポーリング
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | select(.user.login | test("coderabbit"; "i"))] | length'
```

**判定ロジック**:
- コメント数が0 → 30秒待って再確認（CodeRabbitがまだ処理中）
- コメント数が安定（2回連続同数） → レビュー完了と判断
- 10分経過 → タイムアウト。現状のコメントで進める

#### 2.2 CI 状態の確認

```bash
# CI の完了を待つ（PENDING の間はポーリング）
gh pr checks {pr_number} --watch --fail-fast
```

`--watch` が使えない場合のフォールバック:

```bash
# 30秒間隔でポーリング
gh pr checks {pr_number} --json name,state,conclusion \
  --jq '.[] | select(.conclusion != "") | {name, state, conclusion}'
```

**判定ロジック**:
- 全チェックの `state` が `COMPLETED` かつ `conclusion` が `SUCCESS` → CI パス
- いずれかの `conclusion` が `FAILURE` → CI失敗。ユーザーに報告して停止
- `state` が `PENDING` または `IN_PROGRESS` → 30秒待って再確認

#### 2.3 終了条件の判定

**未解決コメントの判定**: CodeRabbit の指摘（`in_reply_to_id == null`）のうち、返信がないものを未解決とみなす。

```bash
# CodeRabbitの指摘ID一覧
CR_IDS=$(gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | select(.user.login | test("coderabbit"; "i")) | select(.in_reply_to_id == null) | .id]')

# 返信済みID一覧
REPLY_TO_IDS=$(gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | select(.in_reply_to_id != null) | .in_reply_to_id] | unique')

# 未返信の指摘を抽出
UNRESOLVED=$(echo "$CR_IDS" | jq --argjson replied "$REPLY_TO_IDS" \
  '[.[] | select(. as $id | $replied | index($id) | not)]')
UNRESOLVED_COUNT=$(echo "$UNRESOLVED" | jq 'length')
```

**判定**:
- CI パス (`conclusion` が全て `SUCCESS`) + `UNRESOLVED_COUNT` が 0 → **ループ終了、規約反映へ**
- CI パスだが未解決コメントあり → 2.4 へ
- CI 未完了 → 2.2 に戻って待機

#### 2.4 レビュー指摘の修正

未解決コメントがある場合、`/pr-review-fix` を実行する。
修正後 push し、ループ先頭（2.1）に戻る。

### 3. レビュー指摘の規約・ナレッジ反映

終了条件達成後、マージ前に `/review-to-rules` を実行する。
修正した指摘から規約化すべき内容を判断し、rules/ / knowledge/ に反映する。

反映の有無は `git status --porcelain` でファイル変更を検出する。

```bash
# /review-to-rules 実行後
if [ -n "$(git status --porcelain)" ]; then
  # 変更あり → コミット → push → ループ先頭（2.1）に戻る
  # （push後にCIとCodeRabbitが再度走るため）
  git add .claude/rules/ .claude/knowledge/
  git commit -m "chore: reflect review findings to rules and knowledge"
  git push
else
  # 変更なし → マージへ進む
fi
```

### 4. マージ

終了条件を満たしたらスカッシュマージする:

```bash
gh pr merge {pr_number} --squash --delete-branch
```

### 5. ローカルブランチの切り替え

```bash
git checkout {baseRefName} && git pull
```

`{baseRefName}` はステップ1で取得した値を使用する。

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
| CodeRabbitレビュータイムアウト | コメント0件ならそのまま進行、あれば現状で修正 |
| CI失敗 | 失敗内容を報告してユーザーに判断を委ねる |
| マージコンフリクト | ユーザーに報告して停止 |

## 注意事項

- `--force`、`--hard`、`--no-verify`は使用しない
- マージ先は PRの baseRefName（通常 main）
- ユーザーの明示的な指示なしに force push しない
