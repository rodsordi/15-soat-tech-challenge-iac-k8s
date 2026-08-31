output "eks_cluster_name" {
  description = "AWS EKS Cluster Name"
  value       = module.eks_cluster.cluster_name
}

output "eks_cluster_endpoint" {
  description = "AWS EKS Cluster Endpoint"
  value       = module.eks_cluster.cluster_endpoint
}

output "ecr_repository_url" {
  description = "AWS ECR Repository URL for Java Application"
  value       = module.ecr.repository_url
}

output "app_service_name" {
  description = "Java Application Service Name"
  value       = module.app_garage.service_name
}

output "api_gateway_url" {
  description = "AWS API Gateway Public Invoke URL (Single Entry Point)"
  value       = module.api_gateway.api_gateway_url
}

output "aws_region" {
  description = "AWS Region where cluster is deployed"
  value       = var.aws_region
}

output "keycloak_internal_url" {
  description = "Internal Keycloak URL for intra-cluster communication and VPC workloads"
  value       = module.keycloak.keycloak_internal_url
}

output "keycloak_service_name" {
  description = "Keycloak internal Kubernetes service name"
  value       = module.keycloak.service_name
}


