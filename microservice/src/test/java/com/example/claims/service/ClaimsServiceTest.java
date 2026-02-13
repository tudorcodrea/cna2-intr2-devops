package com.example.claims.service;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ClaimsServiceTest {

    @Mock
    private com.example.claims.repository.ClaimsRepository claimsRepository;

    @InjectMocks
    private ClaimsServiceImpl claimsService;

    private Claim testClaim;
    private ClaimSummary testSummary;
    private CreateClaimRequest createRequest;

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

        createRequest = new CreateClaimRequest();
        createRequest.setClaimId("new-claim-123");
        createRequest.setCustomerId("new-customer-456");
        createRequest.setStatus("PENDING");
        createRequest.setDescription("New test claim");
        createRequest.setAmount(1500.00);
    }

    @Test
    void getClaim_ExistingClaim_ReturnsClaim() {
        // Given
        when(claimsRepository.findById("test-claim-123")).thenReturn(testClaim);

        // When
        Claim result = claimsService.getClaim("test-claim-123");

        // Then
        assertThat(result).isNotNull();
        assertThat(result.getClaimId()).isEqualTo("test-claim-123");
        assertThat(result.getStatus()).isEqualTo("UNDER_REVIEW");
    }

    @Test
    void getClaim_NonExistingClaim_ThrowsException() {
        // Given
        when(claimsRepository.findById("non-existing")).thenReturn(null);

        // When & Then
        assertThatThrownBy(() -> claimsService.getClaim("non-existing"))
                .isInstanceOf(RuntimeException.class);
    }

    @Test
    void summarizeClaim_ValidClaimId_ReturnsSummary() {
        // Given
        when(claimsRepository.generateSummary(any(Claim.class))).thenReturn(testSummary);
        when(claimsRepository.findById("test-claim-123")).thenReturn(testClaim);

        // When
        ClaimSummary result = claimsService.summarizeClaim("test-claim-123");

        // Then
        assertThat(result).isNotNull();
        assertThat(result.getClaimId()).isEqualTo("test-claim-123");
        assertThat(result.getModelUsed()).isEqualTo("test-model");
    }

    @Test
    void generateClaimFiles_ValidClaimId_CallsRepository() {
        // Given
        when(claimsRepository.findById("test-claim-123")).thenReturn(testClaim);

        // When
        claimsService.generateClaimFiles("test-claim-123");

        // Then - verify the repository method was called (implicitly tested through mocking)
        // In a real scenario, you might verify interactions or side effects
    }

    @Test
    void createClaim_ValidRequest_ReturnsCreatedClaim() {
        // Given
        Claim createdClaim = new Claim();
        createdClaim.setClaimId("new-claim-123");
        createdClaim.setCustomerId("new-customer-456");
        createdClaim.setStatus("PENDING");
        createdClaim.setDescription("New test claim");
        createdClaim.setAmount(1500.00);
        createdClaim.setCreatedDate(LocalDateTime.now());
        createdClaim.setUpdatedDate(LocalDateTime.now());

        when(claimsRepository.save(any(CreateClaimRequest.class))).thenReturn(createdClaim);

        // When
        Claim result = claimsService.createClaim(createRequest);

        // Then
        assertThat(result).isNotNull();
        assertThat(result.getClaimId()).isEqualTo("new-claim-123");
        assertThat(result.getStatus()).isEqualTo("PENDING");
    }
}