---
name: review-to-rules
description: "PRレビュー指摘から規約・ナレッジへの反映を自動化。修正した指摘を分析し、rules/ / knowledge/ に反映すべきか判断・実行する。「/review-to-rules」「指摘を規約化して」と言った時に使用。"
---

# レビュー指摘 → 規約・ナレッジ自動反映

PRレビューで修正した指摘を分析し、再発防止のために rules/ / knowledge/ に反映する。

## 使用方法

```bash
/review-to-rules                    # 現在のブランチのPRから指摘を取得
/review-to-rules <PR URL>           # PR URLを直接指定
```

## ワークフロー

### 1. 修正済み指摘の収集

返信済み（＝修正済み）の指摘を収集する。

```bash
# CodeRabbitのトップレベルコメント
CR_IDS=$(gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | select(.user.login | test("coderabbit"; "i")) | select(.in_reply_to_id == null) | .id]')

# 返信済みIDの抽出
REPLY_TO_IDS=$(gh api repos/{owner}/{repo}/pulls/{pr_number}/comments \
  --jq '[.[] | select(.in_reply_to_id != null) | .in_reply_to_id] | unique')
```

### 2. 指摘の分類

| 分類 | 反映先 |
|------|--------|
| 全員が守るべきコーディング規約 | `.claude/rules/` |
| セキュリティ関連の判断基準 | `.claude/knowledge/security-principles.md` |
| シェルスクリプトのパターン | `.claude/knowledge/shell-best-practices.md` |
| 設計方針に関わるもの | `.claude/knowledge/design-principles.md` |
| 一過性の指摘（反映不要） | なし |

**分類基準:**
- 同じ指摘が今後も繰り返し発生しうるか？ → Yes なら反映対象
- 一度きりのバグ修正・タイポ修正 → 反映不要

### 3. 反映を実施

各指摘について:
1. 該当する rules/ または knowledge/ ファイルを読み込む
2. 既存のスタイル・フォーマットを維持して追記
3. 過剰な加筆をしない

### 4. 結果報告

```text
## review-to-rules 結果

### 反映内容
- .claude/rules/bash.md: 「tmpファイルはmktempで作成」を追加
- .claude/knowledge/shell-best-practices.md: パイプ処理のパターンを追記

### 反映不要と判断した指摘
- [タイポ修正] — 一過性の修正のため
```

## 5. スタンプ発行

処理完了後、必ずスタンプを発行する（反映の有無に関わらず）:

```bash
touch /tmp/.vibemux-review-to-rules-ok
```

このスタンプがないと `gh pr merge` が hooks でブロックされる。

## 注意事項

- `git add` / `git commit` / `git push` はこのスキル内では実行しない（呼び出し元に委ねる）
- knowledge/ の記事は既存ファイルに追記する（新規ファイル乱立を防ぐ）
- rules/ への追加は慎重に — 本当に繰り返し発生する指摘のみ
