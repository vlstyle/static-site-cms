locals {
  basic_auth_hash = var.basic_auth_enabled ? nonsensitive(sha256("${random_id.salt.hex}${base64encode("${var.basic_auth_user}:${var.basic_auth_password}")}")) : ""
}

data "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "random_id" "salt" {
  byte_length = 16
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

data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

resource "aws_cloudfront_response_headers_policy" "this" {
  name = "${var.name}-noindex"

  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = "noindex, nofollow"
      override = true
    }

    dynamic "items" {
      for_each = var.preview_caching_enabled ? [] : [1]

      content {
        header   = "Cache-Control"
        value    = "no-cache"
        override = true
      }
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "admin" {
  name = "${var.name}-admin"

  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = "noindex, nofollow"
      override = true
    }

    dynamic "items" {
      for_each = var.admin_caching_enabled ? [] : [1]

      content {
        header   = "Cache-Control"
        value    = "no-cache"
        override = true
      }
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
    domain_name              = data.aws_s3_bucket.this.bucket_regional_domain_name
    origin_path              = "/${var.prefix}"
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  ordered_cache_behavior {
    path_pattern               = "/admin/*"
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = var.admin_caching_enabled ? data.aws_cloudfront_cache_policy.optimized.id : data.aws_cloudfront_cache_policy.disabled.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.admin.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.this.arn
    }
  }

  default_cache_behavior {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = var.preview_caching_enabled ? data.aws_cloudfront_cache_policy.optimized.id : data.aws_cloudfront_cache_policy.disabled.id
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
    resources = [data.aws_s3_bucket.this.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.prefix}/admin", "${var.prefix}/admin/*"]
    }
  }

  statement {
    sid       = "WriteAdminObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${data.aws_s3_bucket.this.arn}/${var.prefix}/admin/*"]
  }

  statement {
    sid       = "Invalidate"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [aws_cloudfront_distribution.this.arn]
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
    resources = [data.aws_s3_bucket.this.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.prefix}/preview/pr-*"]
    }
  }

  statement {
    sid       = "WritePreviewObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${data.aws_s3_bucket.this.arn}/${var.prefix}/preview/pr-*"]
  }
}

resource "aws_iam_role_policy" "preview" {
  count = length(var.preview_publisher_subjects) > 0 ? 1 : 0

  name   = "${var.name}-preview-publisher"
  role   = aws_iam_role.preview[0].id
  policy = data.aws_iam_policy_document.preview[0].json
}
