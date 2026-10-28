variable "region" {
  description = "メインのリージョン。"
  type        = string
  default     = "ap-northeast-1"
}

variable "name" {
  description = "リソース名の接頭辞。IAMロール名・SSMパラメータ名などの接頭辞（本番サイトは <name>-site、CMSは <name> になる）。"
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

variable "basic_auth_reader_iam_group" {
  description = "Basic認証の資格情報（SSM）を読めるIAMグループ名。nullなら付与しない。"
  type        = string
  default     = null
}

variable "site" {
  description = "本番サイト（S3 + CloudFront）。nullなら作らない。"
  type = object({
    bucket_name = string
    domains     = list(string)
  })
  default = null
}

variable "cms" {
  description = "CMSの管理画面（/admin/）とPRのプレビュー（/preview/pr-<番号>/）を1つのドメインで配信する。nullなら作らない。"
  type = object({
    bucket_name         = string
    domain              = string
    basic_auth_enabled  = optional(bool, true)
    basic_auth_user     = optional(string, "cms")
    allowed_ipv4_cidrs  = optional(list(string), [])
    preview_expire_days = optional(number, 30)
  })
  default = null
}

variable "cms_basic_auth_password" {
  description = "CMSのBasic認証のパスワード。nullなら自動生成してSSMに保存する。渡す場合はTF_VAR_cms_basic_auth_passwordで渡し、リポジトリには書かない。"
  type        = string
  default     = null
  sensitive   = true
}
