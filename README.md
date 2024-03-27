# AWS - PSP Platform Egineering - Pilot



## Table of Contents

1. [How to deploy Infrastructure and Besu cluster](#how-to-deploy)
1. [Ingress Services](#ingress-services)
1. [Configuring Index Pattern in Kibana](#configuring-index-pattern-in-kibana)
1. [Testing Cluster Besu](#testing-cluster-besu)
1. [Stop and Start Besu Services](#stop-and-start-besu)
1. [Installing Sirato - Optional](#installing-sirato---optional)
1. [Troubleshooting](#troubleshooting)
1. [How to destroy infrastructure](#how-to-destroy)

## How to deploy

### Pre-reqs

- 2 AWS Accounts
    - Control Plane Account
        - S3 bucket for Terraform backend
    - Data Plane Account
- AWS SSO
- VPC and Subnet IDs
- terraform 1.5.0
- AWS CLI >= 2.3.1
- jq 1.6

Tag your subnets with: karpenter-discovery = $cluster-name
