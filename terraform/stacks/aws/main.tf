data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "site" {
  source = "../../modules/aws/static-site"
  count  = var.site == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name              = "${var.name}-site"
  bucket_name       = var.site.bucket_name
  domains           = var.site.domains
  hosted_zone_id    = var.hosted_zone_id
  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  deploy_subjects   = ["${var.github_subject_prefix}:ref:refs/heads/main"]
}

module "admin" {
  source = "../../modules/aws/static-site"
  count  = var.admin == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                        = "${var.name}-admin"
  bucket_name                 = var.admin.bucket_name
  domains                     = [var.admin.domain]
  hosted_zone_id              = var.hosted_zone_id
  caching_enabled             = false
  not_found_page              = null
  noindex                     = true
  basic_auth_enabled          = var.admin.basic_auth_enabled
  basic_auth_reader_iam_group = var.basic_auth_reader_iam_group
  allowed_ipv4_cidrs          = var.admin.allowed_ipv4_cidrs
  oidc_provider_arn           = data.aws_iam_openid_connect_provider.github.arn
  deploy_subjects             = ["${var.github_subject_prefix}:ref:refs/heads/main"]
}

module "preview" {
  source = "../../modules/aws/preview"
  count  = var.preview == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                        = "${var.name}-preview"
  bucket_name                 = var.preview.bucket_name
  domain                      = var.preview.domain
  hosted_zone_id              = var.hosted_zone_id
  expire_days                 = var.preview.expire_days
  basic_auth_reader_iam_group = var.basic_auth_reader_iam_group
  oidc_provider_arn           = data.aws_iam_openid_connect_provider.github.arn
  publisher_subjects          = ["${var.github_subject_prefix}:pull_request"]
}
