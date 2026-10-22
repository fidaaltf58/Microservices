output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "ecr_registry" {
  description = "ECR registry host (use as the image prefix)."
  value       = split("/", aws_ecr_repository.service["api-gateway"].repository_url)[0]
}

output "ecr_repositories" {
  value = { for k, r in aws_ecr_repository.service : k => r.repository_url }
}

output "db_endpoints" {
  value = { for k, d in aws_db_instance.db : k => d.address }
}

output "db_secret_names" {
  description = "Secrets Manager entries read by External Secrets Operator."
  value       = { for k, s in aws_secretsmanager_secret.db : k => s.name }
}

output "github_actions_role_arn" {
  description = "Set as the AWS_ROLE_ARN variable in the GitHub repository."
  value       = aws_iam_role.github_actions.arn
}

output "external_secrets_role_arn" {
  description = "Annotate the external-secrets service account with this role (scripts/bootstrap-cluster.sh does it)."
  value       = aws_iam_role.external_secrets.arn
}
