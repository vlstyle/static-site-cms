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

module "cms" {
  source = "../../modules/aws/cms-hosting"
  count  = var.cms == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                       = var.name
  bucket_name                = var.cms.bucket_name
  domain                     = var.cms.domain
  hosted_zone_id             = var.hosted_zone_id
  preview_expire_days        = var.cms.preview_expire_days
  basic_auth_enabled         = var.cms.basic_auth_enabled
  basic_auth_user            = var.cms.basic_auth_user
  basic_auth_password        = var.cms_basic_auth_password
  allowed_ipv4_cidrs         = var.cms.allowed_ipv4_cidrs
  oidc_provider_arn          = data.aws_iam_openid_connect_provider.github.arn
  admin_deploy_subjects      = ["${var.github_subject_prefix}:ref:refs/heads/main"]
  preview_publisher_subjects = ["${var.github_subject_prefix}:pull_request"]
}
