output "msk_arn" { value = aws_msk_cluster.this.arn }
output "bootstrap_brokers_tls" { value = aws_msk_cluster.this.bootstrap_brokers_tls }
output "zookeeper_connect" { value = aws_msk_cluster.this.zookeeper_connect_string }
output "glue_registry_arn" { value = aws_glue_registry.this.arn }
output "flink_role_arn" { value = aws_iam_role.flink.arn }
