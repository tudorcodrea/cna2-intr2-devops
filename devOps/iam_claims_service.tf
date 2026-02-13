# IAM Role for Claims Service (IRSA - IAM Roles for Service Accounts)

resource "aws_iam_role" "claims_service_role" {
  name = "claims-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_eks_cluster.introspect2_eks.identity[0].oidc[0].issuer, "https://", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.introspect2_eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:default:claims-service-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "claims_service_policy" {
  name = "claims-service-policy"
  role = aws_iam_role.claims_service_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:us-east-1:${data.aws_caller_identity.current.account_id}:table/claims*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::claims-notes-bucket",
          "arn:aws:s3:::claims-notes-bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = "arn:aws:lambda:us-east-1:${data.aws_caller_identity.current.account_id}:function:claims-summarizer-lambda"
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      }
    ]
  })
}

# Data sources for OIDC provider
data "aws_eks_cluster" "introspect2_eks" {
  name = var.cluster_name
}