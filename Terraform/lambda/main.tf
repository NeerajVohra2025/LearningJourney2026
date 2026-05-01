# IAM Role Configuration
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.name}-lambda-exec-role-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        {
          Action = "sts:AssumeRole",
          Effect = "Allow",
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        }
      ]
    )
  })
}

# Get current region for Lambda Insights layer ARN
data "aws_region" "current" {}

# Lambda Insights configuration for standard regions
locals {
  lambda_insights_account_id = var.lambda_insights_account_id    # AWS-owned account for standard regions
  lambda_insights_version    = var.lambda_insights_layer_version # Current latest version

  # Enable Lambda Insights layer if the variable is set
  insights_layer = var.enable_lambda_insights ? (
    ["arn:aws:lambda:${data.aws_region.current.name}:${local.lambda_insights_account_id}:layer:LambdaInsightsExtension:${local.lambda_insights_version}"]
  ) : []
}

# Attach required AWS managed policies to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_exec_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Attach the AWSXrayWriteOnlyAccess policy to the IAM role only when X-Ray is enabled  
resource "aws_iam_role_policy_attachment" "xray_policy_attach" {
  count      = var.enable_xray ? 1 : 0
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

# VPC access policy attachment - dynamically attached only when VPC configuration is provided
resource "aws_iam_role_policy_attachment" "vpc_access_policy_attach" {
  count      = length(var.subnet_ids) > 0 && var.vpc_id != "" ? 1 : 0
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Add Lambda Insights permissions - dynamically attached only when Lambda Insights is enabled
resource "aws_iam_role_policy_attachment" "lambda_insights_policy_attachment" {
  count      = var.enable_lambda_insights ? 1 : 0
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}

/*
 Lambda Function
*/
resource "aws_lambda_function" "lambda_function" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = var.lambda_handler
  runtime          = var.runtime
  filename         = data.archive_file.archive.output_path
  source_code_hash = data.archive_file.archive.output_base64sha256
  environment {
    variables = var.environment_variables
  }

  layers = concat(
    var.lambda_layers,
    local.insights_layer
  )

  # Dynamic VPC configuration - only created when both subnet_ids and vpc_id are provided
  # This allows the Lambda to be deployed either with or without VPC access
  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 && var.vpc_id != "" ? [1] : []

    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = length(aws_security_group.lambda_sg) > 0 ? aws_security_group.lambda_sg.*.id : []
    }
  }

  # Function execution configuration
  timeout     = var.timeout     # Maximum execution time in seconds
  memory_size = var.memory_size # Memory allocation in MB

  # X-Ray tracing configuration - conditional based on enable_xray variable
  tracing_config {
    mode = var.enable_xray ? (var.env == "prod" ? "PassThrough" : "Active") : "PassThrough"
  }
  depends_on = [aws_iam_role.lambda_exec_role]

  # Resource tagging for better organization and cost tracking
  tags = merge(
    { "Name" = "${var.name}-aws-lambda-function-${var.env}" },
    var.tags
  )
}

# Lambda Deployment Package
# Creates ZIP archive from source code for Lambda deployment
data "archive_file" "archive" {
  type        = var.archive_file
  source_file = "${var.lambda_code_path}/${var.lambda_source_filename}"
  output_path = "${var.lambda_code_path}/${var.lambda_output_path}"
}

# CloudWatch Logging
# Sets up log group with retention policy for Lambda logs
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${var.name}-lambda-log-group-${var.env}"
  retention_in_days = var.retention_in_days
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      name # Ignore changes to the name of the log group
    ]
  }
  tags = merge(
    { "Name" = "${var.name}-lambda-log-group-${var.env}" },
    var.tags
  )
}

# Network access control for Lambda when running in VPC
resource "aws_security_group" "lambda_sg" {
  count       = length(var.subnet_ids) > 0 && var.vpc_id != "" ? 1 : 0
  name        = "${var.name}-lambda-sg-${var.env}"
  description = "Security group for Lambda function"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }
  # HTTP ingress
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS ingress - for secure API communication
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP egress - for outbound API calls
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS egress - for secure API calls (Teams webhook, etc.)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(
    { "Name" = "${var.name}-lambda-sg-${var.env}" },
    var.tags
  )
}

# Add CloudWatch alarm notification permissions
resource "aws_iam_policy" "lambda_cloudwatch_alarm_policy" {
  name        = "${var.name}-lambda-cloudwatch-alarm-policy-${var.env}"
  description = "Allows Lambda to manage CloudWatch alarms and publish notifications"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:DeleteAlarms"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "sns:Publish"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:sns:*:*:*"
      }
    ]
  })
}

# Attach the CloudWatch alarm policy to the Lambda execution role
resource "aws_iam_role_policy_attachment" "lambda_cloudwatch_alarm_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_cloudwatch_alarm_policy.arn
}