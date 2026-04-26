# lazygit + delta 推奨設定ガイド

> **オプトイン設定です。** この設定は vibemux の動作に必須ではありません。lazygit の diff 表示を見やすくしたいユーザー向けのリファレンスです。delta を使わないユーザーには影響しません。

## 概要

[delta](https://github.com/dandavison/delta) は Rust 製の diff ビューアで、`git diff` や lazygit の diff 表示にシンタックスハイライトや行番号を追加できる。vibemux のワークスペース内で lazygit を使う際に、diff の視認性を向上させたい場合に設定するとよい。

## 1. delta のインストール

Homebrew でインストールする。

```bash
brew install git-delta
```

インストール後、`delta --version` で確認できる。

```bash
delta --version
```

## 2. ~/.gitconfig への delta 設定

`~/.gitconfig` に以下を追加する。

```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    line-numbers = true
    syntax-theme = Dracula

[merge]
    conflictstyle = zdiff3
```

### 主なオプション

| オプション | 説明 |
|---|---|
| `navigate` | `n` / `N` キーで diff のファイル間を移動できるようになる |
| `line-numbers` | diff に行番号を表示する |
| `syntax-theme` | シンタックスハイライトのテーマ（`delta --list-syntax-themes` で一覧を確認できる） |

`syntax-theme` は好みに応じて変更してよい。`Dracula` はダークターミナル向けの例。

## 3. lazygit の config.yml への pager 設定

lazygit の設定ファイルに pager を指定する。

### 設定ファイルのパス

macOS では lazygit の設定ディレクトリは以下の場所にある。

```text
~/Library/Application Support/lazygit/config.yml
```

パスは `lazygit --print-config-dir` で確認できる。

```bash
lazygit --print-config-dir
```

### 設定内容

`config.yml` に以下を追加する。

```yaml
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
```

### `--paging=never` について

lazygit は自身でページャを制御するため、delta 側のページャ（`less` 等）が有効になると表示が二重になる。`--paging=never` を指定して delta 側のページャを無効にすること。

## 4. 元に戻す方法

delta の設定を解除して元の状態に戻すには、以下の手順を行う。

### gitconfig から delta 設定を削除

`~/.gitconfig` から以下のセクションを削除する。

```ini
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    navigate = true
    line-numbers = true
    syntax-theme = Dracula
```

`[merge]` セクションの `conflictstyle` は delta と無関係に有用な設定なので、残してもよい。

### lazygit の pager 設定を削除

`config.yml` から `git.paging` セクションを削除する。

```yaml
# 以下を削除
git:
  paging:
    colorArg: always
    pager: delta --dark --paging=never
```

### delta のアンインストール（任意）

不要であれば delta 自体をアンインストールできる。

```bash
brew uninstall git-delta
```
