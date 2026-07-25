variable "namespace_name" {
  type        = string
  description = "Kubernetes namespace"
  default     = "garage"
}

variable "image_url" {
  type        = string
  description = "Container image URL"
  default     = "garage-api:latest"
}

variable "db_host" {
  type        = string
  description = "Database Host URL/Endpoint"
  default     = "localhost"
}

variable "db_port" {
  type        = string
  description = "Database Port"
  default     = "5432"
}

variable "db_name" {
  type        = string
  description = "Database Name"
  default     = "postgres"
}

variable "db_username" {
  type        = string
  description = "Database User"
  default     = "postgres"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database Password"
  default     = "Postgres2026!"
}

variable "irsa_role_arn" {
  type        = string
  description = "IAM Role ARN for ServiceAccount (IRSA)"
  default     = ""
}

variable "ingress_class_name" {
  type        = string
  description = "Ingress class name for Kubernetes Ingress"
  default     = "alb"
}
