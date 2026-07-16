package com.ones.api.domain.subscriptions;

import java.time.Instant;
import java.util.Objects;

public class UserSubscription {

    private final String userId;
    private final String planId;
    private final String status;
    private final String mercadoPagoPreapprovalId;
    private final Instant startedAt;
    private final Instant expiresAt;
    private final Instant nextPaymentDate;
    private final Instant cancelledAt;
    private final Instant updatedAt;

    public UserSubscription(
            String userId,
            String planId,
            String status,
            String mercadoPagoPreapprovalId,
            Instant startedAt,
            Instant expiresAt,
            Instant nextPaymentDate,
            Instant cancelledAt,
            Instant updatedAt
    ) {
        this.userId = Objects.requireNonNull(userId);
        this.planId = Objects.requireNonNull(planId);
        this.status = status;
        this.mercadoPagoPreapprovalId = mercadoPagoPreapprovalId;
        this.startedAt = startedAt;
        this.expiresAt = expiresAt;
        this.nextPaymentDate = nextPaymentDate;
        this.cancelledAt = cancelledAt;
        this.updatedAt = Objects.requireNonNull(updatedAt);
    }

    public String getUserId() {
        return userId;
    }

    public String getPlanId() {
        return planId;
    }

    public String getStatus() {
        return status;
    }

    public String getMercadoPagoPreapprovalId() {
        return mercadoPagoPreapprovalId;
    }

    public Instant getStartedAt() {
        return startedAt;
    }

    public Instant getExpiresAt() {
        return expiresAt;
    }

    public Instant getNextPaymentDate() {
        return nextPaymentDate;
    }

    public Instant getCancelledAt() {
        return cancelledAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public boolean isActive() {
        return "active".equalsIgnoreCase(status) || "free".equalsIgnoreCase(status);
    }

    public UserSubscription withPlan(String planId, String status, Instant updatedAt) {
        return new UserSubscription(
                userId, planId, status, mercadoPagoPreapprovalId, startedAt,
                expiresAt, nextPaymentDate, cancelledAt, updatedAt
        );
    }

    public UserSubscription withStatus(String status, Instant updatedAt) {
        return new UserSubscription(
                userId, planId, status, mercadoPagoPreapprovalId, startedAt,
                expiresAt, nextPaymentDate, cancelledAt, updatedAt
        );
    }

    public UserSubscription withMercadoPagoPreapprovalId(String preapprovalId, Instant updatedAt) {
        return new UserSubscription(
                userId, planId, status, preapprovalId, startedAt,
                expiresAt, nextPaymentDate, cancelledAt, updatedAt
        );
    }
}
