# CloudWatch Monitoring and Observability

# CloudWatch Dashboard for Claims Service
resource "aws_cloudwatch_dashboard" "claims_service_dashboard" {
  dashboard_name = "${var.cluster_name}-claims-service-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # API Gateway Metrics
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.claims_api.name, { "stat" : "p50", "label" : "API Latency p50" }],
            [".", ".", ".", ".", { "stat" : "p95", "label" : "API Latency p95" }],
            [".", ".", ".", ".", { "stat" : "p99", "label" : "API Latency p99" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Latency"
          period  = 300
        }
      },

      # Error Rates by Endpoint
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.claims_api.name, "Method", "GET", { "label" : "GET Errors" }],
            [".", "4XXError", ".", ".", ".", "GET", { "label" : "GET 4XX Errors" }],
            [".", "5XXError", ".", ".", ".", "POST", { "label" : "POST Errors" }],
            [".", "4XXError", ".", ".", ".", "POST", { "label" : "POST 4XX Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "API Gateway Error Rates by Endpoint"
          period  = 300
        }
      },

      # Lambda Metrics
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.claims_summarizer.function_name, { "stat" : "Average", "label" : "Summarizer Duration" }],
            [".", "Errors", ".", ".", { "stat" : "Sum", "label" : "Summarizer Errors" }],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.claim_generate_files.function_name, { "stat" : "Average", "label" : "Generator Duration" }],
            [".", "Errors", ".", ".", { "stat" : "Sum", "label" : "Generator Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Lambda Function Performance"
          period  = 300
        }
      },

      # DynamoDB Metrics
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", aws_dynamodb_table.claims.name, { "stat" : "Average", "label" : "Read Latency" }],
            [".", "ThrottledRequests", ".", ".", { "stat" : "Sum", "label" : "Throttled Requests" }],
            [".", "SystemErrors", ".", ".", { "stat" : "Sum", "label" : "System Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "DynamoDB Performance"
          period  = 300
        }
      },

      # S3 Metrics
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/S3", "AllRequests", "BucketName", aws_s3_bucket.claims_notes.bucket, "FilterId", "EntireBucket", { "label" : "Total Requests" }],
            [".", "4xxErrors", ".", ".", ".", ".", { "label" : "4XX Errors" }],
            [".", "5xxErrors", ".", ".", ".", ".", { "label" : "5XX Errors" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "S3 Bucket Metrics"
          period  = 300
        }
      },

      # Bedrock Usage (if available)
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          query = "SOURCE '/aws/lambda/claims-summarizer-lambda' | fields @timestamp, @message | filter @message like /Bedrock/ or @message like /bedrock/ | sort @timestamp desc | limit 100"
          region = var.aws_region
          title  = "Bedrock API Usage Logs"
        }
      },

      # Application Logs
      {
        type   = "log"
        x      = 0
        y      = 18
        width  = 24
        height = 6

        properties = {
          query = "SOURCE '/aws/containerinsights/${var.cluster_name}/application' | fields @timestamp, @message, kubernetes.pod_name, kubernetes.container_name | filter kubernetes.container_name = 'claims-service' | sort @timestamp desc | limit 100"
          region = var.aws_region
          title  = "Application Logs (Last 100 entries)"
        }
      }
    ]
  })
}

# CloudWatch Alarms

# API Gateway 5XX Errors Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "${var.cluster_name}-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors API Gateway 5XX errors"
  alarm_actions       = []

  dimensions = {
    ApiName = aws_api_gateway_rest_api.claims_api.name
  }
}

# Lambda Errors Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.cluster_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "3"
  alarm_description   = "This metric monitors Lambda function errors"
  alarm_actions       = []

  dimensions = {
    FunctionName = aws_lambda_function.claims_summarizer.function_name
  }
}

# High Latency Alarm
resource "aws_cloudwatch_metric_alarm" "api_gateway_high_latency" {
  alarm_name          = "${var.cluster_name}-api-gateway-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  extended_statistic  = "p95"
  threshold           = "5000"
  alarm_description   = "This metric monitors API Gateway p95 latency > 5 seconds"
  alarm_actions       = []

  dimensions = {
    ApiName = aws_api_gateway_rest_api.claims_api.name
  }
}

# DynamoDB Throttling Alarm
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttling" {
  alarm_name          = "${var.cluster_name}-dynamodb-throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors DynamoDB throttling events"
  alarm_actions       = []

  dimensions = {
    TableName = aws_dynamodb_table.claims.name
  }
}

# CloudWatch Log Groups for structured logging
resource "aws_cloudwatch_log_group" "claims_service_logs" {
  name              = "/aws/eks/${var.cluster_name}/claims-service"
  retention_in_days = 30

  tags = {
    Name        = "${var.cluster_name}-claims-service-logs"
    Environment = "dev"
    Project     = var.cluster_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_summarizer_logs" {
  name              = "/aws/lambda/claims-summarizer-lambda"
  retention_in_days = 30

  tags = {
    Name        = "${var.cluster_name}-lambda-summarizer-logs"
    Environment = "dev"
    Project     = var.cluster_name
  }
}

resource "aws_cloudwatch_log_group" "lambda_generator_logs" {
  name              = "/aws/lambda/claim_generate_files"
  retention_in_days = 30

  tags = {
    Name        = "${var.cluster_name}-lambda-generator-logs"
    Environment = "dev"
    Project     = var.cluster_name
  }
}

# CloudWatch Log Metric Filters for custom metrics
resource "aws_cloudwatch_log_metric_filter" "api_errors" {
  name           = "${var.cluster_name}-api-errors"
  pattern        = "{ $.level = \"ERROR\" }"
  log_group_name = aws_cloudwatch_log_group.claims_service_logs.name

  metric_transformation {
    name      = "APIErrorCount"
    namespace = "ClaimsService"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "lambda_invocations" {
  name           = "${var.cluster_name}-lambda-invocations"
  pattern        = "[time, request_id, level, msg=\"Invoking*Lambda*\"]"
  log_group_name = aws_cloudwatch_log_group.claims_service_logs.name

  metric_transformation {
    name      = "LambdaInvocations"
    namespace = "ClaimsService"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "bedrock_usage" {
  name           = "${var.cluster_name}-bedrock-api-calls"
  pattern        = "[time, request_id, level, msg=\"*Bedrock*\"]"
  log_group_name = aws_cloudwatch_log_group.lambda_summarizer_logs.name

  metric_transformation {
    name      = "BedrockAPICalls"
    namespace = "ClaimsService"
    value     = "1"
  }
}