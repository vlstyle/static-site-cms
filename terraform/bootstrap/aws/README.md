# ブートストラップ（初回のみ）

TerraformをGitHub Actionsから動かすために必要な、次のリソースを作る。これらはActionsからは作れないので、**最初の1回だけ人が手元で実行する**。

| リソース | 用途 |
|---|---|
| GitHub ActionsのOIDCプロバイダ | ActionsがAWSの一時クレデンシャルを取得する（同じアカウントに作成済みなら `create_oidc_provider = false`） |
| S3バケット | 共有バケットの本体（バージョニング・暗号化・パブリックアクセスブロック）。`terraform/` にstateを置き、`cms/`・`staging/`・`production/` は `stacks/aws` が配信用に使う。バケットポリシーとライフサイクルは `stacks/aws` が管理する |
| `<name>-terraform-plan` ロール | PRのplan用。`ReadOnlyAccess` + stateの読み書き。subjectは `pull_request` と `main` |
| `<name>-terraform-apply` ロール | `main` のapply用。既定は `AdministratorAccess`（`apply_policy_arns` で絞れる）。subjectは `main` のみ |

## 手順

1. 管理者権限のAWSクレデンシャルで、`example.tfvars` を参考に `terraform.tfvars` を書く。

   ```hcl
   bucket_name           = "example-site"
   github_subject_prefix = "repo:owner/site-repo"
   ```

2. 適用する。

   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. このモジュールのstateを共有バケットへ移す（下の「stateの移行」）。

4. 出力 `github_variables` の3つの値を、サイトリポジトリの `config/deploy.env` に書く（`TERRAFORM_PLAN_ROLE_ARN` `TERRAFORM_APPLY_ROLE_ARN` `TERRAFORM_STATE_BUCKET`）。

5. サイトリポジトリに `terraform/terraform.tfvars` と、plan・applyの呼び出しworkflowを置く（[../../README.md](../../README.md) の「GitHub Actionsから実行する」）。PRにplanが投稿され、`main` へのマージでapplyされる。

6. applyの出力 `github_variables` は、`terraform-apply.yml` の `env-file` 入力で `config/deploy.env` へ書かれる（更新のPRをマージする）。

## stateの移行

このモジュールのstateは、最初は手元に作られる。バケットができたら、`terraform/bootstrap.tfstate` へ移す。

```bash
cat > backend.tf <<'EOF'
terraform {
  backend "s3" {}
}
EOF
terraform init -migrate-state -force-copy -backend-config="bucket=<bucket_name>" -backend-config="key=terraform/bootstrap.tfstate" -backend-config="region=ap-northeast-1" -backend-config="use_lockfile=true"
```

`backend.tf` はコミットしない。移行後は手元のstateファイルを削除してよい。

## 注意

- apply用ロールの既定は強い権限を持つ。配信基盤に必要な権限（S3・CloudFront・ACM・Route 53・IAM）に絞ることを推奨する。
- `github_subject_prefix` はアカウントのOIDC subjectの形式に合わせる（IDを含める設定のアカウントでは `repo:owner@123/name@456`）。
