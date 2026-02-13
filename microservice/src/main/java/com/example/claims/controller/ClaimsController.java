package com.example.claims.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;
import com.example.claims.service.ClaimsService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/v1/claims")
public class ClaimsController {

    private static final Logger logger = LoggerFactory.getLogger(ClaimsController.class);

    private final ClaimsService claimsService;

    @Autowired
    public ClaimsController(ClaimsService claimsService) {
        this.claimsService = claimsService;
    }

    @GetMapping("/")
    public ResponseEntity<String> health() {
        logger.info("Health check endpoint called");
        return ResponseEntity.ok("OK");
    }

    @GetMapping("/{claimId}")
    public ResponseEntity<Claim> getClaim(@PathVariable String claimId) {
        logger.info("Retrieving claim with ID: {}", claimId);
        try {
            Claim claim = claimsService.getClaim(claimId);
            logger.info("Successfully retrieved claim: {}", claimId);
            return ResponseEntity.ok(claim);
        } catch (Exception e) {
            logger.error("Failed to retrieve claim {}: {}", claimId, e.getMessage());
            return ResponseEntity.notFound().build();
        }
    }

    @PostMapping("/{claimId}/summarize")
    public ResponseEntity<ClaimSummary> summarizeClaim(@PathVariable String claimId) {
        logger.info("Starting claim summarization for ID: {}", claimId);
        try {
            ClaimSummary summary = claimsService.summarizeClaim(claimId);
            logger.info("Successfully generated summary for claim: {}", claimId);
            return ResponseEntity.ok(summary);
        } catch (Exception e) {
            logger.error("Failed to summarize claim {}: {}", claimId, e.getMessage(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @PostMapping("/{claimId}/generate")
    public ResponseEntity<String> generateClaimFiles(@PathVariable String claimId) {
        logger.info("Starting file generation for claim ID: {}", claimId);
        try {
            claimsService.generateClaimFiles(claimId);
            logger.info("Successfully initiated file generation for claim: {}", claimId);
            return ResponseEntity.ok("Files generation initiated successfully");
        } catch (Exception e) {
            logger.error("Failed to generate files for claim {}: {}", claimId, e.getMessage(), e);
            return ResponseEntity.internalServerError().build();
        }
    }

    @PostMapping
    public ResponseEntity<Claim> createClaim(@Valid @RequestBody CreateClaimRequest request) {
        logger.info("Creating new claim for customer: {}", request.getCustomerId());
        try {
            Claim createdClaim = claimsService.createClaim(request);
            logger.info("Successfully created claim with ID: {}", createdClaim.getClaimId());
            return ResponseEntity.ok(createdClaim);
        } catch (Exception e) {
            logger.error("Failed to create claim: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().build();
        }
    }
}