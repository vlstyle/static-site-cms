output "bucket" {
  value = data.aws_s3_bucket.this.bucket
}

output "prefix" {
  value = var.prefix
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.this.arn
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
