output "github_variables" {
  description = "サイトリポジトリのActionsのリポジトリ変数に設定する値。"
  value = merge(
    {
      AWS_REGION = var.region
      S3_BUCKET  = var.bucket_name
    },
    var.cms == null ? {} : {
      CMS_DOMAIN                = var.cms.domain
      CMS_ADMIN_DEPLOY_ROLE_ARN = module.cms[0].admin_deploy_role_arn
      CMS_PREVIEW_ROLE_ARN      = module.cms[0].preview_publisher_role_arn
    },
    var.staging == null ? {} : {
      STAGING_SITE_URL                   = coalesce(var.staging.site_url, "https://${var.staging.domains[0]}")
      STAGING_DEPLOY_ROLE_ARN            = module.staging[0].deploy_role_arn
      STAGING_CLOUDFRONT_DISTRIBUTION_ID = module.staging[0].distribution_id
    },
    var.production == null ? {} : {
      PRODUCTION_SITE_URL                   = coalesce(var.production.site_url, "https://${var.production.domains[0]}")
      PRODUCTION_DEPLOY_ROLE_ARN            = module.production[0].deploy_role_arn
      PRODUCTION_CLOUDFRONT_DISTRIBUTION_ID = module.production[0].distribution_id
    },
  )
}
