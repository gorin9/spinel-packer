# spinel-packer

[matz/spinel](https://github.com/matz/spinel) コミュニティ向けの最小パッケージング CLI。
1 つの Ruby スクリプト + 共通モジュールで **依存追加 / 更新 / 復元 / 内容ロック / 単一ファイル化** を提供。

本家 `spinel` コマンドには触らず、独立した補助ツールとして動作する。

## なぜ作ったか

- Spinel は AOT コンパイラで **`require` (gem ロード) を意図的にサポートしない**
- 唯一の依存解決は `require_relative` で **parse 時に inline**
- 既存の `rubygems` / `bundler` は移植不能 (eval/metaprog 不在で大半の gem が動かない)
- 結果として **エコシステムが薄い** — `optcarrot` ですら自前の `tools/pack-for-spinel.rb` を書いている

→ Crystal の `shards` や Go の `go mod` 相当の **最小限の vendoring + pack ツール** を提供する。

## 設計原則

1. **Zero ceremony**: `spinel app.rb` が動く前提を壊さない
2. **No registry**: GitHub URL がそのまま identifier (Go modules 風)
3. **vendor は .gitignore**: 開発者は `install` で取得、CI/本番は lock から復元
4. **Lockfile が真**: `Spinelfile.lock` の `tree_sha256` が改ざん検出の source of truth
5. **Ruby DSL**: `Spinelfile` は純 Ruby (TOML/YAML 不使用)
6. **`require_relative` のみ**: 新しい require 機構は作らない

## インストール

依存: Ruby (任意のバージョン)、git

```sh
git clone https://github.com/gorin9/spinel-packer.git ~/.local/spinel-packer
sudo ln -s ~/.local/spinel-packer/spinel-packer /usr/local/bin/spinel-packer
```

## 使い方

### サブコマンド一覧

```sh
spinel-packer install <repo>[@<ref>]   # 新規依存追加 (Spinelfile + lock + fetch)
spinel-packer install                   # Spinelfile.lock から厳密復元 (本番/CI)
spinel-packer upgrade <repo>[@<ref>]   # 既存依存を更新
spinel-packer lock                      # vendor/ → Spinelfile.lock 再生成
spinel-packer check                     # vendor/ と Spinelfile.lock の一致検証 (drift で exit 1)
spinel-packer pack <entry.rb> [-o O]   # require_relative を再帰展開し単一 .rb 化
spinel-packer version
```

### `<repo>` 表記

- `owner/repo` — `https://github.com/owner/repo.git` の shorthand
- `github.com/owner/repo` — 同上 (明示)
- `@<ref>` 省略時は `"main"` を解決
- `<ref>` はブランチ名、タグ名、または SHA

### 典型的なフロー

#### 開発者: 新規プロジェクト

```sh
$ spinel-packer install gorin9/spnl-web
  resolving gorin9/spnl-web@main ...
  resolved → 49cd5eb
  fetched gorin9/spnl-web into vendor/gorin9__spnl-web (13 files)
  Spinelfile + Spinelfile.lock updated
done.

$ cat Spinelfile
spinel "0.1"
use "gorin9/spnl-web", sha: "49cd5ebf1e9662ff28d08ee5241753cc4d6f0ba8"

$ cat Spinelfile.lock   # tree_sha256 付き
{...}
```

#### 開発者: 依存追加

```sh
$ spinel-packer install gorin9/spnl-json@v1.0   # tag 指定
```

#### 開発者: 依存更新

```sh
$ spinel-packer upgrade gorin9/spnl-web         # main の最新へ
$ spinel-packer upgrade gorin9/spnl-web@v2.0    # 特定タグへ
```

#### 本番/CI: 既存 lock から復元

```sh
$ spinel-packer install   # 引数なし = Spinelfile.lock を読む
  → gorin9/spnl-web @ 49cd5eb ...
    ok (tree verified)
done.
```

不一致 (lock 改ざんや依存 repo 改変) で **exit 1**。

#### CI 検証

```yaml
# .github/workflows/build.yml
- run: spinel-packer install    # vendor/ を lock 通り復元
- run: spinel-packer check      # 念のため一致確認
- run: spinel httpd_async.rb -o app
```

### ディレクトリ規約

```
myapp/
├── app.rb              ← エントリポイント
├── Spinelfile          ← マニフェスト (commit)
├── Spinelfile.lock     ← snapshot (commit, .lock も含む)
├── .gitignore          ← /vendor/ を除外
└── vendor/             ← .gitignore (ローカル生成、コミット不要)
    └── owner__repo/
        ├── .spnl-source
        └── *.rb
```

## Spinelfile (依存マニフェスト)

純 Ruby DSL。`install` / `upgrade` で自動編集される:

```ruby
spinel "0.1"

use "gorin9/spnl-web", sha: "49cd5ebf..."        # SHA 固定 (install 後)
use "gorin9/spnl-json", tag: "v1.0"               # tag 指定 (手書き)
use "gorin9/spnl-url", branch: "main"             # 可変 (非推奨)
use "git+http://internal/path.git", sha: "..."   # 他ホスト
```

各 `use` は **github.com/<user>/<repo>** を意味する。
他ホスト (GitLab, tatami) は `git+...` 形式で明示。

## 名前空間の運用

Spinel は `require_relative` 後すべて同一 AST に展開される。**名前衝突を避ける責任は
ライブラリ側**:

```ruby
# vendor/gorin9__spnl-web/web/json.rb
module SpnlWeb
  module JSON
    def self.encode(obj); ...; end
  end
end
```

利用側:
```ruby
SpnlWeb::JSON.encode({ x: 1 })
```

トップレベル `class JSON` は他のライブラリと衝突するリスクが高い。

## 何をしないか (意図的)

- ❌ **central registry** — GitHub URL で十分
- ❌ **semver 解決** — `^1.0` のような range は持たない (SHA / tag 指定のみ)
- ❌ **transitive 依存解決** — 各ライブラリが自分の `Spinelfile` + `vendor/` を持つ前提
- ❌ **gem ロード機構** — `require_relative` のみ
- ❌ **TOML/YAML** — `Spinelfile` (Ruby DSL) のみ
- ❌ **vendor/ コミット強制** — `.gitignore` 推奨、lock 復元が標準ワークフロー

## ファイル構成

```
spinel-packer/
├── README.md              この文書
├── LICENSE                MIT
├── spinel-packer          実行可能 Ruby スクリプト (350 行)
├── lib/
│   └── spinel_manifest.rb 共通: Spinelfile DSL parser (40 行)
└── docs/
    └── spec.md            詳細仕様 (日本語)
```

## 関連プロジェクト

- [matz/spinel](https://github.com/matz/spinel) — 本家 Spinel コンパイラ
- [optcarrot/tools/pack-for-spinel.rb](https://github.com/mame/optcarrot/blob/experiment/spinel/tools/pack-for-spinel.rb) — `pack` 機能のオリジン
- [gorin9/spnl-web](https://github.com/gorin9/spnl-web) — 本ツールで配布する最初の Web ライブラリ
- [gorin9/spinel-demo](https://github.com/gorin9/spinel-demo) — 本ツールを使った動作デモ
- [rubocop_spinel](https://github.com/gurgeous/rubocop_spinel) — Spinel 互換性チェック

## ライセンス

MIT

## 状態

**v0.2** (proof-of-concept). 本家未承認の community spec。
動作確認済: install / upgrade / install (lock 経由) / lock / check / pack (Debian bookworm + Ruby 3.3)。
