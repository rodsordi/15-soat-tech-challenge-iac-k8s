output "service_name" {
  value       = kubernetes_service.garage_api.metadata[0].name
  description = "Java application service name"
}

output "deployment_name" {
  value       = kubernetes_deployment.garage_api.metadata[0].name
  description = "Java application deployment name"
}

output "service_host" {
  value       = try(kubernetes_service.garage_api.status[0].load_balancer[0].ingress[0].hostname, "localhost")
  description = "Internal Load Balancer Hostname"
}

