# Repository Ecosystem & CI/CD Pipeline

## Repository Ecosystem

Three repository types work together through the CI/CD pipeline and ArgoCD:

```mermaid
graph LR
    subgraph REPOS["📁 CodeCommit Repositories"]
        R1["🔵 credit-card-java<br/><i>App Code Repo</i><br/>Java · Dockerfile · buildspec<br/>Owner: Dev Team"]
        R2["🟢 credit-card-data-plane<br/><i>Helm Chart Repo</i><br/>Chart.yaml · values · templates<br/>Owner: Dev Team"]
        R3["🟡 control-plane-operations<br/><i>Platform Repo · GitOps</i><br/>argocd/ · catalog/ · runtime/<br/>Owner: Platform Team"]
    end

    subgraph ECR_REG["📦 ECR Container Registry"]
        E1[credit-card<br/>Docker image<br/>:latest :abc1234]
        E2[credit-card-chart<br/>OCI Helm chart<br/>0.1.0 · 0.2.0]
    end

    subgraph ARGO["🔄 ArgoCD"]
        A1[catalog App]
        A2[dataplane AppSets]
        A3[apps AppSets]
    end

    R1 -->|Pipeline builds| E1
    R2 -->|Pipeline packages| E2
    R3 -->|ArgoCD watches| A1
    R3 -->|ArgoCD watches| A2
    R3 -->|ArgoCD watches| A3
    E2 -.->|OCI pull| A3

    style REPOS fill:#f5f5f5,stroke:#666
    style ECR_REG fill:#fce4ec,stroke:#c62828
    style ARGO fill:#e8f5e9,stroke:#4caf50
```

| Repository | Type | Content | Consumed By |
|---|---|---|---|
| credit-card-java | App Code | Java source, Dockerfile, buildspec | CodePipeline Stage 1 |
| credit-card-data-plane | Helm Chart | Chart.yaml, values.yaml, templates/ | CodePipeline Stage 2 |
| control-plane-operations | Platform (GitOps) | argocd/, catalog/, runtime/, applications/ | ArgoCD (all ApplicationSets) |

## CI/CD Pipeline — Detailed Flow

```mermaid
graph LR
    subgraph TRIGGER["⚡ Trigger"]
        EB[EventBridge<br/>push to main]
    end

    subgraph PIPELINE["🔧 CodePipeline · credit-card-pipeline"]
        S1["<b>Stage 1: Build Image</b><br/>━━━━━━━━━━━━━━━━━<br/>1. mvn clean package<br/>2. docker build<br/>3. Push to ECR<br/>   :$COMMIT_SHA + :latest"]
        S2["<b>Stage 2: Package Chart</b><br/>━━━━━━━━━━━━━━━━━━<br/>1. Clone helm repo<br/>2. Update image tag<br/>3. helm package<br/>4. helm push OCI → ECR"]
        S3["<b>Stage 3: Update Ops</b><br/>━━━━━━━━━━━━━━━━━<br/>1. Get chart version<br/>2. Get image tag<br/>3. Update config.json<br/>4. Update values.yaml<br/>5. codecommit create-commit"]
    end

    subgraph OUTPUT["📤 Outputs"]
        ECR1[ECR: Docker image]
        ECR2[ECR: OCI Helm chart]
        OPS[Platform Repo updated<br/>config.json + values.yaml]
    end

    EB -->|credit-card-java| S1
    S1 --> S2
    S2 --> S3
    S1 -.-> ECR1
    S2 -.-> ECR2
    S3 --> OPS
    OPS -->|ArgoCD detects change| ARGO_SYNC[ArgoCD Sync ✅]

    style TRIGGER fill:#fff3e0,stroke:#e65100
    style PIPELINE fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    style OUTPUT fill:#e8f5e9,stroke:#2e7d32
```

### What Stage 3 writes to the Platform Repo

```
control-plane-operations/
├── runtime/development/credit-card/apps/
│   ├── config.json          ◄── { chartUrl, chartName, chartVersion }
│   └── values.yaml          ◄── { image.repository, image.tag }
```

## End-to-End: Code Push to Running Workload

```mermaid
sequenceDiagram
    participant Dev as 👨‍💻 Developer
    participant CC as 📁 credit-card-java
    participant Pipe as 🔧 CodePipeline
    participant ECR as 📦 ECR
    participant Ops as 📁 Platform Repo
    participant Argo as 🔄 ArgoCD
    participant Spoke as 📦 Spoke EKS

    Dev->>CC: git push (Java code)
    CC->>Pipe: EventBridge trigger
    Pipe->>ECR: Stage 1: Build & push Docker image
    Pipe->>ECR: Stage 2: Package & push Helm OCI chart
    Pipe->>Ops: Stage 3: Update config.json + values.yaml
    Ops-->>Argo: Git change detected
    Argo->>ECR: Pull OCI Helm chart
    Argo->>Ops: Pull values.yaml
    Argo->>Spoke: Helm install (multi-source)
    Note over Spoke: credit-card app running ✅
```
