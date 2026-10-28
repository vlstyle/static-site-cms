output "github_variables" {
  description = "サイトリポジトリのActionsのリポジトリ変数に設定する値。"
  value = merge(
    var.site == null ? {} : {
      DEPLOY_TARGET              = "aws"
      AWS_DEPLOY_ROLE_ARN        = module.site[0].deploy_role_arn
      AWS_REGION                 = var.region
      S3_BUCKET                  = module.site[0].bucket
      CLOUDFRONT_DISTRIBUTION_ID = module.site[0].distribution_id
    },
    var.cms == null ? {} : {
      CMS_DOMAIN                = var.cms.domain
      CMS_S3_BUCKET             = module.cms[0].bucket
      CMS_ADMIN_DEPLOY_ROLE_ARN = module.cms[0].admin_deploy_role_arn
      CMS_PREVIEW_ROLE_ARN      = module.cms[0].preview_publisher_role_arn
    },
  )
}

output "basic_auth_ssm_parameters" {
  description = "Basic認証の資格情報（自動生成した場合）が入っているSSMパラメータ名。"
  value       = compact([var.cms == null ? null : module.cms[0].basic_auth_ssm_parameter])
}
