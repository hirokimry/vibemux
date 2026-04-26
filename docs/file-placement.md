# ファイル配置ポリシー

vibecorp を導入したリポジトリにおける、各ディレクトリの役割と配置基準を定義する。

## ディレクトリ構造の全体図

```text
導入先リポジトリ/
├── MVV.md                      ← 方針層: 最上位方針
├── docs/                       ← 設計層: 公式ポリシー・仕様（Source of Truth）
├── knowledge/                  ← 設計層: 外部発信用ナレッジ（記事素材等）
├── skills/                     ← 実行層: ワークフロー定義（/vibecorp:xxx）
├── .claude/
│   ├── CLAUDE.md               ← プロジェクト指示
│   ├── agents/                 ← 実行層: エージェント宣言（who does what）
│   ├── knowledge/              ← 実行層: エージェント別の判断基準・記録
│   │   ├── cto/
│   │   ├── cpo/
│   │   └── ...
│   ├── hooks/                  ← 実行層: 機械的ゲート（規約の最後の砦）
│   ├── rules/                  ← 実行層: コーディング規約
│   ├── vibecorp.yml            ← プロジェクト設定
│   ├── vibecorp.lock           ← マニフェスト
│   └── settings.json           ← フック設定
├── tests/                      ← テスト
└── (プロジェクト固有のコード)
```

この構成は [3層アーキテクチャ](design-philosophy.md#3層アーキテクチャ) に対応する:

| 層 | ディレクトリ | 役割 |
|---|---|---|
| 方針層 | `MVV.md` | 全判断の最上位基準。ファウンダーのみ編集 |
| 設計層 | `docs/`, `knowledge/` | 仕様・ポリシーの Source of Truth |
| 実行層 | `.claude/`, `skills/` | エージェント・スキル・フック・ルールの定義 |

## 各ディレクトリの役割と配置基準

### `docs/` — 公式ポリシー・仕様

プロジェクト全体の Source of Truth。公式ポリシー・仕様・設計決定を記載する。

**置くもの:**

- 公式ポリシー・制約（MUST / MUST NOT 形式）
- プロダクト仕様書・アーキテクチャ設計
- セキュリティ・法務・コスト等の専門ポリシー
- 画面遷移・データライフサイクル等の設計ドキュメント

**置かないもの:**

- エージェント個別の判断基準 → `.claude/knowledge/` へ
- コーディング規約 → `.claude/rules/` へ
- 外部発信用のナレッジ記事 → `knowledge/` へ
- 一時的な議論・メモ → GitHub Issues へ

### `knowledge/` — 外部発信用ナレッジ

プロジェクトを通じて得たナレッジの蓄積。ブログ記事・Qiita 投稿等の素材として活用する。

**置くもの:**

- 一般向けの技術記事素材
- 開発プロセスの実践ナレッジ（他プロジェクトでも応用可能な知見）
- チュートリアル・ベストプラクティス集

**置かないもの:**

- プロジェクト固有の制約・ポリシー → `docs/` へ
- エージェント用の判断基準 → `.claude/knowledge/` へ

### `.claude/knowledge/` — エージェント別の判断基準・記録

各職種エージェントが判断する際の基準とナレッジ。`docs/` に定義されたポリシーを「エージェント固有の視点でどう解釈するか」を記載する。

```text
.claude/knowledge/
├── cto/
│   ├── tech-principles.md         ← 技術選定の判断基準
│   ├── skill-design-patterns.md   ← スキル設計の繰り返しパターン
│   └── hooks-design-patterns.md   ← フック設計の繰り返しパターン
├── cpo/
│   └── product-principles.md      ← プロダクト判断の優先順位
├── sm/
│   └── organization.md            ← 組織図・各エージェント管轄
├── legal/
│   └── legal-principles.md        ← 法務判断の優先順位
├── security/
│   └── security-principles.md     ← 脅威モデル・判断基準
├── accounting/
│   └── cost-principles.md         ← コスト構造・判断基準
└── （拡張可能）
```

**置くもの:**

- `docs/` ポリシーのエージェント視点での解釈ガイド
- レビューで繰り返し検出されたパターン（教訓の蓄積）
- 判断に迷った時の判定基準と優先順位
- エスカレーション基準（何を人間に上げるか）

**置かないもの:**

- 一般向けのナレッジ記事 → `knowledge/` へ
- エージェントのメタデータ（名前・ツール・モデル） → `.claude/agents/` へ
- 公式ポリシー → `docs/` へ

### `.claude/agents/` — エージェント宣言

エージェントのメタデータを定義する場所。「誰が何を担当するか」の宣言。

**置くもの:**

- エージェント定義ファイル（name, description, tools, model）
- 役割・責務の明記
- 管轄ファイルの一覧

**置かないもの:**

- 判断ロジックの詳細 → `.claude/knowledge/{role}/` へ
- ワークフロー定義 → `skills/`（Plugin ルート）へ

### `skills/` — ワークフロー定義（Plugin 名前空間）

Claude Code の `/vibecorp:xxx` として実行されるスキル。1スキル1ディレクトリ。Plugin ルート直下に配置する。

**置くもの:**

- `SKILL.md`（ワークフロー定義・実行フロー・条件分岐）
- 複数エージェントのオーケストレーション
- 出力フォーマットの定義

**置かないもの:**

- エージェントの判断ロジック → `.claude/agents/`, `.claude/knowledge/` へ
- 機械的なゲート制御 → `.claude/hooks/` へ

### `.claude/hooks/` — 機械的ゲート

Claude Code のイベントフックとして実行されるシェルスクリプト。規約の「最後の砦」として機械的に強制する。

**置くもの:**

- IF-THEN ロジックで実装可能な制約
- ファイル保護（protect-files.sh）
- ワークフロー強制（sync-gate.sh, review-gate.sh）

**置かないもの:**

- 人間の判断が必要な複雑ロジック → スキル化する
- コーディング規約 → `.claude/rules/` へ

### `.claude/rules/` — コーディング規約

全エージェント共通のコーディング規約。Claude Code が自動的に読み込み、全エージェントに適用する。

**置くもの:**

- Linter / Formatter では自動検出できないプロジェクト固有の規約
- 「何を書くか / 書かないか」のスタイル基準
- レビュー指摘から抽出された共通パターン

**置かないもの:**

- 公式ポリシー → `docs/` へ
- エージェント固有の判断基準 → `.claude/knowledge/` へ
- Linter が検出できる一般的なベストプラクティス

### `~/.cache/vibecorp/plans/<repo-id>/` — 実装計画

Issue 対応時の実装計画ファイル（#334 で `.claude/plans/` から移行）。

**置くもの:**

- `{ブランチ名}.md` 形式の計画ファイル
- Issue 駆動ワークフローの設計フェーズで生成

**置かないもの:**

- 設計思想・アーキテクチャ → `docs/` へ
- 進捗報告 → GitHub Issues / PR へ

**配置理由:**

- worktree 配下に書き込むと Claude Code の `.claude/` 書き込み確認ダイアログが parent session に届かず、teammate プロセスが応答しなくなる（Anthropic bug #25254）
- XDG キャッシュ配下に配置することでダイアログを回避しつつ、`<repo-id>` によって worktree 間でも一意の保存先が得られる

### `tests/` — 自動テスト

hooks・install.sh 等のシェルスクリプトの自動テスト。

**置くもの:**

- `test_*.sh` の命名規則に従うテストファイル
- CI で自動実行される前提のテスト
- hooks の追加時に同時追加するテストケース

**置かないもの:**

- アプリケーションコードのテスト → プロジェクト固有のテストディレクトリへ

## `docs/` と `.claude/knowledge/` の使い分け

この2つは混同しやすいが、役割が異なる。

| 観点 | `docs/` | `.claude/knowledge/` |
|---|---|---|
| 対象読者 | 全員（人間 + 全エージェント） | 特定の職種エージェント |
| 内容 | 公式ポリシー・仕様（「何をすべきか」） | 判断基準・解釈（「どう判断するか」） |
| 更新者 | 管轄エージェント or ファウンダー | 各職種エージェントが運用中に蓄積 |
| 例 | セキュリティポリシー（MUST/MUST NOT） | セキュリティエージェントの脅威モデル・判定基準 |

`docs/` が「憲法」なら、`.claude/knowledge/` は「判例集」。

## `knowledge/` と `.claude/knowledge/` の使い分け

| 観点 | `knowledge/`（ルート） | `.claude/knowledge/` |
|---|---|---|
| 用途 | 外部発信（記事・ブログ素材） | 内部判断（エージェントの意思決定支援） |
| 対象読者 | 一般の開発者 | 特定の職種エージェント |
| 汎用性 | 他プロジェクトでも応用可能 | プロジェクト固有 |

## `.claude/` の git 管理ポリシー

`.claude/` は **基本的に git で追跡する**。ただしファイルの出自によって追跡/除外を使い分ける。

### 追跡する理由

| 理由 | 説明 |
|---|---|
| チーム一貫性 | clone したら全員同じ rules/knowledge が揃う。各自が install.sh を実行する運用はバージョンずれの温床 |
| コードレビュー | rules や knowledge の変更が PR を通る。規約の変更がレビューなしで入るのは危険 |
| 再現性 | CI でも同じ設定が使える |
| update の一元管理 | 一人が `--update` → PR → マージ。全員が個別に update する運用は破綻する |

### ファイルの分類と追跡方針

`.claude/` 内のファイルは **出自** によって分類される。

| 分類 | 例 | source of truth | 追跡 |
|---|---|---|---|
| プロジェクト設定 | `CLAUDE.md`, `vibecorp.yml` | このファイル自体 | する |
| プロジェクト独自 | 独自の rules, knowledge | このファイル自体 | する |
| テンプレート由来 | hooks, skills, agents, settings.json, lock | `templates/` | 状況による（後述） |
| 一時ファイル | `~/.cache/vibecorp/plans/<repo-id>/` | 会話中に生成 | しない |

> **注意**: `memory/` は Claude Code がユーザーの HOME ディレクトリ（`~/.claude/projects/`）に保存するため、プロジェクトの `.claude/` 内には作られない。リポジトリ側での対処は不要。

### 導入先リポジトリの推奨構成

導入先リポジトリでは `templates/` ディレクトリが存在しない。hooks/skills/agents を含む全ファイルが `.claude/` 内の唯一のコピーであるため、**全て追跡するのが正しい**。

`install.sh` が `.claude/.gitignore` を自動生成する。実装計画は XDG パス（`~/.cache/vibecorp/plans/<repo-id>/`）に保存されるため、`.claude/plans/` は作成されない。

```text
# .claude/.gitignore（自動生成）
# ※ plans/ は ~/.cache/vibecorp/plans/<repo-id>/ に保存されるため除外不要
```

### テンプレートソースリポジトリの構成

vibecorp のようにテンプレートソース（`templates/`）を持つリポジトリでは、テンプレート由来ファイルが `templates/` と `.claude/` に二重存在する。`templates/` を source of truth として、`.claude/` 側のテンプレート由来ファイルは除外する。

```text
# .claude/.gitignore（テンプレートソースリポジトリ用）
# テンプレート管理ファイル（templates/ が source of truth）
hooks/
skills/
agents/
settings.json
vibecorp.lock

# 一時ファイル
# plans/ は ~/.cache/vibecorp/plans/<repo-id>/ に保存されるため除外不要
```

この構成により、プロジェクト独自の rules や knowledge は git 管理しつつ、テンプレートとの二重管理を避けられる。

### 個人設定

`settings.local.json`（Claude Code 公式機能）を使えば、チーム共有の `settings.json` を上書きせずに個人カスタマイズできる。これは Claude Code 自体が `.gitignore` 対象としているため、追加設定不要。

## 配置してはいけないもの

以下はどのディレクトリにも配置してはならない。

### 独自名前空間

`.claude/vibecorp/` のような独自ディレクトリは作らない。全ファイルを Claude Code の規約パス（`.claude/hooks/`, `.claude/agents/`, `.claude/rules/`）および Plugin ルート（`skills/`）に直接配置する。

### シークレット・認証情報

シークレット、トークン、APIキー、パスワードをコミットしない。git history に残ることも許容しない。

### 特定プロダクト名・ローカルパス依存

- 特定の別リポジトリやプロダクト名を直接記載しない
- 特定マシンのパスをハードコードしない
- 汎用的な表現（「導入先プロジェクト」等）を使う
