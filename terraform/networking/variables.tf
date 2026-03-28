variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Prefix name for resources"
  type        = string
  default     = "psp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "workshop"
}
