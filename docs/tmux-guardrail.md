# tmux ガードレール設計

> このドキュメントは AI エージェントによる tmux 操作を安全に保つためのガードレール方針を定義する Source of Truth です。
> 関連: [Issue #30 (問い3・問い4)](https://github.com/hirokimry/vibemux/issues/30) / [Issue #31](https://github.com/hirokimry/vibemux/issues/31) / [Issue #35](https://github.com/hirokimry/vibemux/issues/35)

## 目的と背景

vibemux は tmux を AI と人が同じ画面で開発するための土台と位置付けている（MVV.md）。AI エージェントが tmux に対して破壊的なコマンド（`kill-server`, `set-option -g`, `set-hook` 等）を発行すると、ユーザーのフローが回復不能なレベルで破壊される。

ガードレールの第一段は Issue #31 で実装する **PATH shim**（`$PATH` 先頭に置く `tmux` ラッパー）であり、許可リストを通過したコマンドのみ本物の tmux に委譲する。

しかし PATH shim は次の経路で容易にバイパスされる:

- `/usr/bin/tmux kill-server` のような **絶対パス直叩き**
- `command tmux ...` `env tmux ...` のような **組み込み・ラッパー経由**
- `$(command -v tmux)` 等で取得した実体パスへの **再 exec**
- シェル関数・エイリアスの上書き

このドキュメントは、これら絶対パス直叩き経路を検知・将来的にブロックするための 2 段階防御モデルを設計する。

## 脅威モデル

### 想定攻撃者

ユーザー権限で動作する AI エージェント（=「自分自身」）。意図せず破壊的コマンドを発行することが現実的なリスク。意図的な悪意ある攻撃者は信頼境界の外（ユーザーアカウント単位）として扱う。

### 攻撃シナリオ

| # | シナリオ | PATH shim 単体 | 本設計 Phase A | 本設計 Phase B |
|---|---|---|---|---|
| 1 | `tmux kill-server` | ブロック | （対象外） | （対象外） |
| 2 | `/usr/bin/tmux kill-server` | 素通し | 検知（警告） | ブロック |
| 3 | `command tmux kill-server` | 素通し | 検知（警告） | ブロック（解決後 `/usr/bin/tmux` の `process-exec` が拒否される） |
| 4 | `env tmux kill-server` | 素通し | 検知（警告） | ブロック（解決後 `/usr/bin/tmux` の `process-exec` が拒否される） |
| 5 | `T=$(command -v tmux); $T kill-server` | 素通し | 検知（警告・正規化後） | ブロック |
| 6 | `alias tmux=/usr/bin/tmux; tmux kill-server` | 素通し | 検知（警告） | ブロック |

> Phase B の判定は **解決後（exec 直前）の絶対パス**に対して行われる。`command` / `env` のようなラッパー経由でも、最終的に `/usr/bin/tmux` を exec しようとすれば sandbox-exec / bwrap の `(deny process-exec (literal "/usr/bin/tmux"))` ルールに引っかかってブロックされる。ただし shim ディレクトリ未経由でも tmux のインストール先が許可リストに無いケース（例: nix profile）では Phase B のフォールバック規則（regex）の有無で挙動が変わる点に留意する。

### 信頼境界

- 同一ユーザーアカウント内のプロセス間信頼 = 本設計のスコープ外
- ガードレールは「自分自身の事故防止」が主目的であり、`chmod` レベルの権限分離やプロセス署名検証は行わない

## 2 段階防御モデル

### Phase A: 事後検知（現時点）

- ログベース検知。実行は止めない（警告出力のみ）
- OS 非依存。macOS / Linux 双方で動作する
- vibecorp プラグイン未導入の vibemux 単体でも動作する

### Phase B: sandbox 統合（将来）

- `sandbox-exec`（macOS）/ `bwrap`（Linux）で `/usr/bin/tmux` への直接 exec をブロック
- OS 依存。`VIBECORP_ISOLATION=1` が有効な場合にのみ適用
- vibecorp プラグイン側の `claude.sb` プロファイルに統合する

### `VIBECORP_ISOLATION` が無効な環境での動作

- `VIBECORP_ISOLATION=1` 未指定 = passthrough モード
- Phase A は常時動作する（PATH shim と独立）
- Phase B は無効化される

## Phase A: 事後検知の設計

### 検知層の選択肢

| 選択肢 | 概要 | 利点 | 欠点 |
|---|---|---|---|
| **PreToolUse Bash フック** | `Bash` ツールの `tool_input.command` を解析 | リアルタイム警告、Claude Code セッション内に閉じる | Claude Code 経由でないシェル実行は捕捉できない |
| **command-log スキャナ** | `~/.cache/vibecorp/state/<repo-id>/command-log` を非同期スキャン | Claude Code 経由の全 Bash を網羅 | 事後検知のみ、リアルタイム警告は出ない |
| **両方併用** | PreToolUse でリアルタイム警告 + command-log で監査ログ | 即時性と網羅性を両立 | 実装コスト 2 倍 |

vibemux 単体（vibecorp 未導入）では `command-log` が存在しないため、**PreToolUse Bash フック方式を主、command-log スキャナ方式を vibecorp 統合時の補強**として採用する。最終的な配置先は Issue #31 実装時に確定する。

### コマンド正規化規則

`.claude/rules/shell.md` の「コマンド判定（フック内）」を踏襲し、判定前に以下の正規化を行う:

1. **環境変数プレフィックスの除去**
   `KEY=VALUE [KEY2=VALUE2 ...] CMD ARGS` の `KEY=VALUE` 列を取り除く
   - 例: `TMUX_TMPDIR=/tmp /usr/bin/tmux ls` → `/usr/bin/tmux ls`
2. **ラッパーコマンドの剥離**
   先頭が `env` / `command` / `exec` / `nice` / `nohup` / `time` / `timeout` の場合、それらの引数（`-` で始まるオプションを含む）を除去して次の単語を取り出す
   - 例: `command tmux kill-server` → `tmux kill-server`
   - 例: `env -u TMUX /usr/bin/tmux ls` → `/usr/bin/tmux ls`
3. **`basename` 正規化**
   先頭単語を `basename` で実体名に変換する
   - 例: `/usr/bin/tmux` → `tmux`
   - 例: `./tmux` → `tmux`
4. **判定**
   正規化後の先頭単語が `tmux` であれば tmux 実行とみなす

### 経路の区別

検知後、PATH shim 経由か絶対パス直叩きかを区別してログに記録する。

- **shim 経路**: 解決後の絶対パスが PATH shim ディレクトリ配下（例: `<vibecorp-bin>/tmux`）
- **direct 経路**: それ以外（`/usr/bin/tmux`, `/opt/homebrew/bin/tmux` 等）

判定例:

```bash
# 解決後パスの取得（shellcheck 準拠・引用必須）
resolved="$(command -v "$first_word" 2>/dev/null || true)"
case "$resolved" in
  "$VIBECORP_SHIM_DIR"/tmux) route="shim" ;;
  *) route="direct" ;;
esac
```

`VIBECORP_SHIM_DIR` は vibecorp が `templates/claude/bin/` 等に配置する shim ディレクトリ。vibecorp 未導入時は常に `direct` 扱いとなる。

### 警告出力

- **stderr 出力**: `vibemux: WARN tmux direct execution detected: <正規化後のコマンド> (route=<shim|direct>)`
- **ログファイル追記**:
  `${XDG_CACHE_HOME:-$HOME/.cache}/vibecorp/state/<repo-id>/tmux-direct-exec.log`
  形式: `<ISO8601 timestamp>\t<route>\t<正規化後のコマンド>`
- **`<repo-id>` 構成**: `docs/design-philosophy.md`「ゲートスタンプの保存先」セクションの仕様に従う

### 実行ブロックの可否

Phase A では **警告のみ・実行は止めない**。理由:

- MVV Value #2「フローを切らない」: 誤検知でユーザー作業を遮断するリスクを避ける
- Phase A はバイパス経路の **可視化** が目的であり、ブロックは Phase B（sandbox）に委譲する
- ユーザーが意図的に `/usr/bin/tmux` を使うケース（デバッグ・バージョン確認）を阻害しない

### 重複出力の抑制

PATH shim 経由の正規呼び出しでも先頭単語の `basename` は `tmux` になり、`route=shim` として検知される。この場合は WARN 抑止し、ログにのみ `route=shim` で記録する（あるいは抑止する）。Issue #31 と擦り合わせ最終決定する。

## Phase B: sandbox 統合の設計（将来）

### macOS（sandbox-exec / `claude.sb`）

vibecorp の `.claude/sandbox/claude.sb`（SBPL = Sandbox Policy Language）に以下のルールを追加することで、`VIBECORP_ISOLATION=1` 環境下で tmux バイナリへの直接 exec を拒否する。

```scheme
;; tmux 直接 exec を拒否し、shim 経由のみ許可
(deny process-exec*
  (literal "/usr/bin/tmux")
  (literal "/usr/local/bin/tmux")
  (literal "/opt/homebrew/bin/tmux"))

(allow process-exec*
  (subpath (param "VIBECORP_SHIM_DIR")))
```

- `process-exec*` は `process-exec` と `process-exec-interpreter` を含む包括ルール
- `(literal ...)` は完全一致のため、新しい tmux インストール先（例: nix profile, asdf）は別途許可リストに追加するか、以下のフォールバックを併用する:

```scheme
;; tmux という basename での exec 全般を拒否し、shim ディレクトリだけは個別許可
(deny process-exec
  (regex #"/tmux$"))
(allow process-exec
  (subpath (param "VIBECORP_SHIM_DIR")))
```

実装時は false-positive を避けるため、`literal` での明示列挙を優先し、`regex` フォールバックは opt-in（環境変数で有効化）とする。

### Linux（bwrap）— Phase 2 以降

bwrap（bubblewrap）でサンドボックス内のファイルシステム可視性を制御する。`/usr/bin/tmux` をダミーバイナリで読み取り専用バインドする方式が候補:

```bash
bwrap \
  --ro-bind / / \
  --ro-bind "$VIBECORP_SHIM_DIR/tmux" /usr/bin/tmux \
  --ro-bind "$VIBECORP_SHIM_DIR/tmux" /usr/local/bin/tmux \
  ...
```

- 利点: `$PATH` を介さずファイルシステムレベルで誘導するため、絶対パスでも shim が呼ばれる
- 欠点: ディストリビューション依存、bwrap 未導入環境での代替が必要
- スケジュール: macOS Phase B が安定したのち着手する

### `VIBECORP_ISOLATION` が無効な場合

- Phase B のルールは適用されない
- Phase A の警告ログだけが残る
- vibemux 単体運用では Phase A のみで運用する

## `VIBECORP_ISOLATION` との統合

### 既存の二重サンドボックス防止との関係

`docs/design-philosophy.md`「プロセス隔離（Phase 1 PoC）」で定義されているとおり、二重サンドボックス防止は `VIBECORP_SANDBOXED=1` + PPID チェーン検証の AND 条件で判断される。本設計の Phase B はこの判定を踏襲し、すでに sandbox 内で動作している場合は重複適用を行わない。

### sandbox 内での Phase A 動作

- Phase A の検知フックは sandbox 内でも動作する（書き込み先 `~/.cache/vibecorp/` は claude.sb の writable subpath に含まれる）
- ログの永続化先は sandbox 内外で同一の `<repo-id>` 配下となるため、隔離レイヤをまたいで監査可能

### `VIBECORP_ISOLATION` 未対応時のフォールバック

- vibemux 単体（vibecorp 未導入）では `VIBECORP_ISOLATION` は未定義
- Phase A はそれでも動作する（vibecorp に依存しない PreToolUse フック方式）
- Phase B は vibecorp の `claude.sb` プロファイル更新が必須なため、vibecorp 統合後にのみ有効化される

## エスケープハッチ

### 意図的な絶対パス利用

ユーザーがデバッグやバージョン確認のために `/usr/bin/tmux -V` を実行することは正当な利用である。Phase A は警告のみで実行を止めないため、特別な opt-out は不要。

### `VIBEMUX_GUARDRAIL_OFF` の是非

警告ログを完全に止めたいケース向けに `VIBEMUX_GUARDRAIL_OFF=1` を設ける案も検討したが、以下の理由で **採用しない**:

- 警告は実行をブロックしないため、UX 阻害がない
- opt-out 環境変数は誤って常時設定されるリスクがある（`.zshrc` 等）
- 必要な場合は `2>/dev/null` 等で個別に抑止可能

Phase B（実際にブロックするモード）を将来導入する際は、別途 `VIBECORP_ISOLATION` の有無で制御する（Phase B 自体が opt-in のため重複の opt-out は不要）。

## テスト戦略（実装時）

Issue #31（PATH shim 実装）または専用の実装 Issue で本設計を実装する際、`tests/test_tmux_guardrail.sh` を新規作成し以下のケースを検証する。

| # | ケース | 期待挙動 |
|---|---|---|
| 1 | `/usr/bin/tmux kill-server` を Bash ツールで実行 | WARN ログ + ファイルログに `route=direct` で記録 |
| 2 | `command tmux kill-server` を Bash ツールで実行 | 正規化後 `tmux kill-server` として検知、ファイルログに記録 |
| 3 | `KEY=val /usr/bin/tmux ls` を Bash ツールで実行 | 環境変数プレフィックス除去後、`route=direct` で検知 |
| 4 | PATH shim 経由（`tmux kill-server`）を実行 | shim による拒否が先行する。Phase A 側は `route=shim` で抑止 or 静音記録 |
| 5 | `env -u TMUX /usr/bin/tmux ls` を実行 | `env` 剥離 + 環境変数除去後、`route=direct` で検知 |
| 6 | サブシェル `(cd /tmp && /usr/bin/tmux ls)` | `cd` 部分はスキップし `/usr/bin/tmux ls` を検知 |
| 7 | `VIBECORP_ISOLATION=1` 下で Phase B を有効化したビルド | `/usr/bin/tmux` の exec が sandbox-exec で拒否される（macOS のみ） |

シェルテストは `set -euo pipefail` を前提とし、環境変数の有無による分岐は `.claude/rules/testing.md` に従いサブシェル内で制御する。

## 未解決事項・将来課題

- **シェル組み込み経由の bypass**: `type tmux` `which tmux` で取得したパスを別変数経由で exec した場合、Phase A の正規化では完全には捕捉できない。Phase B のサンドボックスでカバーする
- **スクリプト経由の exec**: ユーザーが書いたシェルスクリプト内から `/usr/bin/tmux` を呼ぶケースは、スクリプト全文を解析しないと検知できない。Phase A のスコープ外
- **macOS 以外の Phase B**: bwrap（Linux）対応は vibecorp の隔離レイヤ拡張と連動し、Phase 2 以降に着手する
- **shim ディレクトリ位置の絶対化**: `VIBECORP_SHIM_DIR` を sandbox-exec の `(param ...)` として渡す具体的な install.sh 改修は Issue #31 で扱う
- **誤検知時のサプレッション**: 大量の `direct` ログが出る環境で個別ルールを除外する仕組み（allowlist）は本設計のスコープ外。将来 `~/.config/vibemux/guardrail-allowlist` 等で対応する余地を残す

## 参照

- [`MVV.md`](../MVV.md) — 全判断の基準
- [`docs/design-philosophy.md`](./design-philosophy.md) — 「プロセス隔離（Phase 1 PoC）」「ガードレール」セクション
- [`docs/SECURITY.md`](./SECURITY.md) — セキュリティ全般
- [`.claude/rules/shell.md`](../.claude/rules/shell.md) — コマンド判定の正規化ルール
- Issue [#30](https://github.com/hirokimry/vibemux/issues/30) — vibemux プロダクト方向性の再検証（問い3・問い4）
- Issue [#31](https://github.com/hirokimry/vibemux/issues/31) — tmux ラッパー（PATH shim）の実装
- Issue [#35](https://github.com/hirokimry/vibemux/issues/35) — 本設計
