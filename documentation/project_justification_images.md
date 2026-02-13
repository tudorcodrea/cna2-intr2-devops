# Project Implementation: Architecture and Observability Images

This document provides visual justification and architectural context for the GenAI-enabled Claim Status API project. The following images illustrate key components, design decisions, and operational insights that support the project's architecture and implementation.

## Architecture and Design

### Overall Architecture
- ![Overall Architecture](architectureDiagram.png)

### AI Scaling Architecture
- ![AI Scaling Architecture](ArchitectureDiagramAIScaling.png)

### API Gateway and Claims Contract
- ![API Gateway Claims Contract](APIGw-claims-contract.png)

### Autoscaling and Lambda
- ![AI Autoscaling](claims-lambdas.png)
- ![AI Autoscaler How It Works](AI-Autoscaler-How-It-Works.md)
- ![AI Autoscaling Architecture](AI-Autoscaling-Architecture.md)

## Observability and Performance

### CloudWatch and Load Testing
- ![CloudWatch Dashboard](cloudwatch-dashboard.png)
- ![JMeter Load Test](JMeter-load-test.png)
- ![DynamoDB Load Test](DynamoDB-load-test.png)
- ![Claim Lambdas Load Test](claim-lambdas-load-test.png)

### Data Storage
- ![S3 Claims Bucket](S3-claims-bucket.png)
- ![S3 Claims Bucket Details](S3-claims-bucket-details.png)

## Notes
- For detailed explanations, see the corresponding markdown files and diagrams in this folder.
- These visuals support the architectural choices, scalability, and operational readiness of the project.
