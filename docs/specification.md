# vibemux プロダクト仕様書

> このドキュメントはプロダクトの公式仕様を定義する Source of Truth です。

## 概要

vibemux は tmux ベースのバイブコーディングワークスペースランチャー。単一の bash スクリプトで構成され、コマンドひとつで3ペイン開発環境を立ち上げる。

## 機能仕様

### コア機能

| サブコマンド | 説明 |
|---|---|
| `vibemux new <session> [dir]` | 3ペインセッションを新規作成 |
| `vibemux attach <session>` | 既存セッションにアタッチ |
| `vibemux list` | アクティブなセッション一覧 |
| `vibemux version` | バージョン表示 |

### ペインレイアウト

```text
┌──────────┬─────────────────────┐
│ top-left │                     │
│  (0.0)   │       right         │
├──────────┤       (0.2)         │
│ bot-left │                     │
│  (0.1)   │                     │
└──────────┴─────────────────────┘
```

tmux の分割順序により、ペインインデックスは以下の通り固定される:

1. `new-session` で最初のペイン作成 → index 0（後の top-left）
2. `split-window -h` で右ペイン分割 → index 0 が左、新ペインが右（index 2 に移動）
3. `split-window -v -t 0.0` で左を上下分割 → top-left が 0.0、bottom-left が 0.1

### 設定

3階層で構成を決定する。設定ファイルは `source` で後から読み込まれるため、設定ファイル内の直接代入（`VAR=value`）は環境変数を上書きする:

1. 設定ファイル (`~/.config/vibemux/config`) — `source` で最後に適用されるため実質最優先
2. 環境変数
3. スクリプト内デフォルト値

設定ファイルで環境変数を優先させたい場合は `${VAR:-value}` パターンを使用する。

| 変数 | 説明 | デフォルト |
|---|---|---|
| `VIBEMUX_PANE_TOP_LEFT` | 左上ペインのコマンド | *(シェル)* |
| `VIBEMUX_PANE_BOTTOM_LEFT` | 左下ペインのコマンド | `lazygit` |
| `VIBEMUX_PANE_RIGHT` | 右ペインのコマンド | *(シェル)* |
| `VIBEMUX_RIGHT_RATIO` | 右ペインの幅 (%) | `70` |
| `VIBEMUX_FOCUS` | 初期フォーカス | `right` |
| `VIBEMUX_CONFIG` | 設定ファイルパス | `~/.config/vibemux/config` |

### 補助機能

- 二重起動防止: `$TMUX` 環境変数による tmux ネスト検知
- セッション重複防止: 同名セッション存在時のエラー通知

## 非機能要件

### セキュリティ

詳細は `SECURITY.md` を参照。

## 開発ワークフロー

### Makefile ターゲット

| ターゲット | 説明 |
|---|---|
| `make setup-hooks` | git hooks パス設定 (`core.hooksPath .githooks`) |
| `make lint` | shellcheck 実行 (vibemux, pre-commit, pre-push) |
| `make test` | `tests/test_*.sh` を順次実行 |
| `make check` | lint + test を実行（コミット前に必須） |
| `make install` | `~/.local/bin/vibemux` にシンボリックリンク作成 |

### 品質チェックフロー

1. `make setup-hooks` で git hooks を有効化
2. コミット時: pre-commit フックが自動実行（シークレット検知、shellcheck）
3. プッシュ時: pre-push フックが自動実行（全ファイル shellcheck、必須ファイル確認）
4. CI: GitHub Actions で `make check` を実行
