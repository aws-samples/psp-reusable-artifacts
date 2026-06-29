# Modules

## bootstrap/ — Control Plane (Hub Account)

```mermaid
graph TB
    subgraph BOOTSTRAP["bootstrap/ · Terraform"]
        VPC[VPC + Subnets]
        EKS[EKS Cluster<br/>Auto Mode]
        CAPS[Capabilities<br/>ACK · KRO · ArgoCD]
        IAM_R[IAM<br/>control-plane-admin]
        CC_R[CodeCommit<br/>+ seed repo]
        PIPE_R[CI/CD Pipeline<br/>CodePipeline + CodeBuild]
        ECR_R[ECR Repositories]
        TMPL[Templates<br/>ApplicationSets · Manifests]
    end

    VPC --> EKS
    EKS --> CAPS
    IAM_R --> CAPS
    CC_R --> TMPL
    TMPL --> CC_R
    ECR_R --> PIPE_R

    style BOOTSTRAP fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
```

Dependencies: `terraform-aws-modules/eks/aws` (~> 21.15), `terraform-aws-modules/vpc/aws` (~> 6.0)

## agentcore-mcp/ — GenAI MCP Platform

```mermaid
graph TB
    subgraph AGENTCORE["agentcore-mcp/ · Terraform"]
        ECR_A[ECR<br/>argocd-mcp]
        CB_A[CodeBuild<br/>ARM64 native build]
        SM_A[Secrets Manager<br/>ArgoCD API Token]
        COG_A[Cognito<br/>OAuth M2M]
        IAM_A[IAM<br/>AgentCore execution role]
        RT_A[AgentCore Runtime<br/>ArgoCD MCP Server]
    end

    ECR_A --> CB_A
    CB_A --> RT_A
    SM_A --> RT_A
    COG_A --> RT_A
    IAM_A --> RT_A

    style AGENTCORE fill:#fff8e1,stroke:#ff8f00,stroke-width:2px
```

Inputs: `argocd_server_url` (from bootstrap outputs), `argocd_api_token` (manual)

## catalog/ — Platform APIs (KRO RGDs)

| RGD | Kind | Purpose |
|-----|------|---------|
| eks-cluster.yaml | EKSCluster | Provisions EKS Auto Mode cluster in spoke account with IAM roles, addons, ArgoCD registration |
| helm-install.yaml | HelmInstall | Creates ArgoCD Application for Helm chart deployment to spoke clusters |
| spoke-account-iam.yaml | SpokeAccountIAM | Maps K8s namespace to spoke account execution role via IAMRoleSelector |

## runtime/ — Environment Claims

```
runtime/<environment>/<runtime-name>/
├── data-plane/claim.yaml    # SpokeAccountIAM + EKSCluster + HelmInstall
└── apps/                    # Application configs for ApplicationSets
    ├── config.json          # { chartUrl, chartName, chartVersion, clusterName, namespace }
    └── values.yaml          # Helm values overrides
```
