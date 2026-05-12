# Spinel パッケージング規約 (spinel-tools 草案 v0.1)

[matz/spinel](https://github.com/matz/spinel) のコミュニティ向け、
依存管理・配布の最小規約。本家未承認の **community spec**。

## 設計原則

1. **Zero ceremony**: 単独ファイル `app.rb` を `spinel app.rb` で動かせる現状を壊さない
2. **No registry**: GitHub URL がそのまま identifier。中央集約しない
3. **Vendor by default**: 依存は `vendor/` にソースで置く。コミットも歓迎
4. **Lockfile-less**: バージョンは manifest に直接書く (git SHA / tag / branch)
5. **Ruby DSL**: TOML/YAML を持ち込まない (Ruby DSL のみ)
6. **`require_relative` だけ**: 新しい require 機構は作らない (Spinel に書ける範囲)

## ディレクトリ規約

```
myapp/
├── app.rb              ← エントリポイント
├── Spinelfile          ← 依存マニフェスト (依存ゼロなら省略)
└── vendor/
    └── <user>__<repo>/   ← <user>__<repo> でディレクトリ名重複回避
        └── *.rb
```

理由:
- `vendor/<user>__<repo>/` 形式は **GitHub の user/repo 構造** に対応。
  `vendor/gorin9__spnl-web/web/json.rb` のような階層。
- `__` (double underscore) を separator にして `/` を避ける (file system 都合)。

## Spinelfile (依存マニフェスト)

純 Ruby DSL。Spinel 自身でも実行できる:

```ruby
# Spinelfile
spinel "0.1"   # spec バージョン

use "gorin9/spnl-web", sha: "abc1234"          # SHA 固定
use "ikasamt/spnl-json", tag: "v1.0"           # tag 指定
use "ikasamt/spnl-url", branch: "main"         # branch (mutable、非推奨だが許容)
```

各 `use` は **github.com/<user>/<repo>** を意味する。
他ホスト (GitLab, tatami) は明示 URL:

```ruby
use "git+http://tatami.internal/git/myorg/mylib.git", sha: "deadbeef"
```

## エントリポイントでの参照

```ruby
# app.rb
require_relative "vendor/gorin9__spnl-web/web/json"
require_relative "vendor/ikasamt__spnl-url/url"

# 自分のコード
class App
  ...
end
```

vendor 内ファイルは Spinel の `require_relative` で **parse 時に inline** される。
ランタイム require は不要。

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

明示モジュール名を切ること。トップレベル `class JSON` は他のライブラリと衝突する
リスクが高い。

## バージョン指定

Manifest の `sha:` / `tag:` / `branch:` のいずれか:

| 指定 | 性質 | 推奨度 |
|---|---|---|
| `sha: "abc1234"` | git commit SHA で完全固定 | ★★★ (再現性最高) |
| `tag: "v1.0"` | 不可変想定の git tag | ★★ (普通の運用) |
| `branch: "main"` | 可変 ref | ★ (デモ/実験用のみ) |

ロックファイル無しのため、**`sha:` が事実上のロック**。
依存を更新したい時は手動で SHA を書き換える。

## ツール `spinel-packer` (3 subcommand)

3 サブコマンドのみ:

### `spinel-packer vendor`

`Spinelfile` を読み、各 `use` 行を `vendor/` 配下に取得する。

```
$ spinel-packer vendor
  → gorin9/spnl-web @ abc1234 ... ok (12 files)
  → ikasamt/spnl-url @ v1.0   ... ok (2 files)
done.
```

- `sha:` 指定: `git clone --depth 50` → checkout SHA → `.git/` 削除
- `tag:` 指定: `git clone --depth 1 --branch <tag>` → `.git/` 削除
- `branch:` 指定: 同上、branch を指定
- 既に vendor に存在し SHA が一致 → skip
- 不一致 → 上書き (警告表示)

### `spinel-packer lock` / `spinel-packer lock --check`

`vendor/` 配下の現状を `Spinelfile.lock` (JSON) に出力。
監査・再現性確認用:

```json
{
  "spinel_version": "0.1",
  "generated_at": "2026-05-11T...",
  "deps": [
    {
      "name": "gorin9/spnl-web",
      "sha": "abc1234567...",
      "file_count": 12,
      "sha256": "deadbeef..."
    },
    ...
  ]
}
```

`Spinelfile.lock` はコミット推奨。`git diff` で依存更新の影響を確認できる。

#### `--check` モード (CI 用)

```
$ spinel-packer lock --check
OK: vendor/ は Spinelfile.lock と一致 (3 deps)
```

ローカル vendor/ がコミット済みの Spinelfile.lock と一致するか検証する。
不一致なら exit 1 + どの dep が drift してるかを diff 表示。

用途:
- CI で「誰かが vendor/foo/bar.rb をいじって commit した」を検出
- リリース前に「環境が再現可能か」確認

### `spinel-packer pack`

`require_relative` を再帰的に展開して **単一 .rb ファイル** を出力。
optcarrot の `tools/pack-for-spinel.rb` を一般化したもの。

```
$ spinel-packer pack app.rb > dist/app-single.rb
$ spinel dist/app-single.rb
```

用途:
- 配布: vendor/ を含まない 1 ファイルだけ送りたい
- inspect: inline 後の形を読みたい
- 互換: spinel コマンドが手元に無い環境に Ruby ソースとして送る

## 何をしない (意図的)

- ❌ **central registry** — GitHub URL で十分
- ❌ **`Spinelfile.lock` 自動生成** — `sha:` を manifest に書く運用、必要時のみ `spinel-packer lock`
- ❌ **semver 解決** — `^1.0` のような range は持たない (タグか SHA 固定のみ)
- ❌ **transitive 依存解決** — 各ライブラリが自分の `Spinelfile` を持って `vendor/` を持つ
  → アプリケーションは flat に `vendor/<user>__<repo>` を見るだけ
- ❌ **gem ロード機構** — `require` は実装しない、`require_relative` のみ
- ❌ **設定ファイル** — `spinel-tools.toml` 等は無い、`Spinelfile` のみ

## なぜこの設計か

| 設計判断 | 理由 |
|---|---|
| GitHub URL = identifier | Go modules と同じ、registry インフラ不要 |
| Ruby DSL manifest | Rakefile/Gemfile と同じ世界観、Ruby 利用者に馴染みやすい |
| vendor をコミット推奨 | mruby/Spinel と同じく「依存を消さない/動かさない」前提 |
| transitive 解決しない | ライブラリ間の version conflict を発生させない |
| `spinel app.rb` 単体で動く | spinel-tools は **optional layer**、必須にしない |

## 移行例: 現在の `web/` を `spnl-web` repo に切り出す

Before:
```
myapp/
├── httpd_async.rb
├── helper.c
└── web/
    └── *.rb (date.rb, logger.rb, ...)
```

After:
```
myapp/
├── httpd_async.rb       # require_relative "vendor/me__spnl-web/web/date" etc.
├── helper.c
├── Spinelfile           # use "me/spnl-web", sha: "..."
├── Spinelfile.lock      # 自動生成
└── vendor/
    └── me__spnl-web/
        ├── helper-include/  (C ヘッダなど)
        └── web/
            └── *.rb
```

別 repo `me/spnl-web` のソースをそのまま vendor/ に展開。
`spinel-packer vendor` で取得、`spinel httpd_async.rb` でビルド。

## ツールの命名方針

`spinel` という名前は本家コンパイラ専用。**触らない**。

本ツールは独立した 1 バイナリ `spinel-packer` として配布。
git/docker と同じく **subcommand パターン**:

```
spinel-packer vendor       # 依存を vendor/ に取得
spinel-packer lock         # vendor/ 状態を JSON 固定 (オプション)
spinel-packer lock --check # CI 用の drift 検証
spinel-packer pack <e.rb>  # 単一 .rb 化
```

理由:
- `spinel-foo` を複数置くと混乱しやすい (`-vendor` `-lock` `-pack`...)
- subcommand 化で「これはパッケージ管理ツール (`packer`) です」が明示される
- 1 ファイルで配布できる → `curl ... > ~/bin/spinel-packer` の 1 行で install

## 実装規模

pure Ruby + 標準コマンド (`git`, `tar`, `sha256sum`) のみで:

| ファイル | 行数 |
|---|---|
| `lib/spinel_manifest.rb` (DSL parser, 共通) | 約 40 |
| `spinel-packer` (dispatcher + 3 subcmd) | 約 200 |
| **合計** | **約 240 行** |

→ tarball / `curl` で配布、`~/bin/spinel-packer` + `~/bin/lib/spinel_manifest.rb`
で動く。Spinel 本体への install は不要。

## 制限事項 (v0.1)

- Windows 未対応 (git / tar 前提)
- HTTP 認証付き repo は環境変数 (`GIT_TOKEN` 等) に依存
- バイナリ依存 (`.a`, `.so`) はサポート外、Ruby ソースのみ
- C ヘルパファイル (`.c`) 取り込みは慣習的に `helper.c` という名前にする、CLI は関知しない

## 関連プロジェクト

- [optcarrot/tools/pack-for-spinel.rb](https://github.com/mame/optcarrot/blob/experiment/spinel/tools/pack-for-spinel.rb) — pack 機能のオリジン
- [rubocop_spinel](https://github.com/gurgeous/rubocop_spinel) — Spinel 互換性チェック
- (TBD) `spnl-web`, `spnl-json`, `spnl-url` — このスペックに沿った最初のライブラリ群
