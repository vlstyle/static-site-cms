# Terraform

静的サイトの配信基盤（AWS）。サイトリポジトリは `terraform.tfvars` にパラメータを書くだけで使える（plan・applyの再利用workflowも提供する）。

## 構成

1つのS3バケットを、プレフィックスで用途ごとに分けて使う。

| プレフィックス | 内容 | 配信 |
|---|---|---|
| `terraform/` | Terraformのstate（`stack.tfstate`・bootstrapの `bootstrap.tfstate`）。配信しない | なし |
| `cms/` | 管理画面（`cms/admin/`）とPRのプレビュー（`cms/preview/pr-<番号>/`）。プレビューは30日で自動削除 | `https://<cms.domain>/admin/`・`/preview/pr-<番号>/`。Basic認証 |
| `staging/` | `main` にマージされた内容が常に反映される最終確認用のサイト | `https://<staging.domains[0]>/`。Basic認証、noindex |
| `production/` | 手動のworkflowで反映する公開サイト | `https://<production.domains[0]>/` |

CloudFrontは `cms`・`staging`・`production` で別々のディストリビューションを作り、それぞれの `origin_path` をプレフィックスにする。バケットポリシーは各ディストリビューションに自分のプレフィックスだけの読み取りを許可するので、`terraform/` は配信されない。

| パス | 内容 |
|---|---|
| `modules/aws/static-site` | 既存のバケットの1プレフィックスを配信する CloudFront + ACM + Route 53 + デプロイ用IAMロール。stagingとproductionに使う。Basic認証・IPv4制限・noindexはオプション |
| `modules/aws/cms-hosting` | 既存のバケットの1プレフィックスで、CMSの管理画面（`/admin/`）とPRのプレビュー（`/preview/pr-<番号>/`）を配信する。Basic認証、IPv4制限、noindex。スターターのテンプレートが `base`（サブパス）に対応している必要がある |
| `bootstrap/aws` | 初回だけ手元で適用するルートモジュール。OIDCプロバイダ、plan/apply用ロール、共有バケット本体（バージョニング・暗号化・パブリックアクセスブロック） |
| `stacks/aws` | `cms-hosting` と `static-site`（staging・production）を束ねたルートモジュール。変数は `cms`・`staging`・`production`（`null` なら作らない）。バケットポリシーとライフサイクルはこのスタックが持つ |

バケット本体はbootstrap、バケットポリシーとライフサイクルはスタックが管理する（スタックはバケットを `data` で参照する）。バケットポリシーにはスタックで作るCloudFrontのARNが必要で、1つのバケットのポリシーを2つのルートモジュールで持てないため。

## 使い方

最初に、[`bootstrap/aws`](bootstrap/aws/README.md)（OIDCプロバイダ・plan/applyロール・共有バケット）を1回だけ手元で適用する。

`stacks/aws/example.tfvars` を参考に `terraform.tfvars` を書く。

```hcl
hosted_zone_id        = "Z0123456789ABCDEFGHIJ"
github_subject_prefix = "repo:owner/site-repo"
bucket_name           = "example-site"

cms        = { domain = "cms.example.com", allowed_ipv4_cidrs = ["203.0.113.0/24"] }
staging    = { domains = ["staging.example.com"] }
production = { domains = ["example.com", "www.example.com"] }
```

`staging`・`production` の `site_url` を省略すると `https://<domains[0]>` になる。別の値にしたいときは `site_url` で上書きできる（ビルドに渡す `SITE_URL` になる）。

### Basic認証のパスワード

CMSとstagingのBasic認証（既定で有効）のパスワードは、環境変数 `TF_VAR_basic_auth_password` で渡す（GitHub ActionsのSecretから渡す。リポジトリには書かない）。渡さないとplanが失敗する。CloudFront Functionにはソルト付きSHA-256のハッシュだけが入り、パスワード自体はstateにもSSMにも残らない。

ユーザー名は `cms.basic_auth_user`（既定 `cms`）、`staging.basic_auth_user`（既定 `staging`）。

適用後、出力 `github_variables` の値をサイトリポジトリのActionsのリポジトリ変数に設定する。

### staging・productionの反映

| 環境 | 反映のしかた | OIDCのsubject |
|---|---|---|
| staging | `main` へのpushで自動。deployジョブに `environment: staging` を付ける | `repo:<owner>/<repo>:environment:staging` |
| production | 手動実行（`workflow_dispatch`）。deployジョブに `environment: production` を付ける | `repo:<owner>/<repo>:environment:production` |

`site-deploy.yml` の `ref-from-environment: staging` を指定すると、productionのビルドは「stagingに最後に成功したデプロイのコミット」になる。`SITE_URL` はproductionの値でビルドし直すので、canonical URLなどにstagingのホスト名が混ざらない。`ref` でコミットを直接指定することもできる。

Environmentの承認者（人の承認ゲート）は、プランによって使えない（無料プランのprivateリポジトリなど）。

## GitHub Actionsから実行する

サイトリポジトリは `terraform/terraform.tfvars` を置き、再利用workflowを呼ぶ。Terraformのコードは `package.json` で固定したコアのバージョンのもの（`node_modules/static-site-cms/terraform/stacks/aws`）が使われるため、コアの参照を上げるとTerraformも同時に更新される。`uses:` のコミットハッシュも `package.json` と揃える。

```yaml
# .github/workflows/terraform-plan.yml
name: Terraform plan
on:
  pull_request:
    paths: ["terraform/**", "package.json", "package-lock.json"]
jobs:
  plan:
    permissions:
      contents: read
      id-token: write
      pull-requests: write
    uses: vlstyle/static-site-cms/.github/workflows/terraform-plan.yml@<コミットハッシュ>
    with:
      role-arn: ${{ vars.TERRAFORM_PLAN_ROLE_ARN }}
      state-bucket: ${{ vars.TERRAFORM_STATE_BUCKET }}
    secrets:
      basic-auth-password: ${{ secrets.BASIC_AUTH_PASSWORD }}
```

```yaml
# .github/workflows/terraform-apply.yml
name: Terraform apply
on:
  push:
    branches: [main]
    paths: ["terraform/**", "package.json", "package-lock.json"]
  workflow_dispatch: {}
jobs:
  apply:
    permissions:
      contents: read
      id-token: write
    uses: vlstyle/static-site-cms/.github/workflows/terraform-apply.yml@<コミットハッシュ>
    with:
      role-arn: ${{ vars.TERRAFORM_APPLY_ROLE_ARN }}
      state-bucket: ${{ vars.TERRAFORM_STATE_BUCKET }}
    secrets:
      basic-auth-password: ${{ secrets.BASIC_AUTH_PASSWORD }}
```

`basic-auth-password` は `TF_VAR_basic_auth_password` としてTerraformに渡り、CMSとstagingのBasic認証のパスワードになる。Basic認証を有効にするとき（既定）は必須。値はGitHubのSecretに置き、リポジトリには書かない。

| 入力 | 既定値 | 内容 |
|---|---|---|
| `role-arn` | （必須） | plan用（読み取り専用 + `terraform/` のstateの読み書き）・apply用のIAMロール |
| `state-bucket` | （必須） | 共有のS3バケット（`terraform/` にstateを置く） |
| `state-key` | `terraform/stack.tfstate` | stateのキー |
| `aws-region` | `ap-northeast-1` | メインのリージョン |
| `tfvars-file` | `terraform/terraform.tfvars` | 呼び出し側リポジトリ内のtfvars |
| `terraform-version` | `1.16.4` | |

planの結果はPRのコメントに投稿され（同じPRでは更新される）、applyは `main` へのpushで実行される。

## 前提と制限

- Route 53のホストゾーンがあること。ホストゾーンが別サービスにある場合は未対応。
- GitHub OIDCプロバイダ（`token.actions.githubusercontent.com`）が同じアカウントに作成済みであること。
- 管理画面のIP制限はIPv4のみ。IPv6からのアクセスは拒否される。
- `github_subject_prefix` は、アカウントのOIDC subjectの形式に合わせる（IDを含める設定のアカウントでは `repo:owner@123/name@456`）。
- apply用の権限は強いため、このリポジトリの参照は必ずコミットハッシュで固定し、更新時に差分を確認する。
