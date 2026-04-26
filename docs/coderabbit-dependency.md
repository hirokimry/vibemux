# CodeRabbit 依存マップ

vibecorp の一部スキルは CodeRabbit に依存する。未導入でも基本機能は動作するが、一部のスキル・ステップがスキップまたは制限される。

## スキル別依存度

| スキル | 依存度 | 未導入時の挙動 |
|--------|--------|----------------|
| `/vibecorp:pr-review-loop` | **高** | スキップ（「対応不要」で即終了 + 案内表示） |
| `/vibecorp:review` | 部分 | `cr review --plain` がスキップされる。カスタムレビュアーのみ実行 |
| `/vibecorp:review-loop` | 間接 | `/vibecorp:review` 経由。cr CLI 不可時はカスタムレビュアーのみ |
| `/vibecorp:review-to-rules` | 部分 | CodeRabbit 指摘なし → 人間レビュアー指摘のみ対象 |
| `/vibecorp:ship` | 間接 | ステップ9（`/vibecorp:pr-review-loop`）がスキップ |
| `/vibecorp:pr` | なし | 影響なし |
| `/vibecorp:commit` | なし | 影響なし |
| `/vibecorp:branch` | なし | 影響なし |
| `/vibecorp:issue` | なし | 影響なし |
| `/vibecorp:plan` | なし | 影響なし |
| `/vibecorp:plan-review-loop` | なし | 影響なし |

## .coderabbit.yaml 設定値と /vibecorp:pr-review-loop の仕様要件の対応

`.coderabbit.yaml` の各設定値は `/vibecorp:pr-review-loop` の特定のステップが正しく動作するための前提条件である。以下に設定値・依存するステップ・理由・変更時の影響を示す。

| 設定キー | 設定値 | 依存するステップ | なぜこの値が必要か | 変更時の影響 |
|----------|--------|-----------------|-------------------|-------------|
| `reviews.request_changes_workflow` | `true` | 2.7（却下指摘の resolve）, 3（auto-merge 確認） | 指摘0件で approve、指摘ありで request changes、全 resolve 後に approve 切替という状態遷移が auto-merge 発動の前提。Branch Protection の「Require approvals」と連動して「レビュー通過 = マージ可能」を実現する | `false` にすると CodeRabbit が approve / request changes を出さなくなり、auto-merge が approve 不足で発動しない |
| `reviews.auto_resolve.enabled` | `true` | 2.6（修正実行）, 2.8（push） | push 時に修正済みコメントを CodeRabbit が自動 resolve する。`/vibecorp:pr-review-loop` の「修正した指摘は返信不要」方針の前提であり、手動 resolve の手間を排除する | `false` にすると修正済みの指摘が未解決のまま残り、ループが終了条件（未解決0件）を満たせなくなる |
| `reviews.auto_review.enabled` | `true` | 2.1（CodeRabbit レビュー待ち） | PR 作成時・push 時に CodeRabbit が自動でレビューを開始する前提。これが無効だとステップ 2.1 のポーリングでコメントが永遠に0件のまま5分経過し、未導入と誤判定される | `false` にすると自動レビューが実行されず、毎回「CodeRabbit 未導入」として扱われる |
| `reviews.auto_review.drafts` | `false` | 2.1（CodeRabbit レビュー待ち） | Draft PR ではレビューをスキップする。vibecorp は Ready for Review 状態の PR のみを対象とするため、Draft 段階でレビューコメントが付くとワークフローが混乱する | `true` にすると Draft PR にもレビューが付き、意図しないタイミングで修正ループが発生する可能性がある |
| `reviews.auto_review.auto_incremental_review` | `true` | 2.1（CodeRabbit レビュー待ち） | push 毎にインクリメンタルレビューが実行され、修正結果に対する追加指摘を検出できる。ループの各反復で新しいレビュー結果を取得する前提 | `false` にすると push 後の再レビューが実行されず、修正が正しいか検証されない |
| `reviews.path_filters` | `!**/*.lock` | 2.3（未解決スレッド取得） | lock ファイルへの指摘を除外し、修正不可能な自動生成ファイルへのノイズ指摘を防止する | フィルタを外すと lock ファイルへの指摘が増え、不要な却下処理が発生する |
| `chat.auto_reply` | `true` | 2.7（却下指摘への返信） | 却下理由の返信に CodeRabbit が自動応答し、スレッドの解決を促進する。返信がない場合でも動作するが、自動応答があるとスレッドの文脈が完結する | `false` にしても動作に支障はないが、却下スレッドの文脈が不完全になる |
| `language` | `ja-JP` | 2.4（妥当性検証） | レビュー指摘が日本語で出力されることで、`.claude/rules/review-criteria.md` に基づく妥当性判定を日本語で一貫して実行できる。`vibecorp.yml` の `language` と連動する | 言語を変更すると指摘の言語と rules の言語が不一致になり、妥当性判定の精度が低下する可能性がある |

### 設定値間の依存関係

上記の設定値は独立ではなく、組み合わせで `/vibecorp:pr-review-loop` のワークフローを成立させている。

```text
auto_review.enabled: true ──→ PR作成時にレビュー開始（ステップ2.1）
         │
auto_incremental_review: true ──→ push毎に再レビュー（ループ継続の前提）
         │
         ▼
request_changes_workflow: true ──→ 指摘あり = request changes
         │                          全resolve後 = approve
         │
auto_resolve.enabled: true ──→ push時に修正済みコメントを自動resolve
         │                      （手動resolveの手間を排除）
         ▼
Branch Protection: Require approvals ──→ approve = マージ可能
         │
         ▼
auto-merge 発動 ──→ マージ完了
```

この連鎖のどれか1つが欠けると、auto-merge によるマージ完了までのワークフローが成立しない。

## フォールバック挙動の詳細

### `/vibecorp:pr-review-loop`（依存度: 高）

CodeRabbit 未導入時は以下の流れになる:

1. ステップ 2.1（レビュー待ち）でコメント数が0のまま5分経過
2. **CodeRabbit 未導入と判断し、修正ループをスキップ**
3. auto-merge 状態を確認・設定
4. 結果報告に「CodeRabbit 未検出。Require approvals が有効な場合、人間による approve が必要です」と案内

修正ループが一度も回らないため、PR上のレビュー指摘修正は人間が手動で対応する前提になる。

### `/vibecorp:review`（依存度: 部分）

`cr` コマンドが利用できない場合:

- CodeRabbit CLI のレビューステップをスキップ
- レポートに「CodeRabbit CLI: 利用不可のためスキップ」と記載
- カスタムレビュアー（`vibecorp.yml` の `review.custom_commands`）があればそれのみ実行
- **カスタムレビュアーも未設定の場合、レビュー結果が0件になる**

### `/vibecorp:review-to-rules`（依存度: 部分）

- CodeRabbit 指摘の抽出はスキップ（`user.login` が CodeRabbit にマッチするコメントがない）
- **人間レビュアーの指摘は正常に収集・分析される**
- 人間レビュアーの指摘もない場合、「反映対象なし」で終了しスタンプを発行する

## Branch Protection との関係

### vibecorp 推奨構成（CodeRabbit あり）

```text
PR作成 → CodeRabbit 自動レビュー → approve → auto-merge → マージ
```

- **Require approvals**: ON（CodeRabbit の approve をゲートにする）
- **Required status checks**: `test`（CI 集約ジョブ）
- **Allow auto-merge**: ON

### CodeRabbit 未導入時

```text
PR作成 → auto-merge 設定 → 人間レビュー → 人間 approve → auto-merge → マージ
```

- **Require approvals**: ON のまま維持（人間の approve が必要）
- approve を外すと CI パスだけでマージされる＝レビューなしマージになるため非推奨
- auto-merge は人間の approve + CI パスで発動する

## CodeRabbit なしの実用ワークフロー

```text
/vibecorp:plan              → 計画策定
/vibecorp:review-loop       → ローカルレビュー（カスタムレビュアー or セルフ）
/vibecorp:commit            → コミット
/vibecorp:pr                → PR作成 + auto-merge 設定
                   → 人間がレビュー・approve
                   → auto-merge でマージ
```

`/vibecorp:pr-review-loop` と `/vibecorp:ship` のステップ9は実質スキップされるため、PR作成後は人間のワークフローに委ねる形になる。

## 設定方法

`vibecorp.yml` に以下を追加することで CodeRabbit を無効化できる:

```yaml
coderabbit:
  enabled: false
```

- **デフォルト**: `true`（キー未定義時も `true` として扱う）
- **`false` 設定時の効果**:
  - `install.sh` が `.coderabbit.yaml` を生成しない
  - `/vibecorp:pr-review-loop` が CodeRabbit レビュー待ちを即座にスキップ（5分待ち解消）
  - `/vibecorp:review` が CodeRabbit CLI セクションをスキップ
  - `/vibecorp:ship` のステップ9で CodeRabbit 関連処理がスキップされる
  - Branch Protection の required checks から `CodeRabbit` が除外される

## install.sh の挙動

`install.sh` は CodeRabbit の有無に関わらず動作する:

- `vibecorp.yml` の `coderabbit.enabled` が `false` の場合、`.coderabbit.yaml` を生成しない
- `coderabbit.enabled` が `true`（デフォルト）の場合、`.coderabbit.yaml` テンプレートを配置（既存ファイルがあればスキップ）
- Branch Protection の Required status checks に CodeRabbit を含めるかは `.coderabbit.yaml` の存在で `resolve_github_checks()` が判定
- CodeRabbit がない環境でもインストールは成功する
