variable "topic_name" {
  type        = string
  description = "Name of the SNS topic for notification events"
  default     = "api-garage_notification-creation_topic"
}

variable "queue_name" {
  type        = string
  description = "Name of the SQS queue for notification processing"
  default     = "api-garage_notification-creation_queue"
}
