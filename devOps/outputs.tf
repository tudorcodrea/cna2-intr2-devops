output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "EKS cluster certificate authority data"
  value       = module.eks.cluster_certificate_authority_data
}

output "node_group_name" {
  description = "EKS node group name"
  value       = "main"  # Using the name from the eks module
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region} --profile ${var.aws_profile}"
}

output "dynamodb_table_name" {
  description = "DynamoDB table name for claims"
  value       = aws_dynamodb_table.claims.name
}

output "s3_bucket_name" {
  description = "S3 bucket name for claims notes"
  value       = aws_s3_bucket.claims_notes.bucket
}

output "ecr_repository_url" {
  description = "ECR repository URL for claims service"
  value       = aws_ecr_repository.claims_service.repository_url
}

output "api_gateway_url" {
  description = "API Gateway invoke URL for claims API"
  value       = "${aws_api_gateway_stage.prod.invoke_url}/claims"
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.claims_api.id
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN for claims"
  value       = aws_dynamodb_table.claims.arn
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for claims notes"
  value       = aws_s3_bucket.claims_notes.arn
}

output "ecr_repository_arn" {
  description = "ECR repository ARN for claims service"
  value       = aws_ecr_repository.claims_service.arn
}

output "claims_summarizer_lambda_name" {
  description = "Lambda function name for claim summarization"
  value       = aws_lambda_function.claims_summarizer.function_name
}

output "claims_summarizer_lambda_arn" {
  description = "Lambda function ARN for claim summarization"
  value       = aws_lambda_function.claims_summarizer.arn
}

output "claim_generate_files_lambda_name" {
  description = "Lambda function name for claim file generation"
  value       = aws_lambda_function.claim_generate_files.function_name
}

output "claim_generate_files_lambda_arn" {
  description = "Lambda function ARN for claim file generation"
  value       = aws_lambda_function.claim_generate_files.arn
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL for the claims API"
  value       = aws_api_gateway_stage.prod.invoke_url
}
