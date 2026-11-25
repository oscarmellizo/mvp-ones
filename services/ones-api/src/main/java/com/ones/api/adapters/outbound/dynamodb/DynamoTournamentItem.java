package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoTournamentItem {

    private String pk;
    private String sk;
    private String payload;
    private Long version;
    private String groupStatus;
    private String knockoutStatus;
    private String eventShardPk;
    private String eventShardSk;
    private String gateStatus;

    @DynamoDbPartitionKey
    public String getPk() {
        return pk;
    }

    public void setPk(String pk) {
        this.pk = pk;
    }

    @DynamoDbSortKey
    public String getSk() {
        return sk;
    }

    public void setSk(String sk) {
        this.sk = sk;
    }

    public String getPayload() {
        return payload;
    }

    public void setPayload(String payload) {
        this.payload = payload;
    }

    public Long getVersion() {
        return version;
    }

    public void setVersion(Long version) {
        this.version = version;
    }

    public String getGroupStatus() {
        return groupStatus;
    }

    public void setGroupStatus(String groupStatus) {
        this.groupStatus = groupStatus;
    }

    public String getKnockoutStatus() {
        return knockoutStatus;
    }

    public void setKnockoutStatus(String knockoutStatus) {
        this.knockoutStatus = knockoutStatus;
    }

    public String getEventShardPk() {
        return eventShardPk;
    }

    public void setEventShardPk(String eventShardPk) {
        this.eventShardPk = eventShardPk;
    }

    public String getEventShardSk() {
        return eventShardSk;
    }

    public void setEventShardSk(String eventShardSk) {
        this.eventShardSk = eventShardSk;
    }

    public String getGateStatus() {
        return gateStatus;
    }

    public void setGateStatus(String gateStatus) {
        this.gateStatus = gateStatus;
    }
}
