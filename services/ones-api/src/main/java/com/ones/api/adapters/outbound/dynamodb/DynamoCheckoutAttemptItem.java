package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoCheckoutAttemptItem {

    private String payerEmailLower; // PK
    private String createdAt; // SK
    private String status;
    private String userId;
    private String planId;
    private Long expiresAt; // TTL
    private String mercadoPagoPlanId;
    private String preapprovalId;
    private String paymentId;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("payerEmailLower")
    public String getPayerEmailLower() { return payerEmailLower; }
    public void setPayerEmailLower(String payerEmailLower) { this.payerEmailLower = payerEmailLower; }

    @DynamoDbSortKey
    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    @DynamoDbAttribute("status")
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbAttribute("planId")
    public String getPlanId() { return planId; }
    public void setPlanId(String planId) { this.planId = planId; }

    @DynamoDbAttribute("expiresAt")
    public Long getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Long expiresAt) { this.expiresAt = expiresAt; }

    @DynamoDbAttribute("mercadoPagoPlanId")
    public String getMercadoPagoPlanId() { return mercadoPagoPlanId; }
    public void setMercadoPagoPlanId(String mercadoPagoPlanId) { this.mercadoPagoPlanId = mercadoPagoPlanId; }

    @DynamoDbAttribute("preapprovalId")
    public String getPreapprovalId() { return preapprovalId; }
    public void setPreapprovalId(String preapprovalId) { this.preapprovalId = preapprovalId; }

    @DynamoDbAttribute("paymentId")
    public String getPaymentId() { return paymentId; }
    public void setPaymentId(String paymentId) { this.paymentId = paymentId; }
}
