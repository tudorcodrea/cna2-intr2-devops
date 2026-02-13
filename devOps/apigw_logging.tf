# API Gateway CloudWatch logging setup

resource "aws_iam_role" "apigw_cloudwatch_role" {
  name = "apigw-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "apigw_cloudwatch_policy" {
  name = "apigw-cloudwatch-policy"
  role = aws_iam_role.apigw_cloudwatch_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the AWS managed policy that grants API Gateway permission to push logs
resource "aws_iam_role_policy_attachment" "apigw_cloudwatch_attach" {
  role       = aws_iam_role.apigw_cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "account" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch_role.arn
}

resource "aws_api_gateway_method_settings" "prod_method_settings" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
    throttling_burst_limit = 5000
    throttling_rate_limit  = 10000
  }
}
