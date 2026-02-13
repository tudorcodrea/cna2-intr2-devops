package com.example.claims.model;

import java.time.LocalDateTime;

public class ClaimSummary {
    private String claimId;
    private Summaries summaries;
    private LocalDateTime generatedAt;
    private String modelUsed;

    // Inner class for summaries
    public static class Summaries {
        private String overall;
        private String customer;
        private String adjuster;
        private String recommendation;

        public Summaries() {}

        public Summaries(String overall, String customer, String adjuster, String recommendation) {
            this.overall = overall;
            this.customer = customer;
            this.adjuster = adjuster;
            this.recommendation = recommendation;
        }

        // Getters and Setters
        public String getOverall() {
            return overall;
        }

        public void setOverall(String overall) {
            this.overall = overall;
        }

        public String getCustomer() {
            return customer;
        }

        public void setCustomer(String customer) {
            this.customer = customer;
        }

        public String getAdjuster() {
            return adjuster;
        }

        public void setAdjuster(String adjuster) {
            this.adjuster = adjuster;
        }

        public String getRecommendation() {
            return recommendation;
        }

        public void setRecommendation(String recommendation) {
            this.recommendation = recommendation;
        }
    }

    // Default constructor
    public ClaimSummary() {}

    // Constructor with parameters
    public ClaimSummary(String claimId, Summaries summaries, LocalDateTime generatedAt, String modelUsed) {
        this.claimId = claimId;
        this.summaries = summaries;
        this.generatedAt = generatedAt;
        this.modelUsed = modelUsed;
    }

    // Getters and Setters
    public String getClaimId() {
        return claimId;
    }

    public void setClaimId(String claimId) {
        this.claimId = claimId;
    }

    public Summaries getSummaries() {
        return summaries;
    }

    public void setSummaries(Summaries summaries) {
        this.summaries = summaries;
    }

    public LocalDateTime getGeneratedAt() {
        return generatedAt;
    }

    public void setGeneratedAt(LocalDateTime generatedAt) {
        this.generatedAt = generatedAt;
    }

    public String getModelUsed() {
        return modelUsed;
    }

    public void setModelUsed(String modelUsed) {
        this.modelUsed = modelUsed;
    }

    @Override
    public String toString() {
        return "ClaimSummary{" +
                "claimId='" + claimId + '\'' +
                ", summaries=" + summaries +
                ", generatedAt=" + generatedAt +
                ", modelUsed='" + modelUsed + '\'' +
                '}';
    }
}