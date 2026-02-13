#!/bin/bash
# aws_terraform_init.sh
# Initializes AWS resources for Terraform backend (S3, DynamoDB, KMS)
# Uses AWS CLI profile 'cna2' and region 'us-east-1'

set -e

PROFILE="cna2"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile "$PROFILE")
BUCKET="introspect2-tf-state-${ACCOUNT_ID}"
DYNAMO_TABLE="introspect2-tf-locks"
KMS_ALIAS="alias/introspect2-tf-key"

echo "Creating S3 bucket: $BUCKET in $REGION"
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" --profile "$PROFILE"
else
  aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" --profile "$PROFILE"
fi

echo "Enabling versioning on bucket"
aws s3api put-bucket-versioning --bucket "$BUCKET" \
--versioning-configuration Status=Enabled --profile "$PROFILE" --region "$REGION"

echo "Blocking public access on bucket"
aws s3api put-public-access-block --bucket "$BUCKET" \
--public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
--profile "$PROFILE" --region "$REGION"

echo "Enabling default encryption (SSE-S3)"
aws s3api put-bucket-encryption --bucket "$BUCKET" \
--server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
--profile "$PROFILE" --region "$REGION"

echo "Creating DynamoDB table for state locking: $DYNAMO_TABLE"
aws dynamodb create-table --table-name "$DYNAMO_TABLE" \
--attribute-definitions AttributeName=LockID,AttributeType=S \
--key-schema AttributeName=LockID,KeyType=HASH \
--billing-mode PAY_PER_REQUEST --region "$REGION" --profile "$PROFILE"

echo "Creating ECR repositories for microservices..."
aws ecr create-repository --repository-name introspect2-claims --region "$REGION" --profile "$PROFILE"

echo "Attaching AmazonVPCFullAccess policy to the IAM user for EC2 permissions"
aws iam attach-user-policy --user-name c04-vlabuser168@stackroute.in --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --profile "$PROFILE"

echo "Creating IAM policy for Terraform backend access..."
aws iam create-policy --policy-name TerraformIntrospect2Policy --policy-document file://terraform-introspect2-policy.json --profile "$PROFILE"

echo "Attaching Terraform policy to IAM user..."
aws iam attach-user-policy --user-name "c04-vlabuser168@stackroute.in" --policy-arn arn:aws:iam::660633971866:policy/TerraformIntrospect2Policy --profile "$PROFILE"

echo "Done. Resources created for Terraform backend."