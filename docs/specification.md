# vibemux プロダクト仕様書

> このドキュメントはプロダクトの公式仕様を定義する Source of Truth です。
> 関連: [Issue #30](https://github.com/hirokimry/vibemux/issues/30)（プロダクト方向性の決着） / [`MVV.md`](../MVV.md)

## 概要

vibemux は **「最初の1画面を立てる道具」** である。`vibemux new <session>` のコマンドひとつで、AI と人が同じ画面で開発するための tmux ワークスペースを立ち上げる。

```text
┌──────────┬─────────────────────┐
│          │                     │
│ lazygit  │       shell         │
│          │                     │
└──────────┴─────────────────────┘
```

shell で AI に指示を出し、lazygit で変更を検証する。**この2ペインが、AI 駆動開発における人間の主要活動をカバーする。**

> 内部構造は3ペイン分割を維持しており、左上ペイン (`top-left`) はデフォルトで空シェル、任意のコマンド（例: yazi）を `VIBEMUX_PANE_TOP_LEFT` で差し込めば opt-in 利用も可能。詳細は [§機能仕様 > ペインレイアウト](#ペインレイアウト) を参照。

## vibemux の責務境界

vibemux は AI 駆動・並列エージェント時代でも「最初の1画面を立てる道具」である。これは **積極的な境界設定** であり、`MVV.md` Value #3「道具に縛られない」を実現するための選択である。

### する

| 項目 | 説明 |
|---|---|
| コマンド1本でセッションを立てる | `vibemux new <name>` で初期環境が整う |
| 推奨レイアウトを提示する | shell + lazygit の2ペインデフォルトを提供する |
| AI が tmux を壊さないガードレールを提供する | PATH shim による禁止コマンドのブロック（[§ガードレール](#ガードレール)） |
| どのエージェントでも動く環境を作る | Claude Code・Aider・Cursor 等に依存しない |

### しない

| 項目 | 委譲先 |
|---|---|
| 並列エージェントの管理・集約 | tmux ネイティブ（タブ・ペイン）と AI エージェントの自律性 |
| セッションの命名・識別・終了 | ユーザーと tmux のネイティブコマンド |
| AI の監視・モニタリング | 人間の目視 + 各エージェントが提供するログ・通知 |
| 特定ツールへの依存実装 | エージェント側の実装に委ねる |

### 「しない」を選ぶ理由

管理機能を抱えれば、特定の並列モデル・命名規則・エージェントに依存した道具となる。これは `MVV.md` Value #3「道具に縛られない」に反するため、これらを担わない。

vibemux は **「場を作る道具」** であり、**「場を運用する道具」ではない**。Mission「ターミナルを、バイブコーディングの最高の場にする」に基づき、最初の1画面を立てる責務に集中する。

## 推奨実行環境

`MVV.md` および [Issue #30](https://github.com/hirokimry/vibemux/issues/30) の決着により、AI 駆動開発の実行基盤として **Ghostty + tmux** を推奨する。VSCode は diff 確認専用に位置づけを格下げした。

| 採用 | 環境 | 用途 |
|---|---|---|
| ✅ | Ghostty + tmux | メイン実行基盤（vibemux の前提環境） |
| 🔽 | VSCode + Claude Code 拡張 | diff 確認専用 |
| 🔽 | Claude リモートモード | モニタリング補助 |

### Ghostty + tmux

> 詳細は Issue [#42](https://github.com/hirokimry/vibemux/issues/42) で追記される。

長時間ループの detach 対応、並列ペイン管理、Rust 製で軽量、といった観点から個人開発・チーム開発ともにメイン実行基盤として採用する。

### VSCode の位置づけ

> 詳細は Issue [#40](https://github.com/hirokimry/vibemux/issues/40) で追記される。

AI が 100% コードを書く前提では LSP 等のリッチエディタ機能の価値が低下する。VSCode は daily driver から外し、diff 確認専用ツールとして位置づける。

### vibemux のポジショニング

> 詳細は Issue [#41](https://github.com/hirokimry/vibemux/issues/41) で追記される。

vibemux は AI 駆動開発における実行環境を再定義する存在であり、エディタ中心の旧来開発フローから、ターミナル + 並列エージェントを軸とする新しい開発フローへの転換を支える基盤である。

## 機能仕様

### コア機能

| サブコマンド | 説明 |
|---|---|
| `vibemux new <session> [dir]` | 新規セッションを作成 |
| `vibemux attach <session>` | 既存セッションにアタッチ |
| `vibemux list` | アクティブなセッション一覧 |
| `vibemux version` | バージョン表示 |

### ペインレイアウト

デフォルトは **2ペイン構成**（lazygit + shell）である。Issue #30（問い3）の検証に基づき、yazi（ファイルマネージャ）はデフォルトから廃止された。

```text
┌──────────┬─────────────────────┐
│ top-left │                     │
│ (empty)  │       right         │
├──────────┤      (shell)        │
│ bot-left │                     │
│ (lazygit)│                     │
└──────────┴─────────────────────┘
```

#### 構造詳細

tmux の split-window により内部的には3ペイン構造を維持する。`top-left` はデフォルトで空シェルとなり、視覚的には2ペイン UX として動作する。

ペインインデックスの割り当て順序:

1. `new-session` で最初のペイン作成 → index 0（後の top-left）
2. `split-window -h` で右ペイン分割 → 右ペインが index 2
3. `split-window -v -t 0.0` で左を上下分割 → top-left が 0.0、bottom-left が 0.1

#### yazi デフォルト廃止の経緯

[Issue #30](https://github.com/hirokimry/vibemux/issues/30)（問い3）の検証で、ファイルツリーは AI 駆動開発において主役にも準主役にもならないと判定された。

- AI が 100% 書く前提では、ファイル構造の探索を AI に依頼する方が高速
- 変更ファイル一覧は lazygit が既にカバーしている
- ファウンダーの実行動でも、yazi が見られる頻度は稀であった

このため `VIBEMUX_PANE_TOP_LEFT` のデフォルトを空シェルに変更した。yazi を引き続き使いたい場合は環境変数で復元できる:

```bash
VIBEMUX_PANE_TOP_LEFT=yazi vibemux new myproject
```

> なお `MVV.md` Value #2「ファイル・git・AIが常に視界にある」の「ファイル」の定義見直しはファウンダー判断事項として継続検討中である。本仕様書では yazi デフォルト廃止という決定事項のみを記述する。

### 設定

3階層で構成を決定する。設定ファイルは `source` で後から読み込まれるため、設定ファイル内の直接代入（`VAR=value`）は環境変数を上書きする:

1. 設定ファイル (`~/.config/vibemux/config`) — `source` で最後に適用されるため実質最優先
2. 環境変数
3. スクリプト内デフォルト値

設定ファイルで環境変数を優先させたい場合は `${VAR:-value}` パターンを使用する。

| 変数 | 説明 | デフォルト |
|---|---|---|
| `VIBEMUX_PANE_TOP_LEFT` | 左上ペインのコマンド | *(空シェル — yazi 等を opt-in 可能。経緯は [§ペインレイアウト](#ペインレイアウト))* |
| `VIBEMUX_PANE_BOTTOM_LEFT` | 左下ペインのコマンド | `lazygit` |
| `VIBEMUX_PANE_RIGHT` | 右ペインのコマンド | *(シェル)* |
| `VIBEMUX_RIGHT_RATIO` | 右ペインの幅 (%) | `70` |
| `VIBEMUX_FOCUS` | 初期フォーカス | `right` |
| `VIBEMUX_CONFIG` | 設定ファイルパス | `~/.config/vibemux/config` |

### 補助機能

- 二重起動防止: `$TMUX` 環境変数による tmux ネスト検知
- セッション重複防止: 同名セッション存在時のエラー通知

## 並列エージェント時代の vibemux

並列エージェント実行時代でも、vibemux の役割は変わらない。最初の1画面を立てる責務に集中し、並列の起動・管理・終了は tmux と AI エージェントの自律性に委ねる。

### vibemux が管理しないもの

| 領域 | 委譲先 |
|---|---|
| **並列エージェントの管理・集約** | tmux ネイティブ（タブ追加・ペイン分割）と AI エージェントの自律的な並列化 |
| **セッションの命名・識別・終了** | ユーザーが `vibemux new <name>` で命名し、終了は `tmux kill-session` / 全ペイン exit / `git worktree remove` |
| **AI の監視・モニタリング** | 各エージェントが提供するログ・通知・人間の目視（lazygit 等） |

### 並列時の役割分担

並列化が起きるとき、粒度に応じて主体が分かれる。

| 粒度 | 主体 | 操作 | 環境 |
|---|---|---|---|
| **タブ（フルワークスペース）** | ユーザー | 新タブで `vibemux new` | 2ペイン（shell + lazygit）が丸ごと立つ |
| **ペイン（軽量並列）** | AI エージェント | ペイン追加 + worktree 分離 | shell のみ。lazygit は元の1個で worktree 切替 |

`vibemux window` のような中間コマンドは **設けない**。タブ内の並列化は AI + tmux ネイティブの責務である。

### セッションのライフサイクル

vibemux は永続的な状態を持たない（DB なし・常駐プロセスなし）。終了・クリーンアップは生成元のネイティブコマンドに委ねる。

| リソース | 生成 | 終了 |
|---|---|---|
| tmux セッション | `vibemux new` | `tmux kill-session` / 全ペイン exit |
| AI が追加したペイン | AI（`split-window`） | `exit` でペイン消滅 |
| AI が作った worktree | AI（`git worktree add`） | `git worktree remove` |

`vibemux kill` のような終了コマンドは提供しない。

## ガードレール

vibemux は AI エージェントの tmux 操作が破壊的にならないよう、PATH shim ベースのガードレールを提供する。詳細設計は [`docs/tmux-guardrail.md`](./tmux-guardrail.md) に記載する。

### 位置づけ

- **目的**: AI が誤って `kill-server` 等の破壊的コマンドを発行しても、ユーザーのフローを毀損しないようブロックする
- **実装**: PATH shim（`$PATH` 先頭に置く tmux ラッパー）で、許可リストを通過したコマンドのみ本物の tmux に委譲する
- **ツール非依存**: Claude Code 固有の `permissions.deny` には依存しない（`MVV.md` Value #3「道具に縛られない」準拠）。Aider・Cursor・他の CLI エージェントでも同じガードレールが機能する
- **段階的防御**: 絶対パス直叩き等の bypass は2段階防御モデル（Phase A: 事後検知、Phase B: sandbox 統合）で対処する

### 関連

- [`docs/tmux-guardrail.md`](./tmux-guardrail.md) — ガードレール設計の Source of Truth
- [`docs/tmux-kill-session-identification.md`](./tmux-kill-session-identification.md) — `kill-session` の自セッション識別方式

## 非機能要件

### セキュリティ

詳細は [`docs/SECURITY.md`](./SECURITY.md) を参照。

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

## 参照

- [`MVV.md`](../MVV.md) — 全判断の最上位基準
- [Issue #30](https://github.com/hirokimry/vibemux/issues/30) — vibemux プロダクト方向性の再検証（4問の決着）
- [`docs/tmux-guardrail.md`](./tmux-guardrail.md) — ガードレール設計
- [`docs/design-philosophy.md`](./design-philosophy.md) — 設計思想
- [`docs/SECURITY.md`](./SECURITY.md) — セキュリティ仕様
