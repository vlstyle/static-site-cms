locals {
  wildcard_domain = "*.${var.domain}"
  basic_auth_user = "preview"
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

    filter {}

    expiration {
      days = var.expire_days
    }

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

resource "random_password" "basic_auth" {
  length  = 24
  special = false
}

resource "aws_ssm_parameter" "basic_auth" {
  name  = "/${var.name}/basic-auth"
  type  = "SecureString"
  value = "${local.basic_auth_user}:${random_password.basic_auth.result}"
}

data "aws_iam_policy_document" "basic_auth_reader" {
  count = var.basic_auth_reader_iam_group != null ? 1 : 0

  statement {
    sid       = "ReadBasicAuth"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.basic_auth.arn]
  }

  statement {
    sid       = "DecryptViaSsm"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["ssm.*.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "basic_auth_reader" {
  count = var.basic_auth_reader_iam_group != null ? 1 : 0

  name   = "${var.name}-basic-auth-reader"
  policy = data.aws_iam_policy_document.basic_auth_reader[0].json
}

resource "aws_iam_group_policy_attachment" "basic_auth_reader" {
  count = var.basic_auth_reader_iam_group != null ? 1 : 0

  group      = var.basic_auth_reader_iam_group
  policy_arn = aws_iam_policy.basic_auth_reader[0].arn
}

resource "aws_cloudfront_function" "this" {
  name    = var.name
  runtime = "cloudfront-js-2.0"
  publish = true
  comment = "Basic auth and host-to-prefix rewrite for PR previews"

  code = templatefile("${path.module}/function.js.tftpl", {
    basic_auth   = base64encode("${local.basic_auth_user}:${random_password.basic_auth.result}")
    domain_regex = replace(var.domain, ".", "\\.")
  })
}

resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name       = local.wildcard_domain
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

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "PR previews"
  aliases         = [local.wildcard_domain]
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
  name    = local.wildcard_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "aaaa" {
  zone_id = var.hosted_zone_id
  name    = local.wildcard_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

data "aws_iam_policy_document" "publisher_trust" {
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
      values   = var.publisher_subjects
    }
  }
}

resource "aws_iam_role" "publisher" {
  name               = "github-actions-${var.name}-publisher"
  assume_role_policy = data.aws_iam_policy_document.publisher_trust.json
}

data "aws_iam_policy_document" "publisher" {
  statement {
    sid       = "ListPreviewBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["pr-*"]
    }
  }

  statement {
    sid       = "WritePreviewObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.this.arn}/pr-*"]
  }
}

resource "aws_iam_role_policy" "publisher" {
  name   = "${var.name}-publisher"
  role   = aws_iam_role.publisher.id
  policy = data.aws_iam_policy_document.publisher.json
}
