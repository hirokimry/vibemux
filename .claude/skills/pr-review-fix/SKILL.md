---
name: pr-review-fix
description: "PRの未解決コメントを1回修正してpushする。定期実行は /pr-review-loop を使う。「/pr-review-fix」「コメント直して」と言った時に使用。"
---

# PRレビュー修正（単発）

PRの現在の状態を確認し、未解決コメントがあれば修正してpushする。
1回の実行で現在の指摘を処理して終了する。

## 使用方法

```bash
/pr-review-fix                    # 現在のブランチのPRを自動検出
/pr-review-fix <PR URL>           # PR URLを直接指定
/pr-review-fix --worktree <path>  # worktree 内で実行
```

## worktree モード

`--worktree <path>` が指定された場合、全操作を指定パス内で実行する。

- **Bash**: 全コマンドを `cd <path> && command` で実行する
- **Read/Write/Edit**: `<path>/` を基準とした絶対パスを使用する
- **サブスキル呼び出し**: `--worktree <path>` を引き継ぐ
- 未指定時は従来通り CWD で実行する（後方互換）
- **`$CLAUDE_PROJECT_DIR`**: worktree モードでは `<path>` に置き換える

## 前提条件

- PRが既に作成されていること（未作成なら `/pr` を先に実行すること）
- 現在のブランチがPRのheadブランチであること

## ワークフロー

### 1. PR情報を取得

**PR URLが指定された場合**: URLからowner/repo/PR番号を抽出する。

**PR URLが未指定の場合**: 現在のブランチから自動検出する:

```bash
gh pr view --json number,url,headRefName,baseRefName,state --jq '{number, url, headRefName, baseRefName, state}'
```

PRが見つからない場合はエラー。

### 2. マージ済みチェック

```bash
gh pr view {pr_number} --json state --jq '.state'
```

- `MERGED` → 「PR #{pr_number} はマージ済みです」と報告して**正常終了**
- `CLOSED` → 「PR #{pr_number} はクローズされています」と報告して**正常終了**
- `OPEN` → ステップ3へ

### 3. CodeRabbit 有効性の確認

```bash
awk '/^coderabbit:/{found=1; next} found && /^[^ ]/{exit} found && /enabled:/{print $2}' \
  "$CLAUDE_PROJECT_DIR"/.claude/vibecorp.yml
```

- 結果が `false` → **CodeRabbit 無効。ステップ7（auto-merge確認）へ直接進む**
- 結果が `true` または空（未定義）→ CodeRabbit 有効。ステップ4へ

### 4. rate limit チェック

```bash
gh api repos/{owner}/{repo}/issues/{pr_number}/comments \
  --paginate \
  --jq '[.[] | select(.user.login | test("coderabbit"; "i")) | select(.body | test("[Rr]ate limit"))] | length'
```

1以上なら「CodeRabbit が rate limit 中のため停止しています。rate limit 解除後に再実行してください」と報告して**停止する**。

### 5. 未解決スレッドの取得

GraphQL API で未解決の CodeRabbit レビュースレッドを取得する:

```bash
gh api graphql -f query='
  query {
    repository(owner: "{owner}", name: "{repo}") {
      pullRequest(number: {pr_number}) {
        reviewThreads(first: 100) {
          nodes {
            isResolved
            id
            comments(first: 10) {
              nodes {
                id
                databaseId
                author { login }
                body
                path
                line
              }
            }
          }
        }
      }
    }
  }' \
  --jq '.data.repository.pullRequest.reviewThreads.nodes
    | [.[] | select(.isResolved == false)
    | select(.comments.nodes[0].author.login | test("coderabbit"; "i"))]'
```

- `isResolved == false` かつ先頭コメントが CodeRabbit のスレッドのみ抽出
- 各スレッドの `id`（thread node ID）は却下時の resolve mutation で使用する

**未解決0件 → 「未解決コメントなし」と報告して正常終了。**
**未解決あり → ステップ6へ。**

### 6. 指摘の修正

#### 6.1 妥当性検証

`.claude/rules/review-criteria.md` の判定基準に従い、指摘を分類する。
設計方針に関わる大きな変更はユーザーに確認する。

#### 6.2 修正計画

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

#### 6.3 修正実行

修正計画に従ってコードを修正する。

- **計画に記載された範囲のみを変更する**
- 修正後、関連するテスト・lint を実行して通過を確認する

#### 6.4 却下した指摘に返信・resolve

**修正した指摘**: 返信不要。次のステップ（6.5）の push 時に CodeRabbit の auto-resolve で自動的に resolved になる。

**却下した指摘**: 却下理由を返信した後、GraphQL mutation でスレッドを resolve する。

却下理由の返信:

```bash
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  -X POST \
  -f body="{却下理由の markdown}" \
  -F in_reply_to={comment_database_id}
```

- `{comment_database_id}` はステップ5で取得した先頭コメントの `databaseId`（REST API 整数ID）

返信後、即座にスレッドを resolve する:

```bash
gh api graphql -f query='
  mutation {
    resolveReviewThread(input: { threadId: "{thread_node_id}" }) {
      thread { isResolved }
    }
  }'
```

- `{thread_node_id}` はステップ5で取得した各スレッドの `id` フィールド（例: `PRRT_xxx`）
- 返信 → resolve の順序で実行する（resolve 済みスレッドには CodeRabbit は再反応しない）

#### 6.5 コミット・push

`/commit` を使用してコミットし（worktree モードでは `--worktree <path>` を引き継ぐ）、リモートに push する:

```bash
git push
```

### 7. 結果報告

```text
## /pr-review-fix 完了

- PR: #{pr_number}
- 修正: {n}件
- 却下: {n}件
```

**マージ済みの場合:**

```text
## /pr-review-fix 完了

- PR: #{pr_number}
- 状態: マージ済み
```

**未解決コメントなしの場合:**

```text
## /pr-review-fix 完了

- PR: #{pr_number}
- 未解決コメント: なし
```

## 制約

- `--force`、`--hard`、`--no-verify` は使用しない
- ユーザーの明示的な指示なしに force push しない
- 判断に迷う指摘はユーザーに確認する
- 修正前に必ず関連ファイルを読み込む
- **`@coderabbitai approve` の投稿は禁止** — approve は CodeRabbit が自動発行するか、人間が手動で行う
- **jq では string interpolation `\(...)` を使わない** — 必ず `+` で結合する（[根拠](docs/design-philosophy.md#jq-string-interpolation-の禁止)）
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）
