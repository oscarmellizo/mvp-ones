package com.ones.api.domain.photos;

import java.time.Instant;
import java.util.Objects;

public class Photo {

    private final String photoId;
    private final String eventId;
    private final String guestId;
    private final Instant createdAt;
    private final Instant uploadedAt;

    private final String status;

    private final String s3KeyOriginal;
    private final String s3KeyMedium;
    private final String s3KeySmall;

    private final String ownerName;

    private final String sharedByUserId;
    private final String sharedByName;

    public Photo(
            String photoId,
            String eventId,
            String guestId,
            Instant createdAt,
            Instant uploadedAt,
            String status,
            String s3KeyOriginal,
            String s3KeyMedium,
            String s3KeySmall
    ) {
        this.photoId = Objects.requireNonNull(photoId);
        this.eventId = Objects.requireNonNull(eventId);
        this.guestId = Objects.requireNonNull(guestId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.uploadedAt = uploadedAt;
        this.status = status;
        this.s3KeyOriginal = s3KeyOriginal;
        this.s3KeyMedium = s3KeyMedium;
        this.s3KeySmall = s3KeySmall;

        this.ownerName = null;
        this.sharedByUserId = null;
        this.sharedByName = null;
    }

    public Photo(
            String photoId,
            String eventId,
            String guestId,
            Instant createdAt,
            Instant uploadedAt,
            String status,
            String s3KeyOriginal,
            String s3KeyMedium,
            String s3KeySmall,
            String ownerName,
            String sharedByUserId,
            String sharedByName
    ) {
        this.photoId = Objects.requireNonNull(photoId);
        this.eventId = Objects.requireNonNull(eventId);
        this.guestId = Objects.requireNonNull(guestId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.uploadedAt = uploadedAt;
        this.status = status;
        this.s3KeyOriginal = s3KeyOriginal;
        this.s3KeyMedium = s3KeyMedium;
        this.s3KeySmall = s3KeySmall;

        this.ownerName = ownerName;
        this.sharedByUserId = sharedByUserId;
        this.sharedByName = sharedByName;
    }

    public String getPhotoId() {
        return photoId;
    }

    public String getEventId() {
        return eventId;
    }

    public String getGuestId() {
        return guestId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUploadedAt() {
        return uploadedAt;
    }

    public String getStatus() {
        return status;
    }

    public String getS3KeyOriginal() {
        return s3KeyOriginal;
    }

    public String getS3KeyMedium() {
        return s3KeyMedium;
    }

    public String getS3KeySmall() {
        return s3KeySmall;
    }

    public String getOwnerName() {
        return ownerName;
    }

    public String getSharedByUserId() {
        return sharedByUserId;
    }

    public String getSharedByName() {
        return sharedByName;
    }
}
