variable "name_prefix" {
  type    = string
  default = "cdc"
}
variable "environment" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "subnet_ids" {
  type = list(string)
}
variable "allowed_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/8"]
}
variable "kafka_version" {
  type    = string
  default = "3.8.0"
}
variable "broker_count" {
  type    = number
  default = 3
}
variable "broker_instance_type" {
  type    = string
  default = "kafka.m7g.large"
}
variable "broker_ebs_gb" {
  type    = number
  default = 200
}
variable "kms_key_arn" {
  type = string
}
variable "lakehouse_bucket_arns" {
  type = list(string)
}
variable "tags" {
  type    = map(string)
  default = {}
}
