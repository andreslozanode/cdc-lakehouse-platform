# ---------------------------------------------------------------------------
# Storage module: S3 buckets for the Iceberg lakehouse (data + savepoints + ml)
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

locals {
  buckets = {
    lakehouse  = "${var.name_prefix}-lakehouse-${var.environment}"
    warehouse  = "${var.name_prefix}-iceberg-wh-${var.environment}"
    savepoints = "${var.name_prefix}-flink-savepoints-${var.environment}"
  }
}

resource "aws_s3_bucket" "this" {
  for_each      = local.buckets
  bucket        = each.value
  force_destroy = var.force_destroy
  tags          = merge(var.tags, { Role = each.key })
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle: expirar versiones viejas + abortar multipart incompletos.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket   = each.value.id

  rule {
    id     = "abort-incomplete-mpu"
    status = "Enabled"
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"
    noncurrent_version_expiration { noncurrent_days = var.noncurrent_version_days }
  }

  # Datos fríos Iceberg -> Glacier IR pasados 90 días (solo bucket lakehouse).
  dynamic "rule" {
    for_each = each.key == aws_s3_bucket.this["lakehouse"].id ? [1] : []
    content {
      id     = "cold-to-glacier"
      status = "Enabled"
      filter { prefix = "warehouse/cold/" }
      transition {
        days          = 90
        storage_class = "GLACIER_IR"
      }
    }
  }
}
