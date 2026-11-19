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
    private final boolean shared;
    private final int processingAttempts;
    private final String processingErrorCode;
    private final Long processingLeaseUntilEpoch;
    private final Long processingRetryAtEpoch;

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
        this(photoId, eventId, guestId, createdAt, uploadedAt, status, s3KeyOriginal, s3KeyMedium, s3KeySmall,
                null, null, null, false, 0, null, null, null);
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
        this(photoId, eventId, guestId, createdAt, uploadedAt, status, s3KeyOriginal, s3KeyMedium, s3KeySmall,
                ownerName, sharedByUserId, sharedByName, false, 0, null, null, null);
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
            String sharedByName,
            boolean shared
    ) {
        this(photoId, eventId, guestId, createdAt, uploadedAt, status, s3KeyOriginal, s3KeyMedium, s3KeySmall,
                ownerName, sharedByUserId, sharedByName, shared, 0, null, null, null);
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
            String sharedByName,
            boolean shared,
            int processingAttempts,
            String processingErrorCode,
            Long processingLeaseUntilEpoch,
            Long processingRetryAtEpoch
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
        this.shared = shared;
        this.processingAttempts = Math.max(0, processingAttempts);
        this.processingErrorCode = processingErrorCode;
        this.processingLeaseUntilEpoch = processingLeaseUntilEpoch;
        this.processingRetryAtEpoch = processingRetryAtEpoch;
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

    public boolean isShared() {
        return shared;
    }

    public int getProcessingAttempts() {
        return processingAttempts;
    }

    public String getProcessingErrorCode() {
        return processingErrorCode;
    }

    public Long getProcessingLeaseUntilEpoch() {
        return processingLeaseUntilEpoch;
    }

    public Long getProcessingRetryAtEpoch() {
        return processingRetryAtEpoch;
    }
}
