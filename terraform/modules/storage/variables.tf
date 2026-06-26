variable "name_prefix" {
  type        = string
  description = "Prefijo de nombres de recursos."
  default     = "cdc"
}

variable "environment" {
  type        = string
  description = "dev | staging | prod"
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "kms_key_arn" {
  type        = string
  description = "ARN de KMS para SSE-KMS. null => SSE-S3 (AES256)."
  default     = null
}

variable "noncurrent_version_days" {
  type    = number
  default = 30
}
