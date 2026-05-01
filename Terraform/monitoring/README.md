Row 1: Service Health & Resource Monitoring:

    *Task Status Widget:
        Business Value:
        Provides immediate, at-a-glance visibility into the operational readiness and scaling status of ECS services. This is critical for SREs and operations teams to confirm that services are running as expected and to quickly identify scaling or deployment issues.
        Current Status:
        2 Running Tasks (blue): Indicates the ECS cluster currently has two tasks in a running state, matching the desired count for high availability.
        0 Pending Tasks (green): No tasks are waiting for resources or stuck in scheduling, which means the cluster is healthy and not resource-constrained.
        Architecture:
        Service-level task monitoring: The widget aggregates both cluster-wide and service-specific task counts.
        Baseline comparison: The legend distinguishes between overall cluster metrics and individual service metrics.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Represents the cluster-wide running task count (baseline for comparison).
        🟠 m1 Running: Represents the running task count for a specific ECS service (e.g., ecs-monitoring-service-ecs-user).
        Management Value:
        Enables rapid confirmation of service availability and scaling health.
        Supports proactive incident response by highlighting pending tasks or discrepancies.
        Operational Insight:
        The absence of pending tasks and the presence of running tasks indicate the service is stable and operating at the desired capacity.
        Purpose:
        To provide a real-time snapshot of ECS service health, supporting both operational monitoring and executive reporting.
       
    *Memory Widget:
        Business Value:
        Tracks memory utilization at both the cluster and service level, enabling capacity planning and early detection of memory leaks or resource exhaustion.
        Current Status:
        The memory line is flat, indicating stable memory usage for the monitored service.
        Architecture:
        Service-specific memory monitoring: Each line in the legend corresponds to a service or the cluster baseline.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide memory utilization.
        🟢 m0 Cluster: Memory baseline for the entire cluster.
        Other lines: Service-specific memory usage.
        Management Value:
        Supports right-sizing and cost optimization by tracking actual memory usage.
        Early warning for memory-related incidents.
        Operational Insight:
        Stable memory usage suggests no leaks or abnormal consumption.
        Purpose:
        To ensure services are operating within allocated memory limits and to support scaling decisions
   
    *Network RX Widget:
        Business Value:
        Monitors inbound network traffic, which is essential for understanding service load, detecting DDoS attacks, or troubleshooting connectivity issues.
        Current Status:
        Shows periodic spikes, indicating bursts of incoming traffic.
        Architecture:
        Cluster and service-level network monitoring: Tracks both overall and per-service network RX bytes.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide network RX.
        🟠 m1 Network Rx Bytes: Service-specific inbound traffic.
        Management Value:
        Helps in capacity planning and network troubleshooting.
        Identifies abnormal traffic patterns.
        Operational Insight:
        Spikes may correlate with batch jobs, deployments, or external integrations.
        Purpose:
        To provide visibility into network ingress, supporting both security and performance monitoring.

    *Network TX Widget:
        Business Value:
        Monitors outbound network traffic, crucial for understanding service egress, data transfer costs, and external API usage.
        Current Status:
        Similar to RX, shows spikes indicating outgoing data bursts.
        Architecture:
        Cluster and service-level network monitoring: Both overall and per-service TX bytes are tracked.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide network TX.
        🟠 m1 Network Tx Bytes: Service-specific outbound traffic.
        Management Value:
        Supports cost management (AWS data transfer fees) and performance troubleshooting.
        Operational Insight:
        Outbound spikes may indicate data exports, backups, or integrations.
        Purpose:
        To ensure network egress is within expected parameters and to quickly identify anomalies.

Row 2: Performance and Storage Utilization

    CPU Widget:
        Business Value:
        Monitors real-time CPU usage for ECS services, supporting performance tuning.
        Architecture:
        Plots CPU usage for both cluster and service.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide CPU.
        🟠 m0 Cluster: Baseline.
        🟢 Service-specific: Service CPU usage.
        Management Value:
        Detects CPU spikes or underutilization.
        Operational Insight:
        Variability may indicate workload changes.
        Purpose:
        Ensures optimal CPU allocation and performance.
       
    Storage Write Widget:
        Business Value:
        Tracks write operations to storage, important for performance and cost.
        Architecture:
        Plots storage write bytes at cluster and service level.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide writes.
        🟠 m1 Storage Write Bytes: Service-specific writes.
        Management Value:
        Identifies abnormal write activity.
        Operational Insight:
        Flat line suggests stable write operations.
        Purpose:
        Prevents storage saturation and supports scaling.    
   
    Ephemeral Storage Utilization Widget:  
        Business Value:
        Monitors usage of ephemeral storage, which is critical for stateless workloads.
        Architecture:
        Tracks ephemeral storage usage at cluster and service level.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide ephemeral storage.
        🟠 m1 Ephemeral Storage: Service-specific usage.
        Management Value:
        Prevents out-of-storage incidents.
        Operational Insight:
        Flat line indicates stable usage.
        Purpose:
        Ensures stateless services have sufficient scratch space.    
   
    Service Count Widget:
        Business Value:
        Shows the number of services running in the cluster.
        Architecture:
        Plots service count at both cluster and service level.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide service count.
        🟠 m1 Service Count: Service-specific count.
        Management Value:
        Confirms service inventory matches expectations.
        Operational Insight:
        Flat line at "1" indicates expected service count.
        Purpose:
        Supports compliance and operational audits.    
       
Row 3: Storage and Service Inventory
    Storage Read Widget:
        Business Value:
        Monitors read operations on storage, critical for performance and cost management.
        Architecture:
        Plots storage read bytes at cluster and service level.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide storage reads.
        🟠 m1 Storage Read Bytes: Service-specific reads.
        Management Value:
        Detects abnormal storage activity.
        Operational Insight:
        Step change may indicate batch jobs or data processing.
        Purpose:
        Prevents storage bottlenecks and supports scaling decisions.

    Container Instance Count Widget:
        Business Value:
        Tracks the number of ECS container instances, ensuring sufficient capacity for running tasks.
        Architecture:
        Monitors instance count at both cluster and service level.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide instance count.
        🟠 m1 Container Instances: Service-specific instance count.
        Management Value:
        Ensures cluster is scaled appropriately.
        Operational Insight:
        Flat line indicates stable infrastructure.
        Purpose:
        Supports capacity planning and high availability.  

    *Tasks Widget:
        Business Value:
        Shows the number of running tasks for a specific ECS service.
        Architecture:
        Plots running task count over time.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide running tasks.
        🟠 m0 Cluster: Baseline.
        🟢 Service-specific: Individual service task count.
        Management Value:
        Confirms service is running at desired scale.
        Operational Insight:
        Flat line at "2" indicates stable service operation.
        Purpose:
        Ensures service reliability and SLA compliance.  

    *Service Details Widget:
        Business Value:
        Provides a summary of active services in the cluster.
        Architecture:
        Tracks service count at both cluster and service level.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide active services.
        🟢 m1 Active Services: Service-specific count.
        Management Value:
        Confirms all expected services are deployed.
        Operational Insight:
        Flat line at "1" indicates expected service presence.
        Purpose:
        Supports inventory management and compliance.  

Row 4: Resource and Task Analytics  
    Task CPU Analysis Widget:
        Business Value:
        Tracks CPU allocation and usage per ECS service, supporting cost optimization and right-sizing.
        Architecture:
        Plots CPU units allocated and used per service.
        Includes threshold lines for allocated CPU.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide CPU usage.
        🟠 m1 Service: Service-specific CPU allocation and usage.
        Management Value:
        Identifies over-provisioning or under-provisioning of CPU resources.
        Operational Insight:
        Flat line indicates stable CPU usage; threshold lines help spot overages.
        Purpose:
        Prevents resource bottlenecks and unnecessary costs.    
   
    Task Memory Analysis Widget:
        Business Value:
        Monitors memory allocation and usage per ECS service for capacity planning and stability.
        Architecture:
        Plots memory usage and allocation per service.
        Includes threshold lines for allocated memory.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide memory usage.
        🟠 m1 Service: Service-specific memory allocation and usage.
        Management Value:
        Detects memory leaks or underutilization.
        Operational Insight:
        Flat line suggests stable memory usage.
        Purpose:
        Ensures services remain within memory limits, avoiding OOM errors.

    Task Analytics Widget:
        Business Value:
        Shows the number of services and running tasks, providing a quick health snapshot.
        Architecture:
        Compares total services in the cluster with running tasks.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Service count.
        🟠 m0 Total Services in Cluster: Baseline for total services.
        🟢 Service-specific: Running task count.
        Management Value:
        Confirms service deployment matches expectations.
        Operational Insight:
        "1" service, "2" running tasks: healthy deployment.
        Purpose:
        Validates service scaling and deployment status.    

    Resource Efficiency Widget:
        Business Value:
        Measures how efficiently resources (CPU, memory) are used across the cluster.
        Architecture:
        Aggregates resource usage metrics for efficiency analysis.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide resource usage.
        🟠 m1 CPU Efficiency: CPU efficiency metric.
        Management Value:
        Identifies opportunities for optimization.
        Operational Insight:
        Flat line indicates consistent resource usage.
        Purpose:
        Supports cost control and performance tuning.  

Row 5: Multi-Service Task Distribution Widget:
        Business Value:
        Provides a consolidated view of task distribution across all ECS services in the cluster, enabling rapid assessment of service scaling and health.
        Architecture:
        Aggregates running task counts for each service and the cluster as a whole.
        Uses both baseline (cluster) and per-service metrics for comparison.
        Legend Analysis:
        🔵 ECS/ContainerInsights: Cluster-wide running task count.
        🟠 m0 Cluster Total Tasks: Labeled baseline for total running tasks.
        🟢 Service-specific: Individual service task counts.
        Management Value:
        Quickly confirms if all services are running as expected.
        Detects imbalances or scaling anomalies across services.
        Operational Insight:
        The value "2" indicates two tasks are running in the cluster, matching expected service deployment.
        Purpose:
        Ensures all critical services are up and running, supporting SLAs and rapid incident response.  
#############################################################################################
CloudWatch Metrics Notation Deep Dive
Understanding m0, m1, m2, m3 References
The m0, m1, m2, m3 notation represents CloudWatch Dashboard metric identifiers that enable:
    Multiple Metric Correlation: Display related metrics in a single widget
    Baseline Comparisons: Service vs Cluster performance analysis
    Management Intelligence: Service identification and resource context
    Mathematical Calculations: Derive efficiency ratios and per-task metrics    

1. What are m0, m1, m2, ... in CloudWatch Dashboards?

    a. Metric Labels in Terraform
    In your Terraform code, each metric or statistic is paired with a label like m0, m1, m2, etc.
    Example:
    Here, m0 is a metric reference label used by CloudWatch dashboards to identify and display the corresponding metric in the widget legend and graph.    

    b. How CloudWatch Uses These Labels
    When you define a widget (via Terraform or JSON), each metric is assigned a unique ID (m0, m1, ...).
    These IDs are used:
    To reference the metric in the widget’s legend.
    To combine or compare metrics (e.g., for math expressions).
    To display the correct label and color in the dashboard.

    Metric Reference Pattern:
    # Pattern: [MetricDefinition, MetricReference]
    [
      ["Namespace", "MetricName", "DimensionName", "DimensionValue"],  # Raw metric
      ["m1", "Display Label for this metric"]                        # Metric reference
    ]    
   
2. Step-by-Step Meaning of Each Label
    m0
    Usually the Baseline or Cluster-Level Metric
    Example:
    m0 might represent the total running tasks in the cluster or cluster-wide CPU/memory/network usage.
    Purpose:
    Provides a baseline for comparison against service-specific metrics.
    m1, m2, m3, m4, ...
    Service-Specific or Additional Metrics  
   
    Example assignments:
    m1: First service’s metric (e.g., running tasks for service-1).
    m2: Second service’s metric (e.g., running tasks for service-2).
    m3: Third service’s metric, and so on.
    Purpose:
    Allows you to distinguish between metrics for different services or resources within the same widget.
    Each mX is mapped to a specific service or metric dimension.    
   
    How They Appear in the Dashboard?:
        In the widget legend, you’ll see:
        m0: Cluster or baseline metric (e.g., "Cluster Total Tasks")
        m1: Service 1 (e.g., "Service: ecs-monitoring-service-ecs-user | CPU")
        m2: Service 2, etc.
        The color and order are consistent with these labels.
       
3. How to Interpret in Your Dashboard
    m0: Always look for this as your cluster or baseline metric.
    m1, m2, ...: Map these to your ECS services or other resources as per your Terraform code.
    Legend: The legend in each widget will show which metric each label refers to, often including the service name for clarity.        
   
4. Example from Your Code
    [
      ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name],
      ["m0", "Cluster Total Tasks"],
      ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", local.validated_service_names[0]],
      ["m1", "Service: ${local.validated_service_names[0]} | Tasks"],
      ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.ecs_cluster_name, "ServiceName", local.validated_service_names[1]],
      ["m2", "Service: ${local.validated_service_names[1]} | Tasks"]
    ]
   
    m0: Cluster total tasks
    m1: Tasks for first service
    m2: Tasks for second service
   
###########################################################
Dashboard Widget Analysis:
    1. Multi-Service Task Distribution Widget:
        Purpose: Executive-level cross-service task allocation visibility
        multi_service_task_distribution = [
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m1", "Service: ecs-monitoring-service-ecs-user | Tasks"],
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "ecs-monitoring-testing"],
          ["m4", "Cluster: ecs-monitoring-testing | Total Tasks"]
        ]

        Management Intelligence:
            m1: Service-specific task count (Primary metric for service performance)
            m4: Cluster baseline (Total tasks across all services)
            Comparison: Service efficiency = m1/m4 ratio shows service workload distribution

        Widget Shows:
            "2": Your service is running 2 tasks
            "--": Missing metrics for m2, m3 (additional services not configured)


    2. Task CPU Analysis Widget:
        Purpose: Per-task CPU resource efficiency analysis
        task_level_cpu_metrics = [
          ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m1", "ecs-monitoring-service-ecs-user Total Service CPU"],
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m2", "ecs-monitoring-service-ecs-user Running Tasks"],
          ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", "ecs-monitoring-testing"],
          ["m3", "Cluster CPU Baseline"]
        ]
        Management Intelligence:
            m1: Total CPU consumption by your service
            m2: Number of running tasks (for per-task calculation)
            m3: Cluster CPU baseline (for efficiency comparison)
            Per-Task CPU: m1 ÷ m2 = CPU per task
            Efficiency: (m1 ÷ m3) × 100 = Service CPU % of cluster
        Widget Shows:
            CPU Efficiency Target (50): Management threshold for optimal performance
            Allocated (256 units): Your task CPU allocation

    3. Task Memory Analysis Widget:
        Purpose: Per-task memory resource efficiency analysis
        Current Configuration:
        task_level_memory_metrics = [
          ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m1", "ecs-monitoring-service-ecs-user Total Service Memory"],
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m2", "ecs-monitoring-service-ecs-user Running Tasks"],
          ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", "ecs-monitoring-testing"],
          ["m3", "Cluster Memory Baseline"]
        ]
        Management Intelligence:
            m1: Total memory consumption by your service
            m2: Number of running tasks
            m3: Cluster memory baseline
            Per-Task Memory: m1 ÷ m2 = Memory per task
            Efficiency: (m1 ÷ m3) × 100 = Service memory % of cluster
        Widget Shows:
            Memory Efficiency Target (512MB): Management threshold
            Allocated (512MB): Your task memory allocation  

    4. Task Analytics Widget:
        Purpose: Task distribution and scaling activity monitoring
        Current Configuration:
        task_container_analytics_metrics = [
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m1", "ecs-monitoring-service-ecs-user Running Tasks"],
          ["ECS/ContainerInsights", "PendingTaskCount", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m2", "ecs-monitoring-service-ecs-user Pending Tasks"],
          ["ECS/ContainerInsights", "ServiceCount", "ClusterName", "ecs-monitoring-testing"],
          ["m3", "Total Services in Cluster"]
        ]
        Management Intelligence:
            m1: Currently running tasks (2 tasks)
            m2: Pending tasks (0 - no scaling activity)
            m3: Total services in cluster (1 service)
            Scaling Health: m2 = 0 indicates stable service
            Service Density: m1 ÷ m3 = Tasks per service ratio
        Widget Shows:
            "2": 2 running tasks
            "0": 0 pending tasks (healthy scaling)
            "1": 1 service in cluster        
         
    5. Resource Efficiency Widget:
        Purpose: Service resource allocation vs utilization analysis
        Current Configuration:
        service_efficiency_metrics = [
          ["ECS/ContainerInsights", "CpuUtilized", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m1", "Service: ecs-monitoring-service-ecs-user CPU Used"],
          ["ECS/ContainerInsights", "MemoryUtilized", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m2", "Service: ecs-monitoring-service-ecs-user Memory Used"],
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", "ecs-monitoring-testing", "ServiceName", "ecs-monitoring-service-ecs-user"],
          ["m3", "Service: ecs-monitoring-service-ecs-user Tasks (2 target)"]
        ]
        Management Intelligence:
            m1: Actual CPU usage
            m2: Actual memory usage
            m3: Task count (with target reference)
            CPU Efficiency: m1 ÷ (256 × m3) = CPU utilization %
            Memory Efficiency: m2 ÷ (512 × m3) = Memory utilization %
        Widget Shows:
        "267": Resource units (composite metric)        
       
###############################################################################################
Multi-Service Capability Analysis
Current State: Single Service Configuration:
ecs_service_names = ["ecs-monitoring-service-ecs-user"]
Multi-Service Configuration Example:
    ecs_service_names = [
      "ecs-monitoring-service-ecs-user",
      "ecs-web-service",
      "ecs-api-service"
    ]
#########
Management Dashboard Would Show:
    m1: Service 1 tasks (e.g., 2 tasks)
    m2: Service 2 tasks (e.g., 3 tasks)
    m3: Service 3 tasks (e.g., 1 task)
    m4: Total cluster tasks (6 tasks)
    Cross-Service Comparison Metrics:
    Service Load Distribution: m1:m2:m3 ratio
    Cluster Efficiency: (m1+m2+m3) ÷ m4 should equal 1.0
    Service Scaling: Individual service task trends
   
Management Comparison Examples:
    Example 1: Single Service vs Multi-Service
        Single Service Environment:
        Multi-Service Widget:
            m1: 2 tasks (100% of workload)
            m4: 2 tasks (cluster total)
            Ratio: 2:2 = 100% service utilization
        Multi-Service Environment:
        Multi-Service Widget:
            m1: 2 tasks (web service)
            m2: 3 tasks (api service)  
            m3: 1 task (monitoring service)
            m4: 6 tasks (cluster total)
            Ratio: 2:3:1:6 = 33%:50%:17% service distribution    
   
    Example 2: Resource Efficiency Comparison
        CPU Efficiency Analysis:
        Service A: m1 = 150 CPU units, m3 = 2 tasks
            Per-Task CPU: 150 ÷ 2 = 75 CPU units per task
            Efficiency: 75 ÷ 256 = 29% CPU utilization
        Service B: m1 = 200 CPU units, m3 = 1 task  
            Per-Task CPU: 200 ÷ 1 = 200 CPU units per task
            Efficiency: 200 ÷ 256 = 78% CPU utilization
        Management Insight: Service B is more CPU-efficient per task  

    Example 3: Scaling Activity Analysis
        Task Analytics Comparison:
            Service A: m1 = 2 running, m2 = 0 pending (stable)
            Service B: m1 = 1 running, m2 = 2 pending (scaling up)
            Service C: m1 = 3 running, m2 = 0 pending (stable)
        Management Insight: Service B is experiencing scaling activity  

#####################################################################################
# For 1 service: Creates only necessary metrics
m1 = "Service: ecs-monitoring-service-ecs-user | Tasks"

# For 2 services: Creates comparison metrics
m1 = "Service: ecs-monitoring-service-ecs-user | Tasks"
m2 = "Service: ecs-web-service | Tasks"

# For 3 services: Creates full comparison
m1 = "Service: ecs-monitoring-service-ecs-user | Tasks"
m2 = "Service: ecs-web-service | Tasks"  
m3 = "Service: ecs-api-service | Tasks"        