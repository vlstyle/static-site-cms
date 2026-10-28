locals {
  generate_password = var.basic_auth_enabled && var.basic_auth_password == null
  password          = var.basic_auth_enabled ? coalesce(var.basic_auth_password, one(random_password.generated[*].result)) : null
  basic_auth_hash   = var.basic_auth_enabled ? nonsensitive(sha256("${random_id.salt.hex}${base64encode("${var.basic_auth_user}:${local.password}")}")) : ""
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "expire-previews"
    status = "Enabled"

    filter {
      prefix = "preview/"
    }

    expiration {
      days = var.preview_expire_days
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

data "aws_iam_policy_document" "bucket" {
  statement {
    sid       = "AllowCloudFrontRead"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}

resource "random_id" "salt" {
  byte_length = 16
}

resource "random_password" "generated" {
  count = local.generate_password ? 1 : 0

  length  = 24
  special = false
}

resource "aws_ssm_parameter" "basic_auth" {
  count = local.generate_password ? 1 : 0

  name  = "/${var.name}/basic-auth"
  type  = "SecureString"
  value = "${var.basic_auth_user}:${random_password.generated[0].result}"
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "basic_auth_reader" {
  count = local.generate_password && var.basic_auth_reader_iam_group != null ? 1 : 0

  statement {
    sid       = "ReadBasicAuth"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.basic_auth[0].arn]
  }

  statement {
    sid       = "DecryptViaSsm"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ssm.${data.aws_region.current.region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "basic_auth_reader" {
  count = local.generate_password && var.basic_auth_reader_iam_group != null ? 1 : 0

  name   = coalesce(var.basic_auth_reader_policy_name, "${var.name}-basic-auth-reader")
  policy = data.aws_iam_policy_document.basic_auth_reader[0].json
}

resource "aws_iam_group_policy_attachment" "basic_auth_reader" {
  count = local.generate_password && var.basic_auth_reader_iam_group != null ? 1 : 0

  group      = var.basic_auth_reader_iam_group
  policy_arn = aws_iam_policy.basic_auth_reader[0].arn
}

resource "aws_cloudfront_function" "this" {
  name    = var.name
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Routing for /admin and /preview/pr-N${var.basic_auth_enabled ? ", basic auth" : ""}${length(var.allowed_ipv4_cidrs) > 0 ? ", IP restriction" : ""}"

  code = templatefile("${path.module}/function.js.tftpl", {
    allowed_cidrs   = var.allowed_ipv4_cidrs
    basic_auth_hash = local.basic_auth_hash
    salt            = random_id.salt.hex
  })
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "${var.name}-noindex"

  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = "noindex, nofollow"
      override = true
    }
  }
}

resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name       = var.domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "validation" {
  for_each = {
    for o in aws_acm_certificate.this.domain_validation_options : o.domain_name => {
      name   = o.resource_record_name
      type   = o.resource_record_type
      record = o.resource_record_value
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.validation : r.fqdn]
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = var.name
  aliases         = [var.domain]
  price_class     = var.price_class
  http_version    = "http2and3"

  origin {
    domain_name              = aws_s3_bucket.this.bucket_regional_domain_name
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.this.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.this.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

resource "aws_route53_record" "a" {
  zone_id = var.hosted_zone_id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  zone_id = var.hosted_zone_id
  name    = var.domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_iam_policy_document" "admin_trust" {
  count = length(var.admin_deploy_subjects) > 0 ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.admin_deploy_subjects
    }
  }
}

resource "aws_iam_role" "admin" {
  count = length(var.admin_deploy_subjects) > 0 ? 1 : 0

  name               = "github-actions-${var.name}-admin-deploy"
  assume_role_policy = data.aws_iam_policy_document.admin_trust[0].json
}

data "aws_iam_policy_document" "admin" {
  count = length(var.admin_deploy_subjects) > 0 ? 1 : 0

  statement {
    sid       = "ListAdminPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["admin", "admin/*"]
    }
  }

  statement {
    sid       = "WriteAdminObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.this.arn}/admin/*"]
  }
}

resource "aws_iam_role_policy" "admin" {
  count = length(var.admin_deploy_subjects) > 0 ? 1 : 0

  name   = "${var.name}-admin-deploy"
  role   = aws_iam_role.admin[0].id
  policy = data.aws_iam_policy_document.admin[0].json
}

data "aws_iam_policy_document" "preview_trust" {
  count = length(var.preview_publisher_subjects) > 0 ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = var.preview_publisher_subjects
    }
  }
}

resource "aws_iam_role" "preview" {
  count = length(var.preview_publisher_subjects) > 0 ? 1 : 0

  name               = "github-actions-${var.name}-preview-publisher"
  assume_role_policy = data.aws_iam_policy_document.preview_trust[0].json
}

data "aws_iam_policy_document" "preview" {
  count = length(var.preview_publisher_subjects) > 0 ? 1 : 0

  statement {
    sid       = "ListPreviewPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["preview/pr-*"]
    }
  }

  statement {
    sid       = "WritePreviewObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.this.arn}/preview/pr-*"]
  }
}

resource "aws_iam_role_policy" "preview" {
  count = length(var.preview_publisher_subjects) > 0 ? 1 : 0

  name   = "${var.name}-preview-publisher"
  role   = aws_iam_role.preview[0].id
  policy = data.aws_iam_policy_document.preview[0].json
}
