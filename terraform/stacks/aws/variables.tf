variable "region" {
  description = "メインのリージョン。"
  type        = string
  default     = "ap-northeast-1"
}

variable "name" {
  description = "リソース名の接頭辞。CMS（管理画面とプレビュー）のリソースは <name>、stagingは <name>-staging、productionは <name>-production になる。"
  type        = string
  default     = "cms"
}

variable "tags" {
  description = "全リソースに付けるタグ。"
  type        = map(string)
  default     = {}
}

variable "hosted_zone_id" {
  description = "公開ドメインのRoute 53ホストゾーンID。"
  type        = string
}

variable "github_subject_prefix" {
  description = "GitHub OIDCのsubjectのうち、リポジトリを指す部分。例: repo:owner/name（subjectにIDを含める設定のアカウントでは repo:owner@123/name@456）。"
  type        = string
}

variable "bucket_name" {
  description = "cms・staging・production・terraformを置く共有のS3バケット名。bootstrap/awsで作成済みのもの。"
  type        = string
}

variable "cms" {
  description = "CMSの管理画面（/admin/）とPRのプレビュー（/preview/pr-<番号>/）。nullなら作らない。"
  type = object({
    domain              = string
    basic_auth_enabled  = optional(bool, true)
    basic_auth_user     = optional(string, "cms")
    allowed_ipv4_cidrs  = optional(list(string), [])
    preview_expire_days = optional(number, 30)
  })
  default = null
}

variable "staging" {
  description = "mainにマージされた内容が常に反映される最終確認用のサイト。noindexを付ける。nullなら作らない。site_urlを省略すると https://<domains[0]> になる。"
  type = object({
    domains            = list(string)
    site_url           = optional(string)
    basic_auth_enabled = optional(bool, true)
    basic_auth_user    = optional(string, "staging")
    allowed_ipv4_cidrs = optional(list(string), [])
  })
  default = null
}

variable "production" {
  description = "公開サイト。nullなら作らない。site_urlを省略すると https://<domains[0]> になる。"
  type = object({
    domains            = list(string)
    site_url           = optional(string)
    allowed_ipv4_cidrs = optional(list(string), [])
  })
  default = null
}

variable "basic_auth_password" {
  description = "CMSとstagingのBasic認証のパスワード（Basic認証が有効なとき必須）。TF_VAR_basic_auth_passwordで渡し、リポジトリには書かない。"
  type        = string
  default     = null
  sensitive   = true
}
