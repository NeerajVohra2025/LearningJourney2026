# Core Configuration Variables
variable "name" {
  description = "Name of the application, used to create consistent resource naming across the module"
  type        = string
}

variable "env" {
  description = "Deployment environment (dev, test, stage, prod) - affects resource naming and potentially behavior"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources for organization, cost tracking and access control"
  type        = map(string)
  default     = {}
}

variable "lambda_function_name" {
  description = "The name of the Lambda function as it appears in AWS console and APIs"
  type        = string
}

# Runtime Configuration
# Settings that affect Lambda execution behavior

variable "runtime" {
  description = "The runtime environment for the Lambda function (e.g., python3.9, nodejs16.x, java11)"
  type        = string
}

variable "environment_variables" {
  description = "A map of environment variables passed to the Lambda function at runtime"
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "Maximum execution duration for the Lambda function in seconds (max: 900s/15min)"
  type        = number
}

variable "memory_size" {
  description = "Memory allocation for the Lambda function in MB (128-10240), affects CPU allocation and pricing"
  type        = number
}

variable "lambda_handler" {
  description = "The function entrypoint in your code (e.g., filename.function_name)"
  type        = string
  default     = "lambda_function.lambda_handler"
}

# Lambda Code Deployment
variable "lambda_code_path" {
  description = "Path to the directory containing Lambda function source code"
  type        = string
}

variable "lambda_source_filename" {
  description = "The name of the Lambda function's main source code file"
  type        = string
}

variable "lambda_output_path" {
  description = "The destination path where the packaged Lambda deployment ZIP will be created"
  type        = string
}

variable "archive_file" {
  description = "The archive file type to use when packaging the Lambda function (typically 'zip')"
  type        = string
  default     = "zip"
}

# Monitoring and Logging

variable "retention_in_days" {
  description = "The number of days to retain Lambda function logs in CloudWatch Logs"
  type        = number
  default     = 14 # Two weeks retention balances observability with cost
}

# Network Configuration

variable "subnet_ids" {
  description = "List of subnet IDs for VPC-connected Lambda - leave empty for direct internet access"
  type        = list(string)
  default     = [] # Empty list means Lambda runs outside VPC with internet access
}

variable "vpc_id" {
  description = "The VPC ID for Lambda VPC integration - leave empty for direct internet access"
  type        = string
  default     = "" # Empty string means no VPC integration
}

variable "lambda_layers" {
  description = "List of Lambda layer ARNs to attach to the function (Lambda Insights will be added automatically)"
  type        = list(string)
  default     = []
}

variable "enable_lambda_insights" {
  description = "Whether to enable Lambda Insights for enhanced monitoring metrics"
  type        = bool
  default     = true
}

variable "enable_xray" {
  description = "Whether to enable X-Ray tracing for the Lambda function"
  type        = bool
  default     = true
}

variable "lambda_insights_account_id" {
  description = "AWS account ID for Lambda Insights layer - required if enable_lambda_insights is true"
  type        = string
  default     = "580247275435" # AWS-owned account for standard regions
}

variable "lambda_insights_layer_version" {
  description = "The version of the Lambda Insights layer to use - required if enable_lambda_insights is true"
  type        = string
  default     = "38" # Current latest version
}