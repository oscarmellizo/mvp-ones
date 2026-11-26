package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

@DynamoDbBean
public class DynamoCollectionItem {
    private String collectionId;
    private String ownerId;
    private String name;
    private String description;
    private String type;
    private String coverKey;
    private String purpose;
    private String createdAt;
    private String updatedAt;
    private Boolean joinEnabled;
    private String joinTokenHash;
    private Boolean deleting;
    private String partnerSlotKey;
    private String gsi1pk;
    private String gsi1sk;

    @DynamoDbPartitionKey
    public String getCollectionId() { return collectionId; }
    public void setCollectionId(String value) { collectionId = value; }

    @DynamoDbSecondaryPartitionKey(indexNames = "gsi1")
    public String getGsi1pk() { return gsi1pk; }
    public void setGsi1pk(String value) { gsi1pk = value; }

    @DynamoDbSecondarySortKey(indexNames = "gsi1")
    public String getGsi1sk() { return gsi1sk; }
    public void setGsi1sk(String value) { gsi1sk = value; }

    public String getOwnerId() { return ownerId; }
    public void setOwnerId(String value) { ownerId = value; }
    public String getName() { return name; }
    public void setName(String value) { name = value; }
    public String getDescription() { return description; }
    public void setDescription(String value) { description = value; }
    public String getType() { return type; }
    public void setType(String value) { type = value; }
    public String getCoverKey() { return coverKey; }
    public void setCoverKey(String value) { coverKey = value; }
    public String getPurpose() { return purpose; }
    public void setPurpose(String value) { purpose = value; }
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String value) { createdAt = value; }
    public String getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(String value) { updatedAt = value; }
    public Boolean getJoinEnabled() { return joinEnabled; }
    public void setJoinEnabled(Boolean value) { joinEnabled = value; }
    public String getJoinTokenHash() { return joinTokenHash; }
    public void setJoinTokenHash(String value) { joinTokenHash = value; }
    public Boolean getDeleting() { return deleting; }
    public void setDeleting(Boolean value) { deleting = value; }
    public String getPartnerSlotKey() { return partnerSlotKey; }
    public void setPartnerSlotKey(String value) { partnerSlotKey = value; }
}
