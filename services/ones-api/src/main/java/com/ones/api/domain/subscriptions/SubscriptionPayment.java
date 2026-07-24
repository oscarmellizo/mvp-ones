package com.ones.api.domain.subscriptions;

import java.time.Instant;
import java.util.Objects;

public class SubscriptionPayment {

    private final String paymentId; // PK
    private final Instant createdAt; // event time in Ones
    private final String mpDateCreated; // raw from MP if available
    private final String status;
    private final String statusDetail;
    private final Long transactionAmountCents;
    private final String currency;
    private final String payerEmail;
    private final String payerId;
    private final String preapprovalId;
    private final String preapprovalPlanId;
    private final String userId;
    private final String planId;
    private final String checkoutAttemptId;

    public SubscriptionPayment(
            String paymentId,
            Instant createdAt,
            String mpDateCreated,
            String status,
            String statusDetail,
            Long transactionAmountCents,
            String currency,
            String payerEmail,
            String payerId,
            String preapprovalId,
            String preapprovalPlanId,
            String userId,
            String planId,
            String checkoutAttemptId
    ) {
        this.paymentId = Objects.requireNonNull(paymentId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.mpDateCreated = mpDateCreated;
        this.status = status;
        this.statusDetail = statusDetail;
        this.transactionAmountCents = transactionAmountCents;
        this.currency = currency;
        this.payerEmail = payerEmail;
        this.payerId = payerId;
        this.preapprovalId = preapprovalId;
        this.preapprovalPlanId = preapprovalPlanId;
        this.userId = userId;
        this.planId = planId;
        this.checkoutAttemptId = checkoutAttemptId;
    }

    public String getPaymentId() { return paymentId; }
    public Instant getCreatedAt() { return createdAt; }
    public String getMpDateCreated() { return mpDateCreated; }
    public String getStatus() { return status; }
    public String getStatusDetail() { return statusDetail; }
    public Long getTransactionAmountCents() { return transactionAmountCents; }
    public String getCurrency() { return currency; }
    public String getPayerEmail() { return payerEmail; }
    public String getPayerId() { return payerId; }
    public String getPreapprovalId() { return preapprovalId; }
    public String getPreapprovalPlanId() { return preapprovalPlanId; }
    public String getUserId() { return userId; }
    public String getPlanId() { return planId; }
    public String getCheckoutAttemptId() { return checkoutAttemptId; }
}
