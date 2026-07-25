variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
  default     = "techchallenge-cluster"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for VPC Link"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs for VPC Link"
}

variable "integration_uri" {
  type        = string
  description = "HTTP Integration Target URI"
  default     = "http://api-garage.garage.svc.cluster.local:8080"
}
