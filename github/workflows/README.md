# AWS - PSP Platform Egineering - Control Plane Automated Setup


### For Automation use case 
```mv /github ./github```

### Create OIDC Provider for Github


### Create Github Actions Role in the Control Plane Account with the following permission
GitHubAction-AssumeRoleWithAction
-EKS FullAdmin
-S3 Put,List
-ECR FullAdmin
-EC2 FullAdmin
-VPC FullAdmin

Use the following Trust Relationship
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::{CONTROLPLANE_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:{GITHUB_ORG}/*"
                }
            }
        },
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::{CONTROLPLANE_ACCOUNT_ID}:saml-provider/{USER_ID_SSO}"
            },
            "Action": [
                "sts:AssumeRoleWithSAML",
                "sts:TagSession"
            ],
            "Condition": {
                "StringEquals": {
                    "SAML:aud": "https://signin.aws.amazon.com/saml"
                }
            }
        }
    ]
}
```





