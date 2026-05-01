output "sns_topic_arn" {
  description = "The ARN of the SNS topic"
  value       = aws_sns_topic.monitoring_alerts.arn
}

output "sns_topic_name" {
  description = "The name of the SNS topic"
  value       = aws_sns_topic.monitoring_alerts.name
}

output "sns_email_subscription_arns" {
  description = "The ARNs of the email SNS subscriptions"
  value       = var.enable_email_subscriptions ? [for subscription in aws_sns_topic_subscription.email_subscriptions : subscription.arn] : []
}

output "sns_lambda_subscription_arns" {
  description = "The ARNs of the Lambda SNS subscriptions"
  value       = var.enable_lambda_subscriptions ? [for subscription in aws_sns_topic_subscription.lambda_subscriptions : subscription.arn] : []
}

output "sns_all_subscription_arns" {
  description = "The ARNs of all SNS subscriptions (email and Lambda)"
  value = concat(
    var.enable_email_subscriptions ? [for subscription in aws_sns_topic_subscription.email_subscriptions : subscription.arn] : [],
    var.enable_lambda_subscriptions ? [for subscription in aws_sns_topic_subscription.lambda_subscriptions : subscription.arn] : []
  )
}