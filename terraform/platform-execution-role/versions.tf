terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  #   backend "s3" {
  #     bucket = "BUCKETNAME"
  #     key    = "controlplane/tfstate/platform-execution-role.tfstate"
  #     region = "REGION"
  #   }
}
