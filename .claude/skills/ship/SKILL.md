---
name: ship
description: "Issue URLを指定するだけでブランチ作成からPR作成・auto-merge設定までを全自動で実行する。「/ship」「シップして」「Issue対応して」と言った時に使用。"
---

**ultrathink**

# Issue → PR 全自動スキル

GitHub Issue URL を受け取り、ブランチ作成 → 計画 → レビュー → 実装 → PR → auto-merge 設定までを一気通貫で実行する。マージは auto-merge により GitHub が自動実行する。

## 使用方法

```bash
/ship <Issue URL>
/ship <Issue URL> --worktree <path>
```

## worktree モード

`--worktree <path>` が指定された場合、全操作を指定パス内で実行する。

- **Bash**: 全コマンドを `cd <path> && command` で実行する
- **Read/Write/Edit**: `<path>/` を基準とした絶対パスを使用する
- **サブスキル呼び出し**: `--worktree <path>` を引き継ぐ
- 未指定時は従来通り CWD で実行する（後方互換）

## 前提条件

- 現在のブランチが main（またはベースブランチ）であること（worktree モードでは不要）
- GitHub CLI (`gh`) が認証済みであること

## ワークフロー

### 1. ブランチ作成

現在のブランチが `dev/` プレフィックスで始まる場合、ブランチ作成をスキップする（Agent worktree 等で既にブランチが作成済みのケース）。

**worktree モード**: worktree のブランチを `dev/{Issue番号}_{要約}` にリネームする。

```bash
cd <path> && git branch -m <現在のブランチ名> dev/{番号}_{要約}
```

**通常モード**: Issue URL から `dev/{Issue番号}_{要約}` 形式のブランチを作成する。

```bash
gh issue view <Issue URL> --json number,title --jq '.number,.title'
```

タイトルを英語スネークケース2〜4語に要約し、ブランチを作成・チェックアウトする。

```bash
git checkout -b dev/{番号}_{要約}
```

### 2. 実装計画の策定

Issue の本文・完了条件を読み込み、コードベースを調査して実装計画を作成する。

計画は以下に出力する:

```text
.claude/plans/{branch_name}.md
```

計画には以下を含める:
- 概要（Issue の要約）
- 影響範囲（変更が必要なファイル・モジュール）
- Phase 分けされたタスク一覧（各タスクにテスト項目を含む）
- 懸念事項

### 3. 計画レビュー・修正ループ

`/plan-review-loop` を実行する（worktree モードでは `--worktree <path>` を引き継ぐ）。

計画ファイルに対して以下のレビュー観点で評価し、問題0件になるまで修正を繰り返す（最大5回）。

**レビュー観点:**
- 網羅性（Issue の完了条件が全て計画に反映されているか）
- 実現可能性（参照しているファイル・関数が実在するか）
- 独立性（タスクが並行実行可能な粒度に分解されているか）
- テスト（各タスクにテスト項目が含まれているか）
- 影響範囲（変更による副作用が考慮されているか）
- 既存パターンとの整合（プロジェクトの規約と矛盾しないか）

### 4. Issue 本文の更新

計画の設計内容で Issue 本文を更新する。既存の💡概要、🎯背景等のセクションは保持し、設計セクションを追加・更新する。

```bash
gh issue edit <番号> --body "<更新後の本文>"
```

### 5. 実装

計画の Phase に従って順にコーディングを行う。

- 各タスクの完了後にテストを実行して通過を確認する
- テストが失敗した場合はその場で修正する
- 全タスク完了後、全体テストを実行する

### 6. コミット

`/commit` で変更をコミットする（worktree モードでは `--worktree <path>` を引き継ぐ）。

- ステージング対象は実装で変更したファイル + 計画ファイル
- Conventional Commits 形式
- Issue 番号をコミットメッセージに含める

### 7. レビュー・修正ループ

`/review-loop` を実行する（worktree モードでは `--worktree <path>` を引き継ぐ）。

コード変更に対してレビュー→修正を繰り返し、問題0件にする（最大5回）。

レビュー指摘を妥当性検証し、修正すべき指摘のみ修正する。修正後はコミットする。

### 8. PR 作成

**worktree モード:**

```bash
cd <path> && git push origin HEAD
cd <path> && gh pr create --title "<Issueタイトル>" --body "<PR本文>" --base <ベースブランチ>
```

**通常モード:**

```bash
git push origin HEAD
gh pr create --title "<Issueタイトル>" --body "<PR本文>" --base <ベースブランチ>
```

**auto-merge の有効化:**

```bash
gh pr merge --squash --auto
```

- PR タイトルは Issue タイトルをそのまま使用
- PR 本文に `close <Issue URL>` を含める
- PR テンプレートがあればそれに従う

### 9. レビュー修正ループ

`/pr-review-loop` を実行する（worktree モードでは `--worktree <path>` を引き継ぐ）。

`vibecorp.yml` の `coderabbit.enabled` が `false` の場合、CodeRabbit レビュー待ちはスキップされ、CI パス確認と auto-merge 設定のみ実行される。
マージは auto-merge により、CI パス + approve 後に GitHub が自動実行する。

## 介入ポイント

以下の状況ではユーザーに報告して判断を委ねる:

| 状況 | タイミング |
|------|-----------|
| 計画レビューが5回ループしても問題が残る | ステップ3 |
| テストが繰り返し失敗する | ステップ5 |
| コードレビューが5回ループしても問題が残る | ステップ7 |
| CI が失敗する | ステップ9 |
| レビュー修正ループが上限に達する | ステップ9 |

## 結果報告

```text
## /ship 完了

- Issue: #{issue_number}
- PR: #{pr_number}
- ブランチ: dev/{番号}_{要約}
- 計画レビュー: {n}回
- コードレビュー: {n}回
- auto-merge: 設定済み
```

## 制約

- `--force`、`--hard`、`--no-verify` は使用しない
- ユーザーの明示的な指示なしに force push しない
- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）
- **Bash は 1 コマンド 1 呼び出しに分割する** — `cd ... && cmd | head 2>/dev/null` のように cd + パイプ + リダイレクトを含む compound command は Claude Code 本体の built-in security check（path resolution bypass 検出）で止められるため（参照: #258）。単純な `cd && git ...` は対象外
- 介入ポイントではユーザーの指示を待つ（自動でスキップしない）
