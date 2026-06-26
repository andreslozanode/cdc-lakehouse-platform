terraform {
  required_version = ">= 1.9.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }

  # Backend remoto: descomenta y ajusta para state compartido.
  # backend "s3" {
  #   bucket         = "cdc-tfstate-dev"
  #   key            = "cdc-lakehouse/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "cdc-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "cdc-streaming-lakehouse"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

resource "aws_kms_key" "lakehouse" {
  description             = "CDC lakehouse encryption (dev)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

module "storage" {
  source                  = "../../modules/storage"
  name_prefix             = var.name_prefix
  environment             = "dev"
  kms_key_arn             = aws_kms_key.lakehouse.arn
  force_destroy           = true
  noncurrent_version_days = 7
}

module "streaming" {
  source                = "../../modules/streaming"
  name_prefix           = var.name_prefix
  environment           = "dev"
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  allowed_cidrs         = var.allowed_cidrs
  kms_key_arn           = aws_kms_key.lakehouse.arn
  lakehouse_bucket_arns = values(module.storage.bucket_arns)
  broker_count          = 2
  broker_instance_type  = "kafka.t3.small"
}
