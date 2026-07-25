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

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "use_existing_lab_role" {
  type        = bool
  description = "Use existing AWS Academy LabRole instead of creating new IAM roles"
  default     = true
}
