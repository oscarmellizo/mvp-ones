package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

@DynamoDbBean
public class DynamoRealtimeConnectionItem {

    private String connectionId; // PK
    private String userId;       // GSI PK
    private String createdAt;    // GSI SK

    @DynamoDbPartitionKey
    @DynamoDbAttribute("connectionId")
    public String getConnectionId() { return connectionId; }
    public void setConnectionId(String connectionId) { this.connectionId = connectionId; }

    @DynamoDbSecondaryPartitionKey(indexNames = {"byUserId"})
    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbSecondarySortKey(indexNames = {"byUserId"})
    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }
}
