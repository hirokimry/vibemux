# 会話中の一時的な実装計画（git 追跡しない）
plans/
# アップデート時の 3-way マージ用ベーススナップショット
vibecorp-base/
# フック共通ライブラリ（テンプレートからコピーされる生成物）
lib/
# hooks/skills のランタイム state（worktree ごとに分離されるマーカー・ログ）
state/

# ---- machine-specific artifacts (migrate_tracked_artifacts で untrack 対象) ----
# 以下のマーカー配下は machine-specific artifact として扱う。
# install.sh の migrate_tracked_artifacts() が、旧バージョンで tracked 化
# されていた場合に `git rm --cached` で untrack する対象リストを
# ここから自動抽出する（Source of Truth: 本ファイル）。
# 追加時は `.claude/` プレフィックスなしで相対パスを記述する。
bin/claude-real
