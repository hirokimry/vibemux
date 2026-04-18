---
name: audit-cost
description: >
  CFO による週次コスト監査。直近7日間の変更からコスト影響を分析し、
  `knowledge/accounting/audit-YYYY-MM-DD.md` に記録する。full プリセット限定。
  「/audit-cost」「コスト監査」と言った時に使用。
---

**ultrathink**

# /audit-cost: 週次コスト監査

CFO エージェントによる週次コスト監査を自動化する。直近1週間の変更からコスト影響を分析し、監査レポートを `knowledge/accounting/` に保存する。異常検出時は Issue を起票する。

## 前提条件

- **full プリセット専用**（CFO エージェントが必要）
- CFO エージェント定義（`.claude/agents/cfo.md`）が配置済み
- `knowledge/accounting/cost-audit-template.md` が存在

## ワークフロー

### 1. プリセット確認

```bash
awk '/^preset:[[:space:]]*/ { sub(/^preset:[[:space:]]*/, ""); print; exit }' .claude/vibecorp.yml
```

`full` 以外の場合は「/audit-cost は full プリセット専用です」と報告して終了する。

### 2. 監査範囲取得

直近7日間の変更を取得する:

```bash
git log --since="7 days ago" --oneline
git diff "@{7 days ago}"..HEAD --stat
```

コミット数が0件の場合は「監査対象期間に変更なし」とレポートし、空の監査ファイルを生成して終了する。

### 3. CFO エージェント起動

CFO エージェントに以下を渡して起動する（Agent ツール）:

```text
あなたは CFO として、直近1週間のコード変更に対するコスト監査を実施してください。

## 監査範囲
git commit range: @{7 days ago}..HEAD

## 変更内容
{git log / git diff の内容}

## 観点
1. API 呼び出し箇所の増減（Claude API, OpenAI API, 外部 API 全般）
2. ANTHROPIC_API_KEY を扱う箇所の変更
3. ヘッドレス Claude 起動（claude -p / npx / bunx）の増減
4. コスト上限設定（max_issues_per_day, max_issues_per_run 等）の変更
5. 従量課金到達リスクの変化

## 参照ドキュメント
- docs/cost-analysis.md
- knowledge/accounting/cost-audit-template.md

## 出力
knowledge/accounting/cost-audit-template.md の雛形に沿って監査結果を記述してください。
Critical / Major / Minor で指摘を分類してください。
```

### 4. レポート保存

CFO の出力を `knowledge/accounting/audit-YYYY-MM-DD.md` に保存する:

```bash
today=$(date -u +%Y-%m-%d)
cp .claude/knowledge/accounting/cost-audit-template.md \
   ".claude/knowledge/accounting/audit-${today}.md"
```

その後、CFO の出力内容で中身を置き換える。

### 5. 異常検出時の Issue 起票

Critical または Major 指摘がある場合、`/issue` スキルで Issue を起票する:

- ラベル: `audit`, `cost`
- タイトルプレフィックス: `[audit-cost]`
- 本文: 監査レポートのサマリ + レポートファイルへのリンク

Minor のみの場合は起票しない（レポート保存のみ）。

### 6. 結果レポート

```text
## /audit-cost 完了

### 監査範囲
- 期間: YYYY-MM-DD 〜 YYYY-MM-DD
- コミット数: N
- 変更ファイル数: N

### 指摘サマリ
- Critical: N 件
- Major: N 件
- Minor: N 件

### 出力
- レポート: knowledge/accounting/audit-YYYY-MM-DD.md
- 起票 Issue: {URL} / なし
```

## 定期実行

`/schedule` または cron で週次実行:

```bash
# 毎週月曜 09:00 JST に実行
/schedule weekly "0 0 * * 1" /audit-cost
```

## 制約

- **コード変更は一切行わない** — 監査レポートと Issue 起票のみ
- `git add` / `git commit` / `git push` は実行しない
- `--force`、`--hard`、`--no-verify` は使用しない
- **jq では string interpolation `\(...)` を使わない** — 必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない
