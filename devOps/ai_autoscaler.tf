# Lambda function for AI-powered autoscaling
resource "aws_lambda_function" "ai_autoscaler" {
  filename         = "${path.module}/../lambdas/ai_autoscaler.zip"
  function_name    = "${var.cluster_name}-ai-autoscaler"
  role            = aws_iam_role.ai_autoscaler_role.arn
  handler         = "ai_autoscaler.lambda_handler"
  source_code_hash = filebase64sha256("${path.module}/../lambdas/ai_autoscaler.zip")
  runtime         = "python3.12"
  timeout         = 60
  memory_size     = 512

  environment {
    variables = {
      CLUSTER_NAME     = var.cluster_name
      NAMESPACE        = "default"
      DEPLOYMENT_NAME  = "claims-service"
      MIN_REPLICAS     = "2"
      MAX_REPLICAS     = "10"
      AWS_REGION       = var.aws_region
    }
  }

  tags = {
    Name        = "${var.cluster_name}-ai-autoscaler"
    Environment = "production"
  }
}

# IAM role for AI autoscaler Lambda
resource "aws_iam_role" "ai_autoscaler_role" {
  name = "${var.cluster_name}-ai-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# IAM policy for AI autoscaler
resource "aws_iam_role_policy" "ai_autoscaler_policy" {
  name = "${var.cluster_name}-ai-autoscaler-policy"
  role = aws_iam_role.ai_autoscaler_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Bedrock access
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/amazon.nova-lite-v1:0"
      },
      # CloudWatch metrics access
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      # EKS cluster access
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      },
      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      # SNS (for publishing scaling events)
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.autoscaling_notifications.arn
      }
    ]
  })
}

# CloudWatch Log Group for AI autoscaler
resource "aws_cloudwatch_log_group" "ai_autoscaler_logs" {
  name              = "/aws/lambda/${var.cluster_name}-ai-autoscaler"
  retention_in_days = 7
}

# SNS topic for autoscaling notifications
resource "aws_sns_topic" "autoscaling_notifications" {
  name = "${var.cluster_name}-autoscaling-notifications"
}

# SNS topic for CloudWatch alarms to trigger AI autoscaler
resource "aws_sns_topic" "autoscaling_triggers" {
  name = "${var.cluster_name}-autoscaling-triggers"
}

# Subscribe Lambda to SNS topic
resource "aws_sns_topic_subscription" "ai_autoscaler_subscription" {
  topic_arn = aws_sns_topic.autoscaling_triggers.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ai_autoscaler.arn
}

# Lambda permission to allow SNS invocation
resource "aws_lambda_permission" "allow_sns_invocation" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_autoscaler.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.autoscaling_triggers.arn
}

# EventBridge rule for periodic AI analysis (every 5 minutes)
resource "aws_cloudwatch_event_rule" "ai_autoscaler_periodic" {
  name                = "${var.cluster_name}-ai-autoscaler-periodic"
  description         = "Trigger AI autoscaler every 5 minutes for proactive analysis"
  schedule_expression = "rate(5 minutes)"
}

# EventBridge target to invoke Lambda
resource "aws_cloudwatch_event_target" "ai_autoscaler_periodic_target" {
  rule      = aws_cloudwatch_event_rule.ai_autoscaler_periodic.name
  target_id = "ai-autoscaler-lambda"
  arn       = aws_lambda_function.ai_autoscaler.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge_invocation" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ai_autoscaler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ai_autoscaler_periodic.arn
}

# Update existing CloudWatch alarms to publish to autoscaling triggers SNS
# High CPU Alarm - triggers AI autoscaler
resource "aws_cloudwatch_metric_alarm" "pod_high_cpu_ai" {
  alarm_name          = "${var.cluster_name}-pod-high-cpu-ai-trigger"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "Triggers AI autoscaler when pod CPU > 70%"
  alarm_actions       = [aws_sns_topic.autoscaling_triggers.arn]

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = "default"
  }
}

# High Memory Alarm - triggers AI autoscaler
resource "aws_cloudwatch_metric_alarm" "pod_high_memory_ai" {
  alarm_name          = "${var.cluster_name}-pod-high-memory-ai-trigger"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "pod_memory_utilization"
  namespace           = "ContainerInsights"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Triggers AI autoscaler when pod memory > 80%"
  alarm_actions       = [aws_sns_topic.autoscaling_triggers.arn]

  dimensions = {
    ClusterName = var.cluster_name
    Namespace   = "default"
  }
}

# High API Latency Alarm - triggers AI autoscaler
resource "aws_cloudwatch_metric_alarm" "api_high_latency_ai" {
  alarm_name          = "${var.cluster_name}-api-high-latency-ai-trigger"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  extended_statistic  = "p95"
  threshold           = "3000"
  alarm_description   = "Triggers AI autoscaler when API p95 latency > 3s"
  alarm_actions       = [aws_sns_topic.autoscaling_triggers.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.claims_api.name
  }
}

# CloudWatch Logs Insights query to analyze AI autoscaling decisions
resource "aws_cloudwatch_query_definition" "ai_scaling_decisions" {
  name = "${var.cluster_name}/ai-autoscaling-decisions"

  log_group_names = [
    aws_cloudwatch_log_group.ai_autoscaler_logs.name
  ]

  query_string = <<-QUERY
    fields @timestamp, ai_decision.action, ai_decision.target_replicas, ai_decision.confidence, ai_decision.reasoning
    | filter @message like /SCALING_DECISION/
    | parse @message "SCALING_DECISION: *" as decision_json
    | stats count() by ai_decision.action
    | sort @timestamp desc
  QUERY
}
