output "bucket" {
  value = aws_s3_bucket.this.bucket
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

output "basic_auth_ssm_parameter" {
  value = length(aws_ssm_parameter.basic_auth) > 0 ? aws_ssm_parameter.basic_auth[0].name : null
}
