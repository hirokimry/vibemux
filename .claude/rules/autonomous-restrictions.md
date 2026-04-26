# 自律実行不可領域

`/vibecorp:diagnose` → `/vibecorp:autopilot` → `/vibecorp:ship-parallel` の自律改善ループにおいて、**人間の明示的な承認が必須**で自動実行対象から除外しなければならない領域を定義する。

SM エージェントがこのルールに基づき `/vibecorp:diagnose` の候補をフィルタリングする（`/vibecorp:diagnose` ステップ6b）。

## 不可領域の定義

以下のいずれかに該当する改善候補は、SM が「除外」と判定しなければならない。

### 1. 認証

認証・認可の挙動を変更する候補。誤った変更は本体セキュリティを直接毀損する。

- `templates/claude/hooks/*auth*.sh`, `templates/claude/hooks/*permission*.sh`
- `settings.json` / `.claude/settings.local.json` の `permissions` セクション
- `gh auth`, `ANTHROPIC_API_KEY` の扱いを変更する候補

### 2. 暗号

暗号化・認証情報の永続化を扱う候補。誤った変更は情報漏洩につながる。

- `encrypt`, `decrypt`, `secret`, `credential`, `token` を扱うコード
- 認証情報のファイル保存パス・権限変更

### 3. 課金構造

コスト発生構造を変える候補。誤った変更は予算超過を招く。

- `docs/cost-analysis.md`
- `ANTHROPIC_API_KEY` を使う箇所、ヘッドレス Claude 起動方式
- `max_issues_per_day`, `max_issues_per_run` 等のコスト関連上限
- `claude -p`, `npx`, `bunx` で LLM を呼ぶ箇所

### 4. ガードレール

自律実行を制御するガードレール自体の変更。ここを緩めると他の不可領域に到達できてしまう。

- `templates/claude/hooks/protect-files.sh`
- `templates/claude/hooks/diagnose-guard.sh`
- `/vibecorp:diagnose` の `forbidden_targets` デフォルト値
- `~/.cache/vibecorp/state/<repo-id>/diagnose-active` スタンプの制御ロジック

### 5. MVV

プロダクトの根幹方針の変更。

- `MVV.md` 自体の変更

## 判定手順

SM エージェントは改善候補ごとに以下を判定する:

1. 候補の対象ファイル・変更内容を読み取る
2. 上記1〜5の不可領域に該当するかチェック
3. 該当する場合は「除外」と判定（理由として該当領域名を付記）
4. 該当しない場合は「通過」

## 人間承認ルート

不可領域の候補は自動起票対象から除外されるが、ユーザーが手動で Issue を起票して `/vibecorp:ship` で実装することは可能。Phase 5 の狙いは **自律実行を制限する** ことであり、人間による実装までは禁止しない。

## 関連

- Issue #284 Phase 5（#290）
- `/vibecorp:diagnose` ステップ6b
- `/vibecorp:autopilot` 前提条件
