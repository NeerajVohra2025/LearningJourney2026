output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = try(aws_cloudwatch_dashboard.main[0].dashboard_name, null)
}
output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${try(aws_cloudwatch_dashboard.main[0].dashboard_name, null)}"
}
output "java_core_alarms" {
  description = "Java Core service CloudWatch alarm ARNs (JVM metrics)"
  value = contains(local.enabled_services, "java-core") ? {
    heap_used_high      = try(aws_cloudwatch_metric_alarm.java_core_heap_used_high[0].arn, null)
    heap_committed_high = try(aws_cloudwatch_metric_alarm.java_core_heap_committed_high[0].arn, null)
    threads_high        = try(aws_cloudwatch_metric_alarm.java_core_threads_high[0].arn, null)
    cpu_high            = try(aws_cloudwatch_metric_alarm.java_core_cpu_high[0].arn, null) // <-- Added
  } : null
}

output "java_integration_alarms" {
  description = "Java Integration service CloudWatch alarm ARNs (JVM metrics)"
  value = contains(local.enabled_services, "java-integration") ? {
    heap_used_high = try(aws_cloudwatch_metric_alarm.java_integration_heap_used_high[0].arn, null)
    heap_max_high  = try(aws_cloudwatch_metric_alarm.java_integration_heap_max_high[0].arn, null)
    threads_high   = try(aws_cloudwatch_metric_alarm.java_integration_threads_high[0].arn, null)
    cpu_high       = try(aws_cloudwatch_metric_alarm.java_integration_cpu_high[0].arn, null) // <-- Added
  } : null
}

output "rds_alarms" {
  description = "RDS database CloudWatch alarm ARNs (instance metrics)"
  value = contains(local.enabled_services, "rds") ? {
    high_cpu        = try(aws_cloudwatch_metric_alarm.rds_high_cpu[0].arn, null)
    high_read_iops  = try(aws_cloudwatch_metric_alarm.rds_high_read_iops[0].arn, null)
    high_write_iops = try(aws_cloudwatch_metric_alarm.rds_high_write_iops[0].arn, null)
    low_memory      = try(aws_cloudwatch_metric_alarm.rds_low_memory[0].arn, null)
    high_swap_usage = try(aws_cloudwatch_metric_alarm.rds_high_swap_usage[0].arn, null)
  } : null
}

output "rabbitmq_alarms" {
  description = "ARNs of the RabbitMQ alarms"
  value = contains(local.enabled_services, "rabbitmq") ? {
    message_count        = try(aws_cloudwatch_metric_alarm.rabbitmq_message_count[0].arn, null)
    unacknowledged_count = try(aws_cloudwatch_metric_alarm.rabbitmq_unacknowledged_messages[0].arn, null)
    dlq_message_count    = try(aws_cloudwatch_metric_alarm.rabbitmq_dlq_message_count[0].arn, null)
  } : {}
}
# Dashboard output
output "dashboard_arn" {
  description = "CloudWatch dashboard ARN for cross-account sharing"
  value       = try(aws_cloudwatch_dashboard.main[0].dashboard_arn, null)
}

output "enabled_services" {
  description = "List of services with monitoring enabled"
  value       = local.enabled_services
}

output "alarm_configurations" {
  description = "Configuration for CloudWatch alarms"
  value = {
    action_config = local.alarm_action_config
    metric_config = local.metric_config
  }
}

output "alarm_count_debug" {
  description = "Number of alarms created per service"
  value = {
    java_core        = contains(local.enabled_services, "java-core") ? 1 : 0
    java_integration = contains(local.enabled_services, "java-integration") ? 1 : 0
    ecs              = contains(local.enabled_services, "ecs") ? 1 : 0
    rds              = contains(local.enabled_services, "rds") ? 1 : 0
    rabbitmq         = contains(local.enabled_services, "rabbitmq") ? 1 : 0

  }
}

output "enabled_services_debug" {
  description = "List of services enabled for monitoring"
  value       = local.enabled_services
}

output "service_flags_debug" {
  description = "Service enablement flags"
  value = {
    java_core        = local.java_core_monitoring_enabled
    java_integration = local.java_integration_monitoring_enabled
    ecs              = local.ecs_monitoring_enabled
    rds              = local.rds_monitoring_enabled
    rabbitmq         = local.rabbitmq_monitoring_enabled
  }
}

output "enabled_service_mapping" {
  description = "Service mapping between alarm and dashboard components"
  value = {
    enabled_services = local.enabled_services
    mapped_dashboard_services = [
      for service in local.enabled_services :
      try(local.service_mapping[service], "unknown")
    ]
    alarm_count = {
      java_core        = contains(local.enabled_services, "java-core") ? 1 : 0
      java_integration = contains(local.enabled_services, "java-integration") ? 1 : 0
      ecs              = contains(local.enabled_services, "ecs") ? 1 : 0
      rds              = contains(local.enabled_services, "rds") ? 1 : 0
      rabbitmq         = contains(local.enabled_services, "rabbitmq") ? 1 : 0
      total            = length(local.enabled_services)
    }
  }
}




output "debug_service_filtering" {
  description = "Debug: Service filtering configuration"
  value = {
    use_service_filtering = local.use_service_filtering
    service_names         = var.ecs_service_names
    service_count         = length(var.ecs_service_names)
  }
}
