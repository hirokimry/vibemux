# vibemux Design Principles

vibemux の設計思想と技術方針。MVV.md の Values を技術レベルに落とし込んだもの。

## コア設計

### 単一スクリプト構成

vibemux は単一の bash スクリプトで完結する。外部依存は tmux と bash のみ。
理由: Value 1「一発で整う」— インストールが `ln -s` だけで済む。

### 設定の階層

1. 環境変数（最優先）
2. 設定ファイル (`~/.config/vibemux/config`)
3. スクリプト内デフォルト値

理由: Value 3「道具に縛られない」— 環境変数で任意のツールを載せ替え可能。

### ペインレイアウト

固定の3ペイン構成（左上・左下・右）。レイアウト自体はカスタマイズ不可。
理由: Value 1「一発で整う」— 選択肢を減らして即座に開始。

## 拡張方針

- 新機能追加時は既存の環境変数パターン (`VIBEMUX_*`) に従う
- サブコマンド追加は `cmd_xxx()` 関数 + `case` 文への追加
- 設定項目追加は環境変数 → config → デフォルトの3段階を踏襲

## 意図的な重複

### git hooks の secret_patterns 関数

`.githooks/pre-commit` と `.githooks/pre-push` に同一の `secret_patterns()` 関数が存在する。DRY 違反だが意図的。フック間で `source` 依存を作ると、一方のフックが壊れた場合にもう一方も巻き込む。各フックは独立して動作すべき。

### vibemux 本体の `2>/dev/null`

`vibemux` スクリプト内の `tmux has-session 2>/dev/null` や `tmux list-sessions 2>/dev/null` は、`docs/design-philosophy.md` の「コマンドリダイレクトフォールバック禁止」ルールの対象外。このルールは vibecorp が管理するスキル・フック内のコマンドに適用されるもので、vibemux 本体（プロダクトコード）の tmux コマンドは通常のシェルスクリプト慣習に従う。

## やらないこと

- tmux 以外のマルチプレクサ対応（フォーカスを絞る）
- プラグインシステム（単一スクリプトの簡潔さを維持）
- GUI/TUI 設定画面（テキストファイルで十分）
