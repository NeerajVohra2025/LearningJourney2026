/**
 * # ECS Fargate Module Outputs
 *
 */

output "target_group_arn" {
  description = "ARN of the Application Load Balancer target group that routes traffic to this service."
  value       = aws_alb_target_group.ecs_alb_target_group.arn
}

output "service_iam_role_arn" {
  description = "ARN of the IAM role that ECS uses to manage task deployment. "
  value       = aws_iam_role.ecs_execution_role.arn
}

output "service_id" {
  description = "Unique identifier for the ECS service. "
  value       = aws_ecs_service.service.id
}

output "security_group_id" {
  description = "ID of the security group controlling network traffic to and from containers. "
  value       = aws_security_group.ecs_task_sg.id
}

output "task_role_id" {
  description = "ID of the IAM role that application containers assume at runtime."
  value       = aws_iam_role.ecs_task_role.id
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group where application logs are stored."
  value       = aws_cloudwatch_log_group.ecs_task_log_group.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group. "
  value       = aws_cloudwatch_log_group.ecs_task_log_group.arn
}

output "service_name" {
  description = "Name of the ECS service. "
  value       = aws_ecs_service.service.name
}


output "task_definition_family" {
  description = "Family name of the task definition. "
  value       = aws_ecs_task_definition.task.family
}

output "task_definition_revision" {
  description = "Current revision number of the task definition."
  value       = element(split(":", aws_ecs_task_definition.task.arn), length(split(":", aws_ecs_task_definition.task.arn)) - 1)
}

output "container_name" {
  description = "Name of the main application container."
  value       = var.service_name
}

output "otel_enabled" {
  description = "Indicates whether OpenTelemetry observability is enabled for this service."
  value       = var.otel_enabled
}