# Core module settings


variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "environment" {
  description = "Environment name for tagging and resource naming"
  type        = string
  default     = "Dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Add these variables to accept SNS ARNs from your existing SNS module


variable "treat_missing_data" {
  description = "How to treat missing data in CloudWatch alarms"
  type        = string
  default     = "missing"
  validation {
    condition     = contains(["missing", "ignore", "breaching", "notBreaching"], var.treat_missing_data)
    error_message = "Valid values are: missing, ignore, breaching, notBreaching"
  }
}

variable "alarm_prefix" {
  description = "Prefix for alarm names"
  type        = string
  default     = "monitor"
}

variable "alarm_period" {
  description = "Period in seconds for alarms"
  type        = number
  default     = 300
}

variable "evaluation_periods" {
  description = "Number of evaluation periods for alarms"
  type        = number
  default     = 3
}

variable "datapoints_to_alarm" {
  description = "Number of datapoints that must be breaching to trigger an alarm"
  type        = number
  default     = 2
}

variable "sns_notification_topic_arn" {
  description = "ARN of the SNS topic for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "enable_ok_notifications" {
  description = "Whether to send notifications when alarms return to OK state"
  type        = bool
  default     = true
}

# Dashboard configuration
variable "dashboard_monitoring_enabled" {
  description = "Whether to create CloudWatch dashboard"
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  type        = string
  default     = "PO-Consolidated"

}

##### Java Application Configuration
variable "java_dashboard_title" {
  description = "Title for the Java application section"
  type        = string
}

# Java Core Application configuration
variable "java_core_monitoring_enabled" {
  description = "Enable monitoring for Java Core applications"
  type        = bool
  default     = true
}

variable "java_core_service_name" {
  description = "Name of the Java core service"
  type        = string
}
variable "java_core_heap_used_threshold" {
  description = "Threshold for Java Core heap used (in bytes)"
  type        = number
  default     = 536870912 # 512 MB
}

variable "java_core_heap_committed_threshold" {
  description = "Threshold for Java Core heap committed (in bytes)"
  type        = number
  default     = 536870912 # 512 MB
}

variable "java_core_threads_threshold" {
  description = "Threshold for Java Core thread count"
  type        = number
  default     = 200
}

variable "java_core_cpu_threshold" {
  description = "Threshold for Java Core CPU utilization alarm (percent)"
  type        = number
  default     = 80
}

# Java Integration Application configuration
variable "java_integration_monitoring_enabled" {
  description = "Enable monitoring for Java Integration applications"
  type        = bool
  default     = true
}

variable "java_integration_service_name" {
  description = "Name of the Java integration service"
  type        = string

}

variable "java_integration_heap_used_threshold" {
  description = "Threshold for Java Integration heap used (in bytes)"
  type        = number
  default     = 536870912 # 512 MB
}

variable "java_integration_heap_max_threshold" {
  description = "Threshold for Java Integration heap max (in bytes)"
  type        = number
  default     = 1073741824 # 1 GB
}

variable "java_integration_threads_threshold" {
  description = "Threshold for Java Integration thread count"
  type        = number
  default     = 200
}

variable "java_integration_cpu_threshold" {
  description = "Threshold for Java Integration CPU utilization alarm (percent)"
  type        = number
  default     = 80
}

## Service-specific variables organized by service type
# ECS/Fargate
variable "ecs_monitoring_enabled" {
  description = "Whether to monitor ECS resources"
  type        = bool
  default     = true
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to monitor"
  type        = string
  default     = ""
}
variable "ecs_service_count_low" {
  description = "The minimum number of services running on cluster"
  type        = number
  default     = 1
}
variable "ecs_min_running_tasks" {
  description = "Minimum number of running tasks for the ECS service"
  type        = number
  default     = 1
}


variable "ecs_service_task_memory" {
  description = "Map of ECS service names to their task memory allocation in MB"
  type        = map(number)
  default     = {}
}

variable "ecs_service_task_cpu" {
  description = "Map of ECS service names to their task CPU allocation in vCPU units"
  type        = map(number)
  default     = {}
}

variable "ecs_service_network_rx_threshold" {
  description = "Map of ECS service names to their network RX threshold (bytes/sec)"
  type        = map(number)
  default     = {}
}

variable "ecs_service_network_tx_threshold" {
  description = "Map of ECS service names to their network TX threshold (bytes/sec)"
  type        = map(number)
  default     = {}
}

variable "ecs_service_storage_write_threshold" {
  description = "Map of ECS service names to their storage write threshold (bytes/sec)"
  type        = map(number)
  default     = {}
}

variable "ecs_service_storage_read_threshold" {
  description = "Map of ECS service names to their storage read threshold (bytes/sec)"
  type        = map(number)
  default     = {}
}

# ECS Service-specific monitoring variables
variable "ecs_services_to_monitor" {
  description = "List of specific ECS service names to monitor (for per-service alarms)"
  type        = list(string)
  default     = []
}
variable "ecs_service_name_filter" {
  description = "Regular expression pattern to filter ECS services (for pattern-based alarms)"
  type        = string
  default     = ""
}
variable "ecs_task_filter_enabled" {
  description = "Enable filtering and monitoring of specific ECS tasks"
  type        = bool
  default     = false
}
variable "ecs_task_filter_pattern" {
  description = "Regular expression pattern to filter ECS task definitions"
  type        = string
  default     = ""
}

# Service Level Monitoring Configuration
variable "service_level_monitoring_enabled" {
  description = "Enable monitoring at the service level instead of cluster level"
  type        = bool
  default     = true
}
variable "ecs_service_names" {
  description = "List of ECS service names to monitor specifically (e.g., your SmartVu services)"
  type        = list(string)
  default     = []
}

variable "container_insights_enabled" {
  description = "Whether Container Insights is enabled on the ECS cluster"
  type        = bool
  default     = true
}

variable "ecs_service_validation_enabled" {
  description = "Enable validation of ECS service names"
  type        = bool
  default     = true
}

# RDS configuration
variable "rds_monitoring_enabled" {
  description = "Whether to monitor RDS resources"
  type        = bool
  default     = true
}

variable "rds_instance_id" {
  description = "RDS instance identifier to monitor"
  type        = string
  default     = ""
}

variable "rds_cpu_threshold" {
  description = "CPU utilization threshold for RDS (as decimal: 0.8 = 80%)"
  type        = number
  default     = 0.8 # Changed from 80 to match RDS CPU format
}

variable "rds_read_iops_threshold" {
  description = "Threshold for RDS read IOPS alarm"
  type        = number
  default     = 500 # Adjust based on instance type and workload characteristics
}

variable "rds_write_iops_threshold" {
  description = "Threshold for RDS write IOPS alarm"
  type        = number
  default     = 400 # Adjust based on instance type and workload characteristics
}

variable "rds_memory_threshold_bytes" {
  description = "Free memory threshold in bytes for RDS"
  type        = number
  default     = 1073741824 # 1GB
}

variable "rds_swap_usage_threshold_bytes" {
  description = "Threshold for RDS swap usage in bytes before alarm triggers"
  type        = number
  default     = 104857600 # 100 MB, adjust as needed for your environment
}

# RabbitMQ configuration
variable "rabbitmq_monitoring_enabled" {
  description = "Whether to monitor RabbitMQ resources"
  type        = bool
  default     = true
}

variable "rabbitmq_broker_name" {
  description = "Name of the RabbitMQ broker"
  type        = string
}
variable "rabbitmq_broker_id" {
  description = "ID of the RabbitMQ broker to monitor"
  type        = string
  default     = ""
}

variable "rabbitmq_max_message_count" {
  description = "Threshold for RabbitMQ queue message count before alarm triggers"
  type        = number
  default     = 1000
}

variable "rabbitmq_max_unacknowledged_messages" {
  description = "Threshold for RabbitMQ unacknowledged message count before alarm triggers"
  type        = number
  default     = 100
}

variable "rabbitmq_dlq_queue_name" {
  description = "RabbitMQ DLQ queue name to monitor"
  type        = string
}

variable "rabbitmq_dlq_message_count_threshold" {
  description = "Threshold for RabbitMQ DLQ message count alarm"
  type        = number
  default     = 1
}