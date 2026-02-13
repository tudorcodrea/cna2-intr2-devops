package com.example.claims.model;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Pattern;

public class CreateClaimRequest {
    @NotBlank(message = "Claim ID is required")
    private String claimId;

    @NotBlank(message = "Customer ID is required")
    private String customerId;

    @NotBlank(message = "Status is required")
    @Pattern(regexp = "PENDING|APPROVED|DENIED|UNDER_REVIEW", message = "Status must be one of: PENDING, APPROVED, DENIED, UNDER_REVIEW")
    private String status;

    @NotBlank(message = "Description is required")
    private String description;

    @NotNull(message = "Amount is required")
    @DecimalMin(value = "0.0", inclusive = false, message = "Amount must be greater than 0")
    private Double amount;

    // Default constructor
    public CreateClaimRequest() {}

    // Constructor with parameters
    public CreateClaimRequest(String claimId, String customerId, String status, String description, Double amount) {
        this.claimId = claimId;
        this.customerId = customerId;
        this.status = status;
        this.description = description;
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

    public Double getAmount() {
        return amount;
    }

    public void setAmount(Double amount) {
        this.amount = amount;
    }

    @Override
    public String toString() {
        return "CreateClaimRequest{" +
                "claimId='" + claimId + '\'' +
                ", customerId='" + customerId + '\'' +
                ", status='" + status + '\'' +
                ", description='" + description + '\'' +
                ", amount=" + amount +
                '}';
    }
}