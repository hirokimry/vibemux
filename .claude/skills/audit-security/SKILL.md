---
name: audit-security
description: >
  CISO による月次セキュリティ監査。直近30日間の変更から脆弱性・認証変更を分析し、
  `knowledge/security/audit-YYYY-MM-DD.md` に記録する。full プリセット限定。
  「/audit-security」「セキュリティ監査」と言った時に使用。
---

**ultrathink**

# /audit-security: 月次セキュリティ監査

CISO エージェントによる月次セキュリティ監査を自動化する。直近1ヶ月の変更から脆弱性・認証変更を分析し、監査レポートを `knowledge/security/` に保存する。脆弱性検出時は Issue を起票する。

## 前提条件

- **full プリセット専用**（CISO エージェントが必要）
- CISO エージェント定義（`.claude/agents/ciso.md`）が配置済み
- `knowledge/security/security-audit-template.md` が存在

## ワークフロー

### 1. プリセット確認

```bash
awk '/^preset:[[:space:]]*/ { sub(/^preset:[[:space:]]*/, ""); print; exit }' .claude/vibecorp.yml
```

`full` 以外の場合は「/audit-security は full プリセット専用です」と報告して終了する。

### 2. 監査範囲取得

直近30日間の変更を取得する:

```bash
git log --since="30 days ago" --oneline
git diff "@{30 days ago}"..HEAD --stat
```

コミット数が0件の場合は「監査対象期間に変更なし」とレポートし、空の監査ファイルを生成して終了する。

### 3. CISO エージェント起動

CISO エージェントに以下を渡して起動する（Agent ツール）:

```text
あなたは CISO として、直近1ヶ月のコード変更に対するセキュリティ監査を実施してください。

## 監査範囲
git commit range: @{30 days ago}..HEAD

## 変更内容
{git log / git diff の内容}

## 観点
1. 認証・認可ロジックの変更（auth, permission, token 扱い）
2. 新規依存パッケージの追加（package.json / requirements.txt / go.mod）
3. hooks のガードレール変更（protect-files.sh, diagnose-guard.sh 等）
4. secrets / credentials 扱い箇所の変更（ANTHROPIC_API_KEY, gh auth 等）
5. OWASP Top 10 該当変更の有無

## 参照ドキュメント
- docs/SECURITY.md
- rules/autonomous-restrictions.md
- knowledge/security/security-audit-template.md

## 出力
knowledge/security/security-audit-template.md の雛形に沿って監査結果を記述してください。
Critical / Major / Minor で指摘を分類してください。
OWASP Top 10 チェック表も埋めてください。
```

### 4. レポート保存

CISO の出力を `knowledge/security/audit-YYYY-MM-DD.md` に保存する:

```bash
today=$(date -u +%Y-%m-%d)
cp .claude/knowledge/security/security-audit-template.md \
   ".claude/knowledge/security/audit-${today}.md"
```

その後、CISO の出力内容で中身を置き換える。

### 5. 脆弱性検出時の Issue 起票

Critical または Major 指摘がある場合、`/issue` スキルで Issue を起票する:

- ラベル: `audit`, `security`
- タイトルプレフィックス: `[audit-security]`
- 本文: 監査レポートのサマリ + レポートファイルへのリンク

Minor のみの場合は起票しない（レポート保存のみ）。

### 6. 結果レポート

```text
## /audit-security 完了

### 監査範囲
- 期間: YYYY-MM-DD 〜 YYYY-MM-DD
- コミット数: N
- 変更ファイル数: N

### 指摘サマリ
- Critical: N 件
- Major: N 件
- Minor: N 件

### OWASP Top 10 該当
- A01 / A02 / A03 / A07 / A08: あり / なし

### 出力
- レポート: knowledge/security/audit-YYYY-MM-DD.md
- 起票 Issue: {URL} / なし
```

## 定期実行

`/schedule` または cron で月次実行:

```bash
# 毎月1日 09:00 JST に実行
/schedule monthly "0 0 1 * *" /audit-security
```

## 制約

- **コード変更は一切行わない** — 監査レポートと Issue 起票のみ
- `git add` / `git commit` / `git push` は実行しない
- `--force`、`--hard`、`--no-verify` は使用しない
- **jq では string interpolation `\(...)` を使わない** — 必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない
