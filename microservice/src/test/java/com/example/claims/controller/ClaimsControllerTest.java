package com.example.claims.controller;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;
import com.example.claims.service.ClaimsService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.localstack.LocalStackContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.utility.DockerImageName;

import java.time.LocalDateTime;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@WebMvcTest(ClaimsController.class)
@Testcontainers
class ClaimsControllerTest {

    @Container
    static LocalStackContainer localStack = new LocalStackContainer(
        DockerImageName.parse("localstack/localstack:3.0")
    ).withServices(LocalStackContainer.Service.DYNAMODB, LocalStackContainer.Service.S3, LocalStackContainer.Service.LAMBDA);

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private ClaimsService claimsService;

    @Autowired
    private ObjectMapper objectMapper;

    private Claim testClaim;
    private ClaimSummary testSummary;

    @BeforeEach
    void setUp() {
        testClaim = new Claim();
        testClaim.setClaimId("test-claim-123");
        testClaim.setCustomerId("test-customer-456");
        testClaim.setStatus("UNDER_REVIEW");
        testClaim.setDescription("Test vehicle accident claim");
        testClaim.setCreatedDate(LocalDateTime.now());
        testClaim.setUpdatedDate(LocalDateTime.now());

        testSummary = new ClaimSummary();
        testSummary.setClaimId("test-claim-123");
        testSummary.setGeneratedAt(LocalDateTime.now());
        testSummary.setModelUsed("test-model");
    }

    @Test
    void getClaim_ExistingClaim_ReturnsClaim() throws Exception {
        // Given
        when(claimsService.getClaim("test-claim-123")).thenReturn(testClaim);

        // When & Then
        mockMvc.perform(get("/api/v1/claims/test-claim-123"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.claimId").value("test-claim-123"))
                .andExpect(jsonPath("$.status").value("UNDER_REVIEW"))
                .andExpect(jsonPath("$.customerId").value("test-customer-456"));
    }

    @Test
    void getClaim_NonExistingClaim_ReturnsNotFound() throws Exception {
        // Given
        when(claimsService.getClaim("non-existing")).thenThrow(new RuntimeException("Claim not found"));

        // When & Then
        mockMvc.perform(get("/api/v1/claims/non-existing"))
                .andExpect(status().isNotFound());
    }

    @Test
    void summarizeClaim_ValidClaim_ReturnsSummary() throws Exception {
        // Given
        when(claimsService.summarizeClaim("test-claim-123")).thenReturn(testSummary);

        // When & Then
        mockMvc.perform(post("/api/v1/claims/test-claim-123/summarize"))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.claimId").value("test-claim-123"))
                .andExpect(jsonPath("$.modelUsed").value("test-model"));
    }

    @Test
    void generateClaimFiles_ValidClaim_ReturnsSuccess() throws Exception {
        // When & Then
        mockMvc.perform(post("/api/v1/claims/test-claim-123/generate"))
                .andExpect(status().isOk())
                .andExpect(content().string("Files generation initiated successfully"));
    }

    @Test
    void createClaim_ValidRequest_ReturnsCreatedClaim() throws Exception {
        // Given
        CreateClaimRequest request = new CreateClaimRequest();
        request.setClaimId("new-claim-123");
        request.setCustomerId("new-customer-456");
        request.setStatus("PENDING");
        request.setDescription("New test claim");
        request.setAmount(1500.00);

        Claim createdClaim = new Claim();
        createdClaim.setClaimId("new-claim-123");
        createdClaim.setCustomerId("new-customer-456");
        createdClaim.setStatus("PENDING");
        createdClaim.setDescription("New test claim");
        createdClaim.setAmount(1500.00);
        createdClaim.setCreatedDate(LocalDateTime.now());
        createdClaim.setUpdatedDate(LocalDateTime.now());

        when(claimsService.createClaim(any(CreateClaimRequest.class))).thenReturn(createdClaim);

        // When & Then
        mockMvc.perform(post("/api/v1/claims")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.APPLICATION_JSON))
                .andExpect(jsonPath("$.claimId").value("new-claim-123"))
                .andExpect(jsonPath("$.status").value("PENDING"));
    }
}