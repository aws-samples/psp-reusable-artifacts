# Architecture Overview

```mermaid
graph TB
    subgraph DEVOPS["🤖 DevOps Agent Account"]
        DA[AWS DevOps Agent<br/>Observes all environments<br/>Consumes Platform MCPs]
    end

    subgraph GENAI["🧠 GenAI MCP Account"]
        AC[Bedrock AgentCore Runtime<br/>ArgoCD MCP Server<br/>Streamable HTTP /mcp:8000]
        COG[Cognito User Pool<br/>OAuth M2M<br/>client_credentials grant]
        ECRM[ECR · argocd-mcp]
        SM[Secrets Manager<br/>ArgoCD API Token]
        CBM[CodeBuild · ARM64]
    end

    subgraph HUB["⚙️ Control Plane Account"]
        subgraph EKS["EKS Cluster · Auto Mode · control-plane"]
            ACK[ACK Capability<br/>Provisions EKS in spokes]
            KRO[KRO Capability<br/>Resource Graph Definitions]
            ARGO[ArgoCD Capability<br/>GitOps from CodeCommit]
        end
        CC[CodeCommit<br/>control-plane-operations]
        PIPE[CI/CD Pipeline<br/>Java → Docker → Helm → Deploy]
        IAM[control-plane-admin<br/>Cross-account AssumeRole]
        ECR[ECR · App images + Charts]
        IDC[IAM Identity Center<br/>SSO for ArgoCD UI]
    end

    subgraph SPOKES["📦 Data Plane Accounts · Spoke"]
        DEV[Dev<br/>EKS Auto Mode<br/>credit-card + monitoring]
        STG[Staging<br/>EKS Auto Mode]
        PROD[Prod<br/>EKS Auto Mode<br/>credit-card + monitoring]
    end

    DA -->|OAuth token| COG
    DA -->|MCP · Bearer token| AC
    AC -->|HTTPS · ArgoCD API| ARGO
    SM -.->|Token at startup| AC
    ECRM -.->|Image pull| AC
    CBM -->|Build & push| ECRM

    CC -->|GitOps sync| ARGO
    ARGO -->|Deploy claims| KRO
    KRO -->|K8s resources| ACK
    ACK -->|sts:AssumeRole| IAM
    IAM -->|control-plane-execution| DEV
    IAM -->|control-plane-execution| STG
    IAM -->|control-plane-execution| PROD
    ARGO -->|Helm deploy| DEV
    ARGO -->|Helm deploy| STG
    ARGO -->|Helm deploy| PROD
    PIPE -->|Update ops repo| CC
    PIPE -->|Push images| ECR

    style DEVOPS fill:#e8f5e9,stroke:#4caf50,stroke-width:2px
    style GENAI fill:#fff8e1,stroke:#ff8f00,stroke-width:2px
    style HUB fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    style SPOKES fill:#fce4ec,stroke:#c62828,stroke-width:2px
    style EKS fill:#bbdefb,stroke:#1976d2
```

> **Deployment Modes:**
> - **Multi-account (production):** Separate AWS accounts for Hub, GenAI MCP, and Spoke(s) as shown in the architecture diagram.
> - **Single-account (workshop/dev):** All components in one account. Set `enable_ecr_replication = false` in bootstrap, and use the same account ID for `spoke_account_id`.

## IAM Model

```mermaid
graph TB
    subgraph HUB_IAM["Hub Account"]
        CPA["control-plane-admin<br/>━━━━━━━━━━━━━━━━━━<br/>Trust: pods.eks · capabilities.eks<br/>Permissions: sts:AssumeRole"]
    end

    subgraph GENAI_IAM["GenAI MCP Account"]
        AGE["agentcore-argocd-mcp-execution<br/>━━━━━━━━━━━━━━━━━━━━━━━━━━━<br/>Trust: bedrock-agentcore.amazonaws.com<br/>Permissions: ECR pull · Secrets Manager · CW"]
    end

    subgraph SPOKE_IAM["Spoke Accounts"]
        CPE["control-plane-execution<br/>━━━━━━━━━━━━━━━━━━━━━<br/>Trust: hub control-plane-admin<br/>Permissions: EKS · IAM · EC2 · CW Logs"]
    end

    CPA -->|sts:AssumeRole| CPE

    style HUB_IAM fill:#e3f2fd,stroke:#1976d2
    style GENAI_IAM fill:#fff8e1,stroke:#ff8f00
    style SPOKE_IAM fill:#fce4ec,stroke:#c62828
```
