variable "cluster_name" {
  type        = string
  description = "Name of the Kubernetes cluster"
}

variable "namespace_name" {
  type        = string
  description = "Namespace for New Relic infrastructure components"
  default     = "newrelic"
}

variable "newrelic_account_id" {
  type        = string
  description = "New Relic Account ID"
}

variable "newrelic_license_key" {
  type        = string
  sensitive   = true
  description = "New Relic Ingest License Key"
}
