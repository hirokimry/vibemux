# vibecorp プラグイン管理と法務・コンプライアンスの注意点

> PR レビュー指摘から抽出した知見。  
> ソース: PR #27 (`<reviewer>` + CodeRabbit)

## 1. `.claude/` 以下の法務関連ファイルは上流管理

`.claude/agents/plan-legal.md` を含む `.claude/` 配下の全ファイルは、
vibecorp プラグインの `install.sh --update` によって自動生成・上書きされる。

**法務的含意:**

- 本リポジトリで法務エージェント定義やルールファイルを直接修正しても、
  次回 `install.sh --update` 時に上書きされ無効化される
- 法務ルールの追加・変更・是正が必要な場合は **vibecorp 上流リポジトリ** で対応すること
- 本リポジトリ内の法務関連ファイル（`plan-legal.md` 等）の問題は、
  上流の vibecorp リポジトリへ Issue として起票する

## 2. `public-ready.md` 未配布（公開準備チェック欠落リスク）

**確認された問題:**

- `.claude/rules/public-ready.md`（公開準備チェックルール）が
  vibecorp プラグインから未配布の既知の不整合
- 発見箇所: `.claude/agents/plan-legal.md`（法務計画エージェント）のレビュー指摘
- 追跡 Issue: `hirokimry/vibecorp#41`（PR #27 時点）

**法務的リスク評価:**

- `public-ready.md` は公開前の成果物（コード・ドキュメント等）が
  外部公開に適しているかを確認するルールである可能性が高い
- このルールが機能していない期間、公開準備チェックが実施されていない可能性がある
- 上流 vibecorp での修正が完了するまで、公開準備チェックは手動で代替確認が必要

**対応方針:**

- 本リポジトリでの直接修正は不可（次回 update で上書きされるため）
- vibecorp 上流リポジトリで `public-ready.md` の配布を修正することが根本対処
- それまでの暫定措置として、公開前レビューで `public-ready.md` が定める
  基準に相当する確認を手動で実施することを推奨

## 参照

| 項目 | 内容 |
|------|------|
| ソース PR | #27 |
| 関連コメント ID | 3105520885 (`<reviewer>`), 3105521423 (CodeRabbit) |
| 追跡 Issue | hirokimry/vibecorp#41 |
| 発見日 | 2026-04-18 |
