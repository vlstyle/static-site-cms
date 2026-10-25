# static-site-cms

Git をバックエンドにした広報向け静的サイト（お知らせ・イベント・ブロック型ランディングページ）の共通部品。[Astro](https://astro.build/) と [Sveltia CMS](https://sveltiacms.app/) を使う。コンテンツは別のリポジトリ（サイトリポジトリ）に置き、このリポジトリを依存として参照する。

## 提供するもの

| 種類 | 内容 |
|---|---|
| Astro integration | ルート（`/`・`/lp/[slug]`・`/news`・`/events` など）、ブロック、レイアウトを注入する |
| コンテンツのスキーマ | `static-site-cms/content` の `collections`（news・events・lp） |
| 管理画面 | Sveltia CMS のHTMLと `config.yml` のテンプレート。`cms-build-admin` が生成する |
| CIチェック | `cms-path-guard`（ロールに応じた変更範囲の制限）・`cms-check-files`（ファイル名・画像の検査） |
| 再利用 workflow | `site-ci.yml`・`site-preview.yml`・`site-deploy.yml` |

## サイトリポジトリの作り方

必要なファイルは次のとおり。動く例は [`examples/site`](examples/site)。

```
package.json            # astro と static-site-cms（コミット固定のgit依存）
astro.config.mjs        # integrations: [staticSiteCms()]
src/content.config.ts   # export { collections } from 'static-site-cms/content';
src/content/            # news / events / lp
public/images/
cms.config.json         # { "repo": "owner/name", "branch": "main", "baseUrl": "OAuth中継のURL(任意)" }
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

## ファイル名とスラッグ

- お知らせ・イベントは `日付-ランダムID` で自動採番する（ブランチ名・ファイル名に日本語が入らない）。
- LPのスラッグはURLになるため、作成時に半角英小文字・数字・ハイフンで入力する。
- アップロード画像は `日付-ランダムID.webp` にリネームし、最大2000px・5MBまで。

## 開発

```bash
cd examples/site
npm ci
npm run dev
```

## ライセンス

MIT
