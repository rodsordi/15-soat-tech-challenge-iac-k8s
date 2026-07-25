output "repository_url" {
  value       = aws_ecr_repository.garage_api.repository_url
  description = "AWS ECR Repository URL for garage-api"
}

output "repository_arn" {
  value       = aws_ecr_repository.garage_api.arn
  description = "AWS ECR Repository ARN"
}
