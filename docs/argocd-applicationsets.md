# ArgoCD ApplicationSets

ArgoCD uses six ApplicationSets (two per environment) plus one static Application:

```mermaid
graph TB
    subgraph PLATFORM_REPO["📁 Platform Repo · control-plane-operations"]
        CAT[catalog/<br/>eks-cluster.yaml<br/>helm-install.yaml<br/>spoke-account-iam.yaml]
        DP_DIR[runtime/development/*/data-plane/<br/>claim.yaml]
        APP_FILE[runtime/development/*/apps/<br/>config.json + values.yaml]
    end

    subgraph ARGOCD["🔄 ArgoCD on Hub EKS Cluster"]
        subgraph STATIC["Static Application"]
            CATALOG_APP["📋 catalog<br/>Syncs RGDs to kro-system"]
        end

        subgraph DP_APPSETS["Data-Plane ApplicationSets · Provision Infrastructure"]
            DP_DEV["dataplane-development<br/><i>Git Directory Generator</i>"]
            DP_STG["dataplane-staging"]
            DP_PROD["dataplane-production"]
        end

        subgraph APP_APPSETS["Apps ApplicationSets · Deploy Workloads"]
            APP_DEV["apps-development<br/><i>Git File Generator</i>"]
            APP_STG["apps-staging"]
            APP_PROD["apps-production"]
        end
    end

    subgraph GENERATED["🚀 Generated Applications"]
        G1["credit-card-dataplane-development<br/>→ Hub cluster · KRO claims"]
        G2["credit-card-apps-development<br/>→ Spoke cluster · Helm chart"]
    end

    CAT -->|watches| CATALOG_APP
    DP_DIR -->|discovers directories| DP_DEV
    APP_FILE -->|reads config.json| APP_DEV

    DP_DEV -->|generates| G1
    APP_DEV -->|generates| G2

    style PLATFORM_REPO fill:#fff8e1,stroke:#ff8f00
    style ARGOCD fill:#e8f5e9,stroke:#4caf50,stroke-width:2px
    style STATIC fill:#c8e6c9,stroke:#388e3c
    style DP_APPSETS fill:#bbdefb,stroke:#1976d2
    style APP_APPSETS fill:#bbdefb,stroke:#1976d2
    style GENERATED fill:#f3e5f5,stroke:#7b1fa2
```

## Data-Plane vs Apps ApplicationSets

| | Data-Plane AppSet | Apps AppSet |
|---|---|---|
| Generator | Git Directory | Git File (config.json) |
| Watches | `runtime/{env}/*/data-plane/` | `runtime/{env}/*/apps/config.json` |
| Deploys to | Hub cluster (control-plane) | Spoke clusters (by name) |
| Content | KRO claims (SpokeAccountIAM, EKSCluster, HelmInstall) | OCI Helm charts from ECR + values.yaml from Git |
| Purpose | Provision infrastructure | Deploy application workloads |
| Processed by | KRO → ACK → AWS APIs | ArgoCD → Helm → K8s API |

## ApplicationSet Discovery Patterns

```mermaid
graph LR
    subgraph REPO["Platform Repo"]
        C1[catalog/eks-cluster.yaml]
        C2[catalog/helm-install.yaml]
        C3[catalog/spoke-account-iam.yaml]
        D1[runtime/dev/credit-card/data-plane/claim.yaml]
        A1[runtime/dev/credit-card/apps/config.json]
        A2[runtime/dev/credit-card/apps/values.yaml]
    end

    subgraph APPSETS["ApplicationSets"]
        AS_CAT["catalog App"]
        AS_DP["dataplane-development<br/>path: runtime/development/*/data-plane"]
        AS_APP["apps-development<br/>path: runtime/development/*/apps/config.json"]
    end

    C1 & C2 & C3 -->|synced by| AS_CAT
    D1 -->|discovered by| AS_DP
    A1 -->|read by| AS_APP
    A2 -.->|referenced as Helm values| AS_APP

    style REPO fill:#fff8e1,stroke:#ff8f00
    style APPSETS fill:#e8f5e9,stroke:#4caf50
```

## Platform Claim Processing

How infrastructure gets provisioned when a platform engineer pushes a new claim:

```mermaid
sequenceDiagram
    participant PE as 👷 Platform Engineer
    participant Ops as 📁 Platform Repo
    participant Argo as 🔄 ArgoCD
    participant KRO as 🧩 KRO
    participant ACK as ⚙️ ACK
    participant IAM as 🔑 IAM
    participant Spoke as 📦 Spoke Account

    PE->>Ops: git push (claim.yaml)
    Ops-->>Argo: dataplane AppSet discovers new directory
    Argo->>Argo: Generate Application from claim
    Argo->>KRO: Apply SpokeAccountIAM
    KRO->>KRO: Create IAMRoleSelector
    Argo->>KRO: Apply EKSCluster
    KRO->>ACK: Create IAM Roles + EKS Cluster
    ACK->>IAM: AssumeRole (control-plane-execution)
    IAM->>Spoke: Create EKS cluster (Auto Mode)
    Note over Spoke: EKS cluster ready 🎉
    Argo->>KRO: Apply HelmInstall
    KRO->>Argo: Create ArgoCD Application
    Argo->>Spoke: Deploy Helm charts
    Note over Spoke: Monitoring + LB controller running ✅
```
