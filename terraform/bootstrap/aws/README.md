# ブートストラップ（初回のみ）

TerraformをGitHub Actionsから動かすために必要な、次のリソースを作る。これらはActionsからは作れないので、**最初の1回だけ人が手元で実行する**。

| リソース | 用途 |
|---|---|
| GitHub ActionsのOIDCプロバイダ | ActionsがAWSの一時クレデンシャルを取得する（同じアカウントに作成済みなら `create_oidc_provider = false`） |
| S3バケット | Terraformのstate（バージョニング・暗号化あり） |
| `<name>-terraform-plan` ロール | PRのplan用。`ReadOnlyAccess` + stateの読み書き。subjectは `pull_request` と `main` |
| `<name>-terraform-apply` ロール | `main` のapply用。既定は `AdministratorAccess`（`apply_policy_arns` で絞れる）。subjectは `main` のみ |

## 手順

1. 管理者権限のAWSクレデンシャルで、`example.tfvars` を参考に `terraform.tfvars` を書く。

   ```hcl
   state_bucket_name     = "example-terraform-state"
   github_subject_prefix = "repo:owner/site-repo"
   ```

2. 適用する。

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. 出力 `github_variables` の3つの値を、サイトリポジトリのActionsのリポジトリ変数に設定する（`TERRAFORM_PLAN_ROLE_ARN` `TERRAFORM_APPLY_ROLE_ARN` `TERRAFORM_STATE_BUCKET`）。

4. サイトリポジトリに `terraform/terraform.tfvars` と、plan・applyの呼び出しworkflowを置く（[../../README.md](../../README.md) の「GitHub Actionsから実行する」）。PRにplanが投稿され、`main` へのマージでapplyされる。

5. applyの出力 `github_variables` を、サイトリポジトリのActionsのリポジトリ変数に設定する（`DEPLOY_TARGET` `AWS_DEPLOY_ROLE_ARN` `S3_BUCKET` `CLOUDFRONT_DISTRIBUTION_ID` `CMS_DOMAIN` `CMS_S3_BUCKET` `CMS_ADMIN_DEPLOY_ROLE_ARN` `CMS_PREVIEW_ROLE_ARN` など）。

## 注意

- このモジュールのstateは手元に残る。紛失しないよう管理するか、作成した `state_bucket_name` のバケットへ `terraform init -migrate-state` で移す。
- apply用ロールの既定は強い権限を持つ。配信基盤に必要な権限（S3・CloudFront・ACM・Route 53・IAM・SSM）に絞ることを推奨する。
- `github_subject_prefix` はアカウントのOIDC subjectの形式に合わせる（IDを含める設定のアカウントでは `repo:owner@123/name@456`）。
