package com.example.claims.repository;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;

import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.GetItemResponse;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.lambda.LambdaClient;
import software.amazon.awssdk.services.lambda.model.InvokeRequest;
import software.amazon.awssdk.services.lambda.model.InvokeResponse;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;

@Repository
public class ClaimsRepositoryImpl implements ClaimsRepository {

    private static final Logger logger = LoggerFactory.getLogger(ClaimsRepositoryImpl.class);

    private final DynamoDbClient dynamoDbClient;
    private final S3Client s3Client;
    private final LambdaClient lambdaClient;
    private final String s3BucketName;
    private final String summarizerLambdaName;
    private final String generateFilesLambdaName;

    @Autowired
    public ClaimsRepositoryImpl(DynamoDbClient dynamoDbClient, S3Client s3Client, LambdaClient lambdaClient,
                               @Value("${aws.s3.bucket-name}") String s3BucketName,
                               @Value("${aws.lambda.function-name}") String summarizerLambdaName,
                               @Value("${aws.lambda.generate-files-function-name}") String generateFilesLambdaName) {
        this.dynamoDbClient = dynamoDbClient;
        this.s3Client = s3Client;
        this.lambdaClient = lambdaClient;
        this.s3BucketName = s3BucketName;
        this.summarizerLambdaName = summarizerLambdaName;
        this.generateFilesLambdaName = generateFilesLambdaName;
    }

    @Override
    public Claim findById(String claimId) {
        GetItemRequest request = GetItemRequest.builder()
                .tableName("claims")
                .key(Map.of("claimId", AttributeValue.builder().s(claimId).build()))
                .build();

        GetItemResponse response = dynamoDbClient.getItem(request);
        if (response.hasItem()) {
            return mapToClaim(response.item());
        }
        return null;
    }

    @Override
    public ClaimSummary generateSummary(Claim claim) {
        // Prepare payload for Lambda with only claim details
        String payload = String.format(
            "{\"claimId\": \"%s\", \"description\": \"%s\", \"status\": \"%s\", \"customerId\": \"%s\"}",
            claim.getClaimId(),
            claim.getDescription(),
            claim.getStatus(),
            claim.getCustomerId()
        );

        // Invoke Lambda function
        InvokeRequest invokeRequest = InvokeRequest.builder()
                .functionName(summarizerLambdaName)
                .payload(SdkBytes.fromUtf8String(payload))
                .build();

        InvokeResponse invokeResponse = lambdaClient.invoke(invokeRequest);

        // Parse response
        String responsePayload = invokeResponse.payload().asUtf8String();

        // Parse the JSON response to extract summaries
        ClaimSummary.Summaries summaries = parseSummariesFromResponse(responsePayload);

        return new ClaimSummary(
            claim.getClaimId(),
            summaries,
            java.time.LocalDateTime.now(),
            "anthropic.claude-3-sonnet-20240229-v1:0"
        );
    }

    @Override
    public void generateClaimFiles(Claim claim) {
        // Get claim notes from S3
        String notesContent = getClaimNotesFromS3(claim.getClaimId());

        // Prepare payload for Lambda with claim data and notes
        String payload = String.format(
            "{\"claimId\": \"%s\", \"claimData\": {\"claimId\": \"%s\", \"status\": \"%s\", \"customerId\": \"%s\", \"description\": \"%s\"}, \"notes\": \"%s\"}",
            claim.getClaimId(),
            claim.getClaimId(),
            claim.getStatus(),
            claim.getCustomerId(),
            claim.getDescription(),
            notesContent
        );

        logger.info("Invoking generate-files Lambda {} with payload: {}", generateFilesLambdaName, payload);

        try {
            // Invoke Lambda function and surface errors so we can see why S3 files were not produced
            InvokeRequest invokeRequest = InvokeRequest.builder()
                .functionName(generateFilesLambdaName)
                .payload(SdkBytes.fromUtf8String(payload))
                .build();

            InvokeResponse response = lambdaClient.invoke(invokeRequest);

            String responsePayload = "<no payload>";
            try {
                responsePayload = response.payload() != null ? response.payload().asUtf8String() : "<no payload>";
            } catch (Exception e) {
                logger.warn("Failed to read response payload: {}", e.getMessage());
            }

            if (response.functionError() != null) {
                // Bubble up Lambda failure details for visibility during local runs
                String err = "Lambda generate-files failed: " + response.functionError() + " payload=" + responsePayload;
                logger.error(err);
                throw new RuntimeException(err);
            }

            logger.info("Lambda generate-files success. Status code {} payload: {}", response.statusCode(), responsePayload);
        } catch (Exception e) {
            logger.error("Failed to invoke Lambda function {}: {}", generateFilesLambdaName, e.getMessage(), e);
            throw new RuntimeException("Lambda invocation failed: " + e.getMessage(), e);
        }
    }

    private String getClaimNotesFromS3(String claimId) {
        try {
            logger.info("Fetching notes from S3 bucket '{}' key '{}'/notes.txt", s3BucketName, claimId);
            GetObjectRequest request = GetObjectRequest.builder()
                    .bucket(s3BucketName)
                    .key(claimId + "/notes.txt")
                    .build();

            return s3Client.getObjectAsBytes(request).asString(StandardCharsets.UTF_8);
        } catch (Exception e) {
            logger.warn("No notes found for claim '{}' in bucket '{}': {}", claimId, s3BucketName, e.getMessage());
            return "No additional notes available.";
        }
    }

    private ClaimSummary.Summaries parseSummariesFromResponse(String responsePayload) {
        // Simple JSON parsing - extract values from the response
        // Expected format: {"claimId":"...", "summaries":{"overall":"...", "customer":"...", "adjuster":"...", "recommendation":"..."}, "generatedAt":"...", "modelUsed":"..."}

        ClaimSummary.Summaries summaries = new ClaimSummary.Summaries();

        try {
            // Extract overall summary from summaries object
            summaries.setOverall(extractJsonValue(responsePayload, "summaries", "overall"));

            // Extract customer summary from summaries object
            summaries.setCustomer(extractJsonValue(responsePayload, "summaries", "customer"));

            // Extract adjuster summary from summaries object
            summaries.setAdjuster(extractJsonValue(responsePayload, "summaries", "adjuster"));

            // Extract recommendation from summaries object
            summaries.setRecommendation(extractJsonValue(responsePayload, "summaries", "recommendation"));
        } catch (Exception e) {
            // Fallback if parsing fails
            summaries.setOverall("Summary generation failed");
            summaries.setCustomer("Summary generation failed");
            summaries.setAdjuster("Summary generation failed");
            summaries.setRecommendation("UNKNOWN");
        }

        return summaries;
    }

    private String extractJsonValue(String json, String parentKey, String childKey) {
        // First find the parent object
        String parentSearchKey = "\"" + parentKey + "\": {";
        int parentStart = json.indexOf(parentSearchKey);
        if (parentStart == -1) return "Not available";

        // Find the end of the parent object
        int parentEnd = json.indexOf("}", parentStart);
        if (parentEnd == -1) return "Not available";

        // Extract the parent object content
        String parentContent = json.substring(parentStart + parentSearchKey.length(), parentEnd);

        // Now find the child key within the parent content
        String childSearchKey = "\"" + childKey + "\": \"";
        int childStart = parentContent.indexOf(childSearchKey);
        if (childStart == -1) return "Not available";

        childStart += childSearchKey.length();
        int childEnd = parentContent.indexOf("\"", childStart);
        if (childEnd == -1) return "Not available";

        return parentContent.substring(childStart, childEnd);
    }

    private Claim mapToClaim(Map<String, AttributeValue> item) {
        List<String> notes = new ArrayList<>();
        if (item.containsKey("notes") && item.get("notes").l() != null) {
            for (AttributeValue noteValue : item.get("notes").l()) {
                notes.add(noteValue.s());
            }
        }

        return new Claim(
            item.get("claimId").s(),
            item.get("customerId").s(),
            item.get("status").s(),
            item.get("description").s(),
            LocalDateTime.parse(item.get("createdDate").s(), DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            LocalDateTime.parse(item.get("updatedDate").s(), DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            notes,
            Double.parseDouble(item.get("amount").n())
        );
    }

    @Override
    public Claim save(CreateClaimRequest request) {
        LocalDateTime now = LocalDateTime.now();

        PutItemRequest putItemRequest = PutItemRequest.builder()
                .tableName("claims")
                .item(Map.of(
                    "claimId", AttributeValue.builder().s(request.getClaimId()).build(),
                    "customerId", AttributeValue.builder().s(request.getCustomerId()).build(),
                    "status", AttributeValue.builder().s(request.getStatus()).build(),
                    "description", AttributeValue.builder().s(request.getDescription()).build(),
                    "amount", AttributeValue.builder().n(String.valueOf(request.getAmount())).build(),
                    "createdDate", AttributeValue.builder().s(now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)).build(),
                    "updatedDate", AttributeValue.builder().s(now.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)).build()
                ))
                .build();

        dynamoDbClient.putItem(putItemRequest);

        // Return the created claim
        return new Claim(
            request.getClaimId(),
            request.getCustomerId(),
            request.getStatus(),
            request.getDescription(),
            now,
            now,
            new ArrayList<>(), // Empty notes list for new claims
            request.getAmount()
        );
    }
}