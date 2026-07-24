package com.ones.api.domain.subscriptions;

import java.time.Instant;
import java.util.Objects;

public class CheckoutAttempt {

    private final String payerEmailLower;
    private final String createdAt; // ISO-8601
    private final String status; // created, completed, expired
    private final String userId;
    private final String planId;
    private final Long expiresAt; // epoch seconds for DynamoDB TTL
    private final String mercadoPagoPlanId;
    private final String preapprovalId;
    private final String paymentId;

    public CheckoutAttempt(
            String payerEmailLower,
            String createdAt,
            String status,
            String userId,
            String planId,
            Long expiresAt,
            String mercadoPagoPlanId,
            String preapprovalId,
            String paymentId
    ) {
        this.payerEmailLower = Objects.requireNonNull(payerEmailLower);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.status = status;
        this.userId = Objects.requireNonNull(userId);
        this.planId = Objects.requireNonNull(planId);
        this.expiresAt = expiresAt;
        this.mercadoPagoPlanId = mercadoPagoPlanId;
        this.preapprovalId = preapprovalId;
        this.paymentId = paymentId;
    }

    public String getPayerEmailLower() { return payerEmailLower; }
    public String getCreatedAt() { return createdAt; }
    public String getStatus() { return status; }
    public String getUserId() { return userId; }
    public String getPlanId() { return planId; }
    public Long getExpiresAt() { return expiresAt; }
    public String getMercadoPagoPlanId() { return mercadoPagoPlanId; }
    public String getPreapprovalId() { return preapprovalId; }
    public String getPaymentId() { return paymentId; }

    public CheckoutAttempt withCompleted() {
        return new CheckoutAttempt(payerEmailLower, createdAt, "completed", userId, planId, expiresAt, mercadoPagoPlanId, preapprovalId, paymentId);
    }
}
