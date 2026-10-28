# Terraform

静的サイトの配信基盤（AWS）。サイトリポジトリは `terraform.tfvars` にパラメータを書くだけで使える（plan・applyの再利用workflowは別途提供）。

## 構成

| パス | 内容 |
|---|---|
| `modules/aws/static-site` | S3 + CloudFront + ACM + Route 53 + デプロイ用IAMロール。本番サイトと管理画面の両方に使う。Basic認証・IPv4制限・noindexはオプション |
| `modules/aws/cms-hosting` | CMSの管理画面（`/admin/`）とPRのプレビュー（`/preview/pr-<番号>/`）を、1つのドメイン・S3バケット・CloudFrontで配信する。Basic認証、IPv4制限、noindex。プレビューは30日で自動削除。スターターのテンプレートが `base`（サブパス）に対応している必要がある |
| `modules/aws/preview` | PRごとのプレビューを別ホスト名（`pr-<番号>.<domain>`）で配信する。ワイルドカード証明書が必要。サイトを `base` 対応にできない場合の代替 |
| `stacks/aws` | `static-site` と `cms-hosting` を束ねたルートモジュール。変数は `site`・`cms`（`null` なら作らない） |

## 使い方

`stacks/aws/example.tfvars` を参考に `terraform.tfvars` を書く。

```hcl
hosted_zone_id        = "Z0123456789ABCDEFGHIJ"
github_subject_prefix = "repo:owner/site-repo"

site    = { bucket_name = "example-site", domains = ["www.example.com"] }
cms     = { bucket_name = "example-site-cms", domain = "cms.example.com", allowed_ipv4_cidrs = ["203.0.113.0/24"] }
```

### Basic認証のパスワード

`cms.basic_auth_enabled`（既定 `true`）が有効なとき、パスワードは次のどちらかで決まる。

| 方法 | 内容 |
|---|---|
| 外部から渡す（推奨） | 環境変数 `TF_VAR_cms_basic_auth_password`（GitHub ActionsのSecretから渡す）。リポジトリには書かない。CloudFront Functionにはソルト付きSHA-256のハッシュだけが入り、パスワード自体はstateにもSSMにも残らない |
| 自動生成 | 渡さなかった場合。`random_password` で生成し、SSM（`/<name>-cms/basic-auth`、値は `ユーザー名:パスワード`）に保存する。stateにも残る |

ユーザー名は `cms.basic_auth_user`（既定 `cms`）。

適用後、出力 `github_variables` の値をサイトリポジトリのActionsのリポジトリ変数に設定する。自動生成した場合のBasic認証の資格情報は、出力 `basic_auth_ssm_parameters` のSSMパラメータにある。

## 前提と制限

- Route 53のホストゾーンがあること。ホストゾーンが別サービスにある場合は未対応。
- GitHub OIDCプロバイダ（`token.actions.githubusercontent.com`）が同じアカウントに作成済みであること。
- 管理画面のIP制限はIPv4のみ。IPv6からのアクセスは拒否される。
- `github_subject_prefix` は、アカウントのOIDC subjectの形式に合わせる（IDを含める設定のアカウントでは `repo:owner@123/name@456`）。
- apply用の権限は強いため、このリポジトリの参照は必ずコミットハッシュで固定し、更新時に差分を確認する。
