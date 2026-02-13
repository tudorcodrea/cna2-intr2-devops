# Package Lambda source files

data "archive_file" "claims_summarizer_zip" {
  type        = "zip"
  source {
    content  = file("${path.module}/../lambdas/claims_summarizer.py")
    filename = "claims_summarizer.py"
  }
  source {
    content  = file("${path.module}/../lambdas/requirements.txt")
    filename = "requirements.txt"
  }
  output_path = "${path.module}/claims_summarizer.zip"
}

data "archive_file" "claim_data_notes_generator_zip" {
  type        = "zip"
  source {
    content  = file("${path.module}/../lambdas/claim_data_notes_generator.py")
    filename = "claim_data_notes_generator.py"
  }
  source {
    content  = file("${path.module}/../lambdas/requirements.txt")
    filename = "requirements.txt"
  }
  output_path = "${path.module}/claim_data_notes_generator.zip"
}

# IAM role for Lambda execution
resource "aws_iam_role" "claims_lambdas" {
  name = "${var.cluster_name}-claims-lambdas-role"

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

resource "aws_iam_role_policy" "claims_lambdas" {
  name = "${var.cluster_name}-claims-lambdas-policy"
  role = aws_iam_role.claims_lambdas.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
      # DynamoDB Read
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.claims.arn
      },
      # S3 Read/Write for notes and generated files
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.claims_notes.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.claims_notes.arn
      },
      # Bedrock invoke
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda: claims summarizer (invoked synchronously)
resource "aws_lambda_function" "claims_summarizer" {
  function_name = "claims-summarizer-lambda"
  role          = aws_iam_role.claims_lambdas.arn
  runtime       = "python3.11"
  handler       = "claims_summarizer.lambda_handler"

  filename         = data.archive_file.claims_summarizer_zip.output_path
  source_code_hash = data.archive_file.claims_summarizer_zip.output_base64sha256

  timeout      = 60
  memory_size  = 1024
  architectures = ["x86_64"]

  environment {
    variables = {
      CLAIMS_TABLE     = aws_dynamodb_table.claims.name
      CLAIMS_BUCKET    = aws_s3_bucket.claims_notes.bucket
      BEDROCK_MODEL_ID = "amazon.nova-lite-v1:0"
    }
  }

  tags = {
    Name        = "${var.cluster_name}-claims-summarizer"
    Environment = var.environment
    Project     = "introspect2"
  }
}

# Lambda: claim file generator (invoked asynchronously)
resource "aws_lambda_function" "claim_generate_files" {
  function_name = "claim_generate_files"
  role          = aws_iam_role.claims_lambdas.arn
  runtime       = "python3.11"
  handler       = "claim_data_notes_generator.lambda_handler"

  filename         = data.archive_file.claim_data_notes_generator_zip.output_path
  source_code_hash = data.archive_file.claim_data_notes_generator_zip.output_base64sha256

  timeout      = 60
  memory_size  = 1024
  architectures = ["x86_64"]

  environment {
    variables = {
      CLAIMS_TABLE     = aws_dynamodb_table.claims.name
      CLAIMS_BUCKET    = aws_s3_bucket.claims_notes.bucket
      BEDROCK_MODEL_ID = "amazon.nova-lite-v1:0"
    }
  }

  tags = {
    Name        = "${var.cluster_name}-claims-generate"
    Environment = var.environment
    Project     = "introspect2"
  }
}
