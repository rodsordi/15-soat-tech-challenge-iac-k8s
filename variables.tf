variable "aws_region" {
  type        = string
  description = "AWS region for infrastructure deployment"
  default     = "us-east-1"
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile name configured in ~/.aws/credentials"
  default     = "default"
}

variable "cluster_name" {
  type        = string
  description = "Name of the AWS EKS cluster"
  default     = "techchallenge-cluster"
}

variable "node_instance_type" {
  type        = string
  description = "Instance type for EKS worker nodes (t3.medium recommended for observability DaemonSets)"
  default     = "t3.medium"
}

variable "db_host" {
  type        = string
  description = "AWS RDS Endpoint address"
  default     = "garage-postgres-db.cvmr3avpubxq.us-east-1.rds.amazonaws.com"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "AWS RDS Master Password (injected via GitHub Actions secret or tfvars)"
}


variable "use_existing_lab_role" {
  type        = bool
  description = "Use existing AWS Academy LabRole instead of creating new IAM roles"
  default     = true
}

# --- NEW RELIC OBSERVABILITY VARIABLES ---

variable "newrelic_account_id" {
  type        = string
  description = "New Relic Account ID"
  default     = "0"
}

variable "newrelic_api_key" {
  type        = string
  sensitive   = true
  description = "New Relic User API Key (NRAK-...)"
  default     = ""
}

variable "newrelic_license_key" {
  type        = string
  sensitive   = true
  description = "New Relic Ingest License Key (NRKEY-...)"
  default     = ""
}

variable "newrelic_region" {
  type        = string
  description = "New Relic Region (US or EU)"
  default     = "US"
}
