# Zero-Trust Immutable Infrastructure Pipeline

## Architecture

```
Terraform → AWS Infra → EKS → ArgoCD → AWX → Ansible → EC2 Fleet via SSM
```

```
┌──────────────────────────────────────────────────────────────────┐
│                        VPC (10.0.0.0/16)                        │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Public-1    │  │  Public-2    │  │  Public-3    │             │
│  │  NAT GW      │  │              │  │              │             │
│  │  ALB          │  │  ALB         │  │  ALB         │             │
│  └──────┬───────┘  └──────────────┘  └──────────────┘             │
│         │                                                         │
│  ┌──────┴───────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  Private-1    │  │  Private-2   │  │  Private-3   │             │
│  │  EKS Nodes   │  │  EKS Nodes   │  │  EKS Nodes   │             │
│  │  RDS          │  │              │  │              │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                  │
│         ┌──────────────────────────────────┐                     │
│         │       EKS Cluster (K8s 1.33)     │                     │
│         │  ┌──────────┐ ┌──────────┐       │                     │
│         │  │  ArgoCD  │ │   AWX    │       │                     │
│         │  └──────────┘ └──────────┘       │                     │
│         │  ┌──────────┐ ┌──────────┐       │                     │
│         │  │   ESO    │ │ ALB Ctrl │       │                     │
│         │  └──────────┘ └──────────┘       │                     │
│         └──────────────────────────────────┘                     │
└──────────────────────────────────────────────────────────────────┘
```

## Project Phases

| Phase | Scope | Status |
|---|---|---|
| **Phase 1** | EKS + ArgoCD + AWX + RDS + Secrets | ✅ Complete |
| Phase 2 | Packer EC2 fleet + SSM + AWX inventory | Planned |
| Phase 3 | Prometheus + Grafana + CloudWatch | Future |

## Security Features

- **IMDSv2** enforced on all EKS nodes
- **Encrypted gp3** EBS volumes
- **Private subnets** for EKS nodes and RDS
- **IRSA** (IAM Roles for Service Accounts) — no static credentials
- **AWS Secrets Manager** with ESO — secrets never in Git
- **No SSH** — SSM Session Manager only (Phase 2)

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.9.0
- [AWS CLI](https://aws.amazon.com/cli/) configured
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed
- [Packer](https://developer.hashicorp.com/packer/install) (Phase 2)

## Project Structure

```
.
├── .gitignore
├── README.md
├── terraform/
│   ├── main.tf                     # Providers, backend, data sources
│   ├── variables.tf                # All configurable variables
│   ├── terraform.tfvars.example    # Example values
│   ├── vpc.tf                      # VPC module (3 AZs)
│   ├── eks.tf                      # EKS cluster + node group
│   ├── rds.tf                      # PostgreSQL for AWX
│   ├── secrets.tf                  # Secrets Manager
│   ├── iam.tf                      # IRSA roles (ALB, ESO, EBS CSI)
│   ├── helm.tf                     # Helm releases (ArgoCD, ALB, ESO, AWX)
│   └── outputs.tf                  # Cluster, RDS, access outputs
├── kubernetes/
│   ├── awx/
│   │   └── awx-instance.yaml       # AWX Custom Resource
│   ├── external-secrets/
│   │   ├── cluster-store.yaml      # ClusterSecretStore for AWS
│   │   └── awx-secrets.yaml        # ExternalSecrets for DB + admin
│   └── argocd-apps/
│       └── awx.yaml                # ArgoCD Application for AWX
└── packer/                         # Phase 2 — EC2 Golden AMI
    ├── aws-ubuntu.pkr.hcl
    └── setup-scripts/
        └── install.sh
```

## Quick Start

### 1. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 2. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

This creates: VPC, EKS, RDS, Secrets Manager, ALB Controller, ArgoCD, ESO, AWX Operator.

### 3. Connect to EKS

```bash
# Use the output command
aws eks update-kubeconfig --name zerotrust-eks --region us-east-1
kubectl get nodes
```

### 4. Apply Kubernetes Manifests

```bash
# ClusterSecretStore
kubectl apply -f kubernetes/external-secrets/cluster-store.yaml

# AWX secrets (pulls from Secrets Manager)
kubectl apply -f kubernetes/external-secrets/awx-secrets.yaml

# AWX instance
kubectl apply -f kubernetes/awx/awx-instance.yaml

# (Optional) ArgoCD Application for GitOps
kubectl apply -f kubernetes/argocd-apps/awx.yaml
```

### 5. Access UIs

```bash
# ArgoCD password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# AWX password
aws secretsmanager get-secret-value --secret-id zerotrust/awx/admin-credentials --query SecretString --output text | jq -r .password

# Get ALB URLs
kubectl get ingress -A
```

## Technology Stack

| Component | Version |
|---|---|
| Terraform | >= 1.9.0 |
| AWS Provider | ~> 6.0 (6.35.1) |
| VPC Module | 6.6.0 |
| EKS Module | 21.15.1 |
| Kubernetes | 1.33 |
| ArgoCD | 7.8.0 (Helm) |
| AWX Operator | 2.19.1 (Helm) |
| ESO | 0.12.1 (Helm) |
| ALB Controller | 1.11.0 (Helm) |
| RDS PostgreSQL | 16 |
| Packer (Phase 2) | >= 1.9.0 |

## Secrets Flow

```
AWS Secrets Manager → External Secrets Operator → K8s Secrets → AWX/ArgoCD
```

## Deployment Flow

```
Terraform Apply
    ├── VPC + Subnets (3 AZs)
    ├── EKS Cluster + Node Group
    ├── RDS PostgreSQL
    ├── AWS Secrets Manager
    ├── ALB Controller (Helm)
    ├── ArgoCD (Helm)
    ├── External Secrets Operator (Helm)
    └── AWX Operator (Helm)
         ↓
kubectl apply K8s manifests
    ├── ClusterSecretStore
    ├── ExternalSecrets → K8s Secrets
    └── AWX CR → awx-web + awx-task + redis
```
