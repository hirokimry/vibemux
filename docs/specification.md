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

個人開発・チーム開発ともに、AI 駆動開発のメイン実行基盤として **Ghostty + tmux** を推奨する。`MVV.md` Value #3「道具に縛られない」に基づき、これは**推奨**であって他のターミナル（Alacritty / WezTerm / iTerm2 等）の利用を排除するものではない。vibemux のセッション・ペイン構成は素の tmux 上で完結するため、tmux を扱える環境であれば動作する。

#### 採用理由

##### 1. 長時間ループの detach 対応

- **観点**: AI 駆動の自律ループ（`/loop`、並列エージェント実行、ヘッドレス Claude）は数十分〜数時間単位で走る
- **利点**: tmux のセッションはターミナル接続から独立しており、Ghostty を閉じてもバックグラウンドで処理が継続する。再接続時は `vibemux attach` で同じ画面に戻れる
- **vibemux 文脈**: Mission「ターミナルを、バイブコーディングの最高の場にする」を支える前提。ループを切らずに人間が席を立てる

##### 2. 並列ペイン管理

- **観点**: 並列エージェント時代では1セッション内で複数のエージェント・ワークスペースが同時稼働する
- **利点**: tmux ネイティブのウィンドウ・ペイン分割で、追加コストなく並列スロットを確保できる。`split-window` / `new-window` だけで AI が自律的にスロットを増やせる
- **vibemux 文脈**: § 並列エージェント時代の vibemux で示した「タブ＝ユーザー、ペイン＝AI」の役割分担が tmux ネイティブ機能のみで成立する

##### 3. ネイティブ実装で軽量

- **観点**: 開発フローを切らないためにはターミナル自身が起動・描画・スクロールすべての局面で軽量である必要がある
- **利点**: Ghostty は Zig で実装された GPU アクセラレーションターミナル（Issue #42 起票時の表現「Rust 製」は誤りで、正確には Zig 実装）。起動が速く、長時間運用でもメモリフットプリントが安定する。Electron ベースの IDE 内蔵ターミナルと比較してレスポンスが鋭い
- **vibemux 文脈**: Value #2「フローを切らない」に直結する。AI のログ・lazygit のリフレッシュ等、流量の多い出力でも詰まらない。Alacritty（Rust）等の同カテゴリのネイティブターミナルでも同等の利点を享受できる

##### 4. hooks・MCP・worktree との相性

- **観点**: Claude Code の hooks、MCP サーバー、`git worktree` はいずれもローカルファイルシステム・プロセス・PATH を前提として動作する
- **利点**: Ghostty + tmux はホスト OS のネイティブ環境をそのまま共有する。`PATH` shim によるガードレール（`docs/tmux-guardrail.md`）、ローカル MCP プロセス、worktree 切替が一切のブリッジ層なしで機能する
- **vibemux 文脈**: § ガードレールで述べた PATH shim 方式や、並列エージェントが用いる worktree が、追加設定なしで素直に動く

##### 5. Codespaces / Devcontainer との比較での優位性

- **観点**: クラウド型開発環境（GitHub Codespaces、Devcontainer）とローカル型を比較する
- **利点**:
  - **永続性**: ローカル tmux セッションはマシンが起きている限り続く。Codespaces はアイドル停止 / インスタンス再生成でセッションが消える
  - **接続安定性**: ネットワーク断は即座にエージェントの応答停止につながる。tmux + ローカル AI は断線に強い
  - **コスト**: クラウド計算資源・有料プランの上限に縛られない。長時間ループとの相性が良い
  - **権限境界の単純さ**: ローカルファイルシステムを直接扱うため、コンテナ越しの volume / port forwarding 設計が不要
- **vibemux 文脈**: Value #1「一発で整う」と Value #4「組織ごとAIで回す」を、追加インフラなしで成立させる

#### 注記

- VSCode の位置づけは Issue [#40](https://github.com/hirokimry/vibemux/issues/40) で扱う
- vibemux 自身のポジショニングは Issue [#41](https://github.com/hirokimry/vibemux/issues/41) で扱う
- Ghostty 以外のターミナルでも tmux ネイティブ機能のみに依存する vibemux のコア体験は損なわれない（Value #3）

### VSCode の位置づけ

AI が 100% コードを書く前提では、VSCode に依存していた機能の大半が「価値消失」「価値低下」または「元々 CLI で十分」に分類される。完全廃止ではなく、**daily driver からは外し、diff 確認専用ツールとして残す** のが現実的な着地点である。詳細な評価過程は [Issue #30 問い1](https://github.com/hirokimry/vibemux/issues/30#issuecomment-4297693682) を参照。

#### AI 100% 前提での機能再評価

| 機能 | 評価 | 根拠 |
|---|---|---|
| LSP（型補完・タイポ検知） | 価値消失 | AI がタイポも型エラーも自分で直すため、リッチエディタの最大の利点が真っ先に消える |
| inline diff accept UI（Claude Code 拡張） | 価値低下 | 自動レビュー + auto-merge が主経路。通常の確認は GitHub Web で十分で、**大規模 diff / 複数ファイル横比較のみ VSCode を使う** |
| 画像・PDF・Jupyter のインライン表示 | 条件付き必要 | Jupyter を使う場合のみ価値あり。画像・PDF はターミナル image protocol（Ghostty / kitty）で代替可 |
| Live Share | 限定的に必要 | 人間同士のペアプロ文化がある場合のみ。AI 駆動開発では Zoom / tmate で代替可 |
| GUI デバッガ | 限定的に必要 | 日常的に使わないなら不要 |
| linter / formatter / git / 全文検索 | 元々 CLI で十分 | Ghostty + tmux 環境で完結する |

#### 結論: daily driver から外し、diff 専用ツールとして残す

LSP の価値消失と inline diff の価値低下が大きく、VSCode をメインで使う必然性は失われた。一方で、大規模 diff の精読や複数ファイルの横並び比較といった例外ケースでは GitHub Web より UX が優れるため、補助ツールとしては残す。

#### Ghostty + tmux との役割分担

| 環境 | 役割 |
|---|---|
| Ghostty + tmux（メイン） | AI への指示・監視・意思決定・成果物検証（lazygit）・並列エージェント運用 |
| VSCode（補助） | 大規模 diff の精読、複数ファイル比較が必要な例外ケース |

### vibemux のポジショニング

vibemux は **AI 駆動開発の実行環境を再定義する存在** である。エディタ中心の旧来開発フローから、ターミナル + 並列エージェントを軸とする新しい開発フローへの転換を支える基盤として位置づける。

#### 背景: AI が 100% 書く前提での再評価

[Issue #30](https://github.com/hirokimry/vibemux/issues/30)（問い1）の決着により、AI が実装の 100% を書く前提では、エディタ中心の開発環境を構成する主要機能の価値が大きく低下することが確認された。

| エディタが提供してきたもの | AI 駆動前提での価値 |
|---|---|
| LSP・補完・リファクタリング支援 | 低下（AI がコードを生成・改修するため、人間の手書きが減る） |
| シンタックスハイライト・インデント | 低下（読むのは AI への指示と diff が中心） |
| 統合 Git クライアント | 重複（lazygit + AI への指示で代替できる） |
| マルチカーソル・スニペット | 不要化（AI に指示すれば一括変更可能） |

人間の主活動は **「AI への指示」と「変更の検証」** に集約される。指示は shell、検証は lazygit と diff でカバーできるため、エディタ中心モデルは前提として成立しなくなる。

#### vibemux が前提とする開発モデル

| 観点 | エディタ中心モデル | vibemux が前提とするモデル |
|---|---|---|
| 起点 | エディタを開く | `vibemux new` でコマンド1本で2ペインを立てる |
| 主活動 | コードを書く | AI に書かせる + 変更を検証する |
| ツール依存 | 特定エディタ + 拡張に依存 | エージェント・エディタ非依存 |
| 並列化 | エディタウィンドウの多重起動 | tmux ネイティブ（タブ・ペイン）+ AI 自律 |
| 終了 | エディタを閉じる | tmux ネイティブコマンド（`tmux kill-session` 等） |

#### MVV.md との対応

vibemux のポジショニングは `MVV.md` の各 Value を実体化する:

- **Value 1「一発で整う」** — `vibemux new` がコマンド1本で AI 駆動開発の場を立てる
- **Value 2「フローを切らない」** — shell + lazygit の2ペインで、指示と検証が同じ視野に収まる
- **Value 3「道具に縛られない」** — 特定エディタ・特定エージェントに依存しないため、AI ツールの世代交代に追従できる
- **Value 4「組織ごとAIで回す」** — 並列エージェント実行の基底環境として、tmux ネイティブの並列化に委ねる

#### vibemux が「再定義する」範囲

vibemux 自身は管理機能を持たない（[§vibemux の責務境界](#vibemux-の責務境界) 参照）。再定義の対象は **「最初の1画面の構成」** であり、起動後の運用は tmux と AI エージェントの自律性に委ねる。

これにより AI の書き方・並列化のパターンが進化しても、vibemux 側を変える必要がない。AI 駆動開発の実行環境としての普遍性をこの設計で担保する。

#### 関連

- [Issue #30](https://github.com/hirokimry/vibemux/issues/30)（問い1）— VSCode 代替不能機能の AI 駆動前提での再評価
- [Issue #40](https://github.com/hirokimry/vibemux/issues/40) — VSCode の位置づけ詳細
- [Issue #42](https://github.com/hirokimry/vibemux/issues/42) — Ghostty + tmux を推奨する理由
- [`MVV.md`](../MVV.md) — Mission / Vision / Values

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

- **目的**: AI の破壊的 tmux 操作を抑止する。Phase A では検知と警告を行い、Phase B で条件付きブロックを行う
- **実装**: PATH shim（`$PATH` 先頭に置く tmux ラッパー）を第1段として導入し、許可リスト判定と経路識別（shim/direct）を行う
- **ツール非依存**: Claude Code 固有の `permissions.deny` には依存しない（`MVV.md` Value #3「道具に縛られない」準拠）。Aider・Cursor・他の CLI エージェントでも同じガードレールが機能する
- **段階的防御**: 絶対パス直叩き等の bypass は2段階防御モデルで対処する（Phase A: 事後検知・警告のみ / Phase B: sandbox 統合時に条件付きブロック）

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
