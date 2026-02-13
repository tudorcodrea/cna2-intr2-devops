# Introspect2 - GenAI-Enabled Claim Status API Strategy

## Executive Summary
Build a production-ready claim status API with AI-powered summarization capabilities on the provisioned EKS infrastructure. Implement using Java Spring Boot for the main application and AWS Lambda for AI processing via Amazon Bedrock. Focus on clean architecture, security, observability, and automated deployment.

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │────│   EKS Service    │────│     Lambda      │────│     Bedrock     │
│   (REST API)    │    │(Java/Spring Boot)│    │(AI Summarizer)  │    │  (Claude AI)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         └───────────────────────┼───────────────────────┘                       │
                                 │                                               │
                    ┌────────────┴────────────┐                                  │
                    │                         │                                  │
           ┌────────▼────────┐      ┌─────────▼───────┐                          │
           │   DynamoDB      │      │       S3        │◄─────────────────────────┘
           │ (Claim Status)  │      │  (Claim Notes)  │
           └─────────────────┘      └─────────────────┘
```

## Implementation Strategy

### Phase 1: Core Application Development

#### 1.1 Choose Technology Stack
**Decision**: Java with Spring Boot
- **Rationale**:
  - Strong enterprise-grade framework with proven AWS integration
  - Excellent AWS SDK for Java support
  - Robust error handling and resilience patterns
  - Mature ecosystem for microservices
  - Built-in observability and monitoring capabilities

**AI Integration**: AWS Lambda for Bedrock calls
- **Rationale**:
  - Serverless execution reduces application complexity
  - Better cost optimization for AI processing
  - Improved scalability and fault isolation
  - Easier testing and deployment of AI logic
  - Reduced cold start impact on main application
```
src/
├── main/
│   ├── java/
│   │   └── com/example/claims/
│   │       ├── ClaimsApplication.java          # Spring Boot main class
│   │       ├── config/
│   │       │   ├── AwsConfig.java             # AWS SDK configuration
│   │       │   └── WebConfig.java             # Web configuration
│   │       ├── controller/
│   │       │   └── ClaimsController.java      # REST endpoints
│   │       ├── service/
│   │       │   ├── ClaimsService.java         # Business logic
│   │       │   ├── DynamoDbService.java       # DynamoDB operations
│   │       │   ├── S3Service.java            # S3 operations
│   │       │   └── LambdaService.java        # Lambda invocation for AI
│   │       ├── model/
│   │       │   ├── Claim.java                 # Claim entity
│   │       │   ├── ClaimSummary.java          # AI summary response
│   │       │   └── ApiResponse.java           # Standard API responses
│   │       └── exception/
│   │           └── GlobalExceptionHandler.java # Error handling
│   └── resources/
│       ├── application.yml                    # Application configuration
│       └── logback-spring.xml                 # Logging configuration
└── test/
    └── java/
        └── com/example/claims/
            ├── ClaimsControllerTest.java
            ├── ClaimsServiceTest.java
            └── ClaimsApplicationTests.java
├── Dockerfile
├── pom.xml                                    # Maven configuration
└── mvnw                                       # Maven wrapper
```

#### 1.3 Data Models & Schemas

**Claim Status (DynamoDB)**:
```json
{
  "claimId": "string",
  "status": "PENDING|APPROVED|DENIED|UNDER_REVIEW",
  "customerId": "string",
  "createdDate": "ISO8601",
  "updatedDate": "ISO8601",
  "amount": "number",
  "description": "string"
}
```

**Claim Notes (S3)**:
```
s3://claims-bucket/notes/{claimId}/
├── claim-details.json
├── adjuster-notes.json
├── customer-correspondence.json
└── supporting-documents/
```

### Phase 2: API Implementation

#### 2.1 POST /claims/{id}
- **Input**: claimId (path parameter)
- **Process**: Query DynamoDB by claimId
- **Output**: Claim status object or 404
- **Error Handling**: Graceful degradation, structured error responses

#### 2.1 POST /claims/{id}/generate
- **Input**: claimId (path parameter)
- **Process**:
  1. Fetch claim status from DynamoDB
  3. Invoke AWS Lambda function with claim data and notes
  4. Lambda generates adjuster-notes.json & customer-correspondence.json via Bedrock

- **Output**:
```json
{
  "claimId": "string",
  "summaries": {
    "overall": "string",
    "customer": "string",
    "adjuster": "string",
    "recommendation": "string"
  },
  "generatedAt": "ISO8601",
  "modelUsed": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

#### 2.2 POST /claims/{id}/summarize
- **Input**: claimId (path parameter)
- **Process**:
  1. Fetch claim status from DynamoDB
  2. Retrieve all notes from S3 bucket
  3. Invoke AWS Lambda function with claim data and notes
  4. Lambda processes AI summarization via Bedrock
  5. Return structured response from Lambda
- **Output**:
```json
{
  "claimId": "string",
  "summaries": {
    "overall": "string",
    "customer": "string",
    "adjuster": "string",
    "recommendation": "string"
  },
  "generatedAt": "ISO8601",
  "modelUsed": "anthropic.claude-3-sonnet-20240229-v1:0"
}
```

### Phase 3: AI Integration (AWS Lambda + Amazon Bedrock)

#### 3.1 Lambda Function Architecture
**Lambda Function**: `claims-summarizer`
- **Runtime**: Python 3.11
- **Memory**: 1024 MB
- **Timeout**: 60 seconds
- **Trigger**: Synchronous invocation from Spring Boot application

**Lambda Structure**:
```python
src/
├── lambda_function.py          # Main Lambda handler
├── bedrock_service.py          # Bedrock AI integration
├── prompt_templates.py         # AI prompt engineering
├── models.py                   # Data models
└── requirements.txt
```

#### 3.2 Lambda Input/Output Schema
**Input Payload**:
```json
{
  "claimId": "string",
  "claimData": {
    "claimId": "string",
    "status": "PENDING|APPROVED|DENIED|UNDER_REVIEW",
    "customerId": "string",
    "amount": 2500.00,
    "description": "string"
  },
  "claimNotes": [
    {
      "fileName": "claim-details.json",
      "content": "JSON content..."
    },
    {
      "fileName": "adjuster-notes.txt",
      "content": "Text content..."
    }
  ]
}
```

**Output Response**:
```json
{
  "claimId": "string",
  "summaries": {
    "overall": "string",
    "customer": "string",
    "adjuster": "string",
    "recommendation": "APPROVE|DENY|REQUEST_MORE_INFO|SCHEDULE_INSPECTION|PENDING_REVIEW"
  },
  "generatedAt": "ISO8601",
  "modelUsed": "anthropic.claude-3-sonnet-20240229-v1:0",
  "processingTimeMs": 2500
}
```

#### 3.3 Prompt Engineering Strategy
**Overall Summary Prompt**:
```
You are an insurance claims analyst. Summarize the following claim information concisely:

Claim Details: {claim_json}
Claim Notes: {notes_text}

Provide a 2-3 sentence summary covering the key aspects of this claim.
```

**Customer Summary Prompt**:
```
Explain this insurance claim to the customer in simple, clear language:

Claim Details: {claim_json}
Claim Notes: {notes_text}

Focus on what happened, current status, and next steps. Avoid technical jargon.
```

**Adjuster Summary Prompt**:
```
As an insurance adjuster, provide a detailed assessment:

Claim Details: {claim_json}
All Notes: {notes_text}

Include risk assessment, coverage analysis, and recommended actions.
```

**Recommendation Prompt**:
```
Based on the claim details and notes, recommend the next step:

Current Status: {status}
Claim Details: {claim_json}
Recent Notes: {latest_notes}

Choose from: APPROVE, DENY, REQUEST_MORE_INFO, SCHEDULE_INSPECTION, PENDING_REVIEW
```

#### 3.4 Bedrock Configuration
- **Model**: anthropic.claude-3-sonnet-20240229-v1:0
- **Temperature**: 0.1 (consistent responses)
- **Max Tokens**: 1000 per summary
- **Error Handling**: Fallback responses if AI processing fails
- **Cost Optimization**: Pay-per-request pricing through Lambda

#### 3.5 Lambda IAM Permissions
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
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

### Phase 4: Infrastructure Integration

#### 4.1 API Gateway Configuration
**REST API Setup**:
- Resource: `/claims/{id}`
- Methods: GET, POST (for summarize)
- Integration: HTTP proxy to EKS service
- Authentication: IAM or API Key
- CORS: Enabled for web clients
- Throttling: 100 requests/second

#### 4.2 Kubernetes Deployment
**Service Configuration**:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: claims-api
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: claims-api

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: claims-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: claims-api
  template:
    spec:
      serviceAccountName: claims-api-sa
      containers:
      - name: claims-api
        image: claims-api:latest
        ports:
        - containerPort: 8080
        env:
        - name: DYNAMODB_TABLE
          value: "claims-status"
        - name: S3_BUCKET
          value: "claims-notes"
        - name: LAMBDA_FUNCTION
          value: "claims-summarizer"
        - name: AWS_REGION
          value: "us-east-1"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

#### 4.3 IAM Roles & Policies
**EKS Service Account** (for Spring Boot application):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:Query",
        "s3:GetObject",
        "s3:ListBucket",
        "lambda:InvokeFunction"
      ],
      "Resource": "*"
    }
  ]
}
```

**Lambda Execution Role** (for AI summarization):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "bedrock:InvokeModel",
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
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

### Phase 5: CI/CD Pipeline

#### 5.1 CodePipeline Stages
1. **Source**: GitHub repository
2. **Build**: CodeBuild with multi-stage Dockerfile
3. **Security Scan**: Amazon Inspector (ECR image scanning)
4. **Test**: Unit tests + integration tests
5. **Deploy**: kubectl apply to EKS
6. **Validate**: API endpoint testing

#### 5.2 Multi-Stage Dockerfile
```dockerfile
# Build stage
FROM maven:3.9.4-openjdk-17-slim as builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:17-jre-slim
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
CMD ["java", "-jar", "app.jar"]
```

### Phase 6: Observability & Monitoring

#### 6.1 CloudWatch Integration
**Metrics**:
- API latency (p50, p95, p99)
- Error rates by endpoint
- Bedrock API usage/costs
- DynamoDB/S3 operation counts

**Logs**:
- Structured JSON logging
- Request/response tracing
- AI prompt/response logging (sanitized)

#### 6.2 Health Checks
- `/health/ready` - Service readiness
- `/health/live` - Service liveness
- `/metrics` - Prometheus metrics

### Phase 7: Security Implementation

#### 7.1 Security Scanning
- **Container Images**: Amazon Inspector ECR scanning
- **Dependencies**: Safety/Snyk for Python packages
- **Infrastructure**: Checkov for Terraform validation

#### 7.2 Security Hub Integration
- Automated compliance checks
- Vulnerability management
- CIS AWS Foundations benchmarks

### Phase 8: Testing Strategy

#### 8.1 Test Categories
- **Unit Tests**: Service layer testing with Mockito and JUnit 5
- **Integration Tests**: Full API testing with Testcontainers and LocalStack
- **Contract Tests**: API Gateway response validation with Spring Cloud Contract
- **Performance Tests**: Load testing with JMeter or Gatling

#### 8.2 Test Dependencies (pom.xml)
```xml
<dependencies>
  <dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-test</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>junit-jupiter</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.testcontainers</groupId>
    <artifactId>localstack</artifactId>
    <scope>test</scope>
  </dependency>
  <dependency>
    <groupId>org.mockito</groupId>
    <artifactId>mockito-core</artifactId>
    <scope>test</scope>
  </dependency>
</dependencies>
```

#### 8.2 Mock Data Strategy
**Sample Claims**:
```json
{
  "claimId": "CLM-2024-001",
  "status": "UNDER_REVIEW",
  "customerId": "CUST-123",
  "amount": 2500.00,
  "description": "Water damage from burst pipe"
}
```

### Phase 9: Documentation & Validation

#### 9.1 API Documentation
- OpenAPI 3.0 specification (auto-generated by FastAPI)
- Postman collection for testing
- API usage examples

#### 9.2 Architecture Documentation
- System architecture diagrams
- Data flow diagrams
- Security architecture
- Deployment runbooks

## Risk Assessment & Mitigations

### High Risk Items
1. **Lambda Cold Starts**: Implement provisioned concurrency for consistent performance
2. **Bedrock API Limits**: Implement exponential backoff and circuit breaker patterns
3. **Data Privacy**: Sanitize logs, implement least-privilege IAM across services
4. **Distributed Debugging**: Implement correlation IDs for tracing requests across services
5. **Cost Management**: Monitor Lambda and Bedrock usage, implement intelligent caching

### Technical Trade-offs
1. **AI Architecture**: Lambda-based (isolation, scalability) vs direct integration (simplicity, latency)
2. **Technology Stack**: Java/Spring Boot (enterprise maturity) vs Python/FastAPI (rapid development)
3. **Database Choice**: DynamoDB (serverless, scalable for claims)
4. **API Gateway**: REST vs GraphQL (REST for simplicity, GraphQL for flexibility)

## Success Criteria Validation

- [ ] EKS cluster running with 3+ nodes
- [ ] API Gateway endpoints responding correctly
- [ ] Bedrock integration generating coherent summaries
- [ ] CI/CD pipeline with security scanning
- [ ] CloudWatch dashboards with key metrics
- [ ] Comprehensive test coverage (>80%)
- [ ] Security Hub scan analysis

## Implementation Timeline

**Week 1**: Core Spring Boot application development, basic API endpoints
**Week 2**: AWS service integrations (DynamoDB, S3, Lambda), Lambda function development
**Week 3**: AI integration via Lambda, Kubernetes deployment, API Gateway configuration
**Week 4**: CI/CD pipeline with Java builds, security scanning, comprehensive testing
**Week 5**: Observability implementation, performance optimization, production validation

This strategy provides a production-ready implementation with enterprise-grade Java architecture and serverless AI processing, maintaining the architectural flexibility required by the lab objectives.