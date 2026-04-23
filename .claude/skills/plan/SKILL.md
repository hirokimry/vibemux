---
name: plan
description: |
  実装計画作成のガイダンスを提供するスキル。plan modeでの計画策定、EnterPlanMode使用時、
  「実装計画を立てて」「計画を作成」「プランニング」と言われた時、またはGitHub Issueの
  実装方針を決める時に自動的に使用する。計画を ~/.cache/vibecorp/plans/<repo-id>/ ディレクトリに出力する（Claude Code の .claude/ 書込確認プロンプトを回避するため）。
---

# 実装計画作成ガイド

Issue の実装方針を策定し、計画ファイルとして出力する。
**結果のみを簡潔に返すこと。途中経過は不要。**

## 使用方法

```bash
/plan                     # 現在のブランチのIssueから計画を作成
/plan <Issue URL>         # Issue URLを指定して計画を作成
```

## 出力先

```text
~/.cache/vibecorp/plans/<repo-id>/{branch_name}.md
```

ブランチ名は `git branch --show-current` で取得。パスは `vibecorp_plans_mkdir` で取得:

```bash
source "$CLAUDE_PROJECT_DIR"/.claude/lib/common.sh
plans_dir="$(vibecorp_plans_mkdir)"
plan_file="${plans_dir}/$(git branch --show-current).md"
```

計画ファイルを `.claude/` 配下ではなく `~/.cache/vibecorp/plans/<repo-id>/` に配置する理由:
- `.claude/` への書込は Claude Code が毎回「書込確認プロンプト」を出すため、ヘッドレス/teammate 環境で停止する（Issue #334, #369）
- XDG Base Directory 準拠で実ホーム外に配置すれば書込確認プロンプトを回避できる
- `<repo-id>` により worktree ごとに分離される

## ワークフロー

### 1. Issue 情報の取得

ブランチ名から Issue 番号を抽出（例: `dev/67_ship` → #67）し、Issue 本文を取得する。

```bash
gh issue view <番号> --json title,body --jq '.title + "\n" + .body'
```

Issue URL が引数で渡された場合はそれを使用する。

### 2. プロジェクト設定の確認

プロジェクト固有の設計ガイドがあれば参照する。

```bash
if [ -d .claude/planning-guides/ ]; then
  ls .claude/planning-guides/
fi
```

ガイドが存在すれば関連するもののみ読み込む。

### 3. コードベースの調査

Issue の内容に基づき、変更が必要な箇所を調査する:

- 関連ファイルの特定
- 既存の実装パターンの把握
- 影響範囲の確認

### 4. 計画の策定

以下の原則に従って計画を策定する:

1. **独立性**: タスクは可能な限り並行実行できるよう分解
2. **テスト込み**: 各タスクにテストを含め、成功確認を完了条件に
3. **段階的**: 基盤 → 実装 → 統合 の流れを意識

### 5. 計画ファイルの出力

以下のテンプレートで `${plans_dir}/{branch_name}.md`（`~/.cache/vibecorp/plans/<repo-id>/{branch_name}.md`）に書き出す:

```markdown
# {タイトル}

Issue: #{issue_number}
Branch: {branch_name}
作成日: {date}

## 概要

{何を実装するか — Issue の要約}

## 影響範囲

{変更が必要なファイル・モジュールの一覧}

## 実装計画

### Phase 1: {フェーズ名}

- [ ] タスク1
  - 対象: {ファイルパス}
  - 内容: {具体的な変更内容}
- [ ] タスク2

### Phase 2: {フェーズ名}

- [ ] タスク3
- [ ] タスク4

## テスト計画

- [ ] {テスト項目1}
- [ ] {テスト項目2}

## 懸念事項

- {あれば記載}
```

### 6. Issue 本文の更新

計画の「概要」「実装計画」セクションを Issue 本文の設計セクションに反映する。

```bash
gh issue edit <番号> --body "<更新後の本文>"
```

## 制約

- 計画は `~/.cache/vibecorp/plans/<repo-id>/` ディレクトリに出力する（`vibecorp_plans_mkdir` 経由）
- Issue 本文の更新は設計セクションのみ。既存の💡概要、🎯背景等は保持する
- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）

## 返却フォーマット

```text
~/.cache/vibecorp/plans/<repo-id>/{branch_name}.md
```
