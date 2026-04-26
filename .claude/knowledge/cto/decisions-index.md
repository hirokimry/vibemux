# CTO 技術判断記録インデックス

このファイルは目次。CTO エージェントが step 1 で毎回 Read する。
関連する過去判断を特定したら `decisions/YYYY-QN.md` を追加で Read する。

## エントリ

- 2026-04-26 — vibecorp 0.22.0→0.22.2 アップグレード — スキル配布方式をプラグインキャッシュ経由に移行。design-philosophy/file-placement/team-permissionsのドキュメント不整合を修正
- 2026-04-25 — PR #27, #43 技術知見 — `.claude/hooks/` 等は vibecorp plugin 自動生成物。直接修正不可、upstream で対応
- 2026-04-25 — PR #20 技術知見 — `git status --porcelain` スコープ一致ルール・ベースブランチ `{baseRefName}` 参照

## 運用ルール

### エントリ書式

1 エントリ = 1 行:

```text
- YYYY-MM-DD — Issue #NNN または トピック名 — 結論の一行要約
```

### 四半期の命名

- 01-03 → Q1、04-06 → Q2、07-09 → Q3、10-12 → Q4
- 例: 2026-04-18 → `decisions/2026-Q2.md`

### 追記手順

1. `decisions/YYYY-QN.md` に詳細を追記（ファイルがなければ新規作成、`decisions/` ディレクトリ自動作成）
2. 本ファイルのエントリセクションに 1 行サマリを追記（新しい順で上に追加）

詳細仕様: `docs/migration-decisions-index.md`
