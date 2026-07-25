output "service_name" {
  value       = kubernetes_service.garage_api.metadata[0].name
  description = "Java application service name"
}

output "deployment_name" {
  value       = kubernetes_deployment.garage_api.metadata[0].name
  description = "Java application deployment name"
}
