# Spoke Account: control-plane-execution Role

This directory contains the IAM trust policy and least-privilege permission policy for the `control-plane-execution` role that must exist in every spoke account.

## How it works

```
Hub Account                                   Spoke Account
┌─────────────────────────┐                   ┌──────────────────────────────┐
│ ACK pods                │                   │                              │
│   ↓ Pod Identity        │                   │  control-plane-execution     │
│ control-plane-admin     │── sts:AssumeRole ─│    ├─ Trust: hub role        │
│                         │                   │    └─ Policy: EKS (Auto Mode)│
│                         │                   │       + IAM + EC2 + Logs     │
└─────────────────────────┘                   └──────────────────────────────┘
```

## Permission Scope (Auto Mode)

Since spoke clusters use EKS Auto Mode, the permissions are simpler than managed node groups:

1. **EKS** — Create/manage cluster with Auto Mode, addons, access entries
2. **IAM** — Create cluster role with Auto Mode policies (no node role needed)
3. **EC2** — Read networking info, create security groups
4. **CloudWatch Logs** — Create log groups under `/aws/eks/*`

## Deploying

Create this role via CloudFormation StackSets or Organizations baseline:

```bash
aws iam create-role \
  --role-name control-plane-execution \
  --assume-role-policy-document file://control-plane-execution-trust.json

aws iam put-role-policy \
  --role-name control-plane-execution \
  --policy-name control-plane-execution-policy \
  --policy-document file://control-plane-execution-policy.json
```
