---
name: spike-loop
description: "ship-parallel の E2E 検証を自動化する。ヘッドレス Claude で ship-parallel を起動し、command-log ベースで stuck 検出 → 診断 → kill → 再起動をループする。「/spike-loop」「並列検証」と言った時に使用。"
---

**ultrathink**

# spike-loop: ship-parallel 自動 E2E 検証

ヘッドレス Claude で `/ship-parallel` を実行し、command-log を監視して stuck 検出 → 診断スナップショット → kill + cleanup → 分析レポートを自律的にループする。

**full プリセット専用**。ship-parallel と同じく SM エージェントが必要なため。

## 使用方法

```bash
/spike-loop <Issue URL 1> <Issue URL 2> [...]
/spike-loop --max-runs 5    # 最大5回ループ（デフォルト: 3）
```

## 前提条件

- **full プリセット** であること
- `claude` CLI がインストール済みであること
- main ブランチにいること
- GitHub CLI (`gh`) が認証済みであること

## ワークフロー

### 1. 事前チェック

```bash
awk '/^preset:[[:space:]]*/ { sub(/^preset:[[:space:]]*/, ""); print; exit }' "$CLAUDE_PROJECT_DIR/.claude/vibecorp.yml"
```

`full` 以外の場合は「full プリセット専用です」と報告して終了。

```bash
git branch --show-current
```

main でない場合は「main ブランチに切り替えてください」と報告して終了。

### 2. ヘッドレス Claude の起動

Bash ツールの `run_in_background: true` でヘッドレス Claude を起動する。

```bash
claude -p --permission-mode dontAsk --verbose "/ship-parallel <Issue URL 1> <Issue URL 2> [...]"
```

- `-p` (print mode): 非対話、stdout に結果を出力して終了
- `--permission-mode dontAsk`: hook（`team-auto-approve.sh`）が permission を制御する。親セッションへの承認要求を抑制（参照: #260）
- `--verbose`: デバッグ情報を出力

起動後、PID を記録する。

### 3. stuck 監視ループ

command-log の最終タイムスタンプを 30 秒間隔でポーリングし、stuck を検出する。

```bash
# 最終タイムスタンプを取得
tail -1 "$CLAUDE_PROJECT_DIR/.claude/state/command-log" | cut -f1
```

#### 判定ロジック

| 条件 | 判定 | アクション |
|------|------|-----------|
| 最終タイムスタンプから 10 分以上経過 | stuck | ステップ 4 へ |
| 全 Issue の PR が作成済み | 成功 | ステップ 7 へ |
| ヘッドレス Claude プロセスが終了 | 完了（成功 or 失敗） | ステップ 6 へ |

#### 成功判定

各 Issue URL から Issue 番号を抽出し、`dev/{番号}` パターンのブランチで PR が存在するか確認する。

```bash
gh pr list --state open --head "dev/{番号}" --json number --jq '.[0].number'
```

全 Issue の PR が存在すれば成功。

### 4. stuck 時の診断スナップショット

stuck を検出したら、以下の情報を収集して保存する。

```bash
mkdir -p "$CLAUDE_PROJECT_DIR/.claude/state/spike-loop/run_{N}"
```

収集する情報:

```bash
# プロセスツリー
ps aux | grep claude > "$CLAUDE_PROJECT_DIR/.claude/state/spike-loop/run_{N}/processes.txt"

# command-log の末尾 50 行
tail -50 "$CLAUDE_PROJECT_DIR/.claude/state/command-log" > "$CLAUDE_PROJECT_DIR/.claude/state/spike-loop/run_{N}/command-log-tail.txt"

# worktree 一覧
git worktree list > "$CLAUDE_PROJECT_DIR/.claude/state/spike-loop/run_{N}/worktrees.txt"
```

### 5. kill + cleanup

stuck したプロセスと残存リソースを削除する。**各コマンドは 1 呼び出し単位で実行し、パイプで連結しない。** `--force` / `-D` は使用せず、安全に削除できないリソースは手動対応する。

**5-1. ヘッドレス Claude プロセスを kill**（PID を記録しているもの）

```bash
kill <PID>
```

**5-2. 残存 teammate プロセスの PID を取得**

```bash
pgrep -f 'claude.*agent-id'
```

取得した PID を 1 件ずつ `kill <PID>` で終了する（xargs 等のパイプラインは使わない）。

**5-3. worktree の一覧を取得**

```bash
git worktree list --porcelain
```

一覧から spike-loop の対象となる worktree（`worktrees/` 配下で `dev/` ブランチを持つもの）を特定し、1 件ずつ削除する:

```bash
git worktree remove <path>
```

`git worktree remove` は uncommitted 変更があると失敗する。失敗時はスナップショット（ステップ 4）で内容を保全してから、ユーザーに手動対応を求める（`--force` は使用しない）。

**5-4. dev/ ブランチの一覧を取得**

```bash
git branch --list 'dev/*'
```

各ブランチを 1 件ずつ削除する:

```bash
git branch -d <branch>
```

`git branch -d` はマージ済みブランチのみ削除できる。未マージのブランチは削除失敗となるため、ユーザーに手動対応を求める（`-D` は使用しない）。

### 6. 結果確認

ヘッドレス Claude が正常終了した場合（stuck ではなくプロセス終了）、成功判定を行う。

- 全 PR が作成済み → 成功（ステップ 7 へ）
- 一部の PR が未作成 → 失敗（スナップショットを取得してステップ 7 へ）

### 7. 分析・レポート

収集した findings を分析し、レポートを出力する。

```text
## /spike-loop 結果

### ループ {N}
- 状態: {成功 / stuck / 失敗}
- 経過時間: {分}
- command-log エントリ数: {件}
- 最終コマンド: {コマンド}
- PR 作成状況:
  - #{番号}: {作成済み / 未作成}
  - #{番号}: {作成済み / 未作成}

### stuck 分析（stuck の場合のみ）
- 最終コマンドの実行時刻: {タイムスタンプ}
- 無音時間: {分}
- 推定原因: {分析結果}
- スナップショット: .claude/state/spike-loop/run_{N}/

### 総合
- 実行回数: {N}/{最大}
- 成功: {回}
- stuck: {回}
- 失敗: {回}
```

成功の場合は、作成された PR の URL を一覧表示する。

### 8. 次のループ

stuck または失敗の場合、最大ループ回数に達していなければステップ 2 に戻る。

**修正の自動適用は行わない**（Phase 2 で対応予定）。分析レポートを出力し、ユーザーの判断を待つ。ユーザーが修正を指示した場合は、修正後に再度 `/spike-loop` を実行する。

## 制約

- `--force`、`--hard`、`--no-verify` は使用しない
- 修正の自動適用は行わない（分析レポートの出力まで）
- 最大ループ回数のデフォルトは 3 回
- findings は `.claude/state/spike-loop/` に保存する（gitignored）
- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない
- **Bash は 1 コマンド 1 呼び出しに分割する** — compound command は Claude Code 本体の built-in security check で止められるため（参照: #258）
