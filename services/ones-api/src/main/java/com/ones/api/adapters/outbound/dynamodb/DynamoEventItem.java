package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

@DynamoDbBean
public class DynamoEventItem {

    private String eventId;
    private String ownerId;
    private String createdAt;
    private String title;

    private String objective;
    private String location;
    private String startAt;
    private String endAt;
    private String coverKey;

    private Boolean allowGuestInvites;

    private Boolean inviteLinkEnabled;

    private java.util.List<String> frameIds;

    private String gsi1pk;
    private String gsi1sk;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("eventId")
    public String getEventId() {
        return eventId;
    }

    public void setEventId(String eventId) {
        this.eventId = eventId;
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

    @DynamoDbAttribute("title")
    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    @DynamoDbAttribute("objective")
    public String getObjective() {
        return objective;
    }

    public void setObjective(String objective) {
        this.objective = objective;
    }

    @DynamoDbAttribute("location")
    public String getLocation() {
        return location;
    }

    public void setLocation(String location) {
        this.location = location;
    }

    @DynamoDbAttribute("startAt")
    public String getStartAt() {
        return startAt;
    }

    public void setStartAt(String startAt) {
        this.startAt = startAt;
    }

    @DynamoDbAttribute("endAt")
    public String getEndAt() {
        return endAt;
    }

    public void setEndAt(String endAt) {
        this.endAt = endAt;
    }

    @DynamoDbAttribute("coverKey")
    public String getCoverKey() {
        return coverKey;
    }

    public void setCoverKey(String coverKey) {
        this.coverKey = coverKey;
    }

    @DynamoDbAttribute("allowGuestInvites")
    public Boolean getAllowGuestInvites() {
        return allowGuestInvites;
    }

    public void setAllowGuestInvites(Boolean allowGuestInvites) {
        this.allowGuestInvites = allowGuestInvites;
    }

    @DynamoDbAttribute("inviteLinkEnabled")
    public Boolean getInviteLinkEnabled() {
        return inviteLinkEnabled;
    }

    public void setInviteLinkEnabled(Boolean inviteLinkEnabled) {
        this.inviteLinkEnabled = inviteLinkEnabled;
    }

    @DynamoDbAttribute("frameIds")
    public java.util.List<String> getFrameIds() {
        return frameIds;
    }

    public void setFrameIds(java.util.List<String> frameIds) {
        this.frameIds = frameIds;
    }

    @DynamoDbSecondaryPartitionKey(indexNames = "gsi1")
    @DynamoDbAttribute("gsi1pk")
    public String getGsi1pk() {
        return gsi1pk;
    }

    public void setGsi1pk(String gsi1pk) {
        this.gsi1pk = gsi1pk;
    }

    @DynamoDbSecondarySortKey(indexNames = "gsi1")
    @DynamoDbAttribute("gsi1sk")
    public String getGsi1sk() {
        return gsi1sk;
    }

    public void setGsi1sk(String gsi1sk) {
        this.gsi1sk = gsi1sk;
    }
}
