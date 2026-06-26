# ---------------------------------------------------------------------------
# Streaming module: MSK (Kafka) + Glue Schema Registry + IAM para Flink/Connect
# Equivalente gestionado del plano de datos que en local corre en docker-compose.
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

# --- MSK cluster (Kafka gestionado) -----------------------------------------
resource "aws_msk_cluster" "this" {
  cluster_name           = "${var.name_prefix}-msk-${var.environment}"
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.broker_count

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]
    storage_info {
      ebs_storage_info { volume_size = var.broker_ebs_gb }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "TLS"
      in_cluster    = true
    }
    encryption_at_rest_kms_key_arn = var.kms_key_arn
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  open_monitoring {
    prometheus {
      jmx_exporter { enabled_in_broker = true }
      node_exporter { enabled_in_broker = true }
    }
  }

  tags = var.tags
}

resource "aws_msk_configuration" "this" {
  name           = "${var.name_prefix}-msk-cfg-${var.environment}"
  kafka_versions = [var.kafka_version]

  # Producción CDC: compresión zstd, retención e idempotencia.
  server_properties = <<-PROPS
    auto.create.topics.enable=false
    default.replication.factor=${var.broker_count >= 3 ? 3 : var.broker_count}
    min.insync.replicas=${var.broker_count >= 3 ? 2 : 1}
    num.partitions=12
    compression.type=zstd
    log.retention.hours=168
    unclean.leader.election.enable=false
  PROPS
}

resource "aws_security_group" "msk" {
  name        = "${var.name_prefix}-msk-${var.environment}"
  description = "MSK broker access"
  vpc_id      = var.vpc_id

  ingress {
    description = "Kafka TLS from app subnets"
    from_port   = 9094
    to_port     = 9094
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

# --- Glue Schema Registry (reemplaza Confluent SR en AWS) -------------------
resource "aws_glue_registry" "this" {
  registry_name = "${var.name_prefix}-cdc-${var.environment}"
  description    = "Avro schemas for CDC topics"
  tags           = var.tags
}

# --- IAM role para tareas Flink (acceso S3 lakehouse + MSK) -----------------
data "aws_iam_policy_document" "flink_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com", "kinesisanalytics.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flink" {
  name               = "${var.name_prefix}-flink-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.flink_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "flink" {
  statement {
    sid       = "S3Lakehouse"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
    resources = concat(var.lakehouse_bucket_arns, [for a in var.lakehouse_bucket_arns : "${a}/*"])
  }
  statement {
    sid       = "MSKConnect"
    actions   = ["kafka-cluster:Connect", "kafka-cluster:DescribeCluster", "kafka-cluster:*Topic*", "kafka-cluster:ReadData", "kafka-cluster:WriteData", "kafka-cluster:AlterGroup", "kafka-cluster:DescribeGroup"]
    resources = ["${aws_msk_cluster.this.arn}", "${replace(aws_msk_cluster.this.arn, ":cluster/", ":topic/")}/*", "${replace(aws_msk_cluster.this.arn, ":cluster/", ":group/")}/*"]
  }
  statement {
    sid       = "GlueSchemaRegistry"
    actions   = ["glue:GetSchema*", "glue:RegisterSchemaVersion", "glue:PutSchemaVersionMetadata", "glue:CreateSchema"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flink" {
  name   = "flink-data-access"
  role   = aws_iam_role.flink.id
  policy = data.aws_iam_policy_document.flink.json
}
