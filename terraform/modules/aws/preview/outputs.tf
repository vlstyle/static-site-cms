output "bucket" {
  value = aws_s3_bucket.this.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.this.id
}

output "publisher_role_arn" {
  value = aws_iam_role.publisher.arn
}

output "basic_auth_ssm_parameter" {
  value = aws_ssm_parameter.basic_auth.name
}
