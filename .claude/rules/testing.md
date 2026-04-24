hooks やスクリプトを追加・変更した場合、`tests/` 配下に対応するテストを書くこと。

- テストファイルは `test_*.sh` の命名規則に従う
- テストは CI で自動実行される前提で書く
- 既存テストが壊れていないか確認してからコミットする
- 新しい hook を追加したらテストケースも同時に追加する

## 環境変数に依存する機能のテスト

`set -euo pipefail` 下で環境変数（`$TMUX` 等）の有無で挙動が変わる機能をテストする場合、`assert_exit` ヘルパーでは `unset` が効かない（同一シェルで実行されるため）。サブシェルで環境変数を制御する:

```bash
desc="TMUX unset で正常動作"
actual=0
(unset TMUX; "$VIBEMUX" new testsession /some/path) >/dev/null 2>&1 || actual=$?
```

逆に環境変数を設定する場合はコマンドプレフィックスで渡す:

```bash
TMUX=fake "$VIBEMUX" new testsession >/dev/null 2>&1 || actual=$?
```

## set -e 下でのテストスクリプトの早期終了

`set -euo pipefail` を使ったテストスクリプトで前提ファイルが存在しない場合は、`fail()` の呼び出しだけでは不十分。`fail()` は `FAILED` カウンタを増やすだけで `exit` しないため、後続のテストが不正な状態で継続する。

前提ファイル不在のように後続テストが全て無意味になる場合は、`fail()` の後に明示的に `exit 1` する。

```bash
if [[ -f "$SKILL_FILE" ]]; then
  pass "SKILL.md が存在する"
else
  fail "SKILL.md が存在しない"
  # 前提ファイル不在 → 後続テストは全て無意味なので即終了
  exit 1
fi
```
