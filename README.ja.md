# vibemux

[English](README.md)

tmux でバイブコーディング環境を一発で立ち上げるツール。

ファイラ、Git クライアント、AI コーディングアシスタントを 3 ペインで並べて表示。ターミナルがそのままバイブコーディングのコックピットになります。

```
┌──────────┬─────────────────────┐
│  files   │                     │
│          │    AI assistant      │
├──────────┤                     │
│   git    │                     │
└──────────┴─────────────────────┘
```

## なぜ vibemux？

Claude Code や Aider でのバイブコーディングはターミナルで最も力を発揮します。しかし開発中はファイルツリーや git の状態も頻繁に確認したい。ウィンドウを切り替えるたびに集中が途切れます。

vibemux ならすべてが一画面に収まります。ファイル操作、差分確認、AI との対話をキーボードから手を離さずに行えます。

## インストール

```bash
git clone https://github.com/hirokimry/vibemux.git
ln -s "$(pwd)/vibemux/vibemux" ~/.local/bin/vibemux
```

または `vibemux` スクリプトを `$PATH` の通った場所にコピーするだけでも OK です。

## 使い方

```bash
vibemux new myproject              # カレントディレクトリでセッション作成
vibemux new myproject ~/code/app   # 指定ディレクトリでセッション作成
vibemux attach myproject           # 既存セッションにアタッチ
vibemux list                       # アクティブなセッション一覧
```

## 設定

環境変数または `~/.config/vibemux/config` でペインのコマンドをカスタマイズできます。

### 環境変数

| 変数 | 説明 | デフォルト |
|---|---|---|
| `VIBEMUX_PANE_TOP_LEFT` | 左上ペインのコマンド | `yazi` |
| `VIBEMUX_PANE_BOTTOM_LEFT` | 左下ペインのコマンド | `lazygit` |
| `VIBEMUX_PANE_RIGHT` | 右ペインのコマンド | *(シェル)* |
| `VIBEMUX_RIGHT_RATIO` | 右ペインの幅 (%) | `70` |
| `VIBEMUX_FOCUS` | 起動時のフォーカス: `right`, `top-left`, `bottom-left` | `right` |

### 設定ファイル

```bash
# ~/.config/vibemux/config
VIBEMUX_PANE_TOP_LEFT="yazi"
VIBEMUX_PANE_BOTTOM_LEFT="lazygit"
VIBEMUX_PANE_RIGHT="claude --resume"
VIBEMUX_RIGHT_RATIO=70
VIBEMUX_FOCUS=right
```

`VIBEMUX_CONFIG` で別のパスから読み込むこともできます。

### 設定例

**Claude Code + yazi + lazygit**（おすすめ）:

```bash
VIBEMUX_PANE_RIGHT="claude --resume" vibemux new dev
```

**Aider + lf + tig:**

```bash
VIBEMUX_PANE_TOP_LEFT="lf"
VIBEMUX_PANE_BOTTOM_LEFT="tig"
VIBEMUX_PANE_RIGHT="aider"
```

**ミニマル構成 — AI アシスタントのみ:**

```bash
VIBEMUX_PANE_TOP_LEFT="" VIBEMUX_PANE_BOTTOM_LEFT="" VIBEMUX_PANE_RIGHT="claude" vibemux new focus
```

## 必要なもの

- [tmux](https://github.com/tmux/tmux) (>= 3.0)
- Bash (>= 4.0)

## ライセンス

MIT
