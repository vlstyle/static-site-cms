variable "name" {
  description = "リソース名の接頭辞（ロール名・SSMパラメータ名などに使う）。"
  type        = string
  default     = "cms"
}

variable "bucket_name" {
  description = "管理画面とプレビューを置く既存のS3バケット名（バケット自体はこのモジュールでは作らない）。"
  type        = string
}

variable "prefix" {
  description = "バケット内で、このモジュールが使うキーのプレフィックス。<prefix>/admin/ に管理画面、<prefix>/preview/pr-<番号>/ にプレビューを置く。"
  type        = string
  default     = "cms"
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

variable "admin_caching_enabled" {
  description = "管理画面（/admin/*）のキャッシュ。trueならCachingOptimized、falseならCachingDisabled（Cache-Control: no-cache も付ける）。trueのときは、管理画面の配信後にキャッシュを無効化する（outputs の distribution_id）。"
  type        = bool
  default     = true
}

variable "preview_caching_enabled" {
  description = "プレビュー（/preview/pr-<番号>/）のキャッシュ。trueならCachingOptimized、falseならCachingDisabled（Cache-Control: no-cache も付ける）。"
  type        = bool
  default     = false
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
  description = "Basic認証のパスワード。basic_auth_enabledがtrueのとき必須。CloudFront Functionにはハッシュ（ソルト付きSHA-256）だけを埋め込む。"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = !var.basic_auth_enabled || (var.basic_auth_password != null && var.basic_auth_password != "")
    error_message = "basic_auth_enabledがtrueのときは、basic_auth_passwordを指定してください。"
  }
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
