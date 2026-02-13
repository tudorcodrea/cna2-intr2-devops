package com.example.claims.repository;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;

public interface ClaimsRepository {
    Claim findById(String claimId);
    ClaimSummary generateSummary(Claim claim);
    void generateClaimFiles(Claim claim);
    Claim save(CreateClaimRequest request);
}