# Terraform

静的サイトの配信基盤（AWS）。サイトリポジトリは `terraform.tfvars` にパラメータを書くだけで使える（plan・applyの再利用workflowは別途提供）。

## 構成

| パス | 内容 |
|---|---|
| `modules/aws/static-site` | S3 + CloudFront + ACM + Route 53 + デプロイ用IAMロール。本番サイトと管理画面の両方に使う。Basic認証・IPv4制限・noindexはオプション |
| `modules/aws/preview` | PRごとのプレビュー（`pr-<番号>.<domain>`）。ワイルドカード証明書、Basic認証（常に有効）、30日で自動削除 |
| `bootstrap/aws` | 初回だけ手元で適用するルートモジュール。OIDCプロバイダ、plan/apply用ロール、stateバケット |
| `stacks/aws` | 上のモジュールを束ねたルートモジュール。変数は `site`・`admin`・`preview`（`null` なら作らない） |

## 使い方

最初に、[`bootstrap/aws`](bootstrap/aws/README.md)（OIDCプロバイダ・plan/applyロール・stateバケット）を1回だけ手元で適用する。

`stacks/aws/example.tfvars` を参考に `terraform.tfvars` を書く。

```hcl
hosted_zone_id        = "Z0123456789ABCDEFGHIJ"
github_subject_prefix = "repo:owner/site-repo"

site    = { bucket_name = "example-site", domains = ["www.example.com"] }
admin   = { bucket_name = "example-site-admin", domain = "cms.example.com", allowed_ipv4_cidrs = ["203.0.113.0/24"] }
preview = { bucket_name = "example-site-preview", domain = "preview.example.com" }
```

適用後、出力 `github_variables` の値をサイトリポジトリのActionsのリポジトリ変数に設定する。Basic認証の資格情報は出力 `basic_auth_ssm_parameters` のSSMパラメータ（SecureString、値は `ユーザー名:パスワード`）にある。

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
```

| 入力 | 既定値 | 内容 |
|---|---|---|
| `role-arn` | （必須） | plan用（読み取り専用 + stateの読み書き）・apply用のIAMロール |
| `state-bucket` | （必須） | Terraform stateを置くS3バケット |
| `state-key` | `static-site-cms/terraform.tfstate` | stateのキー |
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
