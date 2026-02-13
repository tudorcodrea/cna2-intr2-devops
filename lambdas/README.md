# AWS Lambda Functions for Claims Processing

This directory contains AWS Lambda functions that integrate with DynamoDB and Amazon Bedrock for AI-powered claims processing.

## Lambda Functions

### 1. Claims Summarizer (`claims-summarizer.py`)
Generates structured claim summaries with four components using Amazon Bedrock.

### 2. Claim Data Notes Generator (`claim-data-notes-generator.py`)
Generates adjuster notes and customer correspondence documents using Amazon Bedrock.

## DynamoDB Integration

Both Lambda functions integrate with the `claims` DynamoDB table:

```json
{
  "claimId": "string",           // Primary key
  "status": "PENDING|APPROVED|DENIED|UNDER_REVIEW",
  "customerId": "string",
  "createdDate": "ISO8601",
  "updatedDate": "ISO8601",
  "amount": "number",
  "description": "string"
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAIMS_TABLE` | `claims` | DynamoDB table name for claims |
| `CLAIMS_BUCKET` | `claims-notes-bucket` | S3 bucket for claim notes and generated documents |
| `BEDROCK_MODEL_ID` | `anthropic.claude-3-sonnet-20240229-v1:0` | Bedrock model ID |

## Architecture

```
Spring Boot Service
       ↓
   API Gateway
       ↓
   Lambda Functions → DynamoDB (claims-table)
       ↓              S3 (claims-notes-bucket)
   Amazon Bedrock
```

## Function Details

### Claims Summarizer
- **Function Name**: `claims-summarizer`
- **Purpose**: Generate structured summaries for claims
- **Input**: `{"claimId": "string"}`
- **Output**: Structured summary with overall/customer/adjuster/recommendation components

### Claim Data Notes Generator
- **Function Name**: `claim_generate_files`
- **Purpose**: Generate adjuster notes and customer correspondence
- **Input**: `{"claimId": "string", "claimData": {...}}`
- **Output**: File generation status and S3 locations

## DynamoDB Operations

### Read Operations
- `get_item()` - Fetch claim details by claimId
- Error handling for missing claims
- Automatic data type conversion

### Data Flow
1. Lambda receives claimId
2. Queries DynamoDB for claim details
3. Fetches additional notes from S3
4. Processes with Amazon Bedrock
5. Returns structured response

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "s3:GetObject",
        "bedrock:InvokeModel"
      ],
      "Resource": "*"
    }
  ]
}
```

## Output Format

### Success Response
```json
{
  "statusCode": 200,
  "claimId": "CLM-2024-001",
  "generatedFiles": [
    "s3://claims-notes-bucket/CLM-2024-001/adjuster-notes.json",
    "s3://claims-notes-bucket/CLM-2024-001/customer-correspondence.json"
  ],
  "generatedAt": "2024-01-20T15:30:00Z",
  "message": "Claim documents generated successfully"
}
```

### Error Response
```json
{
  "statusCode": 500,
  "error": "Error description",
  "claimId": "CLM-2024-001",
  "generatedAt": "2024-01-20T15:30:00Z"
}
```

## Generated Documents

### adjuster-notes.json
```json
{
  "assessment": "Detailed assessment of the claim including coverage analysis and risk evaluation",
  "findings": "Key findings from the investigation",
  "recommendations": "Specific recommendations for claim disposition",
  "estimatedSettlement": "Estimated settlement amount if applicable",
  "nextSteps": "Recommended next steps for claim processing",
  "riskLevel": "LOW, MEDIUM, HIGH risk assessment",
  "generatedAt": "2024-01-20T15:30:00Z"
}
```

### customer-correspondence.json
```json
{
  "subject": "Update on Your Water Damage Claim - CLM-2024-001",
  "greeting": "Dear Customer",
  "body": "We are currently reviewing your water damage claim...",
  "nextSteps": "What you can expect next and any actions needed",
  "contactInformation": "How to reach us for updates",
  "closing": "Best regards, Claims Team",
  "generatedAt": "2024-01-20T15:30:00Z"
}
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CLAIMS_TABLE` | `claims-table` | DynamoDB table name for claims data |
| `CLAIMS_BUCKET` | `claims-notes-bucket` | S3 bucket for claim notes and generated documents |
| `BEDROCK_MODEL_ID` | `anthropic.claude-3-sonnet-20240229-v1:0` | Bedrock model ID to use |

## IAM Permissions Required

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:region:account:table/claims-table"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::claims-notes-bucket",
        "arn:aws:s3:::claims-notes-bucket/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "arn:aws:bedrock:region::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Deployment

### Using AWS CLI

1. Create deployment package:
```bash
cd lambdas
pip install -r requirements.txt -t .
zip -r claim-data-notes-generator.zip .
```

2. Create Lambda function:
```bash
aws lambda create-function \
  --function-name claim_generate_files \
  --runtime python3.11 \
  --role arn:aws:iam::account:role/lambda-execution-role \
  --handler claim-data-notes-generator.lambda_handler \
  --zip-file fileb://claim-data-notes-generator.zip \
  --environment Variables="{CLAIMS_TABLE=claims-table,CLAIMS_BUCKET=claims-notes-bucket}" \
  --memory-size 1024 \
  --timeout 60
```

### Using Terraform

```hcl
resource "aws_lambda_function" "claim_generator" {
  function_name = "claim_generate_files"
  runtime       = "python3.11"
  handler       = "claim-data-notes-generator.lambda_handler"
  memory_size   = 1024
  timeout       = 60

  environment {
    variables = {
      CLAIMS_TABLE   = var.claims_table_name
      CLAIMS_BUCKET  = var.claims_bucket_name
      BEDROCK_MODEL_ID = "anthropic.claude-3-sonnet-20240229-v1:0"
    }
  }

  # ... other configuration
}
```

## Testing

### Local Testing

Run the script locally with sample data:

```bash
python claim-data-notes-generator.py
```

### AWS Testing

Test with AWS CLI:

```bash
aws lambda invoke \
  --function-name claim_generate_files \
  --payload '{"claimId": "CLM-2024-001"}' \
  response.json
```

## Monitoring

- **CloudWatch Logs**: Function execution logs
- **CloudWatch Metrics**: Invocation count, duration, errors
- **Bedrock Metrics**: Token usage and costs

## Error Handling

The function handles the following error scenarios:

- Missing `claimId` in input
- Claim not found in DynamoDB
- Missing notes file in S3 (graceful fallback)
- Bedrock API errors
- S3 storage errors

All errors are logged and returned in the response payload.

## Cost Optimization

- **Memory**: 1024 MB provides good performance/cost balance
- **Timeout**: 60 seconds covers typical document generation
- **Bedrock**: Pay-per-request with token-based pricing
- **Reserved Concurrency**: Consider for consistent performance

## Security Considerations

- Input validation for all parameters
- Least-privilege IAM permissions
- No sensitive data in logs
- Secure S3 bucket configurations
- VPC deployment if required for compliance