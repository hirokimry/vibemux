# aimux

[English](README.md)

tmux で AI ペアプログラミング環境を一発で立ち上げるツール。

ファイラ、Git クライアント、AI コーディングアシスタントを 3 ペインで並べて表示。ターミナルがそのまま AI 開発のコックピットになります。

```
┌──────────┬─────────────────────┐
│  files   │                     │
│          │    AI assistant      │
├──────────┤                     │
│   git    │                     │
└──────────┴─────────────────────┘
```

## なぜ aimux？

Claude Code や Aider などの AI コーディングアシスタントはターミナルで最も力を発揮します。しかし開発中はファイルツリーや git の状態も頻繁に確認したい。ウィンドウを切り替えるたびに集中が途切れます。

aimux ならすべてが一画面に収まります。ファイル操作、差分確認、AI との対話をキーボードから手を離さずに行えます。

## インストール

```bash
git clone https://github.com/hirokimry/aimux.git
ln -s "$(pwd)/aimux/aimux" ~/.local/bin/aimux
```

または `aimux` スクリプトを `$PATH` の通った場所にコピーするだけでも OK です。

## 使い方

```bash
aimux new myproject              # カレントディレクトリでセッション作成
aimux new myproject ~/code/app   # 指定ディレクトリでセッション作成
aimux attach myproject           # 既存セッションにアタッチ
aimux list                       # アクティブなセッション一覧
```

## 設定

環境変数または `~/.config/aimux/config` でペインのコマンドをカスタマイズできます。

### 環境変数

| 変数 | 説明 | デフォルト |
|---|---|---|
| `AIMUX_PANE_TOP_LEFT` | 左上ペインのコマンド | `yazi` |
| `AIMUX_PANE_BOTTOM_LEFT` | 左下ペインのコマンド | `lazygit` |
| `AIMUX_PANE_RIGHT` | 右ペインのコマンド | *(シェル)* |
| `AIMUX_RIGHT_RATIO` | 右ペインの幅 (%) | `70` |
| `AIMUX_FOCUS` | 起動時のフォーカス: `right`, `top-left`, `bottom-left` | `right` |

### 設定ファイル

```bash
# ~/.config/aimux/config
AIMUX_PANE_TOP_LEFT="yazi"
AIMUX_PANE_BOTTOM_LEFT="lazygit"
AIMUX_PANE_RIGHT="claude --resume"
AIMUX_RIGHT_RATIO=70
AIMUX_FOCUS=right
```

`AIMUX_CONFIG` で別のパスから読み込むこともできます。

### 設定例

**Claude Code + yazi + lazygit**（おすすめ）:

```bash
AIMUX_PANE_RIGHT="claude --resume" aimux new dev
```

**Aider + lf + tig:**

```bash
AIMUX_PANE_TOP_LEFT="lf"
AIMUX_PANE_BOTTOM_LEFT="tig"
AIMUX_PANE_RIGHT="aider"
```

**ミニマル構成 — AI アシスタントのみ:**

```bash
AIMUX_PANE_TOP_LEFT="" AIMUX_PANE_BOTTOM_LEFT="" AIMUX_PANE_RIGHT="claude" aimux new focus
```

## 必要なもの

- [tmux](https://github.com/tmux/tmux) (>= 3.0)
- Bash (>= 4.0)

## ライセンス

MIT
