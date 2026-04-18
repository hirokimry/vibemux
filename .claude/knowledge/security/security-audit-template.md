# セキュリティ監査レポート雛形

`/audit-security` による月次セキュリティ監査の記録雛形。実施ごとに `audit-YYYY-MM-DD.md` としてコピーして使用する。

---

## 実施日

YYYY-MM-DD（実施者: CISO エージェント / スキル: `/audit-security`）

## 監査範囲

- git commit range: `<base>..<head>`
- 対象期間: YYYY-MM-DD 〜 YYYY-MM-DD（直近30日間）

## 変更サマリ

- コミット数: N
- 変更ファイル数: N
- 認証・認可ロジック変更: あり / なし
- 新規依存パッケージ: N 件
- hooks ガードレール変更: あり / なし
- secrets / credentials 扱い箇所変更: あり / なし

## 指摘事項

### Critical（即時対応）

- （該当なし / 詳細）

### Major（次回リリース前対応）

- （該当なし / 詳細）

### Minor（将来対応）

- （該当なし / 詳細）

## OWASP Top 10 チェック

| カテゴリ | 該当変更 | 所見 |
|---|---|---|
| A01 Broken Access Control | あり / なし | - |
| A02 Cryptographic Failures | あり / なし | - |
| A03 Injection | あり / なし | - |
| A07 Authentication Failures | あり / なし | - |
| A08 Software and Data Integrity | あり / なし | - |

## 推奨アクション

- （具体的な改善提案）

## 次回監査予定日

YYYY-MM-DD（月次: 毎月1日）

## 関連

- `docs/SECURITY.md`
- `rules/autonomous-restrictions.md`
- Phase 6 #291
