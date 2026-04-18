---
name: issue
description: "GitHub Issue の起票を自動化。タイトル・本文からラベルを自動判定し、Assignees を設定して起票する。「/issue」「Issue作成」と言った時に使用。"
---

# 🎫 Issue 起票自動化

ユーザーから Issue 内容をヒアリングし、ラベル自動判定 + Assignees 設定で起票する。
**結果のみを簡潔に返すこと。途中経過は不要。**

## 📋 ワークフロー

### 1. 🔍 リポジトリ情報の取得

```bash
gh repo view --json owner,name,defaultBranchRef --jq '.owner.login + "/" + .name'
```

リポジトリオーナーを Assignees のデフォルトに使用する。

```bash
gh repo view --json owner --jq '.owner.login'
```

### 2. 💬 ユーザーから Issue 内容を取得

以下をユーザーに確認する:

- **タイトル**: Issue の内容（タイプは自動付与するため不要）
- **本文**: Issue の詳細（Markdown 形式）

ユーザーが一度に両方提供した場合はそのまま使用する。

### 3. 🏷️ タイプ判定・ラベル自動付与

まずリポジトリの既存ラベル一覧を取得する。

```bash
gh label list --json name --jq '.[].name' --limit 100
```

次に、タイトルと本文のテキストからキーワードベースでタイプを判定し、対応するラベル候補を決定する。
タイプは Conventional Commits 形式と統一する。

| タイプ | 絵文字 | キーワード | ラベル候補 |
|-------|-------|-----------|-----------|
| `feat` | ✨ | 機能, 追加, 改善, feature, enhance | `enhancement` |
| `fix` | 🐛 | バグ, 不具合, エラー, bug, fix, crash | `bug` |
| `docs` | 📖 | ドキュメント, README, docs, 仕様書 | `documentation` |
| `test` | 🧪 | テスト, test, coverage, 検証 | `testing` |
| `refactor` | 🔄 | リファクタ, refactor, 整理, 統一, 移行 | `refactor` |
| `design` | 📋 | 設計, design, 計画, plan, スキーマ, 分析 | `design` |
| `chore` | ⚙️ | 雑務, 依存, chore, deps | — |
| `ci` | 🔧 | CI, workflow, pipeline, Actions | — |
| `security` | 🔒 | セキュリティ, 認証, protection, auth, gate | — |
| `perf` | ⚡ | パフォーマンス, 高速化, 最適化, performance | — |
| `agent` | 🤖 | エージェント, agent, 自律 | — |
| `integrate` | 🔌 | 統合, 連携, integration | — |
| `release` | 🚀 | リリース, 公開, publish, deploy | — |
| `template` | 📦 | テンプレート, template, プリセット | — |

**ラベル付与ルール**: 候補ラベルのうち、リポジトリに存在するものだけを付与する。存在しないラベルは除外する。

**タイトル形式**: `<emoji> <type>: <subject>`

- タイプはキーワードマッチで自動決定する
- 複数マッチした場合は最初にマッチしたタイプを採用し、存在するラベルは全て付与する
- マッチなしの場合はタイプなし（プレフィックスなし）、ラベルなしで起票する
- ユーザーが既にタイプ付きタイトルを入力した場合はそのまま使用する

### 4. 👤 Assignees 決定

1. `.claude/vibecorp.yml` に `issue.default_assignee` が定義されていればその値を使用
2. 未定義の場合はリポジトリオーナー（手順1で取得）を使用

### 5. 🛡️ CPO プロダクト整合チェック（standard 以上）

vibecorp.yml が存在する場合のみ preset を確認する。

```bash
if [ -f "$CLAUDE_PROJECT_DIR/.claude/vibecorp.yml" ]; then
  awk '/^preset:/ { print $2 }' "$CLAUDE_PROJECT_DIR/.claude/vibecorp.yml"
fi
```

preset が `standard` または `full` の場合のみ、CPO エージェント（`.claude/agents/cpo.md`）に以下を依頼する:

```text
以下の Issue がプロダクト方針に合致するかチェックしてください:

タイトル: <タイトル>
本文: <本文>

判定基準:
- MVV.md のバリューに沿っているか
- docs/specification.md / docs/design-philosophy.md と矛盾していないか
- プリセットスコープの整合（full 専用機能が適切にスコープされているか）

判定: OK または 却下（理由を明記）
```

- CPO が「OK」→ ステップ6（起票）へ進む
- CPO が「却下」→ 却下理由をユーザーに提示して終了する（起票しない）
- preset が `minimal`、vibecorp.yml が存在しない場合、または preset キーが未定義の場合 → このステップをスキップ

### 6. 🚀 Issue 起票

```bash
gh issue create --title "<emoji> <type>: <subject>" --body "<本文>" --assignee "<assignee>" --label "<label1>" --label "<label2>"
```

ラベルなしの場合は `--label` オプションを省略する。

### 7. ✅ 結果報告

起票した Issue の URL を返す。

## ⚠️ 制約

- **jq では string interpolation `\(...)` を使わない** — Bash 上で `\` がエスケープ文字、`()` がサブシェルとして解釈され、意図しない展開やパースエラーを引き起こすため。必ず `+` で結合する
- **コマンドをそのまま実行する** — `2>/dev/null`、`|| echo`、`; echo` 等のリダイレクトやフォールバックを付加しない（[根拠](docs/design-philosophy.md#コマンドリダイレクトフォールバックの禁止)）
- リポジトリに存在しないラベルは `--label` に渡さない（`gh issue create` がエラーになるため）
- `vibecorp.yml` が存在しない、または `issue.default_assignee` が未定義でも正常に動作すること

## 📤 返却フォーマット

### 通過時

```text
<Issue URL>
タイトル: <emoji> <type>: <subject>
ラベル: <付与したラベル一覧（なしの場合は「なし」）>
担当者: <assignee>
```

### 却下時（CPO ゲート）

```text
❌ 起票を見送りました
理由: <CPOの却下理由>
MVV観点: <どのバリューに抵触したか>
```
