# 組織運用ナレッジ

docs/ai-organization.md の組織構成と MVV.md から導出される、SM の判断基準。
AI組織構成は `docs/ai-organization.md` を参照すること。

## 組織構成

<!-- プロジェクトに合わせてエージェント構成を記述する -->

| ロール | 判断方式 | 管轄ドキュメント |
|--------|---------|----------------|
| SM（Scrum Master） | 単独判断 | docs/ai-organization.md |
| CTO | 単独判断 | docs/specification.md |
| CPO | 単独判断 | docs/specification.md |
| CFO + 経理チーム | 合議制（多数決） | docs/cost-analysis.md |
| CLO + 法務チーム | 合議制（全会一致） | docs/POLICY.md |
| CISO + セキュリティチーム | 合議制（全会一致） | docs/SECURITY.md |

## 管轄ファイルマッピング

<!-- 各エージェントの責任範囲と書き込み権限を記述する -->
<!-- role-gate.sh は docs/ 配下の書き込みのみを制御する -->

### docs/ 書き込み権限（role-gate.sh で制御）

| ロール | 書き込み可能な docs/ パス |
|--------|------------------------|
| CTO | docs/specification.md（技術スタック部分） |
| CPO | docs/specification.md（プロダクト仕様部分） |
| SM | docs/ai-organization.md |
| 分析員 legal | docs/POLICY.md |
| 分析員 accounting | docs/cost-analysis.md |
| 分析員 security | docs/SECURITY.md |

統括職（CFO, CLO, CISO）は role-gate.sh に個別ケースを持たず、docs/ への直接書き込み権限がない。統括職は分析員チームのメタレビューを行う立場であり、docs/ の更新は分析員が実行する。

SM は組織運営ドキュメント `docs/ai-organization.md` のみ書き込み可能。他の docs/ ファイルには権限を持たない。

### knowledge/ 書き込み権限

knowledge/ は role-gate.sh の制御対象外であり、全ロールが自分の配下ディレクトリに書き込み可能。

| エージェント | knowledge/ パス |
|-------------|----------------|
| CTO | .claude/knowledge/cto/ |
| CPO | .claude/knowledge/cpo/ |
| SM | .claude/knowledge/sm/ |
| CFO | .claude/knowledge/accounting/ |
| CLO | .claude/knowledge/legal/ |
| CISO | .claude/knowledge/security/ |

## ナレッジ配置場所

| ディレクトリ | 用途 |
|-------------|------|
| .claude/knowledge/cto/ | 技術判断原則・判断記録 |
| .claude/knowledge/cpo/ | プロダクト原則・判断記録 |
| .claude/knowledge/sm/ | 組織運用ナレッジ・判断記録 |
| .claude/knowledge/accounting/ | コスト判断基準・判断記録（CFO 管轄） |
| .claude/knowledge/legal/ | 法務判断基準・判断記録（CLO 管轄） |
| .claude/knowledge/security/ | セキュリティ判断基準・判断記録（CISO 管轄） |

## 段階的導入計画

<!-- プロジェクトの導入フェーズに合わせて記述する -->

| フェーズ | 内容 | エージェント |
|---------|------|------------|
| minimal | 基本開発フロー | なし（hooks + rules のみ） |
| standard | CTO + CPO レビュー | CTO, CPO |
| full | 全エージェント + 合議制チーム | SM, CTO, CPO, CFO, CLO, CISO + 分析員 |
