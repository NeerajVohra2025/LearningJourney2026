# CloudWatch Alarm to Microsoft Teams Integration (Plain Text Only)

import json
import urllib.request
import os
from datetime import datetime

# This dictionary helps us show the severity of the alarm in a simple way
SEVERITY_INDICATORS = {
    "CRITICAL": "critical",
    "HIGH": "high",
    "MEDIUM": "medium",
    "LOW": "low",
    "ALARM": "critical",
    "OK": "ok",
    "INSUFFICIENT_DATA": "unknown"
}

# These are the allowed metrics for each service. Only alarms for these will be processed.
ALLOWED_METRICS = {
    "java-core": [
        "jvm.memory.heap.committed",
        "jvm.memory.heap.used",
        "jvm.memory.heap.max",
        "jvm.threads.count"
    ],
    "java-integration": [
        "jvm.memory.heap.committed",
        "jvm.memory.heap.used",
        "jvm.memory.heap.max",
        "jvm.threads.count"
    ],
    "ecs": [
        "CpuUtilized",
        "MemoryUtilized",
        "RunningTaskCount",
        "PendingTaskCount",
        "NetworkRxBytes",
        "NetworkTxBytes",
        "StorageWriteBytes",
        "StorageReadBytes",
        "ServiceCount"
    ],
    "rds": [
        "CPUUtilization",
        "ReadIOPS",
        "WriteIOPS",
        "FreeableMemory",
        "SwapUsage"
    ],
    "rabbitmq": [
        "PublishRate",
        "AckRate",
        "MessageUnacknowledgedCount",
        "MessageCount"
    ]
}

# This dictionary gives more information about each service and its metrics (for Teams message context)
SERVICE_METADATA = {
    "java-core": {
        "icon": "java-core",
        "console_path": "cloudwatch/home#metricsV2:graph=~();search=java-core",
        "common_issues": [
            "High JVM memory usage",
            "Thread pool exhaustion",
            "Garbage collection pauses",
            "Application exceptions"
        ],
        "metric_context": {
            "jvm.memory.heap.committed": "JVM heap memory committed",
            "jvm.memory.heap.used": "JVM heap memory used",
            "jvm.memory.heap.max": "JVM heap memory max",
            "jvm.threads.count": "Number of JVM threads"
        }
    },
    "java-integration": {
        "icon": "java-integration",
        "console_path": "cloudwatch/home#metricsV2:graph=~();search=java-integration",
        "common_issues": [
            "Integration endpoint failures",
            "Timeouts in external calls",
            "High latency in integration flows"
        ],
        "metric_context": {
            "jvm.memory.heap.max": "JVM heap memory max",
            "jvm.memory.heap.used": "JVM heap memory used",
            "jvm.threads.count": "Number of JVM threads"
        }
    },
    "ecs": {
        "icon": "ecs",
        "console_path": "ecs/home#/clusters/",
        "common_issues": [
            "Container health check failure",
            "Task definition resource limits",
            "Image pull failures or registry issues",
            "Service auto-scaling misconfiguration",
            "Container exit due to OOM (out of memory)",
            "Service deployment failures"
        ],
        "metric_context": {
            "CpuUtilized": "Container CPU usage percentage",
            "MemoryUtilized": "Container memory usage percentage",
            "RunningTaskCount": "Number of active tasks",
            "PendingTaskCount": "Tasks waiting to be placed",
            "NetworkRxBytes": "Network received bytes",
            "NetworkTxBytes": "Network transmitted bytes",
            "StorageWriteBytes": "Storage write bytes",
            "StorageReadBytes": "Storage read bytes",
            "ServiceCount": "Number of services"
        }
    },
    "rds": {
        "icon": "rds",
        "console_path": "rds/home#databases:",
        "common_issues": [
            "High CPU utilization due to inefficient queries",
            "Insufficient storage space",
            "Connection pool exhaustion",
            "Read replica lag",
            "Slow query performance"
        ],
        "metric_context": {
            "CPUUtilization": "Database instance CPU usage",
            "FreeableMemory": "Available memory for database",
            "ReadIOPS": "Read operations per second",
            "WriteIOPS": "Write operations per second",
            "SwapUsage": "Swap memory usage"
        }
    },
    "rabbitmq": {
        "icon": "rabbitmq",
        "console_path": "amazon-mq/home#/brokers/details?id=",
        "common_issues": [
            "High CPU/memory utilization",
            "Broker connectivity issues",
            "Queue depth accumulation",
            "Dead-letter queue messages",
            "Consumer application failures"
        ],
        "metric_context": {
            "PublishRate": "Messages published per second",
            "AckRate": "Messages acknowledged per second",
            "MessageUnacknowledgedCount": "Unacknowledged messages",
            "MessageCount": "Total messages"
        }
    }
}

# This function helps us get a simple icon or label for the service or severity
def get_indicator(service=None, severity=None):
    if severity:
        return SEVERITY_INDICATORS.get(severity, "notice")
    if service:
        meta = SERVICE_METADATA.get(service, {})
        return meta.get('icon', 'cloud')
    return 'cloud'

# This function figures out which service the alarm is about
def detect_service(alarm_name, alarm_details):
    trigger = alarm_details.get('Trigger', {})
    namespace = trigger.get('Namespace', '')
    metric_name = trigger.get('MetricName', '')
    dimensions = trigger.get('Dimensions', [])

    # For Java alarms, check for integration or core
    if namespace == "JVM":
        for d in dimensions:
            val = (d.get("name", "") + d.get("value", "")).lower()
            if "integration" in val:
                return "java-integration"
        if "integration" in alarm_name.lower():
            return "java-integration"
        if metric_name == "jvm.memory.heap.max":
            return "java-integration"
        return "java-core"

    # For ECS, RDS, RabbitMQ, check the namespace
    if namespace == "ECS/ContainerInsights":
        return "ecs"
    if namespace == "AWS/RDS":
        return "rds"
    if namespace == "AWS/AmazonMQ":
        return "rabbitmq"

    # If not found, try to guess from the alarm name
    name = alarm_name.lower()
    if "ecs" in name or "container" in name:
        return "ecs"
    if "rds" in name or "database" in name:
        return "rds"
    if "rabbit" in name or "mq" in name:
        return "rabbitmq"
    if "integration" in name:
        return "java-integration"
    if "core" in name:
        return "java-core"

    return None

# This function gives a simple recommended action for each alarm
def get_recommended_action(service, metric_name, state, alarm_details=None):
    if state == "OK":
        return "No action required - the issue has resolved"
    service_actions = {
        "java-core": {
            "jvm.memory.heap.committed": "Check for memory leaks or increase JVM heap allocation.",
            "jvm.memory.heap.used": "Investigate memory usage patterns and optimize application memory handling.",
            "jvm.threads.count": "Review thread pool configuration and look for thread leaks.",
            "default": "Review JVM logs and application performance."
        },
        "java-integration": {
            "jvm.memory.heap.max": "Increase JVM heap max size or optimize memory usage in integration flows.",
            "jvm.memory.heap.used": "Investigate memory usage and optimize integration logic.",
            "jvm.threads.count": "Check for excessive thread creation in integration endpoints.",
            "default": "Review JVM and integration logs for bottlenecks."
        },
        "ecs": {
            "CpuUtilized": "Check for CPU-intensive processes, review task CPU allocation, and consider scaling up if consistently high.",
            "MemoryUtilized": "Investigate memory leaks, review task/container memory limits, and consider scaling up if needed.",
            "RunningTaskCount": "Verify service deployment health, check for task crash loops, and ensure desired count matches running count.",
            "PendingTaskCount": "Check for resource constraints, subnet IP exhaustion, or placement constraints preventing task placement.",
            "NetworkRxBytes": "Investigate high inbound network traffic, check for DDoS or misconfigured clients.",
            "NetworkTxBytes": "Investigate high outbound network traffic, check for data exfiltration or misconfigured services.",
            "StorageWriteBytes": "Review application logs for excessive writes, check for log file growth or data export jobs.",
            "StorageReadBytes": "Review application logs for excessive reads, check for data import jobs or inefficient queries.",
            "ServiceCount": "Check ECS service scaling events and ensure expected services are running.",
            "default": "Review ECS service events, task definitions, and container logs for errors."
        },
        "rds": {
            "CPUUtilization": "Identify resource-intensive queries using Performance Insights and optimize or scale instance.",
            "FreeableMemory": "Check for connection leaks or increase instance size for more memory.",
            "ReadIOPS": "Monitor read throughput and optimize queries.",
            "WriteIOPS": "Monitor write throughput and optimize queries.",
            "SwapUsage": "Investigate swap usage and increase memory if needed.",
            "default": "Review Performance Insights, slow query logs, and recent database activities."
        },
        "rabbitmq": {
            "PublishRate": "Check publisher application health and broker throughput.",
            "AckRate": "Check consumer application health and broker throughput.",
            "MessageUnacknowledgedCount": "Investigate slow consumers or network issues.",
            "MessageCount": "Monitor queue depth and scale consumers if needed.",
            "default": "Check broker logs, review producer/consumer application logs, and verify network connectivity."
        }
    }
    if service in service_actions:
        action = service_actions[service].get(metric_name, service_actions[service].get("default", ""))
        if action:
            return action
    return "Investigate the alarm using CloudWatch logs and metrics"

# This function gathers details about the metric that triggered the alarm
def extract_metric_info(alarm_details, service):
    metric_info = []
    try:
        trigger = alarm_details.get('Trigger', {})
        metric_name = trigger.get('MetricName', '')
        if metric_name:
            service_metrics = SERVICE_METADATA.get(service, {}).get('metric_context', {})
            metric_description = service_metrics.get(metric_name, metric_name.replace('_', ' '))
            metric_info.append({
                "name": metric_name,
                "description": metric_description
            })
            if 'Threshold' in trigger:
                comparison = trigger.get('ComparisonOperator', '')
                comparison = (comparison
                    .replace('GreaterThanOrEqualToThreshold', '>=')
                    .replace('GreaterThanThreshold', '>')
                    .replace('LessThanOrEqualToThreshold', '<=')
                    .replace('LessThanThreshold', '<')
                    .replace('EqualToThreshold', '=')
                )
                metric_info.append({
                    "name": "Threshold",
                    "value": f"{comparison} {trigger.get('Threshold')}"
                })
            if 'EvaluationPeriods' in trigger:
                period_seconds = trigger.get('Period', 60)
                periods = trigger.get('EvaluationPeriods', 1)
                minutes = (period_seconds * periods) / 60
                metric_info.append({
                    "name": "Evaluation",
                    "value": f"{periods} periods of {period_seconds}s ({minutes} min)"
                })
            dimensions = trigger.get('Dimensions', [])
            if dimensions:
                dim_str = ", ".join([f"{d.get('name', d.get('Name', ''))}={d.get('value', d.get('Value', ''))}" for d in dimensions])
                metric_info.append({
                    "name": "Dimensions",
                    "value": dim_str
                })
            if 'Namespace' in trigger:
                metric_info.append({
                    "name": "Namespace",
                    "value": trigger.get('Namespace')
                })
    except Exception as e:
        print(f"WARNING: Failed to extract metric info: {str(e)}")
    return metric_info

# This function converts the message card (structured data) into a plain text message
def adaptive_card_to_text(message_card):
    lines = []
    try:
        attachments = message_card.get("attachments", [])
        for att in attachments:
            content = att.get("content", {})
            body = content.get("body", [])
            for block in body:
                if block.get("type") == "TextBlock":
                    text = block.get("text", "")
                    # Remove markdown for plain text
                    text = text.replace("**", "").replace("[", "").replace("]", "")
                    lines.append(text)
                elif block.get("type") == "FactSet":
                    for fact in block.get("facts", []):
                        title = fact.get("title", "")
                        value = fact.get("value", "")
                        lines.append(f"{title}: {value}")
        # Add action links at the end
        for att in attachments:
            actions = att.get("content", {}).get("actions", [])
            for action in actions:
                if action.get("type") == "Action.OpenUrl":
                    lines.append(f"{action.get('title')}: {action.get('url')}")
    except Exception as e:
        lines.append(f"[Error parsing card: {e}]")
    return "\n".join(lines)

# This is the main function that AWS Lambda will run
def lambda_handler(event, context):
    # Get the Teams webhook URL from environment variables
    teams_workflow_url = os.environ['TEAMS_WORKFLOW_URL']
    print("INFO: Teams notification workflow started")
    for record in event['Records']:
        print("DEBUG: Processing SNS message")
        try:
            sns_message = json.loads(record['Sns']['Message'])
            alarm_name = sns_message.get('AlarmName', 'Unknown Alarm')
            new_state = sns_message.get('NewStateValue', 'UNKNOWN')
            reason = sns_message.get('NewStateReason', 'No reason provided')
            timestamp = sns_message.get('StateChangeTime', '')
            region = sns_message.get('Region', 'us-east-1')
            # Format the timestamp for readability
            try:
                dt = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%S.%f%z")
                timestamp = dt.strftime("%Y-%m-%d %H:%M:%S UTC")
            except:
                try:
                    dt = datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%S%z")
                    timestamp = dt.strftime("%Y-%m-%d %H:%M:%S UTC")
                except:
                    pass
            # Figure out which service this alarm is about
            service = detect_service(alarm_name, sns_message)
            if service not in SERVICE_METADATA or service not in ALLOWED_METRICS:
                print(f"SKIP: Service {service} not recognized or not allowed")
                continue
            # Get metric details
            metric_info = extract_metric_info(sns_message, service)
            metric_name = metric_info[0].get('name') if metric_info else ''
            if metric_name not in ALLOWED_METRICS[service]:
                print(f"SKIP: Metric {metric_name} not allowed for service {service}")
                continue
            service_metadata = SERVICE_METADATA[service]
            service_icon = get_indicator(service=service)
            severity = "CRITICAL" if new_state == "ALARM" else "OK" if new_state == "OK" else "INSUFFICIENT_DATA"
            state_indicator = get_indicator(severity=severity)
            recommended_action = get_recommended_action(service, metric_name, new_state, sns_message)
            common_issues = service_metadata.get('common_issues', [])
            base_console_url = f"https://{region}.console.aws.amazon.com/"
            service_console_path = service_metadata.get('console_path', 'cloudwatch/home#alarmsV2:alarm/')
            resource_name = ""
            console_url = f"{base_console_url}{service_console_path}{resource_name}"
            cloudwatch_url = f"https://{region}.console.aws.amazon.com/cloudwatch/home?region={region}#alarmsV2:alarm/{alarm_name}"
            # Build a structured message (card) for conversion to plain text
            message_card = {
                "attachments": [
                    {
                        "contentType": "application/vnd.microsoft.card.adaptive",
                        "content": {
                            "type": "AdaptiveCard",
                            "version": "1.4",
                            "body": [
                                {
                                    "type": "TextBlock",
                                    "text": f"[{state_indicator}] [{service_icon}] **{service.upper()} ALARM: {severity}**",
                                    "weight": "Bolder",
                                    "size": "Medium",
                                    "color": "attention" if severity in ["CRITICAL", "HIGH", "ALARM"] else "default"
                                },
                                {
                                    "type": "TextBlock",
                                    "text": alarm_name,
                                    "weight": "Bolder",
                                    "wrap": True
                                },
                                {
                                    "type": "FactSet",
                                    "facts": [
                                        {"title": "Status", "value": f"[{state_indicator}] {new_state}"},
                                        {"title": "Region", "value": region},
                                        {"title": "Time", "value": timestamp},
                                        {"title": "Service", "value": f"[{service_icon}] {service.upper()}"}
                                    ]
                                }
                            ]
                        }
                    }
                ]
            }
            # Add metric details if available
            if metric_info:
                metric_facts = {
                    "type": "FactSet",
                    "facts": []
                }
                for info in metric_info:
                    if "name" in info and ("description" in info or "value" in info):
                        metric_facts["facts"].append({
                            "title": info["name"],
                            "value": info.get("value", info.get("description", ""))
                        })
                if metric_facts["facts"]:
                    message_card["attachments"][0]["content"]["body"].append({
                        "type": "TextBlock",
                        "text": "**Metric Details:**",
                        "weight": "Bolder"
                    })
                    message_card["attachments"][0]["content"]["body"].append(metric_facts)
            # Add the reason for the alarm
            message_card["attachments"][0]["content"]["body"].append({
                "type": "TextBlock",
                "text": "**Alarm Reason:**",
                "weight": "Bolder"
            })
            message_card["attachments"][0]["content"]["body"].append({
                "type": "TextBlock",
                "text": reason,
                "wrap": True,
                "isSubtle": False
            })
            # Add recommended action if alarm is active
            if new_state == "ALARM":
                message_card["attachments"][0]["content"]["body"].append({
                    "type": "TextBlock",
                    "text": "**Recommended Action:**",
                    "weight": "Bolder"
                })
                message_card["attachments"][0]["content"]["body"].append({
                    "type": "TextBlock",
                    "text": recommended_action,
                    "wrap": True,
                    "isSubtle": False
                })
                # Add common issues for this service
                if common_issues:
                    message_card["attachments"][0]["content"]["body"].append({
                        "type": "TextBlock",
                        "text": "**Common Issues to Check:**",
                        "weight": "Bolder",
                        "size": "Small"
                    })
                    issues_text = "• " + "\n• ".join(common_issues)
                    message_card["attachments"][0]["content"]["body"].append({
                        "type": "TextBlock",
                        "text": issues_text,
                        "wrap": True,
                        "isSubtle": True,
                        "size": "Small"
                    })
            # Add a reference for tracking
            message_card["attachments"][0]["content"]["body"].append({
                "type": "TextBlock",
                "text": f"Incident tracking reference: {context.aws_request_id}",
                "wrap": True,
                "isSubtle": True,
                "size": "Small"
            })
            # Add helpful links
            message_card["attachments"][0]["content"]["actions"] = [
                {
                    "type": "Action.OpenUrl",
                    "title": "View in CloudWatch",
                    "url": cloudwatch_url
                },
                {
                    "type": "Action.OpenUrl",
                    "title": f"View {service.upper()} Console",
                    "url": console_url
                }
            ]
            # Convert the structured message to plain text
            plain_text = adaptive_card_to_text(message_card)
            teams_text_payload = {
                "text": plain_text
            }
            # Step 1: Try sending plain text first
            try:
                req = urllib.request.Request(
                    teams_workflow_url,
                    data=json.dumps(teams_text_payload).encode('utf-8'),
                    headers={'Content-Type': 'application/json'}
                )
                with urllib.request.urlopen(req) as response:
                    resp_body = response.read().decode()
                    print(f"INFO: Teams plain text notification delivered. Status: {response.status}")
                    print(f"Teams response: {resp_body}")
                    # If Teams returns 200 or 201, consider it successful and skip sending card
                    if response.status in (200, 201):
                        continue
            except Exception as e:
                print(f"WARNING: Plain text send failed, falling back to card. Error: {e}")

            # Step 2: Fallback - Try sending the Adaptive Card if plain text fails
            try:
                req = urllib.request.Request(
                    teams_workflow_url,
                    data=json.dumps(message_card).encode('utf-8'),
                    headers={'Content-Type': 'application/json'}
                )
                with urllib.request.urlopen(req) as response:
                    resp_body = response.read().decode()
                    print(f"INFO: Teams card notification delivered. Status: {response.status}")
                    print(f"Teams response: {resp_body}")
            except Exception as e:
                print(f"ERROR: Both plain text and card notification failed: {e}")
        except Exception as e:
            print(e)
    print(f"INFO: Completed processing {len(event['Records'])} alarm notifications")
    return {
        'statusCode': 200,
        'body': f'Processed {len(event['Records'])} alarm notifications'
    }