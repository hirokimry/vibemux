# tmux kill-session 識別方式

> このドキュメントは vibemux における `tmux kill-session` の所有判定方式を定義する Source of Truth です。

## 背景

- Issue #30 問い3 で、PATH shim 経由の tmux 操作で `kill-session` は **条件付き許可**（AI が自分で作ったセッションのみ）と決定された
- その「AI 所有」を識別する方式を確定し、Issue #31（tmux ラッパー実装）が許可リスト設計に取り込めるようにすることが本ドキュメントのスコープ
- 本ドキュメントは設計のみを定義する。実装（shim 本体への組み込み）は #31 配下のフォローアップ Issue が引き取る

## スコープ

| 対象 | 扱い |
|---|---|
| shim を経由する `kill-session` の所有判定 | **本ドキュメントで定義** |
| shim をバイパスする経路（絶対パス直叩き、`command tmux`、`env tmux`、`tmux -C` REPL 等） | Issue #35「絶対パス直叩き対策」で扱う（事後検知 / sandbox 層） |
| `kill-server`、`set-option -g`、`set-hook`、`bind-key`、`detach-client`、`switch-client`、`synchronize-panes ON` | Issue #31 の絶対禁止リストで一律ブロック |

責任境界は明確に分離している。本識別方式が機能するのは「ユーザーが PATH shim 経由で tmux を呼び出している」前提のみであり、その前提の保証は #35 の責務である。

## 識別方式の選択肢

| 案 | 概要 | 採否 |
|---|---|---|
| A | セッション名プレフィックス命名規則（`vbx-` 等） | 採用（第 1 層） |
| B | tmux ユーザーオプション（`@vibecorp-owner=ai`） | 将来採用余地（Phase ABC） |
| C | 外部トラッキングファイル（TSV） | 採用（第 2 層） |
| D | 環境変数チェーン（`VIBECORP_SANDBOXED=1` 等） | **不採用**: `env -u` / `unset` で偽装可能 |

### 採用案: A + C のハイブリッド（多層識別）

`kill-session` の許可判定は **AND 条件**で行う:

1. **第 1 層（命名規則）**: 対象セッション名が `VIBEMUX_AI_SESSION_PREFIX`（デフォルト `vbx-`）で始まる
2. **第 2 層（トラッキングファイル）**: 対象セッション名が当該 `<repo-id>` 配下の TSV に登録されている
3. **両方を満たす場合のみ許可**

理由:

- 命名規則のみ → ユーザーが偶然・意図的に同じプレフィックスを使った場合に AI が誤って kill するリスクが残る
- TSV のみ → shim をバイパスした手動 `tmux new-session` の誤登録余地はないが、命名規則を加えることで `vibemux list` 等での視認性が向上し、人間が AI 作成セッションを一目で識別できる UX 効果を併せて得られる
- AND 条件 → どちらか片方しか満たさない偶発ケース（例: ユーザーが `vbx-` プレフィックスを偶然使ったが TSV には登録されていない）で誤許可を起こさない

将来 Phase ABC で案 B（tmux ユーザーオプション）を追加し、tmux 自体がメタデータを保持する形へ強化できる余地を残す（#31 の `set-option -t <session>` の許可可否が確定した時点で再評価）。

## 推奨案の詳細仕様

### 第 1 層: セッション名プレフィックス

- 環境変数: `VIBEMUX_AI_SESSION_PREFIX`
- デフォルト値: `vbx-`
- shim の `new-session` インターセプト時、ユーザーが指定した `-s <name>` に当該プレフィックスが付いていなければエラー終了するか、shim が自動付与する（具体動作は実装フェーズで確定。本設計では「プレフィックス必須」のみ規定）
- shim の `kill-session` インターセプト時、`-t` で指定されたセッション名がプレフィックスで始まることを検証
- **プレフィックス変更時の移行動作**: 未定義・ユーザー責任
  - 変更前に作成された TSV エントリは旧プレフィックスのまま残るため、変更後は当該エントリの `kill-session` 拒否が継続する
  - 運用上はユーザーが `tmux-ai-sessions.tsv` を手動でクリアするか、shim が変更を検知した場合に警告を出す（後者は実装フェーズで決定）

### 第 2 層: トラッキングファイル（TSV）

#### パス

```text
${XDG_CACHE_HOME:-$HOME/.cache}/vibecorp/state/<repo-id>/tmux-ai-sessions.tsv
```

`<repo-id>` 構成は `docs/design-philosophy.md`「ゲートスタンプの保存先」セクションの定義（`<sanitized-basename>-<sha8>`）と同一。並列エージェント・複数リポジトリの自然分離を担保する。

#### 行フォーマット

```text
<session-name>\t<created-at-iso8601>\t<creator-pid>
```

- `<session-name>`: shim が `new-session -s <name>` の `<name>` を `tr -cs 'A-Za-z0-9._-' '_'` でサニタイズした値
- `<created-at-iso8601>`: `date -u +%Y-%m-%dT%H:%M:%SZ` 形式
- `<creator-pid>`: shim 起動時の親プロセス PID（孤立エントリ判定の補助情報）

#### `<repo-id>` 計算ロジックの共有

shim は **`.claude/lib/common.sh` の `vibecorp_stamp_dir` 関数を `source` で再利用する**。例:

```bash
# shim 内で <repo-id> を取得する想定コード
if [ -f "$CLAUDE_PROJECT_DIR/.claude/lib/common.sh" ]; then
  # shellcheck source=/dev/null
  source "$CLAUDE_PROJECT_DIR/.claude/lib/common.sh"
  STATE_DIR="$(vibecorp_stamp_dir)"
else
  # フォールバック: shim 単体で同一アルゴリズムを再現
  # ハッシュ実装は common.sh の _vibecorp_sha256_short と同順
  # （shasum → sha256sum → openssl）でフォールバックすること
  TOPLEVEL=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  BASENAME=$(basename "$TOPLEVEL" | tr -cs 'A-Za-z0-9._-' '_')
  if command -v shasum >/dev/null 2>&1; then
    SHA8=$(printf '%s' "$TOPLEVEL" | shasum -a 256 | cut -c1-8)
  elif command -v sha256sum >/dev/null 2>&1; then
    SHA8=$(printf '%s' "$TOPLEVEL" | sha256sum | cut -c1-8)
  else
    SHA8=$(printf '%s' "$TOPLEVEL" | openssl dgst -sha256 | awk '{print substr($NF, 1, 8)}')
  fi
  STATE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/vibecorp/state/${BASENAME}-${SHA8}"
fi
```

両実装の同期テストは shim 実装フェーズで自動化する（`docs/design-philosophy.md` の `<repo-id>` アルゴリズムが変わった場合に shim 側も追従させる責務を明確化）。

#### flock の適用範囲

- **書込（`new-session` 登録 / 孤立エントリ掃除）**: flock で排他
- **読込（`kill-session` の所有確認）**: flock 配下に置かない（read-check-kill のアトミック化はしない）

性能と単純性を優先した判断。TOCTOU 残存リスクは「脅威モデル」セクションで開示する。

#### 孤立エントリ掃除のトリガー

shim が `new-session` で TSV に追記する**直前**に、以下を実行する:

1. `tmux list-sessions -F '#{session_name}'` で現存セッション名一覧を取得
2. TSV をスキャンし、現存しないセッション名のエントリを削除
3. 新規エントリを追記

掃除は flock 配下で実施（書込排他に含まれる）。`kill-session` 拒否経路では掃除をトリガーしない（拒否対象セッションを増やすことで TSV を肥大化させる悪意あるベクタを避けるため）。

## shim の `kill-session` 許可フロー（擬似コード）

```text
function shim_kill_session(args):
    # 1. 引数解析と即時拒否
    if len(args) == 0:
        deny("セッション名を指定してください", route="no-args")
    if "-a" in args:
        deny("-a による全削除は禁止されています", route="prefix-blanket")
    if "-t" not in args or count("-t", args) > 1:
        deny("セッション名の単一指定が必須です", route="prefix-target-required")

    target = parse_t_value(args)

    # 2. tmux ターゲット構文の拒否（名前以外を拒否）
    if target.startswith(":") or target.startswith("$") or target.startswith("="):
        deny("tmux ターゲット構文 ':idx' / '$id' / '=prefix' は許可されていません。リテラルなセッション名を指定してください", route="prefix-non-name-target")

    # 3. 第 1 層: プレフィックス検証
    prefix = env("VIBEMUX_AI_SESSION_PREFIX", default="vbx-")
    if not target.startswith(prefix):
        deny("'%s' は AI が作成したセッションではありません（プレフィックス不一致）", target, route="prefix-mismatch")

    # 4. 第 2 層: TSV 登録確認
    state_dir = compute_state_dir()  # vibecorp_stamp_dir or fallback
    tsv = state_dir + "/tmux-ai-sessions.tsv"
    if not tsv_contains_session(tsv, target):
        deny("'%s' は AI が作成したセッションではありません（TSV 未登録）", target, route="tsv-not-registered")

    # 5. 許可: 本物の tmux に委譲
    exec_real_tmux("kill-session", "-t", target)
```

### 拒否対象（常時）

| 条件 | 拒否理由 |
|---|---|
| 引数なし `kill-session` | 暗黙のカレントセッション破壊を防止 |
| `-a` フラグ | カレント以外を全 kill する操作を禁止 |
| `-t :<idx>` / `-t $<id>` / `-t =<prefix>` | tmux ターゲット構文。名前解決の曖昧さで意図しないセッションに当たる可能性 |
| `-t` の複数指定 | バッチ kill を禁止 |
| プレフィックス不一致 | 第 1 層の判定 |
| TSV 未登録 | 第 2 層の判定 |

### 拒否時のユーザー向けメッセージ仕様

- **出力先**: `stderr`
- **言語**: 日本語
- **終了コード**: `1`
- **メッセージ要件**: 拒否理由が一意に識別できること（運用ログから原因を特定できる粒度）

メッセージ例:

| 拒否理由 | メッセージ例 |
|---|---|
| 引数なし | `vibemux-shim: tmux kill-session を拒否しました: セッション名を指定してください` |
| `-a` フラグ | `vibemux-shim: tmux kill-session -a を拒否しました: 全セッション削除は許可されていません` |
| ターゲット構文 | `vibemux-shim: tmux kill-session を拒否しました: ターゲット '%s' はセッション名ではありません（:idx / $id / =prefix は使用不可）` |
| プレフィックス不一致 | `vibemux-shim: tmux kill-session を拒否しました: '%s' は AI 作成のセッションではありません（プレフィックス不一致）` |
| TSV 未登録 | `vibemux-shim: tmux kill-session を拒否しました: '%s' は AI 作成のセッションではありません（未登録）` |

文言は実装時に微調整可能。設計上の必須要件は「拒否理由が一意に識別できること」。

### 拒否ログの出力先

Issue #35 が採用する以下のログファイルに **統合** する:

```text
${XDG_CACHE_HOME:-$HOME/.cache}/vibecorp/state/<repo-id>/tmux-direct-exec.log
```

- レコードに `event=kill-session-denied` フィールドを付与し、#35 の `event=direct-exec` レコードと区別する
- 統合理由: tmux ガードレール関連の監査証跡を一元化することで、運用時の `tail -f` での観察と grep 抽出が容易になる
- #35 側のフィールド詳細が未確定でも、出力先は `tmux-direct-exec.log` に固定する。`event=kill-session-denied` を必須フィールドとし、追加フィールドは後方互換で拡張する

## 脅威モデル / バイパス経路

| シナリオ | 本設計（A+C） | 補完するレイヤ |
|---|---|---|
| `tmux kill-session vbx-foo` をユーザーが手動実行（プレフィックス偶然一致） | TSV 未登録で **拒否** | --- |
| `tmux kill-session vbx-foo` を AI が実行（正規登録済み） | プレフィックス一致 + TSV 登録 → **許可** | --- |
| `tmux kill-session non-vbx-name` を AI が実行 | プレフィックス不一致で **拒否** | --- |
| `tmux kill-session -a` | フラグ即時 **拒否** | --- |
| `tmux kill-session`（引数なし） | 即時 **拒否** | --- |
| `tmux kill-session -t :0` | ターゲット構文で **拒否** | --- |
| 絶対パス直叩き（`/usr/bin/tmux kill-session vbx-foo`） | shim 不通過 → **本設計は素通し** | **Issue #35** の事後検知（フック）/ sandbox 層 |
| ラッパー回避（`command tmux ...` / `env tmux ...` / `T=$(command -v tmux); $T ...`） | shim 不通過 → **本設計は素通し** | **Issue #35** のフック正規化 |
| `tmux -C ...` REPL 経由の `kill-session` | shim 不通過 → **本設計は素通し** | **Issue #35** と同じ層で抑止 |
| ユーザーが TSV を偽造（手動で行追加） | TSV 登録ありとみなされ許可される | **スコープ外**（信頼境界 = ユーザーアカウント） |

### AND 条件の論理根拠

「TSV 登録なし」 = 「shim 経由の `new-session` を経ていない」 = 「AI 作成ではない」 という推論が成り立つ前提を明示する。

前提が崩れるケース:

1. shim を経由したが TSV 書込前にプロセスが kill された（孤立 vs 未登録の区別が不能）
2. 孤立エントリ掃除直前に同名セッションが手動再作成された（誤って AI 所有と認識される可能性）

これらは **「拒否側に倒れる」** ように設計する（疑わしきは拒否）。誤許可（false positive: AI 所有ではないものを許可）よりも誤拒否（false negative: AI 所有のものを拒否）を許容する方針。誤拒否はユーザーが手動で `tmux kill-session` を直接呼べば解決可能だが、誤許可は復旧不能なため。

### TOCTOU リスク

「new-session の TSV 追記」と「kill-session の TSV 参照」の間にレースが残り得る。具体シナリオ:

1. プロセス A が `tmux new-session vbx-foo`（TSV 追記）
2. プロセス A が死ぬ
3. 孤立エントリ掃除前にプロセス B が `tmux new-session vbx-foo`（再作成、TSV 追記なし or 二重追記）
4. プロセス A の文脈で `kill-session vbx-foo` が実行される（B のセッションが kill される）

このリスクは **許容するリスク** として開示し、実装フェーズで以下の追加手当を検討する:

- TSV 追記時に既存エントリがあれば PID 上書きで重複を排除
- `kill-session` 時に対象セッションの起動時刻と TSV のタイムスタンプを照合（tmux の `#{session_created}` 等を利用）

## Phase 設計

| Phase | 構成 | 状態 |
|---|---|---|
| Phase A | 命名規則のみ（プレフィックスチェック） | **Issue #31 で実装済み**（`.claude/bin/tmux`） |
| Phase AB | + TSV 登録 / 孤立エントリ掃除 / flock | **本ドキュメントが規定する正式実装**。Issue #31 配下のフォローアップ Issue で対応 |
| Phase ABC | + tmux user-option（`@vibecorp-owner=ai`） | 将来拡張（#31 の `set-option -t <session>` 許可確定後） |

### Phase A 実装の差異

Issue #31 で実装した Phase A は本設計書の擬似コードのうち以下を採用している:

- **採用**: 引数構文チェック（`-a` / target-required / `-t` 複数 / `:` `$` `=` ターゲット構文拒否）
- **採用**: プレフィックスチェック（`${VIBEMUX_AI_SESSION_PREFIX:-vbx-}`、グロブ展開対策として `case` + クォート）
- **未採用（Phase AB に委譲）**: 第 2 層 TSV 登録確認 / 孤立エントリ掃除 / flock
- **追加実装**: `VIBEMUX_SHIM_QUIET_PHASE_A=1` で過渡期 WARN を抑制可能
- **追加実装**: prefix-mismatch 時に workaround ヒント（実体 tmux 直叩き or REPL）を stderr に出力

## `vibemux new` 経由セッションの扱い

`vibemux:75` で `tmux new-session -d -s "$session"` を実行している。ただし shim は呼び出し元（人間 / AI）を区別できないため、`vibemux new` 経由のセッションは **「厳密な所有判定ができないケース」** に分類する。

設計指針: 要件「AI が自分で作ったセッションのみ許可」と「疑わしきは拒否」方針に合わせ、**`vibemux new` 経由のセッションは shim の `kill-session` 許可対象外とする**。具体的には:

- `vibemux new` 経由の `new-session` は TSV に登録しない（AI 作成と確定できないため）
- 結果として shim 経由で当該セッションを `kill-session` しようとすると第 2 層（TSV 未登録）で拒否される
- 対話的なセッションの終了は shim 経由ではなく `tmux kill-session` 直接実行（shim 外）またはユーザー操作（`Ctrl-b :kill-session` 等）で行う

本ドキュメントを参照するユーザー向けに、この運用ルールを README で補足することが望ましい（後続 Issue で対応）。

## 関連

- [Issue #30](https://github.com/hirokimry/vibemux/issues/30) — vibemux プロダクト方向性の再検証（問い3で本設計の採用を決定）
- [Issue #31](https://github.com/hirokimry/vibemux/issues/31) — tmux ラッパー（PATH shim）の実装
- [Issue #34](https://github.com/hirokimry/vibemux/issues/34) — 本設計のトラッキング Issue
- [Issue #35](https://github.com/hirokimry/vibemux/issues/35) — 絶対パス直叩き対策の設計（兄弟）
- `docs/design-philosophy.md` 「ガードレール」「ゲートスタンプの保存先」セクション
- `MVV.md` Value #2「フローを切らない」、Value #4「組織ごと AI で回す」
