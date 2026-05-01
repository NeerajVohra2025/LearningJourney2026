output "lambda_function_name" {
  description = "The name of the Lambda function - use when referencing the function in AWS APIs or other Terraform resources"
  value       = aws_lambda_function.lambda_function.function_name
}

output "lambda_function_arn" {
  description = "The Amazon Resource Name (ARN) of the Lambda function - required for permissions, triggers, and cross-service integrations"
  value       = aws_lambda_function.lambda_function.arn
}

output "lambda_security_group_id" {
  description = "The ID of the security group attached to the Lambda function (null if Lambda is deployed without VPC)"
  value       = length(var.subnet_ids) > 0 && var.vpc_id != "" && length(aws_security_group.lambda_sg) > 0 ? aws_security_group.lambda_sg[0].id : null
}
