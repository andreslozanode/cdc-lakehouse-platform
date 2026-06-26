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
  #   bucket         = "cdc-tfstate-prod"
  #   key            = "cdc-lakehouse/prod/terraform.tfstate"
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
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

resource "aws_kms_key" "lakehouse" {
  description             = "CDC lakehouse encryption (prod)"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

module "storage" {
  source                  = "../../modules/storage"
  name_prefix             = var.name_prefix
  environment             = "prod"
  kms_key_arn             = aws_kms_key.lakehouse.arn
  force_destroy           = false
  noncurrent_version_days = 30
}

module "streaming" {
  source                = "../../modules/streaming"
  name_prefix           = var.name_prefix
  environment           = "prod"
  vpc_id                = var.vpc_id
  subnet_ids            = var.subnet_ids
  allowed_cidrs         = var.allowed_cidrs
  kms_key_arn           = aws_kms_key.lakehouse.arn
  lakehouse_bucket_arns = values(module.storage.bucket_arns)
  broker_count          = 3
  broker_instance_type  = "kafka.m7g.large"
}
