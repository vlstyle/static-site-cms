variable "name" {
  description = "リソース名の接頭辞（ロール名・SSMパラメータ名などに使う）。"
  type        = string
}

variable "bucket_name" {
  description = "配信するファイルを置くS3バケット名。"
  type        = string
}

variable "domains" {
  description = "公開するドメイン名。先頭がACM証明書のメインのドメインで、残りはSANになる。"
  type        = list(string)

  validation {
    condition     = length(var.domains) > 0
    error_message = "domains には1つ以上のドメインを指定してください。"
  }
}

variable "hosted_zone_id" {
  description = "ドメインのRoute 53ホストゾーンID。証明書の検証レコードとエイリアスレコードを作る。"
  type        = string
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "caching_enabled" {
  description = "falseにするとキャッシュを無効にする（管理画面のように更新をすぐ反映したい場合）。"
  type        = bool
  default     = true
}

variable "not_found_page" {
  description = "存在しないパスで返すページ（ステータスは404）。nullなら設定しない。"
  type        = string
  default     = "/404.html"
}

variable "noindex" {
  description = "trueにすると全レスポンスに X-Robots-Tag: noindex, nofollow を付ける。"
  type        = bool
  default     = false
}

variable "basic_auth_enabled" {
  description = "trueにするとBasic認証を必須にする。資格情報は自動生成してSSMに保存する。"
  type        = bool
  default     = false
}

variable "basic_auth_reader_iam_group" {
  description = "Basic認証の資格情報（SSMパラメータ）を読めるIAMグループ名。nullなら付与しない。"
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

variable "deploy_subjects" {
  description = "デプロイ用ロールを引き受けられるGitHub OIDCのsubject。空ならロールを作らない。"
  type        = list(string)
  default     = []
}
