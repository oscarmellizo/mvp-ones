package com.ones.api.adapters.outbound.dynamodb;

import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbAttribute;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

@DynamoDbBean
public class DynamoPhotoItem {

    private String photoId;

    private String eventId;
    private String eventSortKey;

    private String guestId;

    private String createdAt;
    private String uploadedAt;

    private String status;

    private String s3KeyOriginal;
    private String s3KeyMedium;
    private String s3KeySmall;

    @DynamoDbPartitionKey
    @DynamoDbAttribute("photoId")
    public String getPhotoId() {
        return photoId;
    }

    public void setPhotoId(String photoId) {
        this.photoId = photoId;
    }

    @DynamoDbAttribute("eventId")
    @DynamoDbSecondaryPartitionKey(indexNames = {"byEventId"})
    public String getEventId() {
        return eventId;
    }

    public void setEventId(String eventId) {
        this.eventId = eventId;
    }

    @DynamoDbAttribute("eventSortKey")
    @DynamoDbSecondarySortKey(indexNames = {"byEventId"})
    public String getEventSortKey() {
        return eventSortKey;
    }

    public void setEventSortKey(String eventSortKey) {
        this.eventSortKey = eventSortKey;
    }

    @DynamoDbAttribute("guestId")
    public String getGuestId() {
        return guestId;
    }

    public void setGuestId(String guestId) {
        this.guestId = guestId;
    }

    @DynamoDbAttribute("createdAt")
    public String getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(String createdAt) {
        this.createdAt = createdAt;
    }

    @DynamoDbAttribute("uploadedAt")
    public String getUploadedAt() {
        return uploadedAt;
    }

    public void setUploadedAt(String uploadedAt) {
        this.uploadedAt = uploadedAt;
    }

    @DynamoDbAttribute("status")
    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    @DynamoDbAttribute("s3KeyOriginal")
    public String getS3KeyOriginal() {
        return s3KeyOriginal;
    }

    public void setS3KeyOriginal(String s3KeyOriginal) {
        this.s3KeyOriginal = s3KeyOriginal;
    }

    @DynamoDbAttribute("s3KeyMedium")
    public String getS3KeyMedium() {
        return s3KeyMedium;
    }

    public void setS3KeyMedium(String s3KeyMedium) {
        this.s3KeyMedium = s3KeyMedium;
    }

    @DynamoDbAttribute("s3KeySmall")
    public String getS3KeySmall() {
        return s3KeySmall;
    }

    public void setS3KeySmall(String s3KeySmall) {
        this.s3KeySmall = s3KeySmall;
    }
}
