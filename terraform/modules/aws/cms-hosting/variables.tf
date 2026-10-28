variable "name" {
  description = "リソース名の接頭辞（ロール名・SSMパラメータ名などに使う）。"
  type        = string
  default     = "cms"
}

variable "bucket_name" {
  description = "管理画面とプレビューを置くS3バケット名。"
  type        = string
}

variable "domain" {
  description = "公開するドメイン名。/admin/ に管理画面、/preview/pr-<番号>/ にPRのプレビューを置く。"
  type        = string
}

variable "hosted_zone_id" {
  description = "ドメインのRoute 53ホストゾーンID。"
  type        = string
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "preview_expire_days" {
  description = "プレビュー（preview/）のファイルを自動削除するまでの日数。管理画面（admin/）は削除しない。"
  type        = number
  default     = 30
}

variable "basic_auth_enabled" {
  description = "trueにするとBasic認証を必須にする。"
  type        = bool
  default     = true
}

variable "basic_auth_user" {
  type    = string
  default = "cms"
}

variable "basic_auth_password" {
  description = "Basic認証のパスワード。nullなら自動生成してSSMに保存する。渡した場合はSSMには保存せず、CloudFront Functionにもハッシュ（ソルト付きSHA-256）だけを埋め込む。"
  type        = string
  default     = null
  sensitive   = true
}

variable "basic_auth_reader_iam_group" {
  description = "自動生成したBasic認証の資格情報（SSMパラメータ）を読めるIAMグループ名。nullなら付与しない。"
  type        = string
  default     = null
}

variable "basic_auth_reader_policy_name" {
  description = "Basic認証の資格情報を読むIAMポリシーの名前。nullなら <name>-basic-auth-reader。"
  type        = string
  default     = null
}

variable "allowed_ipv4_cidrs" {
  description = "アクセスを許可するIPv4のCIDR。空なら制限しない。IPv6からのアクセスは拒否される。"
  type        = list(string)
  default     = []
}

variable "oidc_provider_arn" {
  description = "GitHub ActionsのOIDCプロバイダのARN。"
  type        = string
}

variable "admin_deploy_subjects" {
  description = "管理画面（admin/）を配置するロールを引き受けられるGitHub OIDCのsubject。空ならロールを作らない。"
  type        = list(string)
  default     = []
}

variable "preview_publisher_subjects" {
  description = "プレビュー（preview/pr-*）を配置するロールを引き受けられるGitHub OIDCのsubject。空ならロールを作らない。"
  type        = list(string)
  default     = []
}
