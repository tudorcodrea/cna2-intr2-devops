resource "aws_cloudwatch_log_group" "ci_ecr_scan_results" {
  name              = "/ci/ecr-scan-results"
  retention_in_days = 30
}
