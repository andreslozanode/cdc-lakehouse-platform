output "warehouse_uri" {
  value = module.storage.warehouse_uri
}
output "savepoints_uri" {
  value = module.storage.savepoints_uri
}
output "bucket_names" {
  value = module.storage.bucket_names
}
output "msk_bootstrap_brokers_tls" {
  value     = module.streaming.bootstrap_brokers_tls
  sensitive = true
}
output "flink_role_arn" {
  value = module.streaming.flink_role_arn
}
