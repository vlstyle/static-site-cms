output "github_variables" {
  description = "サイトリポジトリのActionsのリポジトリ変数に設定する値。"
  value = {
    TERRAFORM_PLAN_ROLE_ARN  = aws_iam_role.plan.arn
    TERRAFORM_APPLY_ROLE_ARN = aws_iam_role.apply.arn
    TERRAFORM_STATE_BUCKET   = aws_s3_bucket.this.bucket
  }
}
