package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

@DynamoDbBean
public class DynamoCollectionMemberItem {
    private String collectionId;
    private String memberKey;
    private String userId;
    private String inviteeEmail;
    private String status;
    private String invitedByUserId;
    private String createdAt;
    private String updatedAt;

    @DynamoDbPartitionKey
    @DynamoDbSecondarySortKey(indexNames = {"byUserId", "byInviteeEmail"})
    @DynamoDbSecondaryPartitionKey(indexNames = "byCollectionUser")
    public String getCollectionId() { return collectionId; }
    public void setCollectionId(String value) { collectionId = value; }

    @DynamoDbSortKey
    public String getMemberKey() { return memberKey; }
    public void setMemberKey(String value) { memberKey = value; }

    @DynamoDbSecondaryPartitionKey(indexNames = "byUserId")
    @DynamoDbSecondarySortKey(indexNames = "byCollectionUser")
    public String getUserId() { return userId; }
    public void setUserId(String value) { userId = value; }

    @DynamoDbSecondaryPartitionKey(indexNames = "byInviteeEmail")
    public String getInviteeEmail() { return inviteeEmail; }
    public void setInviteeEmail(String value) { inviteeEmail = value; }

    @DynamoDbSecondarySortKey(indexNames = "byInviteeEmailStatus")
    public String getStatus() { return status; }
    public void setStatus(String value) { status = value; }
    public String getInvitedByUserId() { return invitedByUserId; }
    public void setInvitedByUserId(String value) { invitedByUserId = value; }
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String value) { createdAt = value; }
    public String getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(String value) { updatedAt = value; }
}
