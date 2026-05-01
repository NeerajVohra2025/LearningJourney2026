# Java Core Heap Used Alarm (matches Java Core Heap widget)
resource "aws_cloudwatch_metric_alarm" "java_core_heap_used_high" {
  count                     = contains(local.enabled_services, "java-core") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-core-heap-used-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.memory.heap.used"
  namespace                 = "JVM"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_core_heap_used_threshold
  alarm_description         = "Java Core heap used is high"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.java_core.dimensions
  tags                      = local.common_tags
}

# Java Core Heap Committed Alarm(matches Java Core Heap widget)
resource "aws_cloudwatch_metric_alarm" "java_core_heap_committed_high" {
  count                     = contains(local.enabled_services, "java-core") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-core-heap-committed-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.memory.heap.committed"
  namespace                 = "JVM"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_core_heap_committed_threshold
  alarm_description         = "Java Core heap committed is high"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.java_core.dimensions
  tags                      = local.common_tags
}

# Java Core Threads Count Alarm(matches Java Core Threads widget)
resource "aws_cloudwatch_metric_alarm" "java_core_threads_high" {
  count                     = contains(local.enabled_services, "java-core") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-core-threads-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.threads.count"
  namespace                 = "JVM"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_core_threads_threshold
  alarm_description         = "Java Core thread count is high"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.java_core.dimensions
  tags                      = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "java_core_cpu_high" {
  count                     = var.java_core_monitoring_enabled ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-core-cpu-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.cpu.utilization"
  namespace                 = "CustomNamespace"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_core_cpu_threshold
  alarm_description         = "Java Core CPU utilization exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = { ServiceName = var.java_core_service_name }
  tags                      = local.common_tags
}

# Java Integration Heap Used Alarm(matches Java Integration Heap widget)
resource "aws_cloudwatch_metric_alarm" "java_integration_heap_used_high" {
  count                     = contains(local.enabled_services, "java-integration") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-integration-heap-used-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.memory.heap.used"
  namespace                 = "JVM"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_integration_heap_used_threshold
  alarm_description         = "Java Integration heap used is high"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.java_integration.dimensions
  tags                      = local.common_tags
}

# Java Integration Heap Max Alarm(matches Java Integration Heap widget)
resource "aws_cloudwatch_metric_alarm" "java_integration_heap_max_high" {
  count                     = contains(local.enabled_services, "java-integration") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-integration-heap-max-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.memory.heap.max"
  namespace                 = "JVM"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_integration_heap_max_threshold
  alarm_description         = "Java Integration heap max is high"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.java_integration.dimensions
  tags                      = local.common_tags
}

# Java Integration Threads Count Alarm(matches Java Integration Threads widget)
resource "aws_cloudwatch_metric_alarm" "java_integration_threads_high" {
  count                     = contains(local.enabled_services, "java-integration") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-integration-threads-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.threads.count"
  namespace                 = "JVM"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_integration_threads_threshold
  alarm_description         = "Java Integration thread count is high"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.java_integration.dimensions
  tags                      = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "java_integration_cpu_high" {
  count                     = var.java_integration_monitoring_enabled ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-java-integration-cpu-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "jvm.cpu.utilization"
  namespace                 = "CustomNamespace"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.java_integration_cpu_threshold
  alarm_description         = "Java Integration CPU utilization exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = { ServiceName = var.java_integration_service_name }
  tags                      = local.common_tags
}


# ECS Service Count Alarm (matches ECS Service Count widget)
resource "aws_cloudwatch_metric_alarm" "ecs_service_count_low" {
  count                     = contains(local.enabled_services, "ecs") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-ecs-service-count-low"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "ServiceCount"
  namespace                 = "ECS/ContainerInsights"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.ecs_service_count_low
  alarm_description         = "ECS service count is low"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
  dimensions                = local.metric_config.ecs.cluster_dimensions
}

# ECS Service Running Task Count Alarm (matches ECS Service Running Tasks widget)
resource "aws_cloudwatch_metric_alarm" "ecs_service_running_tasks_low" {
  for_each                  = { for svc in local.validated_service_names : svc => svc }
  alarm_name                = "${var.alarm_prefix}-ecs-service-${each.key}-running-tasks-low"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "RunningTaskCount"
  namespace                 = "ECS/ContainerInsights"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.ecs_min_running_tasks
  alarm_description         = "ECS service ${each.key} running task count is low"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
  dimensions                = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
}



# ECS Service CPU Utilization Alarm (matches Resource Overview widget) - FIXED
resource "aws_cloudwatch_metric_alarm" "ecs_service_cpu_high" {
  for_each            = { for svc in local.validated_service_names : svc => svc }
  alarm_name          = "${var.alarm_prefix}-ecs-service-${each.key}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.alarm_defaults.evaluation_periods

  # Use math expression that matches dashboard with unique CPU IDs
  metric_query {
    id          = "cpu_mm1m0"
    return_data = false
    metric {
      metric_name = "CpuUtilized"
      namespace   = "ECS/ContainerInsights"
      period      = local.alarm_defaults.period
      stat        = "Sum"
      dimensions  = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
    }
  }

  metric_query {
    id          = "cpu_mm0m0"
    return_data = false
    metric {
      metric_name = "CpuReserved"
      namespace   = "ECS/ContainerInsights"
      period      = local.alarm_defaults.period
      stat        = "Sum"
      dimensions  = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
    }
  }

  metric_query {
    id          = "cpu_expr1m0"
    return_data = true
    expression  = "cpu_mm1m0 * 100 / cpu_mm0m0"
  }

  threshold                 = local.ecs_service_cpu_threshold[each.key]
  alarm_description         = "ECS service ${each.key} CPU utilization exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
}

# ECS Service Memory Utilization Alarm (matches Resource Overview widget) - FIXED
resource "aws_cloudwatch_metric_alarm" "ecs_service_memory_high" {
  for_each            = { for svc in local.validated_service_names : svc => svc }
  alarm_name          = "${var.alarm_prefix}-ecs-service-${each.key}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = local.alarm_defaults.evaluation_periods

  # Use math expression that matches dashboard with unique Memory IDs
  metric_query {
    id          = "mem_mm1m0"
    return_data = false
    metric {
      metric_name = "MemoryUtilized"
      namespace   = "ECS/ContainerInsights"
      period      = local.alarm_defaults.period
      stat        = "Sum"
      dimensions  = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
    }
  }

  metric_query {
    id          = "mem_mm0m0"
    return_data = false
    metric {
      metric_name = "MemoryReserved"
      namespace   = "ECS/ContainerInsights"
      period      = local.alarm_defaults.period
      stat        = "Sum"
      dimensions  = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
    }
  }

  metric_query {
    id          = "mem_expr1m0"
    return_data = true
    expression  = "mem_mm1m0 * 100 / mem_mm0m0"
  }

  threshold                 = local.ecs_service_memory_threshold[each.key]
  alarm_description         = "ECS service ${each.key} memory utilization exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
}

# ECS Service Network Rx Alarm (matches Resource Overview widget)
resource "aws_cloudwatch_metric_alarm" "ecs_service_network_rx_high" {
  for_each                  = { for svc in local.validated_service_names : svc => svc }
  alarm_name                = "${var.alarm_prefix}-ecs-service-${each.key}-network-rx-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "NetworkRxBytes"
  namespace                 = "ECS/ContainerInsights"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = lookup(var.ecs_service_network_rx_threshold, each.key, 10000000)
  alarm_description         = "ECS service ${each.key} network RX exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
  dimensions                = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
}

# ECS Service Network Tx Alarm (matches Resource Overview widget)
resource "aws_cloudwatch_metric_alarm" "ecs_service_network_tx_high" {
  for_each                  = { for svc in local.validated_service_names : svc => svc }
  alarm_name                = "${var.alarm_prefix}-ecs-service-${each.key}-network-tx-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "NetworkTxBytes"
  namespace                 = "ECS/ContainerInsights"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = lookup(var.ecs_service_network_tx_threshold, each.key, 10000000)
  alarm_description         = "ECS service ${each.key} network TX exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
  dimensions                = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
}


# ECS Service Storage Write Alarm (matches Storage Overview widget)
resource "aws_cloudwatch_metric_alarm" "ecs_service_storage_write_high" {
  for_each                  = { for svc in local.validated_service_names : svc => svc }
  alarm_name                = "${var.alarm_prefix}-ecs-service-${each.key}-storage-write-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "StorageWriteBytes"
  namespace                 = "ECS/ContainerInsights"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = lookup(var.ecs_service_storage_write_threshold, each.key, 5000000)
  alarm_description         = "ECS service ${each.key} storage write exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
  dimensions                = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
}

# ECS Service Storage Read Alarm (matches Storage Overview widget)
resource "aws_cloudwatch_metric_alarm" "ecs_service_storage_read_high" {
  for_each                  = { for svc in local.validated_service_names : svc => svc }
  alarm_name                = "${var.alarm_prefix}-ecs-service-${each.key}-storage-read-high"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "StorageReadBytes"
  namespace                 = "ECS/ContainerInsights"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = lookup(var.ecs_service_storage_read_threshold, each.key, 5000000)
  alarm_description         = "ECS service ${each.key} storage read exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  tags                      = local.common_tags
  dimensions                = merge(local.metric_config.ecs.cluster_dimensions, { ServiceName = each.key })
}

# RDS Service Alarms
# CPU Utilization Alarm (corresponds to RDS Database "CPU Utilization" widget)
resource "aws_cloudwatch_metric_alarm" "rds_high_cpu" {
  count                     = contains(local.enabled_services, "rds") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rds-high-cpu"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/RDS"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rds_cpu_threshold
  alarm_description         = "RDS instance CPU utilization exceeded ${var.rds_cpu_threshold}%"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rds.dimensions
  tags                      = local.common_tags
}

# Read IOPS Alarm (corresponds to "Database IOPS" widget - blue line)
resource "aws_cloudwatch_metric_alarm" "rds_high_read_iops" {
  count                     = contains(local.enabled_services, "rds") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rds-high-read-iops"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "ReadIOPS"
  namespace                 = "AWS/RDS"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rds_read_iops_threshold
  alarm_description         = "RDS instance read IOPS exceeded ${var.rds_read_iops_threshold} operations/second"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rds.dimensions
  tags                      = local.common_tags
}

# Write IOPS Alarm (corresponds to "Database IOPS" widget - orange line)
resource "aws_cloudwatch_metric_alarm" "rds_high_write_iops" {
  count                     = contains(local.enabled_services, "rds") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rds-high-write-iops"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "WriteIOPS"
  namespace                 = "AWS/RDS"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rds_write_iops_threshold
  alarm_description         = "RDS instance write IOPS exceeded ${var.rds_write_iops_threshold} operations/second"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rds.dimensions
  tags                      = local.common_tags
}

# RDS Freeable Memory Alarm (corresponds to "Freeable Memory" widget)
resource "aws_cloudwatch_metric_alarm" "rds_low_memory" {
  count                     = contains(local.enabled_services, "rds") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rds-low-memory"
  comparison_operator       = "LessThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "FreeableMemory"
  namespace                 = "AWS/RDS"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rds_memory_threshold_bytes
  alarm_description         = "RDS instance freeable memory below ${var.rds_memory_threshold_bytes} bytes"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rds.dimensions
  tags                      = local.common_tags
}

# RDS Swap Usage Alarm (corresponds to "SwapUsage" in Memory Widget)
resource "aws_cloudwatch_metric_alarm" "rds_high_swap_usage" {
  count                     = contains(local.enabled_services, "rds") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rds-high-swap-usage"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "SwapUsage"
  namespace                 = "AWS/RDS"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rds_swap_usage_threshold_bytes
  alarm_description         = "RDS instance swap usage exceeded ${var.rds_swap_usage_threshold_bytes} bytes"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rds.dimensions
  tags                      = local.common_tags
}


## RabbitMQ Alarms

# RabbitMQ Unacknowledged Messages Alarm (corresponds to "Unacknowledged Messages" widget)
resource "aws_cloudwatch_metric_alarm" "rabbitmq_unacknowledged_messages" {
  count                     = contains(local.enabled_services, "rabbitmq") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rabbitmq-unacknowledged-messages"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "MessageUnacknowledgedCount"
  namespace                 = "AWS/AmazonMQ"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rabbitmq_max_unacknowledged_messages
  alarm_description         = "RabbitMQ broker unacknowledged message count exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rabbitmq.broker_dimensions
  tags                      = local.common_tags
}

# RabbitMQ Message Count Alarm (corresponds to "Message Count" widget)
resource "aws_cloudwatch_metric_alarm" "rabbitmq_message_count" {
  count                     = contains(local.enabled_services, "rabbitmq") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rabbitmq-message-count"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "MessageCount"
  namespace                 = "AWS/AmazonMQ"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rabbitmq_max_message_count
  alarm_description         = "RabbitMQ broker message count exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = local.metric_config.rabbitmq.broker_dimensions
  tags                      = local.common_tags
}

# RabbitMQ DLQ Message Count Alarm (corresponds to DLQ widget)
resource "aws_cloudwatch_metric_alarm" "rabbitmq_dlq_message_count" {
  count                     = contains(local.enabled_services, "rabbitmq") ? 1 : 0
  alarm_name                = "${var.alarm_prefix}-rabbitmq-dlq-message-count"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = local.alarm_defaults.evaluation_periods
  metric_name               = "MessageCount"
  namespace                 = "AWS/AmazonMQ"
  period                    = local.alarm_defaults.period
  statistic                 = "Average"
  threshold                 = var.rabbitmq_dlq_message_count_threshold
  alarm_description         = "RabbitMQ DLQ message count exceeded threshold"
  alarm_actions             = local.alarm_action_config.alarm_actions
  ok_actions                = local.alarm_action_config.ok_actions
  insufficient_data_actions = local.alarm_action_config.insufficient_data_actions
  treat_missing_data        = local.alarm_action_config.treat_missing_data
  dimensions                = merge(local.metric_config.rabbitmq.queue_dimensions, { QueueName = var.rabbitmq_dlq_queue_name })
  tags                      = local.common_tags
}