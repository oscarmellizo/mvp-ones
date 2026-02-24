package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSortKey;

@DynamoDbBean
public class DynamoInvitationItem {

    private String inviteeEmail;
    private String eventId;

    private String inviteeUserId;
    private String eventOwnerId;
    private String status;

    private String createdAt;
    private String updatedAt;

    private String eventTitle;
    private String eventLocation;
    private String eventStartAt;
    private String eventEndAt;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("inviteeEmail")
    @DynamoDbSecondarySortKey(indexNames = {"byEventId"})
    public String getInviteeEmail() {
        return inviteeEmail;
    }

    public void setInviteeEmail(String inviteeEmail) {
        this.inviteeEmail = inviteeEmail;
    }

    @DynamoDbSortKey
    @DynamoDbAttribute("eventId")
    @DynamoDbSecondaryPartitionKey(indexNames = {"byEventId"})
    public String getEventId() {
        return eventId;
    }

    public void setEventId(String eventId) {
        this.eventId = eventId;
    }

    @DynamoDbAttribute("inviteeUserId")
    public String getInviteeUserId() {
        return inviteeUserId;
    }

    public void setInviteeUserId(String inviteeUserId) {
        this.inviteeUserId = inviteeUserId;
    }

    @DynamoDbAttribute("eventOwnerId")
    public String getEventOwnerId() {
        return eventOwnerId;
    }

    public void setEventOwnerId(String eventOwnerId) {
        this.eventOwnerId = eventOwnerId;
    }

    @DynamoDbAttribute("status")
    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    @DynamoDbAttribute("updatedAt")
    public String getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(String updatedAt) {
        this.updatedAt = updatedAt;
    }

    @DynamoDbAttribute("eventTitle")
    public String getEventTitle() {
        return eventTitle;
    }

    public void setEventTitle(String eventTitle) {
        this.eventTitle = eventTitle;
    }

    @DynamoDbAttribute("eventLocation")
    public String getEventLocation() {
        return eventLocation;
    }

    public void setEventLocation(String eventLocation) {
        this.eventLocation = eventLocation;
    }

    @DynamoDbAttribute("eventStartAt")
    public String getEventStartAt() {
        return eventStartAt;
    }

    public void setEventStartAt(String eventStartAt) {
        this.eventStartAt = eventStartAt;
    }

    @DynamoDbAttribute("eventEndAt")
    public String getEventEndAt() {
        return eventEndAt;
    }

    public void setEventEndAt(String eventEndAt) {
        this.eventEndAt = eventEndAt;
    }
}
