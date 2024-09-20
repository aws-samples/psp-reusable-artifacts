data "terraform_remote_state" "platform-execution-role" {
  # backend = "local"
  # config = {
  #   path = "${path.module}/platform-execution-role/terraform.tfstate"
  # }

  backend = "s3"
  config = {
    bucket = "BUCKETNAME"
    key    = "controlplane/tfstate/platform-execution-role.tfstate"
    region = "REGION"
  }
}

# data "terraform_remote_state" "git" {
#   backend = "local"
#   config = {
#     path = "${path.module}/../codecommit/terraform.tfstate"
#   }
# }
