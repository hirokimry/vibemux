# 法務監査ログ

## 2026-04-25 | Issue #31 tmux PATH shim Phase A 実装

- **対象範囲**: `.claude/bin/tmux`（新規 333 行）、`tests/test_tmux_shim.sh`（新規 366 行）、`tests/fixtures/fake-tmux`（新規 5 行）、`docs/tmux-guardrail.md`（編集）、`docs/tmux-kill-session-identification.md`（編集）、`Makefile`（編集）
- **差分ファイル**: `/tmp/issue31_diff.patch`（814 行）

### 検出事項とリスクレベル

| # | 内容 | リスク | 対応状況 |
|---|------|--------|----------|
| 1 | `docs/POLICY.md` がテンプレート状態で MUST/MUST NOT 未記述。ポリシー準拠チェック実施不能 | - | 未対応（プロジェクト既存問題） |
| 2 | `write_log()` がコマンド引数を `~/.cache/…/tmux-direct-exec.log` に平文保存。外部送信なし | 低 | 未対応（Phase AB 以降に再評価推奨） |
| 3 | 個人メールアドレス・固有名詞の混入 | なし | 対応不要 |
| 4 | 第三者コードの引用・転載 | なし | 対応不要 |
| 5 | 新規 OSS 依存パッケージの追加 | なし | 対応不要 |
| 6 | `test_tmux_shim.sh` の `|| true` 使用（シム本体コメントの禁止表現と微妙に矛盾） | Trivial | 未対応（法務リスクなし） |

### 総合判定

**問題なし**。ライセンス・著作権・個人情報外部漏洩のいずれも法的リスクなし。

## 2026-04-26 | Issue #70 vibecorp フレームワーク 0.22.0 → 0.22.2 アップグレード

- **対象範囲**: `.claude/settings.json`（permissions/marketplace 追加）、`docs/coderabbit-dependency.md`・`docs/file-placement.md`・`docs/team-permissions.md`（新規追加）、`skills/` 配下 26 ファイル削除（プラグインキャッシュへ移行）、`.claude/vibecorp.lock`（更新）
- **参照コミット**: `21b78e5`（0.21.3→0.22.0）、`4169729`（settings.json 再整理）、`280c8c7`（0.22.0→0.22.2）

### 検出事項とリスクレベル

| # | 内容 | リスク | 対応状況 |
|---|------|--------|----------|
| 1 | `plan-legal.md` 等の法務エージェント定義ファイルへの変更なし | なし | 対応不要 |
| 2 | `settings.json` への `permissions` 追加は `.claude/knowledge/`・`.claude/plans/`・`.claude/rules/` への Edit/Write 許可のみ。外部への情報送信なし | なし | 対応不要 |
| 3 | `extraKnownMarketplaces` に `hirokimry/vibecorp`（GitHub 公開リポジトリ）を追加。第三者リポジトリへの依存増加だが、既存 vibecorp 管理体制の延長であり新規法的リスクなし | 低 | 対応不要（`plugin-compliance.md` 記載の上流管理体制と一致） |
| 4 | スキルファイルのプラグインキャッシュへの移行はローカルコピー削除のみ。著作権・ライセンス上の変更なし | なし | 対応不要 |
| 5 | 新規追加 3 ドキュメント（`coderabbit-dependency.md`・`file-placement.md`・`team-permissions.md`）に個人情報・機密情報・第三者著作物の引用なし | なし | 対応不要 |

### 総合判定

**問題なし**。法務関連ファイル（`plan-legal.md` 等）への変更なし。ライセンス・著作権・個人情報漏洩のいずれも法的リスクなし。
