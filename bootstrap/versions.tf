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
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }

  backend "s3" {
    bucket  = "psp-tfstate-970479985461"
    key     = "psp-workshop/bootstrap/terraform.tfstate"
    region  = "us-east-1"
    profile = "caribei-Admin"
  }
}
