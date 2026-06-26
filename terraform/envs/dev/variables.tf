variable "region" {
  type    = string
  default = "us-east-1"
}
variable "name_prefix" {
  type    = string
  default = "cdc"
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
