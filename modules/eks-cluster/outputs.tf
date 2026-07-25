output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "EKS Cluster Name"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "EKS Cluster Endpoint"
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "EKS Cluster Certificate Authority Data"
}

output "cluster_id" {
  value       = aws_eks_cluster.main.id
  description = "EKS Cluster ID"
}

output "vpc_id" {
  value       = aws_vpc.eks_vpc.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  description = "Public Subnet IDs"
}

output "private_subnet_ids" {
  value       = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  description = "Private Subnet IDs"
}

output "vpc_link_security_group_id" {
  value       = aws_security_group.vpc_link_sg.id
  description = "VPC Link Security Group ID"
}

output "cluster_oidc_issuer_url" {
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
  description = "EKS Cluster OIDC Issuer URL for IRSA ServiceAccounts"
}

output "irsa_role_arn" {
  value       = var.use_existing_lab_role ? data.aws_iam_role.lab_role.arn : (length(aws_iam_role.app_irsa_role) > 0 ? aws_iam_role.app_irsa_role[0].arn : data.aws_iam_role.lab_role.arn)
  description = "IAM Role ARN to be used by Service Accounts (IRSA)"
}
