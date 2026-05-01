provider "aws" {
  region = "us-east-1"
}

# Current AWS region data source
data "aws_region" "current" {}

# Sample local values for testing different service combinations
locals {
  aws_region  = data.aws_region.current.name
  environment = "Dev"
  # dashboard_prefix = "PO"
  dashboard_name              = "PO-Consolidated-${local.environment}"
  ecs_monitoring_enabled      = true
  rds_monitoring_enabled      = true
  rabbitmq_monitoring_enabled = true
  cluster_name                = "ecs-monitoring-testing"
}

# Example dashboard module implementation
module "monitoring_dashboard" {
  source     = "../../modules/monitoring"
  aws_region = local.aws_region

  # General settings
  environment = local.environment
  # dashboard_prefix = local.dashboard_prefix
  dashboard_name = local.dashboard_name
  alarm_prefix   = "alarm-${local.environment}"
  # Dynamic service configuration
  # java_core_monitoring_enabled        = local.java_core_monitoring_enabled
  # java_integration_monitoring_enabled = local.java_integration_monitoring_enabled
  java_core_service_name        = "app-smartvu-core-${local.environment}"
  java_integration_service_name = "app-smartvu-integration-${local.environment}"
  java_dashboard_title          = "SMARTVU Core & Integration - ${upper(local.environment)}"


  # Add the SNS topic ARN
  sns_notification_topic_arn = "arn:aws:sns:us-east-1:652515736805:monitoring_alerts-sns-topic-dev"

  # ECS configuration
  ecs_monitoring_enabled           = local.ecs_monitoring_enabled
  ecs_cluster_name                 = local.ecs_monitoring_enabled ? "ecs-monitoring-testing" : ""
  ecs_cpu_threshold                = 1 #80
  ecs_memory_threshold             = 1 #80
  service_level_monitoring_enabled = true

  # Specify which services to monitor (your 3 SmartVu services)
  ecs_service_names = [
    "ecs-monitoring-service-ecs-user",

  ]
  # I/O thresholds
  ecs_network_rx_threshold    = 12 # 15000000 # 15 MB/s
  ecs_network_tx_threshold    = 12 # 12000000 # 12 MB/s
  ecs_storage_read_threshold  = 8  # 8000000  # 8 MB/s
  ecs_storage_write_threshold = 6  # 6000000  # 6 MB/s

  # Health thresholds
  ecs_min_running_tasks       = 1 # Production minimum
  ecs_min_container_instances = 1

  # RDS configuration
  rds_monitoring_enabled      = local.rds_monitoring_enabled
  rds_instance_id             = local.rds_monitoring_enabled ? "rdsdb-rds-prod" : ""
  rds_cpu_threshold           = 2           #75
  rds_storage_threshold_bytes = 10737418240 # 10 GB

  # Add IOPS alarm thresholds
  rds_read_iops_threshold  = 5 # 500 # Adjust for your environment
  rds_write_iops_threshold = 3 # 400 # Adjust for your environment

  # RabbitMQ configuration
  rabbitmq_broker_name = local.rabbitmq_monitoring_enabled ? "rabbitmq-dlq11-rabbitmq-broker-local-testing" : ""
  #rabbitmq_queue_name         = ""
  rabbitmq_monitoring_enabled = local.rabbitmq_monitoring_enabled
  rabbitmq_broker_id          = local.rabbitmq_monitoring_enabled ? "rabbitmq-dlq11-rabbitmq-broker-local-testing" : ""

  # CloudWatch Alarm settings
  evaluation_periods  = 3
  datapoints_to_alarm = 2
  alarm_period        = 60

  # Tags
  tags = {
    Project     = "InfraMonitoring"
    Environment = local.environment
    Terraform   = "true"
  }
}

# Outputs
output "dashboard_name" {
  description = "The name of the CloudWatch dashboard"
  value       = module.monitoring_dashboard.dashboard_name
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = module.monitoring_dashboard.dashboard_url
}

output "dashboard_arn" {
  description = "ARN of the CloudWatch dashboard"
  value       = module.monitoring_dashboard.dashboard_arn
}

output "alarm_count" {
  description = "Count of alarms created by service"
  value       = module.monitoring_dashboard.alarm_count
}
