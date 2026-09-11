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

variable "newrelic_license_key" {
  type        = string
  sensitive   = true
  description = "New Relic Ingest License Key for OpenTelemetry export"
  default     = ""
}

variable "sns_enabled" {
  type        = bool
  description = "Enable or disable AWS SNS messaging"
  default     = true
}

variable "sqs_enabled" {
  type        = bool
  description = "Enable or disable AWS SQS messaging"
  default     = true
}

variable "notification_topic" {
  type        = string
  description = "Name of SNS topic for notification events"
  default     = "api-garage_notification-creation_topic"
}

variable "notification_queue" {
  type        = string
  description = "Name of SQS queue for notification events"
  default     = "api-garage_notification-creation_queue"
}

variable "use_existing_lab_role" {
  type        = bool
  description = "Whether AWS Academy LabRole is being used"
  default     = true
}

