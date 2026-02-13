resource "aws_iam_policy" "ci_cloudwatch_logs" {
  name        = "ci-cloudwatch-logs"
  description = "Allow CI/CD to write ECR scan results to CloudWatch Logs"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ci/ecr-scan-results*"
      }
    ]
  })
}
