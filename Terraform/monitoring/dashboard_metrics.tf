locals {

  validated_service_names = var.ecs_monitoring_enabled ? [
    for service in var.ecs_service_names : service
    if service != null && service != ""
  ] : []

  ## Java metrics
  java_core_heap_memory_metrics = var.java_core_monitoring_enabled ? [
    [var.java_core_service_name, "jvm.memory.heap.committed", "OTelLib", "io.opentelemetry.jmx", { "label" : "Heap Committed (Aggregate)" }],
    [var.java_core_service_name, "jvm.memory.heap.used", "OTelLib", "io.opentelemetry.jmx", { "label" : "Heap Used (Aggregate)" }]
  ] : []

  java_core_threads_metrics = var.java_core_monitoring_enabled ? [
    [var.java_core_service_name, "jvm.threads.count", "OTelLib", "io.opentelemetry.jmx", { "label" : "Threads (Aggregate)" }]
  ] : []

  java_core_cpu_metrics = var.java_core_monitoring_enabled ? [
    [var.java_core_service_name, "jvm.cpu.recent_utilization", "OTelLib", "io.opentelemetry.jmx", { "label" : "CPU Utilization (Aggregate)" }]
  ] : []

  java_integration_heap_memory_metrics = var.java_integration_monitoring_enabled ? [
    [var.java_integration_service_name, "jvm.memory.heap.used", "OTelLib", "io.opentelemetry.jmx", { "label" : "Heap Used (Aggregate)" }],
    [var.java_integration_service_name, "jvm.memory.heap.max", "OTelLib", "io.opentelemetry.jmx", { "label" : "Heap Max (Aggregate)" }]
  ] : []

  java_integration_threads_metrics = var.java_integration_monitoring_enabled ? [
    [var.java_integration_service_name, "jvm.threads.count", "OTelLib", "io.opentelemetry.jmx", { "label" : "Threads (Aggregate)" }]
  ] : []

  java_integration_cpu_metrics = var.java_integration_monitoring_enabled ? [
    [var.java_integration_service_name, "jvm.cpu.recent_utilization", "OTelLib", "io.opentelemetry.jmx", { "label" : "CPU Utilization (Aggregate)" }]
  ] : []


  ## ECS Metrics

  # ECS Service Count Metrics
  ecs_service_count_metrics = var.ecs_monitoring_enabled ? [
    ["ECS/ContainerInsights", "ServiceCount", "ClusterName", tostring(var.ecs_cluster_name), { "label" : "Cluster Service Count" }]
  ] : []

  # ECS Task Status Metrics
  ecs_task_status_metrics = var.ecs_monitoring_enabled ? [
    for svc in local.validated_service_names : [
      "ECS/ContainerInsights", "RunningTaskCount",
      "ClusterName", var.ecs_cluster_name,
      "ServiceName", svc,
      { "label" : "Running Tasks: ${svc}" }
    ]
  ] : []


  ## CPU and Memory Utilization Metrics
  # CPU Metrics
  cpu_reserved_metrics = var.ecs_monitoring_enabled ? [
    for idx, svc in local.validated_service_names : [
      "ECS/ContainerInsights", "CpuReserved", "ClusterName", var.ecs_cluster_name, "ServiceName", svc,
      { "id" = "cpu_mm0m${idx}", "region" = data.aws_region.current.name, "stat" = "Sum", "visible" = false }
    ]
  ] : []

  cpu_utilized_metrics = var.ecs_monitoring_enabled ? [
    for idx, svc in local.validated_service_names : [
      "ECS/ContainerInsights", "CpuUtilized", "ClusterName", var.ecs_cluster_name, "ServiceName", svc,
      { "id" = "cpu_mm1m${idx}", "region" = data.aws_region.current.name, "stat" = "Sum", "visible" = false }
    ]
  ] : []
  cpu_utilization_metrics_service_only = var.ecs_monitoring_enabled ? [
    for idx, svc in local.validated_service_names : [
      {
        "expression" = "cpu_mm1m${idx} * 100 / cpu_mm0m${idx}",
        "id"         = "cpu_expr1m${idx}",
        "label"      = "[avg: $${AVG}] CPU: ${svc}",
        "region"     = data.aws_region.current.name,
        "stat"       = "Average"
      }
    ]
  ] : []

  # Memory Metrics
  memory_reserved_metrics = var.ecs_monitoring_enabled ? [
    for idx, svc in local.validated_service_names : [
      "ECS/ContainerInsights", "MemoryReserved", "ClusterName", var.ecs_cluster_name, "ServiceName", svc,
      { "id" = "mem_mm0m${idx}", "region" = data.aws_region.current.name, "stat" = "Sum", "visible" = false }
    ]
  ] : []

  memory_utilized_metrics = var.ecs_monitoring_enabled ? [
    for idx, svc in local.validated_service_names : [
      "ECS/ContainerInsights", "MemoryUtilized", "ClusterName", var.ecs_cluster_name, "ServiceName", svc,
      { "id" = "mem_mm1m${idx}", "region" = data.aws_region.current.name, "stat" = "Sum", "visible" = false }
    ]
  ] : []
  memory_utilization_metrics_service_only = var.ecs_monitoring_enabled ? [
    for idx, svc in local.validated_service_names : [
      {
        "expression" = "mem_mm1m${idx} * 100 / mem_mm0m${idx}",
        "id"         = "mem_expr1m${idx}",
        "label"      = "[avg: $${AVG}] Memory: ${svc}",
        "region"     = data.aws_region.current.name,
        "stat"       = "Average"
      }
    ]
  ] : []

  # Only service-level Network Rx metrics
  network_rx_metrics_service_only = var.ecs_monitoring_enabled ? [
    for svc in local.validated_service_names : [
      "ECS/ContainerInsights", "NetworkRxBytes", "ClusterName", var.ecs_cluster_name, "ServiceName", svc, { "label" : "Network Rx: ${svc}" }
    ]
  ] : []

  # Only service-level Network Tx metrics
  network_tx_metrics_service_only = var.ecs_monitoring_enabled ? [
    for svc in local.validated_service_names : [
      "ECS/ContainerInsights", "NetworkTxBytes", "ClusterName", var.ecs_cluster_name, "ServiceName", svc, { "label" : "Network Tx: ${svc}" }
    ]
  ] : []

  # ECS Storage Metrics
  ecs_storage_write_metrics = var.ecs_monitoring_enabled ? [
    for svc in local.validated_service_names : [
      "ECS/ContainerInsights", "StorageWriteBytes", "ClusterName", var.ecs_cluster_name, "ServiceName", svc, { "label" : "Storage Write Bytes: ${svc}" }
    ]
  ] : []

  ecs_storage_read_metrics = var.ecs_monitoring_enabled ? [
    for svc in local.validated_service_names : [
      "ECS/ContainerInsights", "StorageReadBytes", "ClusterName", var.ecs_cluster_name, "ServiceName", svc, { "label" : "Storage Read Bytes: ${svc}" }
    ]
  ] : []


  ## RDS metrics
  # RDS CPU metrics
  rds_cpu_metrics = var.rds_monitoring_enabled ? [
    ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_instance_id]
  ] : []
  # RDS IOPS metrics
  rds_iops_metrics = var.rds_monitoring_enabled ? [
    ["AWS/RDS", "ReadIOPS", "DBInstanceIdentifier", var.rds_instance_id],
    ["AWS/RDS", "WriteIOPS", "DBInstanceIdentifier", var.rds_instance_id]
  ] : []
  # RDS Memory metrics
  rds_memory_metrics = var.rds_monitoring_enabled ? [
    ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.rds_instance_id],
    ["AWS/RDS", "SwapUsage", "DBInstanceIdentifier", var.rds_instance_id]
  ] : []

  ## RabbitMQ metrics
  # RabbitMQ message counts metrics
  rabbitmq_message_counts_metrics = var.rabbitmq_monitoring_enabled ? [
    ["AWS/AmazonMQ", "MessageUnacknowledgedCount", "Broker", var.rabbitmq_broker_name],
    ["AWS/AmazonMQ", "MessageCount", "Broker", var.rabbitmq_broker_name]
  ] : []

  # RabbitMQ Dead Letter Queue (DLQ) metrics
  rabbitmq_dlq_dashboard_metrics = var.rabbitmq_monitoring_enabled ? [
    ["AWS/AmazonMQ", "MessageCount", "QueueName", var.rabbitmq_dlq_queue_name]
  ] : []
}