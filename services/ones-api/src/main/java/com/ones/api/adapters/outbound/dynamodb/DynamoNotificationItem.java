package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoNotificationItem {

    private String userId;        // PK
    private String sk;            // SK: createdAt#id

    private String id;
    private String type;
    private String title;
    private String body;
    private String createdAt;
    private String readAt;
    private String status;
    private String priority;
    private String actionType;
    private String entityType;
    private String entityId;
    private String route;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("userId")
    public String getUserId() { return userId; }
    public void setUserId(String userId) { this.userId = userId; }

    @DynamoDbSortKey
    @DynamoDbAttribute("sk")
    public String getSk() { return sk; }
    public void setSk(String sk) { this.sk = sk; }

    @DynamoDbAttribute("id")
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    @DynamoDbAttribute("type")
    public String getType() { return type; }
    public void setType(String type) { this.type = type; }

    @DynamoDbAttribute("title")
    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    @DynamoDbAttribute("body")
    public String getBody() { return body; }
    public void setBody(String body) { this.body = body; }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() { return createdAt; }
    public void setCreatedAt(String createdAt) { this.createdAt = createdAt; }

    @DynamoDbAttribute("readAt")
    public String getReadAt() { return readAt; }
    public void setReadAt(String readAt) { this.readAt = readAt; }

    @DynamoDbAttribute("status")
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    @DynamoDbAttribute("priority")
    public String getPriority() { return priority; }
    public void setPriority(String priority) { this.priority = priority; }

    @DynamoDbAttribute("actionType")
    public String getActionType() { return actionType; }
    public void setActionType(String actionType) { this.actionType = actionType; }

    @DynamoDbAttribute("entityType")
    public String getEntityType() { return entityType; }
    public void setEntityType(String entityType) { this.entityType = entityType; }

    @DynamoDbAttribute("entityId")
    public String getEntityId() { return entityId; }
    public void setEntityId(String entityId) { this.entityId = entityId; }

    @DynamoDbAttribute("route")
    public String getRoute() { return route; }
    public void setRoute(String route) { this.route = route; }
}
