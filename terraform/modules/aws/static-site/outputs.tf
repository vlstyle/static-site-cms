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

output "distribution_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}

output "deploy_role_arn" {
  value = length(aws_iam_role.deploy) > 0 ? aws_iam_role.deploy[0].arn : null
}
