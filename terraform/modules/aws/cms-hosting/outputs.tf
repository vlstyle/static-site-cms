output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "admin_deploy_role_arn" {
  value = length(aws_iam_role.admin) > 0 ? aws_iam_role.admin[0].arn : null
}

output "preview_publisher_role_arn" {
  value = length(aws_iam_role.preview) > 0 ? aws_iam_role.preview[0].arn : null
}

output "basic_auth_ssm_parameter" {
  description = "パスワードを自動生成した場合の、資格情報（ユーザー名:パスワード）が入っているSSMパラメータ名。"
  value       = length(aws_ssm_parameter.basic_auth) > 0 ? aws_ssm_parameter.basic_auth[0].name : null
}
