resource "aws_iam_policy" "EKSFullAdmin" {
  name        = "EKSFullAdmin"
  description = "Allows full access to Amazon EKS"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "eks:*",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "EKSClusterOperator" {
  name        = "EKSClusterOperator"
  description = "Allows full access to Kubernetes API"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "eks:AccessKubernetesApi",
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role" "pspcontrolplane" {
  name = "PSPControlPlaneAdmin"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "AWS": "arn:aws:iam::aws:root"
        },
        "Condition": {
          "StringLike": {
            "aws:userid": "ADMIN*"
          }
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF

  tags = {
    env = "controlplane"
  }
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.pspcontrolplane.name
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment_eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFullAdmin"
  role       = aws_iam_role.pspcontrolplane.name
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment_ecr" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.pspcontrolplane.name
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment_ecrpublic" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicPowerUser"
  role       = aws_iam_role.pspcontrolplane.name
}

resource "aws_iam_role_policy_attachment" "role_policy_attachment_vpc" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  role       = aws_iam_role.pspcontrolplane.name
}
