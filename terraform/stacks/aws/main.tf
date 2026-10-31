data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

module "cms" {
  source = "../../modules/aws/cms-hosting"
  count  = var.cms == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                       = var.name
  bucket_name                = var.bucket_name
  prefix                     = local.prefixes.cms
  domain                     = var.cms.domain
  hosted_zone_id             = var.hosted_zone_id
  basic_auth_enabled         = var.cms.basic_auth_enabled
  basic_auth_user            = var.cms.basic_auth_user
  basic_auth_password        = var.basic_auth_password
  allowed_ipv4_cidrs         = var.cms.allowed_ipv4_cidrs
  admin_caching_enabled      = var.cms.admin_caching_enabled
  preview_caching_enabled    = var.cms.preview_caching_enabled
  oidc_provider_arn          = data.aws_iam_openid_connect_provider.github.arn
  admin_deploy_subjects      = ["${var.github_subject_prefix}:ref:refs/heads/main"]
  preview_publisher_subjects = ["${var.github_subject_prefix}:pull_request"]
}

module "staging" {
  source = "../../modules/aws/static-site"
  count  = var.staging == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                = "${var.name}-staging"
  bucket_name         = var.bucket_name
  prefix              = local.prefixes.staging
  domains             = var.staging.domains
  hosted_zone_id      = var.hosted_zone_id
  noindex             = true
  basic_auth_enabled  = var.staging.basic_auth_enabled
  basic_auth_user     = var.staging.basic_auth_user
  basic_auth_password = var.basic_auth_password
  allowed_ipv4_cidrs  = var.staging.allowed_ipv4_cidrs
  caching_enabled     = var.staging.caching_enabled
  oidc_provider_arn   = data.aws_iam_openid_connect_provider.github.arn
  deploy_subjects     = ["${var.github_subject_prefix}:environment:staging"]
}

module "production" {
  source = "../../modules/aws/static-site"
  count  = var.production == null ? 0 : 1

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name               = "${var.name}-production"
  bucket_name        = var.bucket_name
  prefix             = local.prefixes.production
  domains            = var.production.domains
  hosted_zone_id     = var.hosted_zone_id
  allowed_ipv4_cidrs = var.production.allowed_ipv4_cidrs
  caching_enabled    = var.production.caching_enabled
  oidc_provider_arn  = data.aws_iam_openid_connect_provider.github.arn
  deploy_subjects    = ["${var.github_subject_prefix}:environment:production"]
}
