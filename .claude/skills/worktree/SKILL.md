---
name: worktree
description: "ワークツリーのライフサイクル管理スキル。一覧表示、マージ済みワークツリーの自動削除、手動削除を行う。「/worktree list」「/worktree clean」「/worktree remove」と言った時に使用。"
---

# ワークツリー管理

git worktree のライフサイクルを管理する。
**結果のみを簡潔に返すこと。途中経過は不要。**

## 使用方法

```bash
/worktree list
/worktree clean
/worktree remove <ブランチ名>
```

## サブコマンド

### list — ワークツリー一覧

全ワークツリーの状態を表示する。

```bash
git worktree list
```

各ワークツリーについて、ブランチ名でタイプを判定し、対応する情報を取得する。

#### ブランチタイプの判定

| パターン | タイプ | PR 確認 |
|---------|--------|---------|
| `worktree-agent-*` | Agent worktree | 不要（PR なし） |
| `dev/*` 等 | 通常 worktree | PR 状態を確認 |

#### 通常 worktree の PR 確認

```bash
gh pr list --head <ブランチ名> --state all --json number,state,title --jq 'if length > 0 then .[0] | ("#" + (.number | tostring)) + " " + (.state | ascii_downcase) + " " + .title else "- - -" end'
```

#### Agent worktree の状態判定

```bash
# 未コミット変更の有無
git -C <worktree_path> status --porcelain

# ベースブランチとの差分の有無
git -C <worktree_path> diff HEAD..origin/main --quiet
```

- 未コミット変更なし + 差分なし → `agent (孤立)`
- 未コミット変更あり or 差分あり → `agent (作業中)`

#### 返却フォーマット

```text
| パス | ブランチ | PR | 状態 |
|------|---------|-----|------|
| /path/to/worktree | dev/62_xxx | #123 | open |
| /path/to/worktree2 | dev/99_yyy | #456 | merged |
| .claude/worktrees/agent-abc123 | worktree-agent-abc123 | - | agent (孤立) |
| .claude/worktrees/agent-def456 | worktree-agent-def456 | - | agent (作業中) |
```

### clean — マージ済み・孤立ワークツリーの自動削除

マージ済みの PR に対応するワークツリー、および孤立した Agent worktree を自動削除する。

#### ワークフロー

1. `git worktree list` で全ワークツリーを取得（メインを除く）
2. 各ワークツリーのブランチ名でタイプを判定する

#### 通常 worktree（`dev/*` 等）の処理

3. ブランチについて PR の状態を確認する
4. `merged` 状態の PR に対応するワークツリーを削除対象とする
5. 削除前に未コミットの変更がないか確認する

```bash
# 未コミット変更の確認（worktree のパスで実行）
git -C <worktree_path> status --porcelain
```

6. 未コミット変更がある場合はスキップしてユーザーに報告する
7. 変更がない場合はワークツリーとローカルブランチを削除する

```bash
git worktree remove <worktree_path>
git branch -d <ブランチ名>
```

#### Agent worktree（`worktree-agent-*`）の処理

Agent worktree は PR を持たないため、以下の条件で削除を判定する:

3. 未コミットの変更がないか確認する

```bash
git -C <worktree_path> status --porcelain
```

4. ベースブランチとの差分がないか確認する（Agent が変更を残していないか）

```bash
git -C <worktree_path> diff HEAD..origin/main --quiet
```

5. **両方とも空**（未コミット変更なし + 差分なし）→ 孤立した Agent worktree として削除する

```bash
git worktree remove <worktree_path>
git branch -d <ブランチ名>
```

6. **いずれかが非空** → スキップしてユーザーに報告する（作業中 or 未プッシュの変更がある）

#### 返却フォーマット

```text
削除: dev/62_xxx (/path/to/worktree)
削除: worktree-agent-abc123 (.claude/worktrees/agent-abc123) [Agent]
スキップ: dev/100_zzz (未コミット変更あり)
スキップ: worktree-agent-def456 (作業中) [Agent]
---
削除: 2件, スキップ: 2件
```

### remove — 指定ワークツリーの手動削除

指定したブランチ名のワークツリーを削除する。

#### ワークフロー

1. `git worktree list` から指定ブランチのパスを特定する
2. 未コミット変更がないか確認する
3. 未コミット変更がある場合はユーザーに確認を求める
4. ワークツリーとローカルブランチを削除する

```bash
git worktree remove <worktree_path>
git branch -d <ブランチ名>
```

`-d` で削除できない場合（未マージ）はユーザーに報告して停止する。`-D` は使用しない。

#### 返却フォーマット

```text
削除: <ブランチ名> (<worktree_path>)
```

## 制約

- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）
- `git branch -D`（強制削除）は使用しない
- 未コミット変更があるワークツリーは自動削除しない
- メインワークツリーは削除対象から除外する
