locals {
  # Decide if we should show widgets for specific services or for the whole cluster
  use_service_filtering = try(var.service_level_monitoring_enabled, false) && try(length(var.ecs_service_names), 0) > 0

  # Set up information about the main service or the cluster, depending on the above setting
  service_context = local.use_service_filtering && length(var.ecs_service_names) > 0 ? {
    primary_service = var.ecs_service_names[0]
    service_count   = length(var.ecs_service_names)
    services_list   = join(", ", var.ecs_service_names)
    } : {
    primary_service = var.ecs_cluster_name
    service_count   = 0
    services_list   = "All Services"
  }

  # Create a filter to show only the selected services in some widgets
  service_filter_expression = local.use_service_filtering ? join(" OR ", [
    for service in try(var.ecs_service_names, []) : "ServiceName=\"${service}\""
  ]) : ""
  # List all the widgets that could be shown on the dashboard
  all_potential_widgets = [

    ## Java application widgets
    {
      widget_id = "java_header"
      type      = "text"
      width     = local.widget_dimensions.header.width,
      height    = local.widget_dimensions.header.height,
      service   = "java",
      count     = var.java_core_monitoring_enabled || var.java_integration_monitoring_enabled ? 1 : 0
      properties = {
        markdown = "# ${var.java_dashboard_title}"
      }
    },

    {
      widget_id = "java_core_heap_memory"
      service   = "java"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        stacked = false
        title   = var.java_core_service_name
        region  = data.aws_region.current.name
        period  = local.alarm_defaults.period
        metrics = local.java_core_heap_memory_metrics
        alarms = [
          aws_cloudwatch_metric_alarm.java_core_heap_used_high[0].arn,
          aws_cloudwatch_metric_alarm.java_core_heap_committed_high[0].arn
        ]
      }
    },
    {

      widget_id = "java_core_threads"
      service   = "java"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        stacked = false
        title   = var.java_core_service_name
        region  = data.aws_region.current.name
        stat    = "Average"
        period  = local.alarm_defaults.period
        metrics = local.java_core_threads_metrics
        yAxis = {
          left = {
            min       = 0
            showUnits = false
            label     = " Core Thread Count"
          }
        }
        alarms = [
          aws_cloudwatch_metric_alarm.java_core_threads_high[0].arn
        ]
      }

    },
    {
      widget_id = "java_core_cpu"
      service   = "java"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        stacked = false
        title   = "${var.java_core_service_name}"
        region  = data.aws_region.current.name
        period  = local.alarm_defaults.period
        metrics = local.java_core_cpu_metrics
        stat    = "Average"
        yAxis = {
          left = {
            min       = 0
            showUnits = false
            label     = "Percent"
          }
        }
        alarms = [
          aws_cloudwatch_metric_alarm.java_core_cpu_high[0].arn
        ]
      }
    },

    {
      widget_id = "java_integration_heap_memory"
      service   = "java"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        stacked = false
        title   = var.java_integration_service_name
        region  = data.aws_region.current.name
        stat    = "Average"
        period  = local.alarm_defaults.period
        metrics = local.java_integration_heap_memory_metrics
        alarms = [
          aws_cloudwatch_metric_alarm.java_integration_heap_used_high[0].arn,
          aws_cloudwatch_metric_alarm.java_integration_heap_max_high[0].arn
        ]
      }

    },
    {
      widget_id = "java_integration_threads"
      service   = "java"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        title   = var.java_integration_service_name
        view    = "timeSeries"
        region  = data.aws_region.current.name
        metrics = local.java_integration_threads_metrics
        period  = local.alarm_defaults.period
        stat    = "Average"
        yAxis = {
          left = {
            min       = 0
            showUnits = false
            label     = "Integration Thread Count"
          }
        }
        alarms = [
          aws_cloudwatch_metric_alarm.java_integration_threads_high[0].arn
        ]
      }
    },

    {
      widget_id = "java_integration_cpu"
      service   = "java"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        stacked = false
        title   = "${var.java_integration_service_name}"
        region  = data.aws_region.current.name
        period  = local.alarm_defaults.period
        metrics = local.java_integration_cpu_metrics
        stat    = "Average"
        yAxis = {
          left = {
            min       = 0
            showUnits = false
            label     = "Percent"
          }
        }
        alarms = [
          aws_cloudwatch_metric_alarm.java_integration_cpu_high[0].arn
        ]
      }
    },

    ## ECS (container) widgets
    {
      widget_id = "ecs_header",
      service   = "ecs",
      type      = "text",
      width     = local.widget_dimensions.header.width,
      height    = local.widget_dimensions.header.height,
      properties = {
        # Show a heading for the ECS section, mentioning the cluster or selected services
        markdown = (
          local.use_service_filtering
          ? "## Container Insights: Selected Services in ${var.ecs_cluster_name}"
          : "## Container Insights: - ${var.ecs_cluster_name}"
        )
      }
    },
    {
      widget_id = "ecs_service_count"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      service   = "ecs"
      properties = {
        title   = "Service Count"
        view    = "timeSeries"
        region  = data.aws_region.current.name
        metrics = local.ecs_service_count_metrics
        period  = local.alarm_defaults.period,
        stat    = "Average"
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_count_low : alarm.arn]
        ])
      }
    },
    {
      widget_id = "ecs_task_status"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      service   = "ecs"
      properties = {
        title   = "Task Status"
        view    = "singleValue"
        region  = data.aws_region.current.name
        metrics = local.ecs_task_status_metrics
        period  = local.alarm_defaults.period
        stat    = "Average"
      }
      alarms = flatten([
        [for alarm in aws_cloudwatch_metric_alarm.ecs_service_running_tasks_low : alarm.arn]

      ])
    },
    {
      widget_id = "ecs_cpu_overview"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      service   = "ecs"
      properties = {
        title  = "CPU Utilization (%)"
        view   = "timeSeries"
        region = data.aws_region.current.name
        metrics = concat(
          local.cpu_utilization_metrics_service_only,
          local.cpu_reserved_metrics,
          local.cpu_utilized_metrics
        )
        period   = local.alarm_defaults.period
        liveData = false
        yAxis = {
          left = {
            min       = 0
            max       = 100
            showUnits = false
            label     = "Percent"
          }
        }
        legend = {
          position = "bottom"
        }
        stacked = false
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_cpu_high : alarm.arn]
        ])
      }
    },
    {
      widget_id = "ecs_memory_overview"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      service   = "ecs"
      properties = {
        title  = "Memory utilization"
        view   = "timeSeries"
        region = data.aws_region.current.name
        metrics = concat(
          local.memory_utilization_metrics_service_only,
          local.memory_reserved_metrics,
          local.memory_utilized_metrics
        )
        period   = local.alarm_defaults.period
        liveData = false
        yAxis = {
          left = {
            min       = 0
            max       = 100
            showUnits = false
            label     = "Percent"
          }
        }
        legend = {
          position = "bottom"
        }
        stacked = false
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_memory_high : alarm.arn]
        ])
      }
    },

    {
      widget_id = "ecs_network_overview"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      service   = "ecs"
      properties = {
        title  = "Network Utilization (Rx, Tx)"
        view   = "timeSeries"
        region = data.aws_region.current.name
        metrics = concat(
          local.network_rx_metrics_service_only,
          local.network_tx_metrics_service_only
        )
        period = local.alarm_defaults.period,
        stat   = "Average"
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_network_rx_high : alarm.arn],
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_network_tx_high : alarm.arn]
        ])
      }
    },
    {
      widget_id = "ecs_storage_overview"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      service   = "ecs"
      properties = {
        title  = "Storage Overview (Read & Write)"
        view   = "timeSeries"
        region = data.aws_region.current.name
        metrics = concat(
          local.ecs_storage_write_metrics,
          local.ecs_storage_read_metrics
        )
        period = local.alarm_defaults.period,
        stat   = "Average"
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_storage_write_high : alarm.arn],
          [for alarm in aws_cloudwatch_metric_alarm.ecs_service_storage_read_high : alarm.arn]
        ])
      }
    },


    ## RDS (database) widgets
    {
      widget_id = "rds_header"
      service   = "rds"
      type      = "text"
      width     = local.widget_dimensions.header.width
      height    = local.widget_dimensions.header.height
      properties = {
        markdown = "## RDS Database: - ${var.rds_instance_id}"
      }
    },
    {
      widget_id = "rds_cpu"
      service   = "rds"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        metrics = local.rds_cpu_metrics
        region  = data.aws_region.current.name
        title   = var.rds_instance_id
        period  = local.alarm_defaults.period
        stat    = "Average"
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.rds_high_cpu : alarm.arn]
        ])
      }
    },
    {
      widget_id = "rds_iops",
      service   = "rds",
      type      = "metric",
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries",
        metrics = local.rds_iops_metrics,
        region  = data.aws_region.current.name,
        title   = var.rds_instance_id,
        period  = local.alarm_defaults.period,
        stat    = "Average"
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.rds_high_read_iops : alarm.arn],
          [for alarm in aws_cloudwatch_metric_alarm.rds_high_write_iops : alarm.arn]
        ])
      }
    },
    {
      widget_id = "rds_memory"
      service   = "rds"
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries"
        metrics = local.rds_memory_metrics
        region  = data.aws_region.current.name
        title   = var.rds_instance_id
        period  = local.alarm_defaults.period
        stat    = "Average"
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.rds_low_memory : alarm.arn],
          [for alarm in aws_cloudwatch_metric_alarm.rds_high_swap_usage : alarm.arn]
        ])
      }
    },


    ## RabbitMQ (message broker) widgets
    {
      widget_id = "rabbitmq_header"
      service   = "rabbitmq"
      type      = "text"
      width     = local.widget_dimensions.header.width
      height    = local.widget_dimensions.header.height
      properties = {
        markdown = "## RabbitMQ Broker: - ${var.rabbitmq_broker_name}"
      }
    },

    {
      widget_id = "rabbitmq_message_counts",
      service   = "rabbitmq",
      type      = "metric"
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries",
        metrics = local.rabbitmq_message_counts_metrics,
        region  = data.aws_region.current.name,
        title   = var.rabbitmq_broker_name,
        period  = local.alarm_defaults.period,
        stat    = "Average",
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.rabbitmq_message_count : alarm.arn],
          [for alarm in aws_cloudwatch_metric_alarm.rabbitmq_unacknowledged_messages : alarm.arn]
        ])
      }
    },
    {
      widget_id = "rabbitmq_dlq_message_count",
      service   = "rabbitmq",
      type      = "metric",
      width     = local.widget_dimensions.quarter.width,
      height    = local.widget_dimensions.quarter.height,
      properties = {
        view    = "timeSeries",
        metrics = local.rabbitmq_dlq_dashboard_metrics,
        region  = data.aws_region.current.name,
        title   = var.rabbitmq_dlq_queue_name,
        period  = local.alarm_defaults.period,
        stat    = "Average",
        alarms = flatten([
          [for alarm in aws_cloudwatch_metric_alarm.rabbitmq_dlq_message_count : alarm.arn]
        ])

      }
    },

  ]

  # Match each widget to its service type for easy filtering
  service_mapping = {
    "java-core"        = "java"
    "java-integration" = "java"
    "ecs"              = "ecs"
    "rds"              = "rds"
    "rabbitmq"         = "rabbitmq"
  }

  # Only keep widgets for services that are enabled in this environment
  filtered_widgets = [
    for widget in local.all_potential_widgets :
    widget if anytrue([
      for service in local.enabled_services :
      try(local.service_mapping[service], "") == widget.service
    ])
  ]

  # Prepare the widgets for the dashboard by removing extra fields CloudWatch doesn't need
  dashboard_widgets = [
    for widget in local.filtered_widgets : {
      type       = widget.type
      width      = widget.width
      height     = widget.height
      properties = widget.properties
    }
  ]
}

# This resource creates the CloudWatch dashboard using the widgets defined above
resource "aws_cloudwatch_dashboard" "main" {
  count          = local.dashboard_monitoring_enabled ? 1 : 0
  dashboard_name = replace(trimspace(var.dashboard_name), " ", "")
  dashboard_body = jsonencode({
    widgets = local.dashboard_widgets
  })
}