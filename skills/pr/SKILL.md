---
name: pr
description: "GitHub PR作成・更新スキル。ユーザーが「/pr」「PR作成」「プルリクエスト作成」と言った時に使用。機能: (1) 既存PR確認と新規/更新モード判定、(2) ブランチ名からIssue番号自動抽出、(3) ベースブランチとの差分分析、(4) Issueリンクプレフィックス設定(ref/close)、(5) PRテンプレート自動生成、(6) PR作成/更新とブラウザ表示。オプション: --close, --ref でプレフィックス指定可能。"
---

# PR作成・更新

GitHub PRを作成・更新する。
**結果のみを簡潔に返すこと。途中経過は不要。**

## worktree モード

`--worktree <path>` が指定された場合、全操作を指定パス内で実行する。

- **Bash**: 全コマンドを `cd <path> && command` で実行する
- **Read/Write/Edit**: `<path>/` を基準とした絶対パスを使用する
- **サブスキル呼び出し**: `--worktree <path>` を引き継ぐ
- 未指定時は従来通り CWD で実行する（後方互換）

## ワークフロー

### 1. リポジトリ情報の取得

```bash
gh repo view --json owner,name,defaultBranchRef --jq '.owner.login + "/" + .name + " " + .defaultBranchRef.name'
```

`REPO_OWNER/REPO_NAME` と `DEFAULT_BRANCH` として保持する。

### 2. 既存PRの確認とベースブランチの特定

以下の優先順で検出する。

**1. 既存PRから取得（最優先）:**

```bash
gh pr view --json baseRefName,number --jq '.baseRefName + " " + (.number | tostring)'
```

取得できれば更新モード。`baseRefName` をベースブランチとする。

**2. merge-base で推定（新規PR時）:**

候補ブランチ（`DEFAULT_BRANCH`, 直近の feature ブランチ等）との merge-base を比較し、最も HEAD に近いものを選ぶ。

```bash
git merge-base HEAD origin/$DEFAULT_BRANCH
```

**3. デフォルト: `DEFAULT_BRANCH`（ステップ1で取得済み）**

### 3. Issue番号の抽出

ブランチ名から取得（例: `dev/12345_feature` → Issue #12345）

### 4. ベースブランチとの差分確認

```bash
git diff origin/$BASE_BRANCH...HEAD
```

```bash
git log --oneline origin/$BASE_BRANCH...HEAD
```

### 5. Issueリンクのプレフィックス決定

- `--close` オプション指定時: `close`
- `--ref` オプション指定時: `ref`
- 未指定時: ユーザーに質問する（デフォルト: `close`）

### 6. PRテンプレート作成

`.github/PULL_REQUEST_TEMPLATE.md` が存在すればそれを読み込み、差分分析に基づいて各セクションを埋める。
テンプレートが存在しなければ、以下の構成で本文を生成する:

- 概要（背景・課題 → Before/After → 懸念事項）
- Issueリンク

**概要の書き方:**

- PR タイトル・本文は CEO が読むため `.claude/rules/communication.md` に従って**動作主語**で書く（「〜になった／〜できるようになった」）
- マークダウンの見出し・区切り線・リストと状態絵文字（✅ / ⚠️ / 🚀 等）を活用し、読みやすくまとめる
- 動作の変化を中心に書く。実装詳細の優先度は低く、必要最小限に留める

**Issueリンクの書き方:**

```text
{prefix} https://github.com/{REPO_OWNER}/{REPO_NAME}/issues/{ISSUE_NUMBER}
```

### 7. PR作成/更新

**新規作成:**

```bash
git push origin HEAD && gh pr create --title "$ISSUE_TITLE" --body "$PR_BODY" --base "$BASE_BRANCH"
```

**auto-merge の有効化（新規作成時のみ）:**

```bash
gh pr merge --squash --auto
```

リポジトリ設定で auto-merge が無効の場合はスキップし、結果報告にその旨を記載する。

**更新:**

```bash
git push origin HEAD && gh pr edit $PR_NUMBER --title "$ISSUE_TITLE" --body "$PR_BODY"
```

**作成/更新後にブラウザで表示:**

```bash
gh pr view --web
```

### 8. /vibecorp:session-harvest の末尾同期呼出（preset standard 以上、新規 PR 時のみ）

PR 作成 + auto-merge 設定が完了した後、セッションで生まれた知見を `knowledge/buffer` に蓄積するため `/vibecorp:session-harvest` を末尾同期で呼ぶ。PR 作成フローはブロックしない（呼出順: PR 作成 → auto-merge 設定 → session-harvest）。

**新規 PR 時のみ実行**: ステップ2で `PR_NUMBER` が取得できた場合は既存 PR 更新であり session-harvest は呼ばない（同一セッションの知見が重複蓄積するのを防ぐ）。`PR_NUMBER` が空の場合のみ新規作成と判定する。

```bash
# 新規 PR の場合のみ実行（既存 PR 更新時はスキップ）
if [ -z "${PR_NUMBER:-}" ]; then
  PRESET="$(awk '/^preset:/ { sub(/^preset:[[:space:]]*/, ""); print; exit }' \
    "${CLAUDE_PROJECT_DIR:-.}/.claude/vibecorp.yml" 2>/dev/null || echo "")"
  case "$PRESET" in
    standard|full)
      # /vibecorp:session-harvest は minimal プリセットでは配置されないため standard 以上のみ
      if ! /vibecorp:session-harvest; then
        echo "[pr] /vibecorp:session-harvest が失敗しました（PR 作成は成功）" >&2
      fi
      ;;
  esac
fi
```

失敗しても PR 作成結果は成功扱い。呼出は末尾同期のため PR URL の返却前に完了する。

## 制約

- **PRタイトル**: `gh issue view {番号} --json title` で取得したIssueタイトルを使用
- **プッシュとPR作成の連結**: `&&` で連結実行
- **チェックボックス**: 自動でチェックしない
- **draftモード不使用**: レビュー可能な状態で作成
- **一時ファイル禁止**: 標準入力から body 設定
- `--force` は使用しない
- 明示的な要求なしに既存PRを閉じない
- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）

## 返却フォーマット

```text
{新規/更新} {PR URL}
```
