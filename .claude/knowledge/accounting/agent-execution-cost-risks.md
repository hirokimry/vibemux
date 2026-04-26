# エージェント実行コストリスク知見

PR レビューコメントから抽出したコスト・課金に関するノウハウ。

---

## 1. `team-auto-approve.sh` バイパスリスク（PR #27）

**出所**: CodeRabbit（自動レビュー） + レビュアー指摘

### 内容

`team-auto-approve.sh` にプロセス置換 `<(...)` / `>(...)` の検出漏れが存在する。
このフックはエージェント自動承認（ヘッドレス Claude 起動）を制御しているため、
バイパスされると **制御されない自律エージェント実行** が発生し、予期しない API コスト増大につながる。

### コスト影響

- 自動承認フックのバイパス → 無制限の `claude -p` / `npx` / `bunx` 起動 → 従量課金に直撃
- `max_issues_per_day` / `max_issues_per_run` 等の上限設定が機能しなくなる可能性

### 現状の扱い

vibecorp upstream の既知問題として追跡中（振る舞いは vibemux にあるが修正は vibecorp 側）。
本リポジトリでのローカル修正は `install.sh --update` で上書きされるため不可。

### コスト判断

**要監視（Major）**: フックバイパスは課金構造を直接毀損する。
vibecorp 本家での修正完了まで、自律実行ループ（`/autopilot`）の稼働時はコスト異常をモニタリングすること。

---

## 2. `.claude/` 管理ファイルとコストガバナンスの制約（PR #27, #43）

**出所**: レビュアー指摘 + CodeRabbit Learnings

### 内容

`.claude/` 配下のファイル（フック・エージェント定義含む）は
`vibecorp install.sh --update` による自動生成物として管理されている。
ローカルで加えたコスト制御の修正（レート制限、上限設定等）は、
次回 `install.sh --update` 実行時に**無音で上書きされる**。

スキルは `~/.claude/plugins/cache/vibecorp/` 配下のプラグインキャッシュから配布される方式に移行済みであり、
`.claude/skills/` はプロジェクトに存在しない。スキルのコスト制御変更も vibecorp upstream への反映が必要。

### コスト影響

- コスト制限の設定（`max_issues_per_day` 等）をローカルで変更しても次回更新で消える
- `.claude/hooks/` 内のガードレールも同様に上書き対象

### コスト判断原則

> `.claude/` 内のコスト関連設定変更は必ず vibecorp upstream に反映させること。
> ローカルパッチは「一時的な緩和措置」と認識し、upstream PR を同時に起票すること。

---

## 3. `session-harvest` スキルの LLM 呼び出しコスト（PR #43）

**出所**: レビュアー指摘

### 内容

`session-harvest` スキルは tmux セッションのサマリ生成に LLM を利用する。
スキルは `~/.claude/plugins/cache/vibecorp/` 配下のプラグインキャッシュから配布されており、
`.claude/skills/` にローカルファイルは存在しない。

### コスト影響

- セッションサマリ生成 = LLM 呼び出し = トークン消費（変動費）
- 高頻度実行（自動化ループ内での多用）はコスト増加につながる
- 呼び出し単価・頻度の把握が必要

### コスト判断

**要注意**: `/autopilot` や定期実行ループで `session-harvest` を頻繁に呼ぶ場合は
トークン消費量を事前に見積もり、`docs/cost-analysis.md` に計上すること。

---

## 参照

- PR #27（`.claude/hooks/` バイパス・ファイル管理ポリシー）
- PR #43（`session-harvest`・`ciso` エージェント）
- `docs/cost-analysis.md`（コスト構造の Source of Truth）
- `.claude/rules/autonomous-restrictions.md`（自律実行不可領域の定義）
