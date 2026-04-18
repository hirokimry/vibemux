# コスト監査レポート雛形

`/audit-cost` による週次コスト監査の記録雛形。実施ごとに `audit-YYYY-MM-DD.md` としてコピーして使用する。

---

## 実施日

YYYY-MM-DD（実施者: CFO エージェント / スキル: `/audit-cost`）

## 監査範囲

- git commit range: `<base>..<head>`
- 対象期間: YYYY-MM-DD 〜 YYYY-MM-DD（直近7日間）

## 変更サマリ

- コミット数: N
- 変更ファイル数: N
- API 呼び出し箇所の増減: +N / -N
- ヘッドレス Claude 起動箇所（claude -p / npx / bunx）の増減: +N / -N

## 指摘事項

### Critical（即時対応）

- （該当なし / 詳細）

### Major（次回リリース前対応）

- （該当なし / 詳細）

### Minor（将来対応）

- （該当なし / 詳細）

## コスト影響評価

| 項目 | 変更前 | 変更後 | 影響度 |
|---|---|---|---|
| 想定月額 API コスト | $X | $Y | 増減 |
| 従量課金到達リスク | Low / Medium / High | Low / Medium / High | - |

## 推奨アクション

- （具体的な改善提案）

## 次回監査予定日

YYYY-MM-DD（週次: 毎週月曜）

## 関連

- `docs/cost-analysis.md`
- Phase 6 #291
