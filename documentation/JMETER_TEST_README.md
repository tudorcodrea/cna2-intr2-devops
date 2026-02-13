# Claims Service JMeter Load Test

This JMeter test plan performs load testing on the Claims Service API with the following characteristics:

## Test Configuration

- **Target Throughput**: 100 claims per minute (configurable via CLAIMS_PER_MINUTE property)
- **Test Duration**: 5 minutes (configurable via TEST_DURATION_MINUTES property)
- **Base URL**: API Gateway endpoint (configurable via BASE_URL property)
- **Thread Configuration**: 10 threads with 30-second ramp-up time

## Test Flow

The test executes the following sequence for each iteration:

1. **Create Claim (POST /claims)**
   - Creates a new claim with random claimId and customerId
   - Extracts the claimId from the response for subsequent requests
   - Expects HTTP 201 response

2. **Get Specific Claim (GET /claims/{id})**
   - Retrieves the claim created in step 1 using the extracted claimId
   - Validates the response contains the correct claimId
   - Expects HTTP 200 response

3. **List Claims (GET /claims)**
   - Retrieves all claims
   - Expects HTTP 200 response

## Running the Test

### Prerequisites
- JMeter 5.6.3 or later installed
- Java 8 or later

### Command Line Execution

```bash
# Run with default settings (100 claims/minute for 5 minutes)
jmeter -n -t claims-service-load-test.jmx -l results.jtl

# Run with custom parameters
jmeter -n -t claims-service-load-test.jmx -l results.jtl \
  -JCLAIMS_PER_MINUTE=200 \
  -JTEST_DURATION_MINUTES=10 \
  -JBASE_URL="https://your-api-gateway-url.execute-api.region.amazonaws.com/prod"
```

### GUI Mode (for test development/debugging)

```bash
jmeter -t claims-service-load-test.jmx
```

## Test Results

The test generates several output files:

- `results.jtl`: Raw test results in JTL format
- Summary Report: Shows throughput, response times, error rates
- Response Time Graph: Visual representation of response times

## Key Metrics to Monitor

- **Throughput**: Should approach 100 requests/minute (1.67 requests/second)
- **Response Time**: Average response time for each endpoint
- **Error Rate**: Percentage of failed requests
- **Success Rate**: Should be close to 100%

## Assertions

The test includes the following validations:

- HTTP status codes (201 for POST, 200 for GET)
- JSON response structure validation
- Claim ID consistency between create and retrieve operations

## Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| BASE_URL | https://wo902fpmsl.execute-api.us-east-1.amazonaws.com/prod | API Gateway base URL |
| CLAIMS_PER_MINUTE | 100 | Target throughput in claims per minute |
| TEST_DURATION_MINUTES | 5 | Test duration in minutes |

## Troubleshooting

1. **Low Throughput**: Check network connectivity and API Gateway limits
2. **High Error Rate**: Verify API endpoints are responding correctly
3. **Response Time Issues**: Check backend service performance and database connections

## Notes

- The test uses random claim IDs to avoid conflicts
- Constant Throughput Timer ensures consistent load regardless of response times
- Thread group is configured for steady-state testing