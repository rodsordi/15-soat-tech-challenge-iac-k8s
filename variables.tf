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
  description = "Instance type for EKS worker nodes"
  default     = "t3.small"
}

variable "db_host" {
  type        = string
  description = "AWS RDS Endpoint address"
  default     = "garage-postgres-db.c1234567890.us-east-1.rds.amazonaws.com"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "AWS RDS Master Password"
  default     = "Postgres2026!"
}

variable "use_existing_lab_role" {
  type        = bool
  description = "Use existing AWS Academy LabRole instead of creating new IAM roles"
  default     = true
}