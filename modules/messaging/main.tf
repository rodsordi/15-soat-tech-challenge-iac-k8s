# --- SNS TOPIC ---
resource "aws_sns_topic" "notification_creation_topic" {
  name = var.topic_name

  tags = {
    Name        = var.topic_name
    Environment = "prd"
    Service     = "api-garage"
  }
}

# --- SQS DEAD LETTER QUEUE (DLQ) ---
resource "aws_sqs_queue" "notification_creation_dlq" {
  name                      = "${var.queue_name}_dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "${var.queue_name}_dlq"
    Environment = "prd"
    Service     = "api-garage"
  }
}

# --- SQS MAIN QUEUE WITH REDRIVE POLICY ---
resource "aws_sqs_queue" "notification_creation_queue" {
  name                       = var.queue_name
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600 # 4 days

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notification_creation_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = var.queue_name
    Environment = "prd"
    Service     = "api-garage"
  }
}

# --- SNS TO SQS SUBSCRIPTION (FANOUT) ---
resource "aws_sns_topic_subscription" "notification_sqs_sub" {
  topic_arn            = aws_sns_topic.notification_creation_topic.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.notification_creation_queue.arn
  raw_message_delivery = true
}

# --- SQS QUEUE POLICY (ALLOW SNS TO SEND MESSAGES) ---
resource "aws_sqs_queue_policy" "notification_queue_policy" {
  queue_url = aws_sqs_queue.notification_creation_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSNotificationPublish"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.notification_creation_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.notification_creation_topic.arn
          }
        }
      }
    ]
  })
}
