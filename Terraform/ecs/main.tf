# Pre-Requisites: ECS Cluster, VPC,Load Balancer, Certificate and Security Group should be created before creating ECS Task and Service
data "aws_region" "current" {}
locals {

  service_container = {
    # Container identification
    name  = var.service_name
    image = var.container_image
    # Resource allocation
    cpu               = var.container_cpu != null ? var.container_cpu : null
    memory            = var.container_memory != null ? var.container_memory : null # hard limit
    memoryReservation = var.container_memory != null ? var.container_memory : null # soft limit
    # Essential flag ensures the task fails if this container fails -
    essential = true

    # Secrets integration for secure credentials management
    secrets = [for item in var.ecs_secrets_vars : { name = item["name"], valueFrom = item["valueFrom"] }]

    # Environment configuration for application behavior
    environment = [for item in var.ecs_environment_vars : { name = item["name"], value = item["value"] }]

    # Network interface configuration
    portMappings = [
      {
        containerPort = var.container_port # port on which application is running in the container
        hostPort      = var.container_port # port on which application is running in the host
        protocol      = "tcp"              # The protocol used for the port mapping.
      }
    ]
    # Observability configuration for log collection
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_task_log_group.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = var.service_name # A prefix for the log stream name
      }
    }
  }
  /**
   * # OpenTelemetry Sidecar Container
   * This optional sidecar container implements the "Sidecar Pattern" for observability.
   */
  otel_sidecar_container = {
    name      = "aws-otel-collector",
    image     = var.otel_image,
    cpu       = var.otel_cpu != null ? var.otel_cpu : null
    memory    = var.otel_memory != null ? var.otel_memory : null
    essential = false,
    # Separate log stream for observability infrastructure
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs_task_log_group.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "${var.service_name}-otel"
      }
    }
  }
  /**
   * # Container Definitions Assembly
   * This dynamically builds the final container definitions based on enabled features.
   */
  container_definitions = concat(
    [local.service_container],
    var.otel_enabled ? [local.otel_sidecar_container] : []
  )

}


/**
* ECS Service
* Maintains desired task count, handles task lifecycle, deployment
* orchestration, and load balancer integration.
*/

resource "aws_ecs_service" "service" {
  name                               = "${var.service_name}-ecs-${var.env}"
  cluster                            = var.ecs_cluster_id
  launch_type                        = "FARGATE"
  task_definition                    = aws_ecs_task_definition.task.arn_without_revision
  scheduling_strategy                = "REPLICA" # The scheduling strategy to use for the service.
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  desired_count                      = var.desired_count # The number of instances of the task definition to place and keep running.
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  depends_on                         = [aws_iam_role.ecs_execution_role, aws_iam_role.ecs_task_role]

  /**
   * # Network Configuration
   * This section defines the network security posture of application.
   * From a security architecture perspective, this controls:
   * - Network segmentation (which subnets the tasks run in)
   * - Network security controls (which security groups apply)
   * - Internet accessibility (whether the task gets a public IP)
   */

  network_configuration {
    #The subnets attribute specifies the subnets in which the ECS tasks will be deployed.
    subnets = var.app_subnets
    #The security_groups attribute specifies the security groups that will be associated with the ECS tasks.Security groups act as virtual firewalls, controlling inbound and outbound traffic to the tasks. By associating security groups, you can enforce network security rules and ensure that only authorized traffic can reach your tasks.
    security_groups = [aws_security_group.ecs_task_sg.id] # The security group that will be associated with the ECS tasks.
    #Tasks that do not need to be directly accessible from the internet. Instead, these tasks can communicate with other resources within the VPC (Virtual Private Cloud) or through a NAT gateway for outbound internet access.
    assign_public_ip = true ###
  }

  ## Configuration block for load balancers, A load balancer can be assigned to route external traffic to service

  # load_balancer {
  #   target_group_arn = aws_alb_target_group.ecs_alb_target_group.arn
  #   container_name   = var.service_name ## container name
  #   container_port   = var.container_port
  # }

  /**
   * # Lifecycle Management
   * - Allowing task count to be managed by autoscaling (ignore_changes)
   * - Ensuring smooth deployments (create_before_destroy)
   * - Preventing Terraform from reverting CI/CD deployments (ignore task_definition)
   */
  lifecycle {
    ignore_changes        = [desired_count, task_definition]
    create_before_destroy = false
  }
  # Resource governance through standardized tagging
  tags = merge(
    { "Name" = "${var.name}-ecs-service-${var.env}"
    },
    var.tags
  )

}

/**
* ECS Task Definition
* Represents the application deployment unit
* It defines the complete runtime environment including:
* - Container composition (application and sidecars)
* - Resource requirements (CPU, memory)
* - Network configuration (network mode)
* - Security posture (IAM roles)
* - Runtime platform (OS, architecture)

*/

resource "aws_ecs_task_definition" "task" {
  track_latest             = true
  family                   = "${var.service_name}-ecs-task-${var.env}"
  requires_compatibilities = ["FARGATE"]

  # Platform selection
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture #"X86_64"  The CPU architecture for the container runtime.
  }

  # Network isolation model
  network_mode = "awsvpc"

  # task size Specify the amount of CPU and memory to reserve for your task.
  cpu    = var.task_cpu
  memory = var.task_memory

  /**
  * Task Execution Role
  * Used by the ECS agent to manage the task lifecycle (e.g., pulling
  * container images from Amazon ECR,storing logs in CloudWatch,
  * or retrieving secrets from AWS Secrets Manager).
  * This role is used by the ECS agent to set up and run the task,
  * not by the containers themselves once running.
  */
  execution_role_arn = aws_iam_role.ecs_execution_role.arn

  /**
 * Task Role
 *
 * Controls runtime permissions for the application running inside
 * containers.
 * This role is assumed by your application at runtime, determining which AWS services
 * your containers can access.
 *
  */
  task_role_arn = aws_iam_role.ecs_task_role.arn


  # Application definition
  container_definitions = jsonencode(local.container_definitions)
  tags = merge(
    { "Name" = "${var.service_name}-ecs-task-${var.env}" },
    var.tags
  )

  # Deployment safety
  lifecycle {
    ignore_changes        = [container_definitions]
    create_before_destroy = true
  }
}

/**
 * # Task Execution Role
 *
 * This role enables the ECS control plane to act on your behalf during task setup.
 * - Controls permissions for container image pulls
 * - Enables writing logs to CloudWatch
 * - Permits access to secrets during container startup
 *
 * This role is used by AWS services (ECS Agent), not by application code.
 */

resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.service_name}-ecs-execution-role-${var.env}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = merge(
    { "Name" = "${var.service_name}-ecs-execution-role-${var.env}" },
    var.tags
  )
}

/**
 * # Task Role
 *
 * This role defines what AWS services , application can access at runtime.
 * - Establishes runtime permission boundaries
 * - Creates service-to-service authentication
 * - Enables secure cloud service integration
 * This role directly impacts application's ability to interact
 * with other services
 */
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.service_name}-ecs-task-role-${var.env}"
  assume_role_policy = jsonencode({
    Version : "2012-10-17"
    Statement : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "ecs-tasks.amazonaws.com"
        },
        Effect : "Allow",
        Sid : ""
      }
    ]
  })

  tags = merge(
    { "Name" = "${var.service_name}-ecs-task-role-${var.env}" },
    var.tags
  )

}

resource "aws_iam_policy" "ecs_execution_policy" {
  name        = "${var.service_name}-ecs-execution-policy-${var.env}"
  description = "IAM policy that grants the necessary permissions for the ECS agent to pull container images from Amazon ECR, send logs to CloudWatch, and send traces to X-Ray on behalf of the task."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"

        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameters"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = var.ecs_secret_manager_arns
      },
      {
        Effect = "Allow",
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ],
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.service_name}-ecs-execution-policy-${var.env}"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy_attachment" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_execution_policy.arn
}


resource "aws_iam_policy" "ecs_task_policy" {
  name        = "${var.service_name}-ecs-task-policy-${var.env}"
  description = "IAM policy that grants the necessary permissions for the ECS task to interact with AWS services."

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [

      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [ # Sending traces to X-Ra
          "xray:PutTelemetryRecords",
          "xray:PutTraceSegments",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",
          "xray:GetSamplingStatisticSummaries",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [ #   Sending metrics to CloudWatch
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [ # Service discovery for comprehensive monitoring
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ec2:DescribeInstances",
          "servicediscovery:ListServices",
          "servicediscovery:ListInstances"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Resource = var.ecs_secret_manager_arns
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ],
        Resource = "*"
      }
    ]
  })

  tags = merge(
    {
      Name = "${var.service_name}-ecs-task-policy-${var.env}"
    },
    var.tags
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# logs for the ECS Task
resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name              = "/ecs/${var.service_name}-ecs-task-log-group-${var.env}"
  retention_in_days = var.retention_days

  tags = {
    Name = "${var.service_name}-ecs-task-log-group-${var.env}"
  }
}

/**
 * # Load Balancer Integration
 *
 * This configuration establishes the connection point between your
 * application and client traffic through the load balancer.
 * - Defines health checking strategy
 * - Controls traffic routing rules
 */
resource "aws_alb_target_group" "ecs_alb_target_group" {
  name_prefix          = var.env
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = var.deregistration_delay

  health_check {
    # health checks should be vars with defaults
    path                = var.health_check_path
    protocol            = var.health_check_protocol
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }
  tags = merge(
    { "Name" = "${var.service_name}-ecs-alb-target-group-${var.env}" },
    var.tags
  )
  lifecycle {
    create_before_destroy = true
  }
}

# load balancer listener
resource "aws_lb_listener_rule" "ecs_alb_listener_rule" {
  count        = length(var.alb_condition)
  listener_arn = var.alb_listener_arn
  priority     = var.alb_priority + count.index

  action {
    # forward to target group
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_alb_target_group.arn
  }

  # much match domain name AND path. APIs should have higher priority and match on something like /api/*
  condition {
    host_header {
      values = var.alb_condition[count.index]["host"]
    }
  }

  condition {
    path_pattern {
      values = var.alb_condition[count.index]["path"]
    }
  }

}

/**
* Security Group
* Controls inbound and outbound traffic to the ECS tasks.
*/

resource "aws_security_group" "ecs_task_sg" {
  name   = "${var.service_name}-ecs-task-sg-${var.env}"
  vpc_id = var.vpc_id # The VPC ID in which the security group will be created.same vpc in which the Load Balancer is created
  # ingress block within a security group resource defines the inbound rules that control the traffic allowed to reach your ECS tasks. This configuration is crucial for ensuring that only authorized traffic can access your tasks, enhancing the security of your application
  ingress {
    description = "Allow traffic from ALB"
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    ##security_groups = [var.alb_security_group_id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  # inbound https traffic (required for ECS Task to get the image from ECR)
  ingress {
    description = "Allow HTTPS traffic "
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  # all outbound traffic allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    { "Name" = "${var.service_name}-ecs-task-sg-${var.env}" },
    var.tags
  )

}