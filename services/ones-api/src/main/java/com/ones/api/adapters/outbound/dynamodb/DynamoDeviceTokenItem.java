package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoDeviceTokenItem {

    private String userId;     // PK
    private String sk;         // SK: platform#tokenHash

    private String platform;
    private String token;      // optional, can be null
    private String tokenHash;
    private String createdAt;
    private String lastUsedAt;
    private Boolean enabled;
    private String deviceInfo;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbSortKey
    @DynamoDbAttribute("sk")
    public String getSk() { return sk; }
    public void setSk(String sk) { this.sk = sk; }

    @DynamoDbAttribute("platform")
    public String getPlatform() { return platform; }
    public void setPlatform(String platform) { this.platform = platform; }

    @DynamoDbAttribute("token")
    public String getToken() { return token; }
    public void setToken(String token) { this.token = token; }

    @DynamoDbAttribute("tokenHash")
    public String getTokenHash() { return tokenHash; }
    public void setTokenHash(String tokenHash) { this.tokenHash = tokenHash; }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    @DynamoDbAttribute("lastUsedAt")
    public String getLastUsedAt() { return lastUsedAt; }
    public void setLastUsedAt(String lastUsedAt) { this.lastUsedAt = lastUsedAt; }

    @DynamoDbAttribute("enabled")
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }

    @DynamoDbAttribute("deviceInfo")
    public String getDeviceInfo() { return deviceInfo; }
    public void setDeviceInfo(String deviceInfo) { this.deviceInfo = deviceInfo; }
}
