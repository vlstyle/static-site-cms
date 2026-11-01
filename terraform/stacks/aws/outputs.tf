output "env_files" {
  description = "サイトリポジトリの config/<環境名>.env に書く値。環境名をキーにしたマップ。"
  value = merge(
    var.cms == null ? {} : {
      cms = {
        AWS_REGION                 = var.region
        S3_BUCKET                  = var.bucket_name
        CMS_DOMAIN                 = var.cms.domain
        DEPLOY_ROLE_ARN            = module.cms[0].admin_deploy_role_arn
        CLOUDFRONT_DISTRIBUTION_ID = module.cms[0].distribution_id
        PREVIEW_ROLE_ARN           = module.cms[0].preview_publisher_role_arn
      }
    },
    var.staging == null ? {} : {
      staging = {
        AWS_REGION                 = var.region
        S3_BUCKET                  = var.bucket_name
        SITE_URL                   = coalesce(var.staging.site_url, "https://${var.staging.domains[0]}")
        DEPLOY_ROLE_ARN            = module.staging[0].deploy_role_arn
        CLOUDFRONT_DISTRIBUTION_ID = module.staging[0].distribution_id
      }
    },
    var.production == null ? {} : {
      production = {
        AWS_REGION                 = var.region
        S3_BUCKET                  = var.bucket_name
        SITE_URL                   = coalesce(var.production.site_url, "https://${var.production.domains[0]}")
        DEPLOY_ROLE_ARN            = module.production[0].deploy_role_arn
        CLOUDFRONT_DISTRIBUTION_ID = module.production[0].distribution_id
      }
    },
  )
}
