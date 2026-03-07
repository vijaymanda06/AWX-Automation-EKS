# Zero-Trust Immutable Infrastructure Pipeline

## Problem Statement (Why this project)

In many companies there are a lot of servers running in cloud environments like AWS. DevOps teams often need to install software, run commands, deploy containers, or update configurations on those servers. Traditionally people used SSH to log into servers and run commands manually or through scripts. But this approach is not very secure or scalable, especially when you have dozens or hundreds of machines.

Another problem is that CI/CD pipelines usually handle application builds, but there still needs to be a reliable way to run automation tasks on infrastructure. Teams need a centralized platform where automation can be executed safely, audited, and integrated with pipelines.

So the idea of this project was to build a central automation platform that can trigger Ansible playbooks from pipelines and securely execute tasks on private servers without opening SSH access.

## What AWX / Ansible Tower is

AWX is basically a web-based automation platform for Ansible. Instead of running Ansible from your laptop or CLI, AWX gives you a UI, API, inventory management, job scheduling, logging, and role-based access control.

In simple terms, it makes Ansible easier to run in a team environment.

The enterprise version of AWX is called Red Hat Ansible Automation Platform, which was earlier known as Ansible Tower.

**Difference in simple terms:**

**AWX**
- Open-source project
- Community supported
- Free to use
- Good for learning and internal automation

**Red Hat Ansible Automation Platform (Ansible Tower)**
- Enterprise product from Red Hat
- Paid subscription
- Includes official support, security patches, automation analytics, and enterprise features

So in this project I used AWX (open-source), but the architecture is almost the same as the enterprise automation platform used in companies.

## What I actually built (project explanation)

So what I did in this project was I built a small automation platform on AWS. I created the infrastructure using Terraform and deployed everything inside an Amazon EKS cluster. Inside that Kubernetes cluster I installed AWX using Helm.

The idea was to run AWX as a centralized automation service. Instead of running Ansible from my laptop, AWX runs playbooks from inside the cluster.

I also created a small EC2 fleet which acts like application servers. These servers were kept completely private — no SSH access and no inbound ports open. To manage them securely I used AWS Systems Manager. This allows commands to run on EC2 instances without opening SSH.

Then I connected the automation workflow with GitLab CI pipelines. Whenever a pipeline runs, it calls the AWX API, which triggers an Ansible playbook. That playbook then uses SSM to execute commands on the private EC2 instances.

For testing I used simple examples like deploying Docker containers (nginx or redis) on those servers. The interesting part is that the servers were completely private and automation still worked through AWS SSM.

I also added some security improvements like restricting outbound network access and using VPC endpoints so the servers only communicate with AWS services instead of the public internet.

So the overall flow looks like this:

`GitLab CI pipeline → AWX API → Ansible playbook → AWS SSM → Private EC2 fleet`

This basically demonstrates how infrastructure automation can be done in a secure way without logging into servers manually.

## Is EKS really necessary for AWX?

Not really. EKS is not mandatory to run AWX. I chose EKS mainly because I wanted to run the automation platform in a containerized and scalable way, but there are multiple ways to deploy AWX depending on the team size and complexity.

In my project I deployed AWX on Amazon EKS using the Helm chart. The reason was mainly to simulate how a platform team might run shared tools inside Kubernetes. Running it on EKS also makes it easier to scale the workers and manage upgrades because everything is container based.

But honestly for smaller teams EKS can be a bit overkill.

### Other ways AWX can be deployed

One option is to run AWX on Amazon ECS. That works fine because AWX itself runs in containers anyway. ECS is easier to operate compared to Kubernetes since AWS manages a lot of the complexity. For a small team that just needs a central automation server, ECS could be a simpler option.

Another option is running AWX on a single VM or a few VMs. Some teams install AWX using Docker Compose or run it on a standalone Kubernetes distribution like k3s or microk8s. This is cheaper and simpler from a cost perspective, but it becomes harder to maintain over time. You have to handle upgrades, backups, and scaling manually.

So basically there are three common approaches:

**VM based deployment**
- AWX running on a single server
- Cheapest option
- But harder to scale and maintain

**Container platform like ECS**
- Easier to manage than Kubernetes
- Good middle ground for small teams

**Kubernetes platform like EKS**
- More complex
- But better for scaling and running multiple platform services

### Why Kubernetes is often used

Even though Kubernetes adds complexity, many companies already run their internal tooling on Kubernetes. So AWX becomes just another service running in the cluster.

In my setup AWX was deployed with Helm and used a PostgreSQL database which in AWS was backed by Amazon RDS. AWX also needs things like Redis and persistent storage, so running it in Kubernetes makes it easier to manage those components as containers.

Once everything is inside the cluster, it becomes easier to integrate with other tools like monitoring stacks or GitOps tools.

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
