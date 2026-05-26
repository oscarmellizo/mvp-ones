package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoTranslationItem {

    private String translationKey;
    private String languageCode;
    private String value;
    private String context;
    private Instant createdAt;
    private Instant updatedAt;
    private String createdBy;
    private String updatedBy;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("translationKey")
    public String getTranslationKey() {
        return translationKey;
    }

    public void setTranslationKey(String translationKey) {
        this.translationKey = translationKey;
    }

    @DynamoDbSortKey
    @DynamoDbAttribute("languageCode")
    public String getLanguageCode() {
        return languageCode;
    }

    public void setLanguageCode(String languageCode) {
        this.languageCode = languageCode;
    }

    @DynamoDbAttribute("value")
    public String getValue() {
        return value;
    }

    public void setValue(String value) {
        this.value = value;
    }

    @DynamoDbAttribute("context")
    public String getContext() {
        return context;
    }

    public void setContext(String context) {
        this.context = context;
    }

    @DynamoDbAttribute("createdAt")
    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    @DynamoDbAttribute("updatedAt")
    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }

    @DynamoDbAttribute("createdBy")
    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    @DynamoDbAttribute("updatedBy")
    public String getUpdatedBy() {
        return updatedBy;
    }

    public void setUpdatedBy(String updatedBy) {
        this.updatedBy = updatedBy;
    }
}
