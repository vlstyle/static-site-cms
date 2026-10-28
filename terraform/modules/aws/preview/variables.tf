variable "name" {
  description = "リソース名の接頭辞（ロール名・SSMパラメータ名などに使う）。"
  type        = string
  default     = "cms-preview"
}

variable "bucket_name" {
  description = "プレビューを置くS3バケット名。"
  type        = string
}

variable "domain" {
  description = "プレビューのドメイン。pr-<番号>.<domain> で配信する（ワイルドカード証明書とレコードを作る）。"
  type        = string
}

variable "hosted_zone_id" {
  description = "ドメインのRoute 53ホストゾーンID。"
  type        = string
}

variable "expire_days" {
  description = "プレビューのファイルを自動削除するまでの日数。"
  type        = number
  default     = 30
}

variable "price_class" {
  type    = string
  default = "PriceClass_200"
}

variable "basic_auth_reader_iam_group" {
  description = "Basic認証の資格情報（SSMパラメータ）を読めるIAMグループ名。nullなら付与しない。"
  type        = string
  default     = null
}

variable "oidc_provider_arn" {
  description = "GitHub ActionsのOIDCプロバイダのARN。"
  type        = string
}

variable "publisher_subjects" {
  description = "プレビューを配置するロールを引き受けられるGitHub OIDCのsubject。"
  type        = list(string)
}
