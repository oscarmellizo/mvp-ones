package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

@DynamoDbBean
public class DynamoSubscriptionPaymentItem {

    private String paymentId;
    private String createdAt;
    private String mpDateCreated;
    private String status;
    private String statusDetail;
    private Long transactionAmountCents;
    private String currency;
    private String payerEmail;
    private String payerId;
    private String preapprovalId;
    private String preapprovalPlanId;
    private String userId;
    private String planId;
    private String checkoutAttemptId;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("paymentId")
    public String getPaymentId() { return paymentId; }
    public void setPaymentId(String paymentId) { this.paymentId = paymentId; }

    @DynamoDbSecondarySortKey(indexNames = {"byUserId", "byPreapprovalId"})
    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    @DynamoDbAttribute("mpDateCreated")
    public String getMpDateCreated() { return mpDateCreated; }
    public void setMpDateCreated(String mpDateCreated) { this.mpDateCreated = mpDateCreated; }

    @DynamoDbAttribute("status")
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    @DynamoDbAttribute("statusDetail")
    public String getStatusDetail() { return statusDetail; }
    public void setStatusDetail(String statusDetail) { this.statusDetail = statusDetail; }

    @DynamoDbAttribute("transactionAmountCents")
    public Long getTransactionAmountCents() { return transactionAmountCents; }
    public void setTransactionAmountCents(Long transactionAmountCents) { this.transactionAmountCents = transactionAmountCents; }

    @DynamoDbAttribute("currency")
    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    @DynamoDbAttribute("payerEmail")
    public String getPayerEmail() { return payerEmail; }
    public void setPayerEmail(String payerEmail) { this.payerEmail = payerEmail; }

    @DynamoDbAttribute("payerId")
    public String getPayerId() { return payerId; }
    public void setPayerId(String payerId) { this.payerId = payerId; }

    @DynamoDbSecondaryPartitionKey(indexNames = "byPreapprovalId")
    @DynamoDbAttribute("preapprovalId")
    public String getPreapprovalId() { return preapprovalId; }
    public void setPreapprovalId(String preapprovalId) { this.preapprovalId = preapprovalId; }

    @DynamoDbAttribute("preapprovalPlanId")
    public String getPreapprovalPlanId() { return preapprovalPlanId; }
    public void setPreapprovalPlanId(String preapprovalPlanId) { this.preapprovalPlanId = preapprovalPlanId; }

    @DynamoDbSecondaryPartitionKey(indexNames = "byUserId")
    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbAttribute("planId")
    public String getPlanId() { return planId; }
    public void setPlanId(String planId) { this.planId = planId; }

    @DynamoDbAttribute("checkoutAttemptId")
    public String getCheckoutAttemptId() { return checkoutAttemptId; }
    public void setCheckoutAttemptId(String checkoutAttemptId) { this.checkoutAttemptId = checkoutAttemptId; }
}
