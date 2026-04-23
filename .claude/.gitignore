# テンプレート管理ファイル（templates/ が source of truth）
hooks/
skills/
agents/
settings.json
vibecorp.lock

# 会話中の一時的な実装計画（#334 以降は ~/.cache/vibecorp/plans/<repo-id>/ に移行）
# 既存リポジトリに残る可能性がある `.claude/plans/` 残骸を追跡対象外にする
plans/
# アップデート時の 3-way マージ用ベーススナップショット
vibecorp-base/
# フック共通ライブラリ（テンプレートからコピーされる生成物）
lib/
# hooks/skills のランタイム state（#334 以降は ~/.cache/vibecorp/state/<repo-id>/ に移行）
# 既存リポジトリに残る可能性がある `.claude/state/` 残骸を追跡対象外にする
state/
# Claude Code 本体が生成するスケジュール情報（CronCreate durable 用）
# ユーザー固有のため他マシン・他ユーザーと共有しない
scheduled_tasks.json
scheduled_tasks.lock

# Claude Code per-user 設定
settings.local.json

# ---- machine-specific artifacts (migrate_tracked_artifacts で untrack 対象) ----
# 以下のマーカー配下は machine-specific artifact として扱う。
# install.sh の migrate_tracked_artifacts() が、旧バージョンで tracked 化
# されていた場合に `git rm --cached` で untrack する対象リストを
# ここから自動抽出する（Source of Truth: 本ファイル）。
# 追加時は `.claude/` プレフィックスなしで相対パスを記述する。
bin/claude-real
