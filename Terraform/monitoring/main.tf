data "aws_region" "current" {}
# Single source of truth for local values
locals {
  # Service enablement flags
  java_core_monitoring_enabled        = var.java_core_monitoring_enabled
  java_integration_monitoring_enabled = var.java_integration_monitoring_enabled
  ecs_monitoring_enabled              = var.ecs_monitoring_enabled
  rds_monitoring_enabled              = var.rds_monitoring_enabled
  rabbitmq_monitoring_enabled         = var.rabbitmq_monitoring_enabled
  dashboard_monitoring_enabled        = var.dashboard_monitoring_enabled

  # Common tags applied to all resources
  common_tags = merge(
    var.tags,
    {
      CreatedAt   = timestamp()
      Environment = var.environment
      Terraform   = "true"
      Module      = "monitoring"
    }
  )
  # Widget dimension standards
  widget_dimensions = {
    header = {
      width  = 24
      height = 1
    }
    full = {
      width  = 24
      height = 6
    }
    half = {
      width  = 12
      height = 6
    }
    third = {
      width  = 8
      height = 6
    }
    quarter = {
      width  = 6
      height = 6
    }
    small = {
      width  = 12
      height = 4
    }
    single_value = {
      width  = 12
      height = 3
    }
  }

  # Alarms configuration values
  alarm_defaults = {
    period              = var.alarm_period
    evaluation_periods  = var.evaluation_periods
    datapoints_to_alarm = var.datapoints_to_alarm
    treat_missing_data  = var.treat_missing_data

  }

  # Alarm action configuration
  alarm_action_config = {
    alarm_actions             = var.sns_notification_topic_arn != "" ? [var.sns_notification_topic_arn] : []
    ok_actions                = var.sns_notification_topic_arn != "" ? [var.sns_notification_topic_arn] : []
    insufficient_data_actions = var.sns_notification_topic_arn != "" ? [var.sns_notification_topic_arn] : []
    treat_missing_data        = var.treat_missing_data
  }

  # Service-specific metric configuration
  metric_config = {
    java_core = {
      namespace = var.java_core_service_name
      dimensions = {
        "OTelLib" = "io.opentelemetry.jmx"
      }
    }
    java_integration = {
      namespace = var.java_integration_service_name
      dimensions = {
        "OTelLib" = "io.opentelemetry.jmx"
      }
    }
    ecs = {
      namespace = "ECS/ContainerInsights"
      cluster_dimensions = {
        "ClusterName" = var.ecs_cluster_name
      }
      service_dimensions = [
        for svc in var.ecs_services_to_monitor : {
          "ClusterName" = var.ecs_cluster_name
          "ServiceName" = svc
        }
      ]
      task_dimensions = [
        for svc in var.ecs_services_to_monitor : {
          "ClusterName" = tostring(var.ecs_cluster_name)
          "ServiceName" = tostring(svc)
          #"TaskDefinitionFamily" = tostring(var.ecs_task_definition_families[svc])
        }
      ]
    }
    rds = {
      namespace = "AWS/RDS"
      dimensions = {
        "DBInstanceIdentifier" = var.rds_instance_id
      }
    }
    rabbitmq = {
      namespace = "AWS/AmazonMQ"
      broker_dimensions = {
        "Broker" = var.rabbitmq_broker_name
      }
      queue_dimensions = {
        "QueueName" = var.rabbitmq_dlq_queue_name
      }
    }

  }

  # Update the enabled_services definition to match service identifiers used in alarms
  enabled_services = compact([
    local.java_core_monitoring_enabled ? "java-core" : "",
    local.java_integration_monitoring_enabled ? "java-integration" : "",
    local.ecs_monitoring_enabled ? "ecs" : "",
    local.rds_monitoring_enabled ? "rds" : "",
    local.rabbitmq_monitoring_enabled ? "rabbitmq" : ""
  ])
  #ecs_memory_threshold = var.ecs_task_memory * 1024 * 1024 * 0.75

  # 75% memory threshold per service (in bytes)
  ecs_service_memory_threshold = {
    for svc, mem in var.ecs_service_task_memory :
    svc => mem * 1024 * 1024 * 0.75
  }
  # 80% CPU threshold per service (in vCPU units, decimal)
  ecs_service_cpu_threshold = {
    for svc, cpu in var.ecs_service_task_cpu :
    svc => cpu * 0.8
  }
}
