# vibemux

[English](README.en.md)

> AI 駆動開発の最初の1画面を、コマンド1本で立てる道具。

`vibemux new project` — これだけで、AI への指示（shell）と変更検証（lazygit）をすぐ始められる 1 画面が整う。バイブコーディングの全活動が、ターミナル 1 画面に収まる。

```text
┌──────────┬─────────────────────┐
│          │                     │
│ lazygit  │       shell         │
│          │                     │
└──────────┴─────────────────────┘
```

## なぜ vibemux？

AI 駆動開発では、shell でエージェントに指示を出し、lazygit で差分を検証する——この 2 つが人間の主活動になる。ウィンドウを切り替えずに、すべてが視界に収まる。

複雑な並列管理は tmux と AI エージェントに委ね、vibemux は「最初の 1 画面を立てる」ことに専念する。並列エージェント時代になっても、その役割は変わらない。

## インストール

```bash
git clone https://github.com/hirokimry/vibemux.git
cd vibemux
make install
```

`make install` は `~/.local/bin/vibemux` に絶対パスでシンボリックリンクを作成します。`~/.local/bin` が `$PATH` に含まれない場合は、追加方法を案内します。

`make` を使いたくない場合は、`vibemux` スクリプトを `$PATH` の通った場所に直接コピーしても動きます。

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
| `VIBEMUX_PANE_LEFT` | 左ペインのコマンド | `lazygit` |
| `VIBEMUX_PANE_RIGHT` | 右ペインのコマンド | *(シェル)* |
| `VIBEMUX_RIGHT_RATIO` | 右ペインの幅 (%) | `70` |
| `VIBEMUX_FOCUS` | 起動時のフォーカス: `right`, `left` | `right` |

### 設定ファイル

```bash
# ~/.config/vibemux/config
VIBEMUX_PANE_LEFT="lazygit"
VIBEMUX_PANE_RIGHT="claude --resume"
VIBEMUX_RIGHT_RATIO=70
VIBEMUX_FOCUS=right
```

`VIBEMUX_CONFIG` で別のパスから読み込むこともできます。

### 設定例

**Claude Code + lazygit**（おすすめ）:

```bash
VIBEMUX_PANE_RIGHT="claude --resume" vibemux new dev
```

**Aider + tig:**

```bash
VIBEMUX_PANE_LEFT="tig"
VIBEMUX_PANE_RIGHT="aider"
```

**ミニマル構成 — AI アシスタントのみ:**

```bash
VIBEMUX_PANE_LEFT="" VIBEMUX_PANE_RIGHT="claude" vibemux new focus
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

## 並列実行

vibemux は「最初の1画面を立てる道具」です。並列エージェント時代でも役割は変わらず、並列の管理・集約には踏み込みません。詳細な決定経緯は [#30](https://github.com/hirokimry/vibemux/issues/30) を参照してください。

### 役割分担

| 粒度 | 起動主体 | 操作 | 内容 |
|---|---|---|---|
| **タブ（フルワークスペース）** | ユーザー | 新タブ → `vibemux new <project>` | vibemux のデフォルトレイアウト（shell + lazygit を中心としたワークスペース）が丸ごと立つ |
| **ペイン（軽量並列）** | AI エージェント | ペイン追加 + worktree 分離 | shell のみ。lazygit は元の 1 インスタンスを共有 |

- **タブ = 人間の境界**: フルワークスペースが欲しい時はユーザーがタブを作って `vibemux new`
- **ペイン = AI の境界**: AI が自律的に worktree を切ってペインを追加する
- **lazygit = 共有の検証手段**: 1 インスタンスで Worktrees タブから `<space>` キーで worktree を切替し、各 worktree の変更を確認する

### vibemux の責務

vibemux が並列時代に提供するのは以下のみです。

- ✅ `vibemux new` で初期 1 画面を立てる
- 🚧 tmux ラッパー（PATH shim）で AI が tmux を壊さないガードレール（[#31](https://github.com/hirokimry/vibemux/issues/31) で実装予定）
- ❌ 並列エージェントの管理・集約・命名・終了には関与しない

並列の起動・終了は tmux と git のネイティブ機能（`tmux new-window`、`tmux split-window`、`git worktree add`、`git worktree remove`）に委ねます。

## ライセンス

MIT
