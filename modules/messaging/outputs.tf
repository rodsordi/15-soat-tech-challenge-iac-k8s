output "topic_arn" {
  value       = aws_sns_topic.notification_creation_topic.arn
  description = "ARN of the SNS topic for notification events"
}

output "topic_name" {
  value       = aws_sns_topic.notification_creation_topic.name
  description = "Name of the SNS topic for notification events"
}

output "queue_arn" {
  value       = aws_sqs_queue.notification_creation_queue.arn
  description = "ARN of the SQS main queue"
}

output "queue_name" {
  value       = aws_sqs_queue.notification_creation_queue.name
  description = "Name of the SQS main queue"
}

output "queue_url" {
  value       = aws_sqs_queue.notification_creation_queue.id
  description = "URL of the SQS main queue"
}

output "dlq_arn" {
  value       = aws_sqs_queue.notification_creation_dlq.arn
  description = "ARN of the SQS dead letter queue"
}

output "dlq_name" {
  value       = aws_sqs_queue.notification_creation_dlq.name
  description = "Name of the SQS dead letter queue"
}
