output "service_name" {
  value       = kubernetes_service.keycloak.metadata[0].name
  description = "Keycloak internal Kubernetes service name"
}

output "service_port" {
  value       = 8080
  description = "Keycloak service port"
}

output "keycloak_internal_url" {
  value       = "http://${kubernetes_service.keycloak.metadata[0].name}.${var.namespace_name}.svc.cluster.local:8080"
  description = "Internal Keycloak URL for intra-cluster communication and VPC workloads"
}
