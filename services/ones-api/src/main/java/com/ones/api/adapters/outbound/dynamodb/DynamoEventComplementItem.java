package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoEventComplementItem {

    private String eventId;
    private String complementId;
    private Boolean enabled;
    private String tabLabel;
    private String updatedAt;

    @DynamoDbPartitionKey
    public String getEventId() {
        return eventId;
    }

    public void setEventId(String eventId) {
        this.eventId = eventId;
    }

    @DynamoDbSortKey
    public String getComplementId() {
        return complementId;
    }

    public void setComplementId(String complementId) {
        this.complementId = complementId;
    }

    public Boolean getEnabled() {
        return enabled;
    }

    public void setEnabled(Boolean enabled) {
        this.enabled = enabled;
    }

    public String getTabLabel() {
        return tabLabel;
    }

    public void setTabLabel(String tabLabel) {
        this.tabLabel = tabLabel;
    }

    public String getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(String updatedAt) {
        this.updatedAt = updatedAt;
    }
}
