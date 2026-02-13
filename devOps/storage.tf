# DynamoDB Table for Claims
resource "aws_dynamodb_table" "claims" {
  name         = "claims"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "claimId"

  attribute {
    name = "claimId"
    type = "S"
  }

  # Enable point-in-time recovery for data protection
  point_in_time_recovery {
    enabled = true
  }

  # Enable server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Tags
  tags = {
    Name        = "${var.cluster_name}-claims-table"
    Environment = var.environment
    Project     = "introspect2"
  }
}

# S3 Bucket for Claims Notes
resource "aws_s3_bucket" "claims_notes" {
  bucket = "claims-notes-bucket"

  tags = {
    Name        = "${var.cluster_name}-claims-notes-bucket"
    Environment = var.environment
    Project     = "introspect2"
  }
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "claims_notes" {
  bucket = aws_s3_bucket.claims_notes.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "claims_notes" {
  bucket = aws_s3_bucket.claims_notes.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "claims_notes" {
  bucket = aws_s3_bucket.claims_notes.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}