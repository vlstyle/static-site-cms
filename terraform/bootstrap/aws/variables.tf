variable "region" {
  description = "メインのリージョン。"
  type        = string
  default     = "ap-northeast-1"
}

variable "name" {
  description = "リソース名の接頭辞。ロール名が <name>-terraform-plan / <name>-terraform-apply になる。"
  type        = string
  default     = "static-site-cms"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "state_bucket_name" {
  description = "Terraform stateを置くS3バケット名。"
  type        = string
}

variable "github_subject_prefix" {
  description = "GitHub OIDCのsubjectのうち、リポジトリを指す部分。例: repo:owner/name（subjectにIDを含める設定のアカウントでは repo:owner@123/name@456）。"
  type        = string
}

variable "create_oidc_provider" {
  description = "GitHub ActionsのOIDCプロバイダを作る。同じアカウントに作成済みならfalse。"
  type        = bool
  default     = true
}

variable "apply_policy_arns" {
  description = "apply用ロールに付けるIAMポリシー。既定は全権限なので、運用に合わせて絞ることを推奨する。"
  type        = list(string)
  default     = ["arn:aws:iam::aws:policy/AdministratorAccess"]
}
