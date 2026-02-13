package com.example.claims.service;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.example.claims.model.Claim;
import com.example.claims.model.ClaimSummary;
import com.example.claims.model.CreateClaimRequest;
import com.example.claims.repository.ClaimsRepository;

@Service
public class ClaimsServiceImpl implements ClaimsService {

    private final ClaimsRepository claimsRepository;

    @Autowired
    public ClaimsServiceImpl(ClaimsRepository claimsRepository) {
        this.claimsRepository = claimsRepository;
    }

    @Override
    public Claim getClaim(String claimId) {
        Claim claim = claimsRepository.findById(claimId);
        if (claim == null) {
            throw new RuntimeException("Claim not found: " + claimId);
        }
        return claim;
    }

    @Override
    public ClaimSummary summarizeClaim(String claimId) {
        Claim claim = claimsRepository.findById(claimId);
        if (claim == null) {
            throw new RuntimeException("Claim not found: " + claimId);
        }

        // Call Lambda function for AI summarization
        return claimsRepository.generateSummary(claim);
    }

    @Override
    public void generateClaimFiles(String claimId) {
        Claim claim = claimsRepository.findById(claimId);
        if (claim == null) {
            throw new RuntimeException("Claim not found: " + claimId);
        }

        // Call Lambda function to generate files
        claimsRepository.generateClaimFiles(claim);
    }

    @Override
    public Claim createClaim(CreateClaimRequest request) {
        return claimsRepository.save(request);
    }
}