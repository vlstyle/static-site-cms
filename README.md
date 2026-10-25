# static-site-cms

Git をバックエンドにした広報向け静的サイト（お知らせ・イベント・ブロック型ランディングページ）の共通部品。[Astro](https://astro.build/) と [Sveltia CMS](https://sveltiacms.app/) を使う。コンテンツは別のリポジトリ（サイトリポジトリ）に置き、このリポジトリを依存として参照する。

## 役割分担

見た目とコンテンツモデルはサイトリポジトリが持ち、コアは基盤だけを提供する。

| 置き場所 | 内容 |
|---|---|
| サイトリポジトリ | レイアウト・ブロックのコンポーネント・ページ・コンテンツのスキーマ（`src/`）、管理画面のコレクション定義（`cms/collections.yml`）、コンテンツ |
| コア（このリポジトリ） | 公開判定などの共通関数（`static-site-cms/published`）、Astro integration、管理画面の共通設定と生成（`cms-build-admin`）、CIチェック（`cms-path-guard`・`cms-check-files`）、再利用 workflow、動くスターター（`examples/site`） |

ブロックを追加・変更するときは、サイトリポジトリの3か所を揃える。

1. `src/content.config.ts`（zodのスキーマ）
2. `src/components/blocks/`（コンポーネント）
3. `cms/collections.yml`（Sveltia CMSの入力フォーム）

## サイトリポジトリの作り方

[`examples/site`](examples/site) をコピーして始める。`cms.config.json` の `repo` を自分のリポジトリに変え、`package.json` の `static-site-cms` をコミット固定のgit依存にする。

```
package.json            # astro と static-site-cms（コミット固定のgit依存）
astro.config.mjs        # integrations: [staticSiteCms()]
cms.config.json         # { "repo": "owner/name", "branch": "main", "baseUrl": "OAuth中継のURL(任意)" }
cms/collections.yml     # 管理画面のコレクション定義
src/                    # content.config.ts・layouts・components・pages
src/content/            # news / events / lp
public/images/
.github/workflows/      # 再利用workflowの呼び出し
```

```json
{
  "dependencies": {
    "astro": "7.4.2",
    "static-site-cms": "github:vlstyle/static-site-cms#<コミットハッシュ>"
  },
  "scripts": {
    "dev": "astro dev",
    "build": "astro build",
    "build:admin": "cms-build-admin",
    "dev:admin": "cms-build-admin && cms-serve-admin"
  }
}
```

### workflow の呼び出し

`uses:` は必ずコミットハッシュで固定する。アカウント固有の値（バケット名・ロールARNなど）は呼び出し側から渡す。

```yaml
# .github/workflows/ci.yml
on:
  pull_request:
    branches: [main]
jobs:
  ci:
    uses: vlstyle/static-site-cms/.github/workflows/site-ci.yml@<コミットハッシュ>
    secrets:
      team-read-token: ${{ secrets.TEAM_READ_TOKEN }}
```

Rulesetの必須チェック名は、呼び出し側のジョブIDを前置した `ci / build`・`ci / path-guard`・`ci / file-check` になる。

## 共通設定（`admin/config.base.yml`）

- ブランチ名・ファイル名を ASCII にするスラッグ設定（`encoding: ascii`）。
- アップロード画像は `日付-ランダムID.webp` にリネームし、最大2000px・5MBまで。
- コレクションごとのスラッグ（お知らせ・イベントは `日付-ランダムID`、LPは作成時に半角英小文字・数字・ハイフンで入力）は、サイトリポジトリの `cms/collections.yml` で指定する。

## 開発

```bash
cd examples/site
npm ci
npm run dev
```

## ライセンス

MIT
