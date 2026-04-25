---
name: sync-edit
description: >
  /sync-check で検出された不整合を、各職種エージェントに委任して修正する。
  各エージェントは自分の管轄ファイルのみ編集する。
  「/sync-edit」と言った時に使用。
---

# sync-edit: 整合性修正（各職種が管轄のみ編集）

`/vibecorp:sync-check` で検出された不整合を、**各職種エージェントに委任して** 修正する。
各エージェントは **自分の管轄ファイルだけ** を編集する。

## 前提条件

- `/vibecorp:sync-check` が先に実行されていること
- sync-check の結果に ⚠️ または ❌ が含まれていること

## ワークフロー

### 1. sync-check 結果の確認

直前の `/vibecorp:sync-check` の結果を参照し、修正が必要なファイルと担当エージェントを特定する。

### 2. 担当エージェントの起動

修正が必要な管轄を持つエージェントを **Agent ツールで順次起動** する（ロールファイルの競合防止）。

#### エージェントと管轄の対応

**デフォルト（CTO / CPO）:**

| エージェント | 管轄ファイル | 編集権限 |
|-------------|------------|---------|
| CTO | `docs/specification.md`（技術スタック部分）、`.claude/rules/`、`.claude/knowledge/cto/` | 管轄のみ |
| CPO | `docs/specification.md`（プロダクト仕様部分）、`.claude/knowledge/cpo/` | 管轄のみ |

**拡張時（上記に加えて追加可能）:**

| エージェント | 管轄ファイル | 編集権限 |
|-------------|------------|---------|
| 法務 | `docs/POLICY.md`、`.claude/knowledge/legal/` | 管轄のみ |
| 経理 | `docs/cost-analysis.md`、`.claude/knowledge/accounting/` | 管轄のみ |
| SM | `docs/ai-organization.md`、`.claude/knowledge/sm/` | 管轄のみ |

**knowledge/ の記事** は、内容の領域に応じて該当する職種エージェントが編集する。

#### 起動方法

各エージェントに以下を渡して Agent ツールで起動する。
**重要**: 各エージェントは hooks による権限チェックを受けるため、ロール宣言が必須。

```text
あなたは {役職名} として、管轄ドキュメントの不整合を修正してください。

## 最初にやること（必須）
以下のコマンドを実行してロールを宣言してください。これにより管轄ファイルの編集権限が付与されます。

source "$CLAUDE_PROJECT_DIR"/.claude/lib/common.sh
stamp_dir="$(vibecorp_state_mkdir)"
echo "{role_id}" > "${stamp_dir}/agent-role"

role_id: cto / cpo / legal / accounting / sm

## あなたの管轄ファイル
{管轄ファイルリスト}

## コード変更の差分
{git diff の内容}

## sync-check で検出された問題
{該当エージェントのチェック結果}

## 制約
- 管轄ファイルのみ編集すること。管轄外は hooks によりブロックされる
- コード変更の内容をドキュメントに正確に反映する
- 既存の記述スタイル・フォーマットを維持する
- 過剰な加筆をしない。変更に関連する部分だけ更新する

## 終了時（必須）
編集完了後、ロールファイルを削除してください。

source "$CLAUDE_PROJECT_DIR"/.claude/lib/common.sh
rm -f "$(vibecorp_state_path agent-role)"

## 出力
- 編集したファイルと変更内容の要約
```

**注意**: エージェントは順次起動すること（並列だとロールファイルが競合する）。

### 3. 結果の統合・レポート出力

全エージェントの修正結果を統合し、以下のフォーマットで出力する:

```text
## sync-edit 結果

### 修正内容

#### CTO（技術設計）
- docs/design-philosophy.md: {変更の要約}
- .claude/knowledge/cto/decisions.md: {変更の要約}

#### CPO（プロダクト）
- docs/specification.md: {変更の要約}

#### 法務（拡張時のみ）
- docs/POLICY.md: {変更の要約}

### 次のステップ
→ `/vibecorp:sync-check` を再実行して整合性を確認してください
```

### 4. 再チェックの案内

修正完了後、必ず `/vibecorp:sync-check` の再実行を案内する。
sync-edit 自身はスタンプを発行しない（スタンプは sync-check のみが発行する）。

## 制約

- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）
