
output "role_name" {
  description = "The Role name"
  value       = aws_iam_role.psp_control_plane_execution.name
}

output "role_arn" {
  description = "The Role ARN"
  value       = aws_iam_role.psp_control_plane_execution.arn
}

# output "assume_role_cluster" {
#   description = "AWS Cli assume role before create Amazon EKS"
#   value       = <<-EOT
#     aws sts assume-role --role-arn "${aws_iam_role.psp_control_plane_execution.arn}" --role-session-name awscli-create-eks

#     #Verify permissions
#     aws sts get-caller-identity
#     EOT
# }
