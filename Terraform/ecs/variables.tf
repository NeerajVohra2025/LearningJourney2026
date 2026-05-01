variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "name" {
  description = "name of the application"
  type        = string
}


variable "env" {
  description = "The environment for the application"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

variable "ecs_cluster_id" {
  description = "ECS Cluster Id"
  type        = string
}


variable "service_name" {
  description = "Service Name"
  type        = string
}

#Number of cpu units used by the task. If the requires_compatibilities is FARGATE this field is required.
variable "task_cpu" {
  description = "Number of cpu units used by the task"
  type        = number
  default     = 256
}

#Amount (in MiB) of memory used by the task. If the requires_compatibilities is FARGATE this field is required.
variable "task_memory" {
  description = "Amount (in MiB) of memory used by the task"
  type        = number
  default     = 512
}

# container name
variable "container_name" {
  description = "Container Name"
  type        = string

}
# container Image URI
variable "container_image" {
  description = "Container Image"
  type        = string
}

# container port
variable "container_port" {
  description = "Container Port"
  type        = number
}

# container cpu
variable "container_cpu" {
  description = "Container Cpu"
  type        = number
  default     = null
}

# container memory
variable "container_memory" {
  description = "Container Memory"
  type        = number
  default     = null
}

variable "alb_listener_arn" {
  description = "Application Load Balancer ARN"
  type        = string
}

variable "alb_priority" {
  description = "Priority Of Application Load Balancer"
  type        = number
}

variable "alb_condition" {
  description = "host and path conditions"
  type        = list(map(list(string)))
  default     = []
}

variable "alb_security_group_id" {
  description = "Application Load Balancer security group"
  type        = string
}

variable "vpc_security_group_id" {
  description = "VPC security group"
  type        = string
}

variable "app_subnets" {
  description = "Application Subnets"
  type        = list(string)
}

variable "ecs_environment_vars" {
  description = "environment variable needed by the application"
  type        = list(map(string))
  default     = []
}


variable "ecs_secrets_vars" {
  description = "secret variable needed by the application"
  type        = list(map(string))
  default     = []
}

variable "ecs_secret_manager_arns" {
  description = "secret manager arn needed by the secret policy"
  type        = list(string)
  default     = []
}


variable "deployment_minimum_healthy_percent" {
  description = "deployment minimum healthy percent"
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "deployment maximum percent"
  type        = number
  default     = 200
}


variable "desired_count" {
  description = "Desired Count"
  type        = number
  default     = 1
}

variable "deregistration_delay" {
  description = "The amount of time for Elastic Load Balancing to wait before changing the state of a deregistering target from draining to unused."
  type        = number
  default     = 60
}

variable "health_check_grace_period_seconds" {
  description = "health check grace period seconds"
  type        = number
  default     = 60
}


variable "health_check_path" {
  description = "health check path"
  type        = string
  default     = "/"
}

variable "health_check_protocol" {
  description = "health check protocol"
  type        = string
  default     = "HTTP"
}

variable "health_check_matcher" {
  description = "health check matcher"
  type        = string
  default     = "200"
}

variable "health_check_interval" {
  description = "health check interval"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "health check timeout"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "healthy threshold"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "unhealthy threshold"
  type        = number
  default     = 2
}


variable "cpu_architecture" {
  description = "cpu_architecture"
  type        = string
  default     = "X86_64"
}

variable "otel_enabled" {
  description = "AWS OTEL Collector sidecar"
  type        = bool
  default     = true
}

variable "otel_cpu" {
  description = "Relative Number of cpu units used by the sidecar"
  type        = number
  default     = null
}

variable "otel_memory" {
  description = "Relative Amount (in MiB) of memory used by the sidecar"
  type        = number
  default     = null
}

variable "otel_image" {
  description = "value of the image to use for the OpenTelemetry Collector"
  type        = string

}

variable "retention_days" {
  description = "retention in days for the log group"
  type        = number
  default     = 30
}