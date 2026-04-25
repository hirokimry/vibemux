# vibemux

[English](README.en.md)

> AI 駆動開発の最初の1画面を、コマンド1本で立てる道具。

`vibemux new project` — これだけで、AI への指示（shell）と変更検証（lazygit）をすぐ始められる 1 画面が整う。バイブコーディングの全活動が、ターミナル 1 画面に収まる。

```text
┌──────────┬─────────────────────┐
│  shell   │                     │
│          │       shell         │
├──────────┤                     │
│ lazygit  │                     │
└──────────┴─────────────────────┘
```

## なぜ vibemux？

AI 駆動開発では、shell でエージェントに指示を出し、lazygit で差分を検証する——この 2 つが人間の主活動になる。ウィンドウを切り替えずに、すべてが視界に収まる。

複雑な並列管理は tmux と AI エージェントに委ね、vibemux は「最初の 1 画面を立てる」ことに専念する。並列エージェント時代になっても、その役割は変わらない。

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
| `VIBEMUX_PANE_TOP_LEFT` | 左上ペインのコマンド | *(シェル)* |
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

## コントリビュート

```bash
git clone https://github.com/hirokimry/vibemux.git
cd vibemux
make setup-hooks   # git hooks を有効化
make check         # lint + tests をローカル実行
```

## 必要なもの

- [tmux](https://github.com/tmux/tmux) (>= 3.0)
- Bash (>= 4.0)

## ライセンス

MIT
