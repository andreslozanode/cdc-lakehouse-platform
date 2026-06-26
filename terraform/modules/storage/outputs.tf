output "bucket_names" {
  value = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "warehouse_uri" {
  value       = "s3://${aws_s3_bucket.this["warehouse"].id}/warehouse"
  description = "URI base del warehouse Iceberg."
}

output "savepoints_uri" {
  value = "s3://${aws_s3_bucket.this["savepoints"].id}/savepoints"
}
