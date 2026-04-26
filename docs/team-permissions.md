# チームモードのパーミッション

## 概要

Agent Teams（`/vibecorp:ship-parallel` 等）でチームメイトを起動すると、Claude Code の既知バグ（[anthropics/claude-code#26479](https://github.com/anthropics/claude-code/issues/26479)）により `settings.local.json` の allow リストがチームメイトに継承されず、パーミッション確認が team lead に大量に飛ぶ。

vibecorp は **承認フローに介入しない** 方針を取る。詳細は `docs/design-philosophy.md` の「承認フローへの非介入」を参照。このドキュメントは、チームモードでの承認負荷をどう下げるかの実用ガイドである。

## vibecorp のスタンス

- vibecorp は Claude Code の承認フローを書き換える hook を提供しない（`team-auto-approve.sh` 相当の自動承認 hook は廃止済み: #336）
- 並列実行は full プリセットの `/vibecorp:ship-parallel` / `/vibecorp:autopilot` に限定される
- full プリセットを選んだユーザーは「並列 + 承認負荷」のトレードオフを理解している前提

## 並列実行時の承認負荷を下げる手段

### 推奨: sandbox + `--dangerously-skip-permissions`

full プリセットで sandbox を有効化した状態で `claude --dangerously-skip-permissions` を使うと承認ダイアログが発生しない。vibecorp の公式サポート範囲はこの組み合わせ。

```bash
# 例: ship-parallel から teammate を起動する場合
claude -p --permission-mode dontAsk --dangerously-skip-permissions --verbose "/vibecorp:ship-parallel <Issue URL>"
```

- `-p`（print mode）: 非対話、stdout に結果を出力して終了
- `--permission-mode dontAsk`: 親セッションへの承認要求を抑制する
- `--dangerously-skip-permissions`（呼び出し側で指定）: 全ツール呼び出しの承認をバイパス

### 自己調整オプション: `.claude/settings.local.json` の allow リスト

sandbox を使わないユーザーは、`.claude/settings.local.json` の `permissions.allow` に使用するコマンドを列挙することで承認ダイアログを減らせる。ただしチームメイトへの継承バグ（#26479）があるため、teammate 側にも同等の設定を配る必要がある。

```json
{
  "permissions": {
    "allow": [
      "Bash(git push:*)",
      "Bash(gh pr:*)",
      "Write(~/.cache/vibecorp/plans/**)"
    ]
  }
}
```

この設定は **ユーザー裁量** であり、vibecorp 本体はデフォルトで何も入れない。

## `--dangerously-skip-permissions` の扱い

| 項目 | 効果 |
|------|------|
| 粒度 | 全ツール呼び出し一律バイパス |
| 安全性 | sandbox なしで使うと危険 |
| 保護 hook との共存 | `protect-files.sh` / `block-api-bypass.sh` 等はフック側で `deny` を返せば依然として有効 |
| 推奨利用 | sandbox 有効環境での並列実行 |

## 背景: パーミッションの3つのレイヤー

Claude Code のパーミッション制御は **3つの独立したレイヤー** で構成される。

| レイヤー | 機能 | チームメイト継承 |
|---------|------|----------------|
| `--permission-mode` | パーミッションモード（`acceptEdits` 等） | **継承される**（公式記載） |
| `--enable-auto-mode` | AI 自律リスク判定による自動承認 | **未対応** |
| `settings.local.json` の `defaultMode` / `allow` | ファイルベースのパーミッション設定 | **継承されない**（#26479） |

### チームメイトに継承されないもの

- **`settings.local.json`**: `defaultMode: "bypassPermissions"` にしてもチームメイトは `acceptEdits` で起動する。`allow` リストも無視される
- **`--enable-auto-mode`**: 研究プレビュー段階。チームメイトへの伝播は未実装
- **Agent の `mode` パラメータ**: `"auto"`, `"bypassPermissions"` 等を指定してもチームモードでは無視される

## 関連する既知の問題

- [anthropics/claude-code#26479](https://github.com/anthropics/claude-code/issues/26479) — Agent Teams が bypassPermissions を無視 + settings.local.json 未継承（OPEN）
- [anthropics/claude-code#28584](https://github.com/anthropics/claude-code/issues/28584) — v2.1.56 以降サブエージェントが全ツールコールで承認要求（OPEN）
- [anthropics/claude-code#23983](https://github.com/anthropics/claude-code/issues/23983) — teammate の PermissionRequest hook が発火しない（OPEN）
- [anthropics/claude-code#18950](https://github.com/anthropics/claude-code/issues/18950) — スキル/サブエージェントが settings.json の権限を継承しない（OPEN）

## 今後の見通し

- `--enable-auto-mode` のチームモード統合が進めば、承認フローの扱いが大きく変わる可能性がある
- `settings.local.json` の継承バグが修正されれば、並列実行の承認負荷は自然に解消する
- [Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams) を定期的に確認すること
