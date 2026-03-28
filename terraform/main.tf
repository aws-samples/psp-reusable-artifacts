provider "aws" {
  region = local.region

  assume_role {
    role_arn    = data.terraform_remote_state.platform-execution-role.outputs.role_arn
    external_id = "terraformSession-workshop"
  }
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
