# --- EKS Outputs ---

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version"
  value       = module.eks.cluster_version
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

# --- VPC Outputs ---

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

# --- RDS Outputs ---

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.awx.endpoint
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.awx.db_name
}

# --- Secrets Outputs ---

output "db_secret_arn" {
  description = "ARN of the DB credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "awx_admin_secret_arn" {
  description = "ARN of the AWX admin credentials secret"
  value       = aws_secretsmanager_secret.awx_admin.arn
}

# --- Access Info ---

output "argocd_initial_password" {
  description = "Command to get ArgoCD initial admin password"
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "awx_admin_password" {
  description = "Command to get AWX admin password from Secrets Manager"
  value       = "aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.awx_admin.name} --query SecretString --output text | jq -r .password"
}
