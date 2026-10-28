# Terraform

静的サイトの配信基盤（AWS）。サイトリポジトリは `terraform.tfvars` にパラメータを書くだけで使える（plan・applyの再利用workflowは別途提供）。

## 構成

| パス | 内容 |
|---|---|
| `modules/aws/static-site` | S3 + CloudFront + ACM + Route 53 + デプロイ用IAMロール。本番サイトと管理画面の両方に使う。Basic認証・IPv4制限・noindexはオプション |
| `modules/aws/preview` | PRごとのプレビュー（`pr-<番号>.<domain>`）。ワイルドカード証明書、Basic認証（常に有効）、30日で自動削除 |
| `bootstrap/aws` | 初回だけ手元で適用するルートモジュール。OIDCプロバイダ、plan/apply用ロール、stateバケット |
| `stacks/aws` | 上のモジュールを束ねたルートモジュール。変数は `site`・`admin`・`preview`（`null` なら作らない） |

## 使い方

最初に、[`bootstrap/aws`](bootstrap/aws/README.md)（OIDCプロバイダ・plan/applyロール・stateバケット）を1回だけ手元で適用する。

`stacks/aws/example.tfvars` を参考に `terraform.tfvars` を書く。

```hcl
hosted_zone_id        = "Z0123456789ABCDEFGHIJ"
github_subject_prefix = "repo:owner/site-repo"

site    = { bucket_name = "example-site", domains = ["www.example.com"] }
admin   = { bucket_name = "example-site-admin", domain = "cms.example.com", allowed_ipv4_cidrs = ["203.0.113.0/24"] }
preview = { bucket_name = "example-site-preview", domain = "preview.example.com" }
```

適用後、出力 `github_variables` の値をサイトリポジトリのActionsのリポジトリ変数に設定する。Basic認証の資格情報は出力 `basic_auth_ssm_parameters` のSSMパラメータ（SecureString、値は `ユーザー名:パスワード`）にある。

## 前提と制限

- Route 53のホストゾーンがあること。ホストゾーンが別サービスにある場合は未対応。
- GitHub OIDCプロバイダ（`token.actions.githubusercontent.com`）が同じアカウントに作成済みであること。
- 管理画面のIP制限はIPv4のみ。IPv6からのアクセスは拒否される。
- `github_subject_prefix` は、アカウントのOIDC subjectの形式に合わせる（IDを含める設定のアカウントでは `repo:owner@123/name@456`）。
- apply用の権限は強いため、このリポジトリの参照は必ずコミットハッシュで固定し、更新時に差分を確認する。
