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
