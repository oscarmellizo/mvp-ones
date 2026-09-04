package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;

@DynamoDbBean
public class DynamoRealtimeSessionTokenItem {

    private String token;     // PK
    private String userId;
    private String createdAt;
    private String expiresAt;
    private Long ttl;         // DynamoDB TTL attribute (epoch seconds)

    @DynamoDbPartitionKey
    @DynamoDbAttribute("token")
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    @DynamoDbAttribute("expiresAt")
    public String getExpiresAt() { return expiresAt; }
    public void setExpiresAt(String expiresAt) { this.expiresAt = expiresAt; }

    @DynamoDbAttribute("ttl")
    public Long getTtl() { return ttl; }
    public void setTtl(Long ttl) { this.ttl = ttl; }
}
