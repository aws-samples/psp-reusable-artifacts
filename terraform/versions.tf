terraform {
    required_version = ">= 1.5.0, < 1.6.0"

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
        kubernetes = {
            source  = "hashicorp/kubernetes"
            version = ">= 2.20"
        }
        kubectl = {
            source  = "gavinbunney/kubectl"
            version = ">= 1.14"
        }
    }
    
#     backend "s3" {
#        bucket = "psp-controlplane-remotestate"
#        key    = "controlplane/tfstate/psp-controlplane.tfstate"
#        region = "us-east-1"
#    }
    backend "s3" {
       bucket = var.s3buckettfstate
       key    = "controlplane/tfstate/psp-controlplane.tfstate"
       region = var.aws_region
   }
}