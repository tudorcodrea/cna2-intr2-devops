# Claims Service

A Spring Boot microservice for managing insurance claims with AI-powered summarization using Amazon Bedrock.

## Overview

The Claims Service provides REST API endpoints for retrieving claim information and generating AI-powered summaries of claim details using AWS Lambda and Amazon Bedrock.

## Architecture

- **Framework**: Spring Boot 3.2.10 with Java 21
- **Database**: Amazon DynamoDB for claim data storage
- **File Storage**: Amazon S3 for claim notes and documents
- **AI Processing**: AWS Lambda with Amazon Bedrock (Claude 3 Sonnet)
- **Deployment**: Kubernetes on AWS EKS

## API Endpoints

### Get Claim Details
```
GET /api/v1/claims/{claimId}
```
Retrieves detailed information about a specific claim.

**Response**: Claim object with ID, customer info, status, description, timestamps, and notes.

### Generate Claim Summary
```
POST /api/v1/claims/{claimId}/summarize
```
Generates an AI-powered summary of the claim using Amazon Bedrock.

**Response**: ClaimSummary object with claim ID, generated summary, timestamp, and AI model used.

## API Documentation

Detailed API reference for the Claims Service. All endpoints are prefixed with `/api/v1/claims` unless otherwise noted.

Common headers
- `Content-Type: application/json`
- `Accept: application/json`
- Optional: `Authorization: Bearer <token>` if you add auth in front of the service (not implemented by default)

1) Health / Service status

```
GET /actuator/health
```
- Description: Spring Boot actuator health endpoint (default path). Returns service health state.
- Response (200):

```json
{
  "status": "UP"
}
```

2) Create Claim

```
POST /api/v1/claims
```
- Description: Create a new claim record. If the caller supplies `claimId` the service uses it; otherwise the service will generate one.
- Request body (application/json):

```json
{
  "claimId": "claim-123",        // optional
  "customerId": "cust-456",
  "status": "UNDER_REVIEW",
  "description": "Vehicle accident claim",
  "amount": 5000.00,
  "notes": ["initial note"]
}
```
- Successful response (201 Created):

```json
{
  "claimId": "claim-1616161616",
  "customerId": "cust-456",
  "status": "UNDER_REVIEW",
  "description": "Vehicle accident claim",
  "amount": 5000.00,
  "createdDate": "2025-12-01T12:00:00Z",
  "updatedDate": "2025-12-01T12:00:00Z"
}
```
- Errors:
  - `400` Bad Request: invalid/missing required fields
  - `500` Internal Server Error: server-side error

3) Get Claim

```
GET /api/v1/claims/{claimId}
```
- Description: Retrieve claim by id.
- Path parameter: `claimId` (string)
- Successful response (200):

```json
{
  "claimId": "claim-1616161616",
  "customerId": "cust-456",
  "status": "UNDER_REVIEW",
  "description": "Vehicle accident claim",
  "amount": 5000.00,
  "notes": ["initial note"],
  "createdDate": "2025-12-01T12:00:00Z",
  "updatedDate": "2025-12-01T12:01:00Z"
}
```
- Errors:
  - `404` Not Found: claim not found
  - `500` Internal Server Error

4) Summarize Claim (AI)

```
POST /api/v1/claims/{claimId}/summarize
```
- Description: Triggers an asynchronous/synchronous AI summarization (depending on implementation) using Amazon Bedrock via the configured Lambda `claims-summarizer-lambda`.
- Path parameter: `claimId`
- Request body: optional parameters for summarization (examples):

```json
{
  "maxTokens": 250,
  "style": "concise"
}
```
- Successful response (200):

```json
{
  "claimId": "claim-1616161616",
  "summary": "Short summary of the claim details...",
  "generatedAt": "2025-12-01T12:05:00Z",
  "modelUsed": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```
- Errors:
  - `404` Not Found: claim not found
  - `502` / `504`: if the Lambda or Bedrock integration times out or fails
  - `500` Internal Server Error

5) Generate Document / Produce Derived Output

```
POST /api/v1/claims/{claimId}/generate
```
- Description: Example endpoint used by load tests to request generated artifacts (PDF, document, or other outputs) for a claim. Implementation may call other downstream services or Lambda functions.
- Request body: depends on artifact type; simple example:

```json
{ "type": "pdf", "options": { "includeNotes": true } }
```
- Successful response (200):

```json
{ "claimId": "claim-1616161616", "documentUrl": "s3://claims-notes-bucket/claim-1616161616/generated.pdf" }
```

6) Update Claim (partial)

```
PATCH /api/v1/claims/{claimId}
```
- Description: Update fields on an existing claim (status, notes, description, amount).
- Request body (application/json): partial Claim object with fields to update.
- Successful response (200): updated Claim object.

7) Delete Claim

```
DELETE /api/v1/claims/{claimId}
```
- Description: Delete a claim and associated notes/documents (if allowed). Returns `204 No Content` on success.

Notes on behavior
- Id generation: when `claimId` is not supplied on create, the service generates a unique id (example format `claim-<timestamp>`). The JMeter test uses `${__time()}` to produce unique ids in load tests.
- ResponseAssertions in tests expect HTTP 200 for successful retrieval/summarization/generation flows.
- The service stores notes/documents in the S3 bucket `claims-notes-bucket` and expects read/write permissions via the running pod's IAM role or via the Lambda execution role for backend functions.

## Configuration

The service is configured via `application.yml`:

```yaml
server:
  port: 8080

aws:
  region: us-east-1
  dynamodb:
    table-name: claims-table
  s3:
    bucket-name: claims-notes-bucket
  lambda:
    function-name: claims-summarizer-lambda

spring:
  profiles:
    active: default
```

## Building and Running

### Prerequisites
- Java 21
- Maven 3.6+
- AWS CLI configured with appropriate permissions

### Build
```bash
mvn clean compile
```

### Run
```bash
mvn spring-boot:run
```

### Test
```bash
mvn test
```

## AWS Resources Required

1. **DynamoDB Table**: `claims-table`
   - Primary Key: `claimId` (String)

2. **S3 Bucket**: `claims-notes-bucket`
   - Structure: `{claimId}/notes.txt`

3. **Lambda Function**: `claims-summarizer-lambda`
   - Runtime: Python 3.11
   - Handler: `lambda_function.lambda_handler`
   - Environment Variables:
     - `BEDROCK_MODEL_ID`: `anthropic.claude-3-sonnet-20240229-v1:0`

4. **ECR repository (images)**: `introspect2-claims`

5. **EKS cluster**: `introspect2-eks`

Notes:
- The devOps scripts and Terraform in the repository (see `devOps/`) create or reference an S3 backend bucket named `introspect2-tf-state-<account-id>` and a DynamoDB table `introspect2-tf-locks` for state locking. The helper script `devOps/aws_terraform_init.sh` will create those resources and an ECR repo named `introspect2-claims` when run with a configured AWS CLI profile.

## Data Models

### Claim
```json
{
  "claimId": "string",
  "customerId": "string",
  "status": "string",
  "description": "string",
  "createdDate": "2024-01-01T00:00:00",
  "updatedDate": "2024-01-01T00:00:00",
  "notes": ["string"]
}
```

### ClaimSummary
```json
{
  "claimId": "string",
  "summary": "string",
  "generatedAt": "2024-01-01T00:00:00",
  "modelUsed": "claude-3-sonnet"
}
```

## Error Handling

The service returns appropriate HTTP status codes:
- `200`: Success
- `404`: Claim not found
- `500`: Internal server error

## Monitoring

- Health checks available at `/actuator/health`
- Metrics available at `/actuator/metrics`
- Logs configured with DEBUG level for the `com.example.claims` package

## Security

- AWS IAM roles for service access
- VPC configuration for network isolation
- No authentication implemented (add as needed for production)

## Development

### Project Structure
```
src/
├── main/
│   ├── java/com/example/claims/
│   │   ├── ClaimsApplication.java
│   │   ├── controller/
│   │   │   └── ClaimsController.java
│   │   ├── service/
│   │   │   ├── ClaimsService.java
│   │   │   └── ClaimsServiceImpl.java
│   │   ├── repository/
│   │   │   ├── ClaimsRepository.java
│   │   │   └── ClaimsRepositoryImpl.java
│   │   ├── model/
│   │   │   ├── Claim.java
│   │   │   └── ClaimSummary.java
│   │   └── config/
│   │       └── AwsConfig.java
│   └── resources/
│       ├── application.yml
│       └── logback-spring.xml
└── test/
    ├── java/com/example/claims/
    │   └── ClaimsApplicationTests.java
    └── resources/
        └── application.yml
```

## Deployment

Deploy to Kubernetes using the provided manifests in the `k8s/` directory (to be created).

Below are recommended steps for preparing AWS, building images, and deploying this service.

1) Configure an AWS CLI profile (example `cna2`)

```bash
aws configure --profile cna2
# or edit ~/.aws/credentials and ~/.aws/config to add a profile named 'cna2'
```

2) Initialize Terraform backend resources (creates S3 state bucket, DynamoDB lock table, and an ECR repo)

Run from the `devOps` directory:

```bash
sh ./aws_terraform_init.sh
```

3) Build and push Docker image to ECR

Adjust `ECR_REGISTRY`, `ECR_REPO`, and `IMAGE_TAG` as needed:

```bash
ECR_REGISTRY=660633971866.dkr.ecr.us-east-1.amazonaws.com
ECR_REPO=introspect2-claims
IMAGE_TAG=latest

docker build -t $ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG .
docker push $ECR_REGISTRY/$ECR_REPO:$IMAGE_TAG
```

4) Update kubeconfig and deploy to EKS

```bash
aws eks update-kubeconfig --name introspect2-eks --region us-east-1 --profile cna2
kubectl apply -f k8s/
```

5) Diagnostics

- A helper PowerShell script `devOps/apigw_diagnostics.ps1` is available to test the API Gateway, call the backend ELB directly, and fetch recent CloudWatch API Gateway execution logs (requires AWS CLI).

PowerShell example:

```powershell
pwsh -ExecutionPolicy Bypass -File .\devOps\apigw_diagnostics.ps1 -ApiUrl "https://<api-id>.execute-api.us-east-1.amazonaws.com/prod/claims/claim-123/generate" -ElbUrl "http://<elb-dns>/api/v1/claims/claim-123/generate" -StartMinutesAgo 30 -AwsProfile cna2
```

## Contributing

1. Follow standard Spring Boot project structure
2. Add unit tests for new functionality
3. Update documentation for API changes
4. Ensure all tests pass before committing