---
name: commit
description: "Conventional Commits形式でのGitコミット自動化。変更を分析し、適切なコミットメッセージを生成してgit add + git commitを実行する。「/commit」「コミットして」と言った時に使用。"
---

# Git コミット自動化

変更を分析し、Conventional Commits形式でコミットを作成する。
**結果のみを簡潔に返すこと。途中経過は不要。**

## ワークフロー

### 1. リポジトリ情報の取得

```bash
gh repo view --json owner,name --jq '.owner.login + "/" + .name'
```

`REPO_OWNER/REPO_NAME` としてIssue URL組み立てに使用する。

### 2. 状態確認

```bash
git status
```

```bash
git diff --staged
```

```bash
git diff
```

```bash
git log --oneline -5
```

### 3. ステージング

特定ファイルを優先して `git add` する。`git add -A` は避ける。

### 4. コミットメッセージ生成と実行

**タイプ:** `feat`(新機能) / `fix`(修正) / `docs`(文書) / `style`(整形) / `refactor`(改善) / `test`(テスト) / `chore`(雑務)

**ルール:**
- 件名は命令形・ピリオドなし・最大30文字
- Issue番号はブランチ名から抽出（例: `dev/12345_feature` → #12345）
- 本文は変更内容を箇条書き

```bash
git commit -m "<type>: <subject>

https://github.com/{REPO_OWNER}/{REPO_NAME}/issues/{ISSUE_NUMBER}

- 変更内容1
- 変更内容2"
```

**HEREDOCやサブシェル展開 `$(...)` は使わないこと。** `-m` に直接文字列を渡す。

### 5. 確認

```bash
git log --oneline -1
```

## 制約

- `--force`、`--hard`、`--no-verify` は使用しない
- **jq では string interpolation `\(...)` を使わない** — 必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない
- `.env`、認証情報、シークレットはコミットしない
- 明示的な要求なしに `--amend` や `push` しない
- `git add -A` より特定ファイルのステージングを優先

## 返却フォーマット

```text
<commit-hash> <type>: <subject>
```
