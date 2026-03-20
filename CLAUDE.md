# CLAUDE.md

## 言語

- 応答は日本語で行う（コード・コミットメッセージ・PR本文は英語）

## プロジェクト概要

vibemux — tmux ベースのバイブコーディングワークスペースランチャー。
単一の bash スクリプト (`vibemux`) で構成される小規模プロジェクト。

## 開発ルール

### コーディング規約

- シェルスクリプトは `set -euo pipefail` を先頭に記述する
- すべてのスクリプトは `shellcheck` を通過すること
- 環境変数のプレフィックスは `VIBEMUX_`
- `.claude/rules/` 配下にパス固有のルールがある場合はそれに従う

### コミット

- [Conventional Commits](https://www.conventionalcommits.org/) 形式を使用する
- `feat:`, `fix:`, `test:`, `docs:`, `ci:`, `refactor:`, `chore:`
- コミットメッセージは英語

### ブランチ

- `dev/{issue番号}_{要約}` 形式でブランチを作成する
- main への直接 push は禁止（branch protection 設定済み）
- squash merge のみ許可

### 品質チェック

- コミット前: `make check` (shellcheck + tests) を実行する
- テストは `tests/` ディレクトリに `test_*.sh` として配置する

### セキュリティ

- 個人メールアドレスをコードやコミットに含めない
- シークレット、API キー、トークンをコミットしない
- `.env` ファイルをコミットしない
- git user.email は `noreply.github.com` アドレスを使用する
