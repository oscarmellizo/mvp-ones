package com.ones.api.application.photos.ports;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.ones.api.domain.photos.Photo;

public interface PhotosRepository {

    Optional<Photo> findById(String photoId);

    Photo upsert(Photo photo);

    Photo completeUpload(Photo photo);

    ProcessingClaim claimProcessing(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            boolean manualRetry,
            Instant now,
            Instant leaseUntil
    );

    Optional<Photo> markProcessingRetrying(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String errorCode,
            Instant retryAt
    );

    Optional<Photo> markProcessingFailed(String eventId, String photoId, String s3KeyOriginal, String errorCode);

    Optional<Photo> markRetryRequested(String eventId, String photoId);

    Photo markReadyInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String s3KeyMedium,
            String s3KeySmall,
            Instant now
    );

    PageResult<Photo> listByEventId(String eventId, int limit, String nextToken);

    PageResult<Photo> listByGuestId(String guestId, int limit, String nextToken);

    PageResult<Photo> listAll(int limit, String nextToken);

    long countByEventId(String eventId);

    void deleteById(String photoId);

    record PageResult<T>(List<T> items, String nextToken) {
    }

    enum ProcessingClaimStatus {
        CLAIMED,
        READY,
        BUSY,
        NOT_FOUND,
        FAILED,
        CONFLICT
    }

    record ProcessingClaim(ProcessingClaimStatus status, Photo photo) {
    }
}
