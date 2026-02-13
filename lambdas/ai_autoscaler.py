"""
AI-Powered Autoscaling Lambda
Receives CloudWatch alerts, uses Bedrock to analyze workload patterns,
and executes intelligent scaling decisions for EKS pods.
"""

import json
import boto3
import os
from datetime import datetime, timedelta

# AWS clients
bedrock_runtime = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
cloudwatch = boto3.client('cloudwatch')
eks = boto3.client('eks')
ec2 = boto3.client('ec2')

# Configuration
BEDROCK_MODEL_ID = "amazon.nova-lite-v1:0"
CLUSTER_NAME = os.environ.get('CLUSTER_NAME', 'introspect2-eks')
NAMESPACE = os.environ.get('NAMESPACE', 'default')
DEPLOYMENT_NAME = os.environ.get('DEPLOYMENT_NAME', 'claims-service')
MIN_REPLICAS = int(os.environ.get('MIN_REPLICAS', '2'))
MAX_REPLICAS = int(os.environ.get('MAX_REPLICAS', '10'))

def lambda_handler(event, context):
    """
    Main handler triggered by CloudWatch alarm or EventBridge rule
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Parse CloudWatch alarm data
        alarm_data = parse_cloudwatch_alarm(event)
        
        # Gather workload metrics
        metrics = gather_workload_metrics()
        
        # Use Bedrock AI to analyze and recommend scaling
        scaling_decision = analyze_with_bedrock(alarm_data, metrics)
        
        # Execute scaling action
        result = execute_scaling(scaling_decision)
        
        # Log decision to CloudWatch Logs
        log_scaling_decision(alarm_data, metrics, scaling_decision, result)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'decision': scaling_decision,
                'result': result,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"Error in AI autoscaler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def parse_cloudwatch_alarm(event):
    """
    Extract alarm details from CloudWatch alarm event
    """
    # Handle SNS-wrapped CloudWatch alarm
    if 'Records' in event and len(event['Records']) > 0:
        message = json.loads(event['Records'][0]['Sns']['Message'])
        alarm_name = message.get('AlarmName', 'Unknown')
        new_state = message.get('NewStateValue', 'UNKNOWN')
        reason = message.get('NewStateReason', '')
        metric_name = message.get('Trigger', {}).get('MetricName', '')
        threshold = message.get('Trigger', {}).get('Threshold', 0)
        
        return {
            'alarm_name': alarm_name,
            'state': new_state,
            'reason': reason,
            'metric_name': metric_name,
            'threshold': threshold,
            'timestamp': message.get('StateChangeTime', datetime.utcnow().isoformat())
        }
    
    # Handle direct EventBridge invocation
    return {
        'alarm_name': 'Scheduled',
        'state': 'TRIGGERED',
        'reason': 'Periodic AI analysis',
        'metric_name': 'Scheduled',
        'threshold': 0,
        'timestamp': datetime.utcnow().isoformat()
    }


def gather_workload_metrics():
    """
    Collect comprehensive metrics from CloudWatch for AI analysis
    """
    end_time = datetime.utcnow()
    start_time = end_time - timedelta(minutes=30)
    
    metrics_to_query = [
        # Pod metrics
        {
            'Id': 'cpu_util',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'ContainerInsights',
                    'MetricName': 'pod_cpu_utilization',
                    'Dimensions': [
                        {'Name': 'ClusterName', 'Value': CLUSTER_NAME},
                        {'Name': 'Namespace', 'Value': NAMESPACE}
                    ]
                },
                'Period': 300,
                'Stat': 'Average'
            }
        },
        {
            'Id': 'mem_util',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'ContainerInsights',
                    'MetricName': 'pod_memory_utilization',
                    'Dimensions': [
                        {'Name': 'ClusterName', 'Value': CLUSTER_NAME},
                        {'Name': 'Namespace', 'Value': NAMESPACE}
                    ]
                },
                'Period': 300,
                'Stat': 'Average'
            }
        },
        # API Gateway metrics
        {
            'Id': 'api_requests',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/ApiGateway',
                    'MetricName': 'Count',
                    'Dimensions': [
                        {'Name': 'ApiName', 'Value': 'claims-api'}
                    ]
                },
                'Period': 300,
                'Stat': 'Sum'
            }
        },
        {
            'Id': 'api_latency',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/ApiGateway',
                    'MetricName': 'Latency',
                    'Dimensions': [
                        {'Name': 'ApiName', 'Value': 'claims-api'}
                    ]
                },
                'Period': 300,
                'Stat': 'Average'
            }
        },
        # Lambda metrics
        {
            'Id': 'lambda_invocations',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/Lambda',
                    'MetricName': 'Invocations',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': 'claims-summarizer'}
                    ]
                },
                'Period': 300,
                'Stat': 'Sum'
            }
        },
        {
            'Id': 'lambda_duration',
            'MetricStat': {
                'Metric': {
                    'Namespace': 'AWS/Lambda',
                    'MetricName': 'Duration',
                    'Dimensions': [
                        {'Name': 'FunctionName', 'Value': 'claims-summarizer'}
                    ]
                },
                'Period': 300,
                'Stat': 'Average'
            }
        }
    ]
    
    response = cloudwatch.get_metric_data(
        MetricDataQueries=metrics_to_query,
        StartTime=start_time,
        EndTime=end_time
    )
    
    # Parse results
    metrics = {}
    for result in response['MetricDataResults']:
        metric_id = result['Id']
        values = result.get('Values', [])
        metrics[metric_id] = {
            'current': values[0] if values else 0,
            'average': sum(values) / len(values) if values else 0,
            'max': max(values) if values else 0,
            'min': min(values) if values else 0,
            'trend': calculate_trend(values)
        }
    
    return metrics


def calculate_trend(values):
    """
    Calculate if metric is increasing, decreasing, or stable
    """
    if len(values) < 2:
        return 'stable'
    
    recent_avg = sum(values[:3]) / min(3, len(values))
    older_avg = sum(values[-3:]) / min(3, len(values))
    
    if recent_avg > older_avg * 1.2:
        return 'increasing'
    elif recent_avg < older_avg * 0.8:
        return 'decreasing'
    else:
        return 'stable'


def analyze_with_bedrock(alarm_data, metrics):
    """
    Use Amazon Bedrock to analyze workload and recommend scaling action
    """
    
    # Construct prompt for Bedrock
    prompt = f"""You are an AI system monitoring a Kubernetes deployment for an insurance claims processing API that uses Amazon Bedrock for AI summarization.

CURRENT SITUATION:
- CloudWatch Alarm: {alarm_data['alarm_name']}
- Alarm State: {alarm_data['state']}
- Reason: {alarm_data['reason']}
- Triggered Metric: {alarm_data['metric_name']}
- Threshold: {alarm_data['threshold']}

WORKLOAD METRICS (Last 30 minutes):
- Pod CPU Utilization: Current={metrics.get('cpu_util', {}).get('current', 0):.1f}%, Average={metrics.get('cpu_util', {}).get('average', 0):.1f}%, Trend={metrics.get('cpu_util', {}).get('trend', 'unknown')}
- Pod Memory Utilization: Current={metrics.get('mem_util', {}).get('current', 0):.1f}%, Average={metrics.get('mem_util', {}).get('average', 0):.1f}%, Trend={metrics.get('mem_util', {}).get('trend', 'unknown')}
- API Request Count: Current={metrics.get('api_requests', {}).get('current', 0):.0f}, Average={metrics.get('api_requests', {}).get('average', 0):.0f}, Trend={metrics.get('api_requests', {}).get('trend', 'unknown')}
- API Latency (ms): Current={metrics.get('api_latency', {}).get('current', 0):.0f}, Average={metrics.get('api_latency', {}).get('average', 0):.0f}, Trend={metrics.get('api_latency', {}).get('trend', 'unknown')}
- Lambda Invocations: Current={metrics.get('lambda_invocations', {}).get('current', 0):.0f}, Average={metrics.get('lambda_invocations', {}).get('average', 0):.0f}, Trend={metrics.get('lambda_invocations', {}).get('trend', 'unknown')}
- Lambda Duration (ms): Current={metrics.get('lambda_duration', {}).get('current', 0):.0f}, Average={metrics.get('lambda_duration', {}).get('average', 0):.0f}, Trend={metrics.get('lambda_duration', {}).get('trend', 'unknown')}

SCALING CONSTRAINTS:
- Minimum Replicas: {MIN_REPLICAS}
- Maximum Replicas: {MAX_REPLICAS}
- Current Deployment: claims-service

ANALYSIS REQUIRED:
1. Assess whether scaling is needed based on the metrics and alarm
2. Consider the AI workload characteristics (Bedrock API calls are slow ~2-5 seconds)
3. Account for metric trends (increasing workload needs proactive scaling)
4. Recommend specific action: SCALE_UP, SCALE_DOWN, or NO_ACTION
5. If scaling, recommend target replica count
6. Provide reasoning for your decision

Respond in JSON format:
{{
    "action": "SCALE_UP|SCALE_DOWN|NO_ACTION",
    "target_replicas": <number between {MIN_REPLICAS} and {MAX_REPLICAS}>,
    "confidence": <0.0 to 1.0>,
    "reasoning": "<brief explanation>",
    "urgency": "LOW|MEDIUM|HIGH"
}}

Provide only valid JSON, no additional text."""

    # Call Bedrock
    request_body = {
        "messages": [
            {
                "role": "user",
                "content": prompt
            }
        ],
        "inferenceConfig": {
            "temperature": 0.1,
            "maxTokens": 500
        }
    }
    
    response = bedrock_runtime.converse(
        modelId=BEDROCK_MODEL_ID,
        messages=request_body['messages'],
        inferenceConfig=request_body['inferenceConfig']
    )
    
    # Parse Bedrock response
    bedrock_response = response['output']['message']['content'][0]['text']
    
    # Extract JSON from response (handle markdown wrapping)
    if '```json' in bedrock_response:
        bedrock_response = bedrock_response.split('```json')[1].split('```')[0].strip()
    elif '```' in bedrock_response:
        bedrock_response = bedrock_response.split('```')[1].split('```')[0].strip()
    
    decision = json.loads(bedrock_response)
    
    # Validate and constrain decision
    decision['target_replicas'] = max(MIN_REPLICAS, min(MAX_REPLICAS, decision.get('target_replicas', MIN_REPLICAS)))
    
    return decision


def execute_scaling(decision):
    """
    Execute the scaling decision using kubectl (via EKS API)
    """
    if decision['action'] == 'NO_ACTION':
        return {
            'success': True,
            'message': 'No scaling action required',
            'previous_replicas': get_current_replicas(),
            'new_replicas': get_current_replicas()
        }
    
    current_replicas = get_current_replicas()
    target_replicas = decision['target_replicas']
    
    # Update deployment replicas via kubectl command
    # Note: This requires Lambda to have EKS cluster access
    result = scale_deployment(DEPLOYMENT_NAME, NAMESPACE, target_replicas)
    
    return {
        'success': result['success'],
        'message': result['message'],
        'previous_replicas': current_replicas,
        'new_replicas': target_replicas,
        'action': decision['action'],
        'reasoning': decision['reasoning']
    }


def get_current_replicas():
    """
    Get current replica count (mock - would use kubectl or K8s API)
    """
    # In production, this would query the Kubernetes API
    # For now, return a placeholder
    return 2


def scale_deployment(deployment, namespace, replicas):
    """
    Scale the Kubernetes deployment
    In production, this would use the Kubernetes Python client or kubectl
    """
    print(f"Scaling {namespace}/{deployment} to {replicas} replicas")
    
    # This is a placeholder - actual implementation would use:
    # 1. Kubernetes Python client library
    # 2. kubectl command via subprocess
    # 3. AWS Systems Manager to run kubectl on a bastion host
    
    return {
        'success': True,
        'message': f'Scaled {deployment} to {replicas} replicas'
    }


def log_scaling_decision(alarm_data, metrics, decision, result):
    """
    Log the scaling decision to CloudWatch Logs for audit trail
    """
    log_entry = {
        'timestamp': datetime.utcnow().isoformat(),
        'alarm': alarm_data,
        'metrics': metrics,
        'ai_decision': decision,
        'execution_result': result
    }
    
    print(f"SCALING_DECISION: {json.dumps(log_entry)}")
    
    # Optionally send to CloudWatch Logs Insights
    # This would use cloudwatch_logs.put_log_events()
