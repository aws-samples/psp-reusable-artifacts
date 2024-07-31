resource "random_id" "id" {
  byte_length = 5
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.controlplaneaccountid}:root"]
    }
  }
}

resource "aws_iam_role" "psp_control_plane_execution" {
  name               = "PSP-ControlPlane-Execution-${random_id.id.hex}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "vpc_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonVPCFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "iam_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "ecr_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "eventbridge_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "ec2_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "s3_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "sqs_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy_attachment" "ssm_full_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = aws_iam_role.psp_control_plane_execution.name
}

resource "aws_iam_role_policy" "eks_full_access" {
  name = "EKSFullAccess"
  role = aws_iam_role.psp_control_plane_execution.name

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["eks:*"],
        "Resource": ["*"]
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "amazon_kms_full_access" {
  name = "AmazonKMSFullAccess"
  role = aws_iam_role.psp_control_plane_execution.name

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["kms:*"],
        "Resource": ["*"]
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "sts_ecr_access" {
  name = "STSandECRAccess"
  role = aws_iam_role.psp_control_plane_execution.name

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": ["ecr-public:GetAuthorizationToken","sts:GetServiceBearerToken"],
        "Resource": ["*"]
      }
    ]
  }
  EOF
}
