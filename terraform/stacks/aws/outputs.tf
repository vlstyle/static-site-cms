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
    var.preview == null ? {} : {
      PREVIEW_ROLE_ARN = module.preview[0].publisher_role_arn
    },
    var.admin == null ? {} : {
      ADMIN_S3_BUCKET                  = module.admin[0].bucket
      ADMIN_CLOUDFRONT_DISTRIBUTION_ID = module.admin[0].distribution_id
      ADMIN_AWS_DEPLOY_ROLE_ARN        = module.admin[0].deploy_role_arn
    },
  )
}

output "basic_auth_ssm_parameters" {
  description = "Basic認証の資格情報が入っているSSMパラメータ名。"
  value = compact([
    var.admin == null ? null : module.admin[0].basic_auth_ssm_parameter,
    var.preview == null ? null : module.preview[0].basic_auth_ssm_parameter,
  ])
}
