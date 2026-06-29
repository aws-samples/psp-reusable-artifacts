terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.37"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }

  backend "s3" {
    bucket  = "psp-tfstate-970479985461"
    key     = "psp-workshop/agentcore-mcp/terraform.tfstate"
    region  = "us-east-1"
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile != "" ? var.aws_profile : null
}
