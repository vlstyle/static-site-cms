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
cms.config.json         # { "repo": "owner/name", "branch": "main", "baseUrl": "OAuth中継のURL(任意)", "timeZone": "Asia/Tokyo" }
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

配信先の情報は、リポジトリのActionsの変数ではなく、環境ごとのファイル `config/<環境名>.env`（`KEY=value`、`#` でコメント）に書く。再利用workflow（`site-deploy.yml`・`terraform-plan.yml`・`terraform-apply.yml`）は、このファイルを読んで動く。配信基盤を作る方法は問わない。

- Terraformを使う場合: [`terraform/`](terraform/README.md) のスタックで作り、`terraform-apply.yml` の `env-dir` 入力で、applyの出力から `config/cms.env`・`staging.env`・`production.env` を更新するPRを作らせる。
- 使わない場合: 手作業・別のIaCなどで下の構成を作り、ファイルを手で書く。

### 環境ごとのファイル

| キー | 内容 | 対象 |
|---|---|---|
| `S3_BUCKET` | 配置先のS3バケット（必須） | すべて |
| `DEPLOY_ROLE_ARN` | 配置に使うロール（必須）。`cms` では管理画面を配置するロール | すべて |
| `AWS_REGION` | 既定 `ap-northeast-1` | すべて |
| `PREFIX` | バケット内のプレフィックス。既定は環境名（`cms` は `cms`） | すべて |
| `CLOUDFRONT_DISTRIBUTION_ID` | 配置後にキャッシュを無効化するディストリビューション。サイトは `/*`、`cms` の管理画面は `/admin/*`。ロールに `cloudfront:CreateInvalidation` が必要 | すべて |
| `SITE_URL` | ビルドに渡す `SITE_URL` | `cms` 以外 |
| `CMS_DOMAIN` | 管理画面とプレビューのドメイン（必須）。`SITE_URL` は `https://<CMS_DOMAIN>` になる | `cms` |
| `PREVIEW_ROLE_ARN` | プレビューを配置するロール（PRで必須） | `cms` |
| `SHOW_UNPUBLISHED` | `true` にすると、公開日時が未来のページも出力する（staging向け）。省略はfalse。workflowの入力 `show-unpublished` が優先する | `cms` 以外 |
| `PUBLISH_SHA` | 本番に出すコミット（40桁）。デフォルトブランチに含まれていること。省略するとデフォルトブランチのHEAD | `production` |

Terraformのplan・applyは、`config/terraform.env` の `TERRAFORM_PLAN_ROLE_ARN` `TERRAFORM_APPLY_ROLE_ARN` `TERRAFORM_STATE_BUCKET`（bootstrapの出力。手で書く）を読む。サンプルは [`examples/site/config/`](examples/site/config)。値に引用符は付けない。

`production.env` の `PUBLISH_SHA` は公開の承認にあたる。`.github/CODEOWNERS` に `/config/production.env` を指定し、ルールセットで「Code Ownerのレビューを必須にする」と、承認者の承認なしには変えられなくなる（Terraformのapplyが更新するキーに `PUBLISH_SHA` は含まれず、ほかのキーを書き換えても `PUBLISH_SHA` は保持される）。

### 本番に出すコミットの更新（`publish-sha.yml`）

`config/production.env` の `PUBLISH_SHA` を更新するPRを作る再利用workflow。入力 `sha`（任意。先頭7桁または40桁の小文字）を受け取り、7桁は先頭が一致するコミット（前方一致。途中の一致は対象にしない）の40桁に補完する。7桁が複数のコミットに一致する場合は、デフォルトブランチの履歴で最も新しいものを採用し、PR本文に候補と採用したコミットを書く。空ならデフォルトブランチの最新コミットを採用する。デフォルトブランチから実行されていること、コミットが存在してデフォルトブランチに含まれていることを検査してから、ブランチ `publish/update-sha` に変更をpushし、デフォルトブランチへのPRを作る（既にPRがあれば、タイトルと本文を更新する）。PRの本文に、変更前と変更後、含まれるコミットの一覧を書く。呼び出し側のジョブには `contents: write`・`pull-requests: write` が必要で、リポジトリの設定「Allow GitHub Actions to create and approve pull requests」を有効にする。Actionsが作ったPRではほかのworkflowが動かない。

```yaml
# .github/workflows/publish-sha.yml: 手動実行
on:
  workflow_dispatch:
    inputs:
      sha:
        description: 本番に出すコミットのSHA（先頭7桁または40桁）。空なら最新のコミット
        type: string
        default: ""
        required: false
permissions:
  contents: write
  pull-requests: write
jobs:
  update:
    uses: vlstyle/static-site-cms/.github/workflows/publish-sha.yml@<コミットハッシュ>
    with:
      sha: ${{ inputs.sha }}
```

### 配信基盤が満たす構成

Terraformを使わない場合は、次を満たすように作る。

- S3バケットを1つ、環境ごとのプレフィックス（`cms/`・`staging/`・`production/` など）で使う。
- 配信するCloudFrontのoriginは、バケットの該当プレフィックス（`origin_path`）にする。管理画面とプレビューは `cms/admin/`・`cms/preview/pr-<番号>/`、ドメインは `CMS_DOMAIN`。プレビューはサブパス（`/preview/pr-<番号>/`）で配信できること。
- IP制限やBasic認証は、CloudFront側（Terraformのスタックでは CloudFront Function）で設定する。デプロイのworkflowは設定しない。
- GitHub ActionsのOIDCで引き受けるIAMロールを作る。信頼ポリシーのsubjectは、`cms` の `DEPLOY_ROLE_ARN` が `repo:<owner>/<repo>:ref:refs/heads/<デフォルトブランチ>`、`PREVIEW_ROLE_ARN` が `repo:<owner>/<repo>:pull_request`、それ以外の環境の `DEPLOY_ROLE_ARN` が `repo:<owner>/<repo>:environment:<環境名>`。
- 各ロールの権限は、自分のプレフィックスへの `s3:ListBucket`（`s3:prefix` 条件）と `s3:GetObject`・`PutObject`・`DeleteObject`。ディストリビューションを指定するなら、`cloudfront:CreateInvalidation`。

### 公開日時

`cms.config.json` の `timeZone`（IANAのタイムゾーン名。省略時は `Asia/Tokyo`）が、サイトのローカルタイムのタイムゾーンになる。`static-site-cms/published` の `localDate` をスキーマの日付項目（`publishDate` など）に使うと、オフセットのない値（`2026-10-31T11:16:00`、`2026-10-31`）をこのタイムゾーンのローカルタイムとして扱う。YAMLのオフセットなしの日時はUTCとして読まれるため、`localDate` が補正する（夏時間も考慮する）。`+09:00` などのオフセット付きの値は、文字列（引用符つき）で書けばそのまま使う。`formatDate` の表示も同じタイムゾーンで行う。

`isPublished` はビルド時に一度だけ判定する。公開日時を過ぎた後に再ビルドしないと、ページは出力されない。環境のenvファイルの `SHOW_UNPUBLISHED=true` は、ビルドに `SHOW_UNPUBLISHED=1` を渡し、公開日時にかかわらず全件を出力する（stagingの確認用）。`site-deploy.yml` の入力 `show-unpublished`（`true`・`false`）を指定すると、envファイルより優先する（手動実行で一時的に状態を変えて確認するときに使う）。どちらも指定がなければfalse（公開日時で絞る）。`cms` のプレビューは常に全件を出力する。

### キャッシュ

`site-deploy.yml` は、アップロード時に `Cache-Control` を付ける。ハッシュ付きのアセットのディレクトリ `_astro`（Astroの既定の出力先）は `public, max-age=31536000, immutable`、それ以外（HTML、管理画面を含む）は `no-cache`（ブラウザは毎回確認する）。`CLOUDFRONT_DISTRIBUTION_ID` があれば、配置のたびに無効化する。古いハッシュのアセットは削除しない（HTMLが参照するのは新しいハッシュだけなので、残っても表示には影響しない）。

### workflowの呼び出し

`site-deploy.yml` は、環境名（`environment`）を受け取り、`config/<環境名>.env` に従って動く。呼び出し側のworkflowには、`permissions` に `id-token: write`・`contents: read`・`deployments: read`・`pull-requests: write` が要る（再利用workflowの要求する権限の上限）。

| 環境名 | 動作 |
|---|---|
| `cms` | `main` へのpushで管理画面（`admin/index.html`・`config.yml`）を `<PREFIX>/admin/` に配置する。PRでは `<PREFIX>/preview/pr-<番号>/` にプレビューを配置してコメントし、PRを閉じると削除する |
| `production` | サイトを配置する。デフォルトブランチから実行されていること、`PUBLISH_SHA` があればそのコミットがデフォルトブランチに含まれていることを検査する。`PUBLISH_SHA` がなければHEAD |
| それ以外（`staging`、`staging1` など） | サイトを配置する。pull_requestでは動かない |

環境名は、GitHubのEnvironment名にもなる（`cms` のプレビューと管理画面は除く）。`production` にEnvironmentの承認者を設定すると、承認後に配置される。

```yaml
# .github/workflows/deploy-staging.yml: mainへのマージで自動
on:
  push:
    branches: [main]
permissions:
  id-token: write
  contents: read
  deployments: read
  pull-requests: write
jobs:
  deploy:
    uses: vlstyle/static-site-cms/.github/workflows/site-deploy.yml@<コミットハッシュ>
    with:
      environment: staging
```

```yaml
# .github/workflows/deploy-production.yml: 手動実行（config/production.env の PUBLISH_SHA のコミットを出す）。show-unpublished は、手動実行のときだけ状態を変えて確認したい場合に渡す
on:
  workflow_dispatch:
    inputs:
      show-unpublished:
        type: choice
        options: ["", "true", "false"]
permissions:
  id-token: write
  contents: read
  deployments: read
  pull-requests: write
jobs:
  deploy:
    uses: vlstyle/static-site-cms/.github/workflows/site-deploy.yml@<コミットハッシュ>
    with:
      environment: production
      show-unpublished: ${{ inputs.show-unpublished }}
```

```yaml
# .github/workflows/cms.yml: 管理画面（mainへのpush）とPRのプレビュー
on:
  push:
    branches: [main]
  pull_request:
    types: [opened, synchronize, reopened, closed]
permissions:
  id-token: write
  contents: read
  deployments: read
  pull-requests: write
jobs:
  cms:
    uses: vlstyle/static-site-cms/.github/workflows/site-deploy.yml@<コミットハッシュ>
    with:
      environment: cms
```

## サブパスで配信する（`base`）

`BASE_PATH` 環境変数（例: `/preview/pr-12`）で、サイトをサブパスの配下に置ける（スターターの `astro.config.mjs` が Astro の `base` に渡す）。

- テンプレートでは、内部リンクと画像のパスを `withBase()`（`static-site-cms/url`）に通す。外部URL・`#` から始まるリンクはそのまま返る。
- CMSが保存する本文（Markdown）の `/images/...` や `/events/` のような絶対パスは、描画済みHTMLを `withBaseInHtml()` に通して補正する（スターターの `news/[slug].astro` など）。
- `cms-check-links <出力ディレクトリ>` が、ビルド結果の内部リンクが `BASE_PATH` で始まり、リンク先が存在するかを検査する。
- `cms-dist-diff <ベースの出力> <PRの出力> [出力先]` が、2つのビルド成果物を比べ、追加・削除・変更されたファイルの一覧を Job Summary に出し、`report.md` と全差分の `dist.patch` を出力先に書く。ハッシュ付きのファイル名（`name.XXXXXXXX.js`）はハッシュを無視して比較する。`site-ci.yml` は、PRのときにベースブランチもビルドして比較し、Job Summary と artifact（`dist-diff`）に出す。ベースのビルドや比較が失敗しても、CIは失敗させない。コアの参照バージョンの更新やAstroの更新で、成果物が変わるかの確認に使う。

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
