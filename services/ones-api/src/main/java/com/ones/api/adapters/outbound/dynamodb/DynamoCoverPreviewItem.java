package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;

@DynamoDbBean
public class DynamoCoverPreviewItem {

    private String coverId;
    private String ownerId;
    private String createdAt;
    private String tempBucket;
    private String tempKey;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("coverId")
    public String getCoverId() {
        return coverId;
    }

    public void setCoverId(String coverId) {
        this.coverId = coverId;
    }

    @DynamoDbAttribute("ownerId")
    public String getOwnerId() {
        return ownerId;
    }

    public void setOwnerId(String ownerId) {
        this.ownerId = ownerId;
    }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    @DynamoDbAttribute("tempBucket")
    public String getTempBucket() {
        return tempBucket;
    }

    public void setTempBucket(String tempBucket) {
        this.tempBucket = tempBucket;
    }

    @DynamoDbAttribute("tempKey")
    public String getTempKey() {
        return tempKey;
    }

    public void setTempKey(String tempKey) {
        this.tempKey = tempKey;
    }
}
