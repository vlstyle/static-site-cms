locals {
  prefixes = {
    state      = "terraform"
    cms        = "cms"
    staging    = "staging"
    production = "production"
  }

  distribution_arns = merge(
    var.cms == null ? {} : { cms = module.cms[0].distribution_arn },
    var.staging == null ? {} : { staging = module.staging[0].distribution_arn },
    var.production == null ? {} : { production = module.production[0].distribution_arn },
  )
}

data "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

data "aws_iam_policy_document" "bucket" {
  dynamic "statement" {
    for_each = local.distribution_arns

    content {
      sid       = "AllowCloudFrontRead${statement.key}"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${data.aws_s3_bucket.this.arn}/${local.prefixes[statement.key]}/*"]

      principals {
        type        = "Service"
        identifiers = ["cloudfront.amazonaws.com"]
      }

      condition {
        test     = "StringEquals"
        variable = "AWS:SourceArn"
        values   = [statement.value]
      }
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  count = length(local.distribution_arns) > 0 ? 1 : 0

  bucket = data.aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.bucket.json
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = data.aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.cms == null ? [] : [var.cms.preview_expire_days]

    content {
      id     = "expire-previews"
      status = "Enabled"

      filter {
        prefix = "${local.prefixes.cms}/preview/"
      }

      expiration {
        days = rule.value
      }
    }
  }

  dynamic "rule" {
    for_each = keys(local.distribution_arns)

    content {
      id     = "expire-noncurrent-${rule.value}"
      status = "Enabled"

      filter {
        prefix = "${local.prefixes[rule.value]}/"
      }

      noncurrent_version_expiration {
        noncurrent_days = 7
      }
    }
  }

  rule {
    id     = "expire-noncurrent-state"
    status = "Enabled"

    filter {
      prefix = "${local.prefixes.state}/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "cleanup-delete-markers"
    status = "Enabled"

    filter {}

    expiration {
      expired_object_delete_marker = true
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
