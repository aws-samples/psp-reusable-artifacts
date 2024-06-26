variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}
variable "vpc_secondary_cidr" {
  description = "VPC CIDR secundary RFC6598"
  type        = list(string)
  default     = ["100.64.0.0/16"]
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Prefix name"
  type        = string
  default     = "cp-networking"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "control-plane"
}
