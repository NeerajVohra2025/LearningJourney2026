# Add this data source at the top of the file
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Creates a secure, trackable SNS topic that serves as the central notification
resource "aws_sns_topic" "monitoring_alerts" {
  name         = "${var.name}-sns-topic-${var.env}"
  display_name = "${var.name}-sns-topic-${var.env}"

  # X-Ray tracing enables end-to-end tracking of messages for troubleshooting
  tracing_config = "Active"

  # Uses custom KMS key if provided, All messages are encrypted at rest using KMS
  kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : aws_kms_key.sns_key.arn

  lifecycle {
    create_before_destroy = true

  }

  tags = merge(
    { "Name" = "${var.name}-sns-topic-${var.env}" },
    var.tags
  )
}

# Two subscription types are supported:
# 1. Email - for human recipients (operations teams, administrators)
# 2. Lambda - for automated processing and integration with other systems
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = var.enable_email_subscriptions ? toset(var.email_addresses) : []
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "email"
  endpoint  = each.value

  # Failed deliveries are sent to DLQ if configured
  redrive_policy = var.dlq_arn != "" ? jsonencode({
    deadLetterTargetArn = var.dlq_arn
  }) : null
}

# Lambda Subscriptions with conditional creation
resource "aws_sns_topic_subscription" "lambda_subscriptions" {
  for_each  = var.enable_lambda_subscriptions ? toset(var.lambda_subscriptions) : []
  topic_arn = aws_sns_topic.monitoring_alerts.arn
  protocol  = "lambda"
  endpoint  = each.value

  # Failed deliveries are sent to DLQ if configured
  redrive_policy = var.dlq_arn != "" ? jsonencode({
    deadLetterTargetArn = var.dlq_arn
  }) : null
}

# Lambda Permissions: Required for SNS to invoke Lambda functions
resource "aws_lambda_permission" "lambda_permissions" {
  for_each      = var.enable_lambda_subscriptions && var.create_lambda_permissions ? toset(var.lambda_subscriptions) : []
  statement_id  = "AllowSNSInvoke-${replace(basename(each.value), ":", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.monitoring_alerts.arn # Update this if needed
  depends_on    = [aws_sns_topic_subscription.lambda_subscriptions]
}

# SECURITY AND IAM CONFIGURATION
# Base SNS Role: Allows the SNS service to perform necessary actions
resource "aws_iam_role" "sns_role" {
  name = "${var.name}-sns-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "sns.amazonaws.com" # Allow SNS to assume the role
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Email Sending Permissions: Only created when email subscriptions are used
resource "aws_iam_policy" "sns_ses_policy" {
  count       = length(var.email_addresses) > 0 ? 1 : 0
  name        = "${var.name}-sns-ses-policy-${var.env}"
  description = "Policy to allow SNS to send emails via SES"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ses:SendEmail",
          "ses:SendRawEmail"
        ],
        Resource = "*"
      }
    ]
  })
}

# Define the IAM Policy to allow SNS to send messages to SQS (if a DLQ ARN is provided)
resource "aws_iam_policy" "sns_sqs_policy" {
  count       = var.dlq_arn != "" ? 1 : 0
  name        = "${var.name}-sns-sqs-policy-${var.env}"
  description = "Policy to allow SNS to send messages to SQS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:SendMessage"
        ],
        Resource = var.dlq_arn
      }
    ]
  })
}

# OBSERVABILITY AND MONITORING
# CloudWatch Log Group: Captures SNS operational logs
resource "aws_cloudwatch_log_group" "sns_log_group" {
  name              = "/aws/sns/${var.name}-sns-log-group-${var.env}"
  retention_in_days = var.retention_in_days

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      name # Ignore changes to the name of the log group
    ]
  }
  tags = merge(
    { "Name" = "${var.name}-sns-log-group-${var.env}" },
    var.tags
  )
}

# CloudWatch Logging Permissions: Allows SNS to write detailed logs
resource "aws_iam_policy" "sns_cloudwatch_policy" {
  name        = "${var.name}-sns-cloudwatch-policy-${var.env}"
  description = "Policy to allow SNS to write logs to CloudWatch"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# X-Ray Tracing Permissions: Enables distributed tracing for observability
resource "aws_iam_policy" "sns_xray_policy" {
  name        = "${var.name}-sns-xray-policy-${var.env}"
  description = "Policy to allow SNS to send traces to X-Ray"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        "Resource" : "*"
      }
    ]
  })
}


# Email Sending Capability: Attach SES permissions when email subscriptions exist
resource "aws_iam_role_policy_attachment" "sns_ses_role_attachment" {
  count      = length(var.email_addresses) > 0 ? 1 : 0
  role       = aws_iam_role.sns_role.name
  policy_arn = aws_iam_policy.sns_ses_policy[count.index].arn
}

# Dead Letter Queue Integration: Attach SQS permissions when DLQ is configured
resource "aws_iam_role_policy_attachment" "sns_sqs_role_attachment" {
  count      = var.dlq_arn != "" ? 1 : 0
  role       = aws_iam_role.sns_role.name
  policy_arn = aws_iam_policy.sns_sqs_policy[count.index].arn
}

# Logging Capability: Attach CloudWatch logging permissions (always enabled)
resource "aws_iam_role_policy_attachment" "sns_cloudwatch_role_attachment" {
  role       = aws_iam_role.sns_role.name
  policy_arn = aws_iam_policy.sns_cloudwatch_policy.arn
}

# Tracing Capability: Attach X-Ray permissions for distributed tracing
resource "aws_iam_role_policy_attachment" "sns_xray_policy_attachment" {
  role       = aws_iam_role.sns_role.name
  policy_arn = aws_iam_policy.sns_xray_policy.arn
}



# Default KMS Key: Used when a custom key isn't provided
resource "aws_kms_key" "sns_key" {
  description = "KMS key for SNS topic"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "kms:*",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowCloudWatchToUseKMSKey",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudwatch.amazonaws.com"
        },
        "Action" : [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : "${data.aws_caller_identity.current.account_id}"
          }
        }
      }
    ]
  })
}

# SNS Topic Policy:
resource "aws_sns_topic_policy" "topic_policy" {
  arn = aws_sns_topic.monitoring_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Id      = "${var.name}-sns-access-policy",
    Statement = [

      # Account-level publishing permissions with security constraints
      {
        Sid    = "AllowAccountPublishing",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes",
          "sns:ListSubscriptionsByTopic"
        ],
        Resource = aws_sns_topic.monitoring_alerts.arn
      },

      {
        Sid    = "AllowCloudWatchPublishing",
        Effect = "Allow",
        Principal = {
          Service = "cloudwatch.amazonaws.com"
        },
        Action   = "sns:Publish",
        Resource = aws_sns_topic.monitoring_alerts.arn,
        Condition = {
          StringLike = {
            "aws:SourceArn" : "arn:aws:cloudwatch:*:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },

    ]
  })
}