variable "namespace_name" {
  type        = string
  description = "Kubernetes namespace for Keycloak deployment"
  default     = "garage"
}

variable "db_host" {
  type        = string
  description = "AWS RDS PostgreSQL Host endpoint"
  default     = "localhost"
}

variable "db_port" {
  type        = string
  description = "AWS RDS PostgreSQL Port"
  default     = "5432"
}

variable "db_name" {
  type        = string
  description = "Database name for Keycloak data"
  default     = "postgres"
}

variable "db_username" {
  type        = string
  description = "Database master username"
  default     = "postgres"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Database master password"
  default     = "Postgres2026!"
}

variable "admin_username" {
  type        = string
  description = "Keycloak bootstrap admin username"
  default     = "admin"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  description = "Keycloak bootstrap admin password"
  default     = "Admin@2026!"
}
