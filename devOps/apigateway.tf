# API Gateway for Claims Service

resource "aws_api_gateway_rest_api" "claims_api" {
  name        = "claims-service-api-simple"
  description = "API Gateway for Claims Service"
}

resource "aws_api_gateway_resource" "claims" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  parent_id   = aws_api_gateway_rest_api.claims_api.root_resource_id
  path_part   = "claims"
}

resource "aws_api_gateway_method" "post_claim" {
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  resource_id   = aws_api_gateway_resource.claims.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_claim_integration" {
  rest_api_id             = aws_api_gateway_rest_api.claims_api.id
  resource_id             = aws_api_gateway_resource.claims.id
  http_method             = aws_api_gateway_method.post_claim.http_method
  type                    = "HTTP"
  integration_http_method = "POST"
  uri                     = "http://a841c067574ca46629418fbd37b7d2a1-492892219.us-east-1.elb.amazonaws.com/api/v1/claims"
}

resource "aws_api_gateway_method" "get_claims" {
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  resource_id   = aws_api_gateway_resource.claims.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_claims_integration" {
  rest_api_id             = aws_api_gateway_rest_api.claims_api.id
  resource_id             = aws_api_gateway_resource.claims.id
  http_method             = aws_api_gateway_method.get_claims.http_method
  type                    = "HTTP"
  integration_http_method = "GET"
  uri                     = "http://a841c067574ca46629418fbd37b7d2a1-492892219.us-east-1.elb.amazonaws.com/api/v1/claims"
}

resource "aws_api_gateway_resource" "claims_id" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  parent_id   = aws_api_gateway_resource.claims.id
  path_part   = "{id}"
}

resource "aws_api_gateway_method" "get_claim" {
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  resource_id   = aws_api_gateway_resource.claims_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "get_claim_integration" {
  rest_api_id             = aws_api_gateway_rest_api.claims_api.id
  resource_id             = aws_api_gateway_resource.claims_id.id
  http_method             = aws_api_gateway_method.get_claim.http_method
  type                    = "HTTP"
  integration_http_method = "GET"
  uri                     = "http://a841c067574ca46629418fbd37b7d2a1-492892219.us-east-1.elb.amazonaws.com/api/v1/claims/{id}"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# Generate resource for claims/{id}/generate
resource "aws_api_gateway_resource" "claims_generate" {
  rest_api_id = aws_api_gateway_rest_api.claims_api.id
  parent_id   = aws_api_gateway_resource.claims_id.id
  path_part   = "generate"
}

resource "aws_api_gateway_method" "post_claim_generate" {
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  resource_id   = aws_api_gateway_resource.claims_generate.id
  http_method   = "POST"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

resource "aws_api_gateway_integration" "post_claim_generate_integration" {
  rest_api_id             = aws_api_gateway_rest_api.claims_api.id
  resource_id             = aws_api_gateway_resource.claims_generate.id
  http_method             = aws_api_gateway_method.post_claim_generate.http_method
  type                    = "HTTP"
  integration_http_method = "POST"
  uri                     = "http://a841c067574ca46629418fbd37b7d2a1-492892219.us-east-1.elb.amazonaws.com/api/v1/claims/{id}/generate"

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

resource "aws_api_gateway_deployment" "claims_deployment" {
  depends_on = [
    aws_api_gateway_integration.post_claim_integration,
    aws_api_gateway_integration.get_claims_integration,
    aws_api_gateway_integration.get_claim_integration,
    aws_api_gateway_integration.post_claim_generate_integration
  ]
  rest_api_id = aws_api_gateway_rest_api.claims_api.id

  lifecycle {
    create_before_destroy = true
  }

  # Force redeployment when integrations change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.post_claim_integration.uri,
      aws_api_gateway_integration.get_claims_integration.uri,
      aws_api_gateway_integration.get_claim_integration.uri,
      aws_api_gateway_integration.post_claim_generate_integration.uri,
    ]))
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.claims_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.claims_api.id
  stage_name    = "prod"
  description   = "Production stage with claims API"
}