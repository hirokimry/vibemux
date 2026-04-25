---
name: issue
description: "GitHub Issue の起票を自動化。タイトル・本文からラベルを自動判定し、Assignees を設定して起票する。「/issue」「Issue作成」と言った時に使用。"
---

# 🎫 Issue 起票自動化

ユーザーから Issue 内容をヒアリングし、ラベル自動判定 + Assignees 設定で起票する。
**結果のみを簡潔に返すこと。途中経過は不要。**

## 📝 本文の書き方

Issue タイトル・本文は CEO が読むため `.claude/rules/communication.md` に従って**動作主語**で書く（「〜になった／〜できるようになった」）。関数名・ファイルパスを並べるのではなく、ソフトウェアのふるまいの変化を 30 秒で掴める形にする。

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

### 5. 🛡️ 3者承認ゲート（standard 以上）

vibecorp.yml が存在する場合のみ preset を確認する。

```bash
if [ -f "$CLAUDE_PROJECT_DIR/.claude/vibecorp.yml" ]; then
  awk '/^preset:/ { print $2 }' "$CLAUDE_PROJECT_DIR/.claude/vibecorp.yml"
fi
```

preset が `standard` または `full` の場合のみ、CISO + CPO + SM の3者で `.claude/rules/autonomous-restrictions.md` に定義された自律実行不可領域（認証 / 暗号 / 課金構造 / ガードレール / MVV）と、プロダクト方針の整合性を判定する。いずれかのエージェントが「除外」判定した場合は起票を中止する。

**責務分離の根拠**: `/vibecorp:autopilot` / `/vibecorp:ship-parallel` の自律ループが全 open Issue を対象とするため、不可領域の門番は起票側（本スキルと `/vibecorp:diagnose`）に集約する。ship 側は起票済み Issue を信頼して実行する。

#### 5a. CISO フィルタリング（不可領域チェック）

CISO エージェント（`.claude/agents/ciso.md`）に以下を依頼する:

```text
以下の Issue が `.claude/rules/autonomous-restrictions.md` の自律実行不可領域に該当するかチェックしてください:

タイトル: <タイトル>
本文: <本文>

不可領域:
1. 認証（hooks/*auth*, hooks/*permission*, settings.json の permissions, gh auth, ANTHROPIC_API_KEY 扱い）
2. 暗号（encrypt/decrypt/secret/credential/token を扱うコード）
3. 課金構造（docs/cost-analysis.md, max_issues_per_day 等のコスト上限, claude -p / npx / bunx で LLM を呼ぶ箇所）
4. ガードレール（protect-files.sh, diagnose-guard.sh, forbidden_targets, diagnose-active スタンプの制御）
5. MVV（MVV.md 自体の変更）

判定: OK または 除外（該当領域名を明記）
```

#### 5b. CPO フィルタリング（MVV / docs 整合）

CPO エージェント（`.claude/agents/cpo.md`）に以下を依頼する:

```text
以下の Issue がプロダクト方針に合致するかチェックしてください:

タイトル: <タイトル>
本文: <本文>

判定基準:
- MVV.md のバリューに沿っているか
- docs/specification.md / docs/design-philosophy.md と矛盾していないか
- プリセットスコープの整合（full 専用機能が適切にスコープされているか）

判定: OK または 除外（理由を明記）
```

#### 5c. SM フィルタリング（自律実行可否チェック）

SM エージェント（`.claude/agents/sm.md`）に以下を依頼する:

```text
以下の Issue が `.claude/rules/autonomous-restrictions.md` の不可領域に該当するかチェックしてください（CISO と独立に判定）:

タイトル: <タイトル>
本文: <本文>

不可領域5分類（認証 / 暗号 / 課金構造 / ガードレール / MVV）のいずれかに該当する変更を Issue が意図している場合は「除外」と判定し、該当領域名を付記してください。

判定: OK または 除外（該当領域名を明記）
```

#### 判定結果の扱い

- 3者全員が「OK」→ ステップ6（起票）へ進む
- いずれかが「除外」→ 起票を中止し、却下フォーマット（後述）で報告して終了する
- preset が `minimal`、vibecorp.yml が存在しない場合、または preset キーが未定義の場合 → このステップを全てスキップ（3者フィルタなし）

**minimal プリセットの安全性**: minimal では 3者フィルタが動作しないが、`/vibecorp:autopilot` / `/vibecorp:ship-parallel` が full プリセット専用のため、不可領域 Issue が自動実装される経路は存在しない。CEO が明示的に `/vibecorp:ship` を呼ぶ手動実装のみ可能で、これは CEO の意思による承認ルートとして許容される。

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

### 却下時（3者承認ゲート）

```text
❌ 起票を見送りました

### 判定結果
- CISO: {OK / 除外（理由）}
- CPO: {OK / 除外（理由）}
- SM: {OK / 除外（該当領域: 認証 / 暗号 / 課金構造 / ガードレール / MVV のいずれか）}

### 却下理由
<除外と判定したエージェントの理由を要約>

### 対処方針
- 不可領域に該当する場合: MVV に立ち返って Issue の目的を再検討するか、CEO による手動承認・実装を検討してください
- MVV 不整合の場合: MVV.md に照らし合わせて Issue タイトル・本文を修正してください
```
