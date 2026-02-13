package com.example.claims.service;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;

public interface ClaimsService {
    Claim getClaim(String claimId);
    ClaimSummary summarizeClaim(String claimId);
    void generateClaimFiles(String claimId);
    Claim createClaim(CreateClaimRequest request);
}