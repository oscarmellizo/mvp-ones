package com.ones.api.adapters.outbound.dynamodb;

import java.util.Map;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

@DynamoDbBean
public class DynamoSubscriptionPlanItem {

    private String planId;
    private String name;
    private String shortDescription;
    private String tier;
    private long priceCents;
    private String currency;
    private String billingInterval;
    private String mercadoPagoPlanId;
    private Map<String, AttributeValue> features;
    private boolean active;
    private int sortOrder;
    private String createdAt;
    private String updatedAt;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("planId")
    public String getPlanId() {
        return planId;
    }

    public void setPlanId(String planId) {
        this.planId = planId;
    }

    @DynamoDbAttribute("name")
    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    @DynamoDbAttribute("shortDescription")
    public String getShortDescription() {
        return shortDescription;
    }

    public void setShortDescription(String shortDescription) {
        this.shortDescription = shortDescription;
    }

    @DynamoDbAttribute("tier")
    public String getTier() {
        return tier;
    }

    public void setTier(String tier) {
        this.tier = tier;
    }

    @DynamoDbAttribute("priceCents")
    public long getPriceCents() {
        return priceCents;
    }

    public void setPriceCents(long priceCents) {
        this.priceCents = priceCents;
    }

    @DynamoDbAttribute("currency")
    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    @DynamoDbAttribute("billingInterval")
    public String getBillingInterval() {
        return billingInterval;
    }

    public void setBillingInterval(String billingInterval) {
        this.billingInterval = billingInterval;
    }

    @DynamoDbAttribute("mercadoPagoPlanId")
    public String getMercadoPagoPlanId() {
        return mercadoPagoPlanId;
    }

    public void setMercadoPagoPlanId(String mercadoPagoPlanId) {
        this.mercadoPagoPlanId = mercadoPagoPlanId;
    }

    @DynamoDbAttribute("features")
    public Map<String, AttributeValue> getFeatures() {
        return features;
    }

    public void setFeatures(Map<String, AttributeValue> features) {
        this.features = features;
    }

    @DynamoDbAttribute("active")
    public boolean isActive() {
        return active;
    }

    public void setActive(boolean active) {
        this.active = active;
    }

    @DynamoDbAttribute("sortOrder")
    public int getSortOrder() {
        return sortOrder;
    }

    public void setSortOrder(int sortOrder) {
        this.sortOrder = sortOrder;
    }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    @DynamoDbAttribute("updatedAt")
    public String getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(String updatedAt) {
        this.updatedAt = updatedAt;
    }
}
