package com.example.claims.model;

import java.time.LocalDateTime;
import java.util.List;

public class Claim {
    private String claimId;
    private String customerId;
    private String status;
    private String description;
    private LocalDateTime createdDate;
    private LocalDateTime updatedDate;
    private List<String> notes;
    private Double amount;

    // Default constructor
    public Claim() {}

    // Constructor with parameters
    public Claim(String claimId, String customerId, String status, String description,
                 LocalDateTime createdDate, LocalDateTime updatedDate, List<String> notes, Double amount) {
        this.claimId = claimId;
        this.customerId = customerId;
        this.status = status;
        this.description = description;
        this.createdDate = createdDate;
        this.updatedDate = updatedDate;
        this.notes = notes;
        this.amount = amount;
    }

    // Getters and Setters
    public String getClaimId() {
        return claimId;
    }

    public void setClaimId(String claimId) {
        this.claimId = claimId;
    }

    public String getCustomerId() {
        return customerId;
    }

    public void setCustomerId(String customerId) {
        this.customerId = customerId;
    }

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public LocalDateTime getCreatedDate() {
        return createdDate;
    }

    public void setCreatedDate(LocalDateTime createdDate) {
        this.createdDate = createdDate;
    }

    public LocalDateTime getUpdatedDate() {
        return updatedDate;
    }

    public void setUpdatedDate(LocalDateTime updatedDate) {
        this.updatedDate = updatedDate;
    }

    public List<String> getNotes() {
        return notes;
    }

    public void setNotes(List<String> notes) {
        this.notes = notes;
    }

    public Double getAmount() {
        return amount;
    }

    public void setAmount(Double amount) {
        this.amount = amount;
    }

    @Override
    public String toString() {
        return "Claim{" +
                "claimId='" + claimId + '\'' +
                ", customerId='" + customerId + '\'' +
                ", status='" + status + '\'' +
                ", description='" + description + '\'' +
                ", createdDate=" + createdDate +
                ", updatedDate=" + updatedDate +
                ", notes=" + notes +
                ", amount=" + amount +
                '}';
    }
}