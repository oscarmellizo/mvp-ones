package com.ones.api.domain.subscriptions;

import java.time.Instant;
import java.util.Collections;
import java.util.Map;
import java.util.Objects;

public class SubscriptionPlan {

    private final String planId;
    private final String name;
    private final String shortDescription;
    private final String tier;
    private final long priceCents;
    private final String currency;
    private final String billingInterval;
    private final String mercadoPagoPlanId;
    private final Map<String, PlanFeature> features;
    private final boolean active;
    private final int sortOrder;
    private final Instant createdAt;
    private final Instant updatedAt;

    public SubscriptionPlan(
            String planId,
            String name,
            String shortDescription,
            String tier,
            long priceCents,
            String currency,
            String billingInterval,
            String mercadoPagoPlanId,
            Map<String, PlanFeature> features,
            boolean active,
            int sortOrder,
            Instant createdAt,
            Instant updatedAt
    ) {
        this.planId = Objects.requireNonNull(planId);
        this.name = name;
        this.shortDescription = shortDescription;
        this.tier = tier;
        this.priceCents = priceCents;
        this.currency = currency;
        this.billingInterval = billingInterval;
        this.mercadoPagoPlanId = mercadoPagoPlanId;
        this.features = features != null ? Collections.unmodifiableMap(features) : Collections.emptyMap();
        this.active = active;
        this.sortOrder = sortOrder;
        this.createdAt = Objects.requireNonNull(createdAt);
        this.updatedAt = Objects.requireNonNull(updatedAt);
    }

    public String getPlanId() {
        return planId;
    }

    public String getName() {
        return name;
    }

    public String getShortDescription() {
        return shortDescription;
    }

    public String getTier() {
        return tier;
    }

    public long getPriceCents() {
        return priceCents;
    }

    public String getCurrency() {
        return currency;
    }

    public String getBillingInterval() {
        return billingInterval;
    }

    public String getMercadoPagoPlanId() {
        return mercadoPagoPlanId;
    }

    public Map<String, PlanFeature> getFeatures() {
        return features;
    }

    public boolean isActive() {
        return active;
    }

    public int getSortOrder() {
        return sortOrder;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public Object getFeatureValue(String key) {
        PlanFeature feature = features.get(key);
        return feature != null ? feature.value() : null;
    }

    public boolean featureEnabled(String key) {
        Object value = getFeatureValue(key);
        return value instanceof Boolean && (Boolean) value;
    }

    public long featureNumber(String key, long defaultValue) {
        Object value = getFeatureValue(key);
        return value instanceof Number ? ((Number) value).longValue() : defaultValue;
    }

    public SubscriptionPlan withActive(boolean active) {
        return new SubscriptionPlan(
                planId, name, shortDescription, tier, priceCents, currency,
                billingInterval, mercadoPagoPlanId, features, active, sortOrder,
                createdAt, Instant.now()
        );
    }
}
