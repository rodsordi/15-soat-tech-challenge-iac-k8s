output "namespace" {
  description = "Namespace where New Relic components are deployed"
  value       = kubernetes_namespace.newrelic.metadata[0].name
}

output "alert_policy_id" {
  description = "ID of the created New Relic Alert Policy"
  value       = newrelic_alert_policy.garage_business_policy.id
}
