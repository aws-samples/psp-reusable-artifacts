data "terraform_remote_state" "platform-execution-role" {
  backend = "s3"
  config = {
    bucket = "BUCKETNAME"
    key    = "controlplane/tfstate/platform-execution-role.tfstate"
    region = "REGION"
  }
}

data "terraform_remote_state" "networking" {
  backend = "s3"
  config = {
    bucket = "BUCKETNAME"
    key    = "controlplane/tfstate/psp-networking.tfstate"
    region = "REGION"
  }
}
