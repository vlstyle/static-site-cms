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

組織のチーム（`site-poweruser`・`site-admins`）を使えない個人アカウントのリポジトリでは、`with: path-guard: false` で `path-guard` ジョブを無効にできる。このとき `ci / path-guard` は必須チェックから外す。

## 配信基盤の契約（envファイル）

配信先の情報は、リポジトリのActionsの変数ではなく、`config/deploy.env`（`KEY=value`、`#` でコメント）に書く。再利用workflow（`site-deploy.yml`・`site-preview.yml`・`terraform-plan.yml`・`terraform-apply.yml`）は、このファイルを読んで動く。配信基盤を作る方法は問わない。

- Terraformを使う場合: [`terraform/`](terraform/README.md) のスタックで作り、`terraform-apply.yml` の `env-file` 入力で、applyの出力からこのファイルを更新するPRを作らせる。
- 使わない場合: 手作業・別のIaCなどで下の構成を作り、このファイルを手で書く。

| キー | 内容 | 使うworkflow |
|---|---|---|
| `AWS_REGION` | 既定 `ap-northeast-1` | すべて |
| `S3_BUCKET` | 共有のS3バケット | deploy・preview |
| `CMS_DOMAIN` | 管理画面とプレビューのドメイン | preview・deploy（管理画面） |
| `CMS_ADMIN_DEPLOY_ROLE_ARN` | 管理画面を配置するロール | deploy（`deploy-admin: true`） |
| `CMS_CLOUDFRONT_DISTRIBUTION_ID` | 管理画面のキャッシュを無効化するディストリビューション。あれば、管理画面の配置後に `/admin/*` を無効化する。ロールに `cloudfront:CreateInvalidation` が必要 | deploy（`deploy-admin: true`） |
| `CMS_PREVIEW_ROLE_ARN` | プレビューを配置するロール | preview |
| `STAGING_SITE_URL` `PRODUCTION_SITE_URL` | ビルドに渡す `SITE_URL` | deploy（`target`） |
| `STAGING_DEPLOY_ROLE_ARN` `PRODUCTION_DEPLOY_ROLE_ARN` | サイトを配置するロール | deploy（`target`） |
| `STAGING_CLOUDFRONT_DISTRIBUTION_ID` `PRODUCTION_CLOUDFRONT_DISTRIBUTION_ID` | 配置後に無効化するディストリビューション | deploy（`target`） |
| `CMS_PREFIX` `STAGING_PREFIX` `PRODUCTION_PREFIX` | バケット内のプレフィックス。既定は `cms`・`staging`・`production` | deploy・preview |
| `TERRAFORM_PLAN_ROLE_ARN` `TERRAFORM_APPLY_ROLE_ARN` `TERRAFORM_STATE_BUCKET` | Terraformのplan・apply用ロールとstateのバケット（bootstrapの出力。手で書く） | terraform-plan・apply |

どのキーも省略できる。値がなければ、その配信は行われない（例: `STAGING_DEPLOY_ROLE_ARN` がなければstagingは配置しない）。workflowの入力で同じ値を渡すと、ファイルより優先される。値に引用符は付けない。サンプルは [`examples/site/config/deploy.env.example`](examples/site/config/deploy.env.example)。

### 配信基盤が満たす構成

Terraformを使わない場合は、次を満たすように作る。

- S3バケットを1つ、`cms/`・`staging/`・`production/` のプレフィックスで使う（プレフィックスは `*_PREFIX` で変えられる）。
- 配信するCloudFrontのoriginは、バケットの該当プレフィックス（`origin_path`）にする。管理画面とプレビューは `cms/admin/`・`cms/preview/pr-<番号>/`、ドメインは `CMS_DOMAIN`。プレビューはサブパス（`/preview/pr-<番号>/`）で配信できること。
- GitHub ActionsのOIDCで引き受けるIAMロールを作る。信頼ポリシーのsubjectは、`CMS_ADMIN_DEPLOY_ROLE_ARN` が `repo:<owner>/<repo>:ref:refs/heads/main`、`CMS_PREVIEW_ROLE_ARN` が `repo:<owner>/<repo>:pull_request`、`STAGING_DEPLOY_ROLE_ARN` が `repo:<owner>/<repo>:environment:staging`、`PRODUCTION_DEPLOY_ROLE_ARN` が `repo:<owner>/<repo>:environment:production`。
- 各ロールの権限は、自分のプレフィックスへの `s3:ListBucket`（`s3:prefix` 条件）と `s3:GetObject`・`PutObject`・`DeleteObject`。サイトのロールにはさらに、ディストリビューションへの `cloudfront:CreateInvalidation`。

### 公開日時

`static-site-cms/published` の `jstDate` をスキーマの日付項目（`publishDate` など）に使うと、タイムゾーンのない値を日本時間として扱う。YAMLのタイムゾーンなしの日時はUTCとして読まれるため、`jstDate` が9時間戻して補正する。`+09:00` などのオフセット付きの値は、文字列（引用符つき）で書けばそのまま使う。

`isPublished` はビルド時に一度だけ判定する。公開日時を過ぎた後に再ビルドしないと、ページは出力されない。`site-deploy.yml` は `target: staging` のビルドで環境変数 `SHOW_UNPUBLISHED=1` を渡し、公開日時にかかわらず全件を出力する（productionは公開日時で絞る）。

### キャッシュ

`site-deploy.yml` は、アップロード時に `Cache-Control` を付ける。ハッシュ付きのアセットのディレクトリ（入力 `immutable-assets-dir`、既定 `_astro`）は `public, max-age=31536000, immutable`、それ以外（HTML、管理画面を含む）は `no-cache`（ブラウザは毎回確認する）。CloudFrontのキャッシュは、productionならリリースのたびに `/*` を無効化する。古いハッシュのアセットは削除しない（HTMLが参照するのは新しいハッシュだけなので、残っても表示には影響しない）。

### workflowの呼び出し

```yaml
# .github/workflows/deploy-staging.yml: mainへのマージで自動
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
  deployments: read
jobs:
  deploy:
    uses: vlstyle/static-site-cms/.github/workflows/site-deploy.yml@<コミットハッシュ>
    with:
      target: staging
      deploy-admin: true
```

```yaml
# .github/workflows/deploy-production.yml: 手動実行。sha が空なら、stagingに最後に成功したデプロイのコミットを反映する
on:
  workflow_dispatch:
    inputs:
      sha:
        type: string
        default: ""
permissions:
  id-token: write
  contents: read
  deployments: read
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    uses: vlstyle/static-site-cms/.github/workflows/site-deploy.yml@<コミットハッシュ>
    with:
      target: production
      ref: ${{ inputs.sha }}
      ref-from-environment: staging
```

```yaml
# .github/workflows/preview.yml
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
permissions:
  contents: read
  id-token: write
  pull-requests: write
jobs:
  preview:
    uses: vlstyle/static-site-cms/.github/workflows/site-preview.yml@<コミットハッシュ>
```

`target` は `environment:` にもなるので、stagingは `environment:staging`、productionは `environment:production` のOIDC subjectで動く。productionは、stagingに最後に成功したデプロイのコミットを、productionの `SITE_URL` でビルドし直す。

## サブパスで配信する（`base`）

`BASE_PATH` 環境変数（例: `/preview/pr-12`）で、サイトをサブパスの配下に置ける（スターターの `astro.config.mjs` が Astro の `base` に渡す）。

- テンプレートでは、内部リンクと画像のパスを `withBase()`（`static-site-cms/url`）に通す。外部URL・`#` から始まるリンクはそのまま返る。
- CMSが保存する本文（Markdown）の `/images/...` や `/events/` のような絶対パスは、描画済みHTMLを `withBaseInHtml()` に通して補正する（スターターの `news/[slug].astro` など）。
- `cms-check-links <出力ディレクトリ>` が、ビルド結果の内部リンクが `BASE_PATH` で始まり、リンク先が存在するかを検査する。

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
