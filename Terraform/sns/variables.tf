variable "name" {
  description = "Name of the SNS topic. "
  type        = string
}

variable "env" {
  description = "Deployment environment (e.g., 'dev', 'test', 'stage', 'prod'). "
  type        = string
}

variable "tags" {
  description = "Resource tagging strategy. Should include mandatory organizational tags such as cost center, application ID, environment, and data classification level."
  type        = map(string)
  default     = {}
}

#----------------------------------------------
# Subscription Configuration
#----------------------------------------------

variable "enable_email_subscriptions" {
  description = "Controls whether email subscriptions are provisioned. "
  type        = bool
  default     = false
}

variable "email_addresses" {
  description = "List of email addresses to subscribe to the SNS topic."
  type        = list(string)
  default     = []
}

variable "enable_lambda_subscriptions" {
  description = "Controls whether Lambda subscriptions are provisioned. "
  type        = bool
  default     = true
}

variable "lambda_subscriptions" {
  description = "List of Lambda ARNs to subscribe to the SNS topic. "
  type        = list(string)
  default     = []
}

variable "create_lambda_permissions" {
  description = "Whether to create Lambda permissions for SNS invocation."
  type        = bool
  default     = true
}

#----------------------------------------------
# Security and Compliance
#----------------------------------------------

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting the SNS topic. "
  type        = string
  default     = ""
}

#----------------------------------------------
# Operational Reliability
#----------------------------------------------

variable "dlq_arn" {
  description = "ARN of the Dead Letter Queue (DLQ) for capturing failed notification deliveries. "
  type        = string
  default     = ""
}

variable "retention_in_days" {
  description = "Retention period (in days) for CloudWatch Log Groups. "
  type        = number
  default     = 14
}