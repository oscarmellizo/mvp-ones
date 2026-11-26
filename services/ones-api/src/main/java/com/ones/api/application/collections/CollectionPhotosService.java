package com.ones.api.application.collections;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.CloudFrontSignedUrlService;
import com.ones.api.application.photos.PhotoNotFoundException;
import com.ones.api.application.photos.PhotoNotOwnedException;
import com.ones.api.application.photos.PhotosService;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotoProcessingQueue;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.photos.PhotoOwner;

@Service
public class CollectionPhotosService {
    private static final Duration GET_URL_TTL = Duration.ofMinutes(120);

    private final CollectionService collections;
    private final PhotosRepository photos;
    private final PhotoLikesRepository likes;
    private final PhotoProcessingQueue processingQueue;
    private final ObjectStoragePresigner presigner;
    private final ObjectStorage storage;
    private final CloudFrontSignedUrlService cdn;
    private final Clock clock;
    private final String bucket;
    private final long putPresignTtlMinutes;

    public CollectionPhotosService(
            CollectionService collections,
            PhotosRepository photos,
            PhotoLikesRepository likes,
            PhotoProcessingQueue processingQueue,
            ObjectStoragePresigner presigner,
            ObjectStorage storage,
            CloudFrontSignedUrlService cdn,
            Clock clock,
            @Value("${ones.s3.events.photos.bucket}") String bucket,
            @Value("${ones.s3.events.photos.put-presign-ttl-minutes:15}") long putPresignTtlMinutes
    ) {
        this.collections = collections;
        this.photos = photos;
        this.likes = likes;
        this.processingQueue = processingQueue;
        this.presigner = presigner;
        this.storage = storage;
        this.cdn = cdn;
        this.clock = clock;
        this.bucket = bucket;
        this.putPresignTtlMinutes = putPresignTtlMinutes;
    }

    public PhotosService.PresignPutResult presignPut(
            String userId, String collectionId, String photoId, String contentType
    ) {
        collections.get(userId, collectionId);
        require(photoId, "photoId");
        String resolvedContentType = contentType == null || contentType.isBlank()
                ? "image/jpeg" : contentType.trim().toLowerCase();
        if (!"image/jpeg".equals(resolvedContentType)) {
            throw new IllegalArgumentException("Collection photos must be JPEG");
        }
        String key = originalKey(collectionId, userId, photoId);
        Instant expiresAt = Instant.now(clock).plus(Duration.ofMinutes(putPresignTtlMinutes));
        String putUrl = presigner.presignPut(
                bucket, key, Duration.ofMinutes(putPresignTtlMinutes), "image/jpeg"
        ).toString();
        return new PhotosService.PresignPutResult(photoId, putUrl, key, expiresAt);
    }

    public Photo complete(
            String userId,
            String userEmail,
            String displayName,
            String collectionId,
            String photoId,
            Instant createdAt,
            String originalKey
    ) {
        collections.get(userId, collectionId);
        require(photoId, "photoId");
        require(originalKey, "s3KeyOriginal");
        String expectedKey = originalKey(collectionId, userId, photoId);
        if (!expectedKey.equals(originalKey.trim())) {
            throw new IllegalArgumentException("Invalid collection photo upload key");
        }

        Instant now = Instant.now(clock);
        Instant capturedAt = createdAt != null && !createdAt.isAfter(now.plus(Duration.ofDays(1)))
                ? createdAt : now;
        String uploaderName = displayName == null || displayName.isBlank()
                ? userEmail : displayName.trim();
        Photo photo = new Photo(
                photoId.trim(),
                PhotoOwner.collection(collectionId),
                userId,
                capturedAt,
                now,
                "uploaded",
                expectedKey,
                null,
                null,
                uploaderName,
                userId,
                uploaderName,
                false,
                0,
                null,
                null,
                null
        );
        Photo completed = photos.completeUpload(photo);
        if (!"ready".equalsIgnoreCase(completed.getStatus())) {
            processingQueue.enqueue(new PhotoProcessingQueue.Job(
                    completed.getStoragePartitionId(),
                    completed.getPhotoId(),
                    completed.getS3KeyOriginal(),
                    "failed".equalsIgnoreCase(completed.getStatus()),
                    UUID.randomUUID().toString()
            ));
        }
        return completed;
    }

    public PhotosService.ListPage list(
            String userId,
            String collectionId,
            int limit,
            String nextToken,
            String filter,
            List<String> guestIds
    ) {
        collections.get(userId, collectionId);
        int pageSize = Math.min(Math.max(limit, 1), 50);
        PhotoOwner owner = PhotoOwner.collection(collectionId);
        String normalizedFilter = filter == null ? "" : filter.trim().toLowerCase();
        Set<String> requestedGuests = guestIds == null ? Set.of() : new HashSet<>(guestIds);
        List<PhotosService.ListItem> result = new ArrayList<>(pageSize);
        String cursor = nextToken;
        String next = null;
        int pagesRead = 0;
        while (result.size() < pageSize && pagesRead++ < 10) {
            PhotosRepository.PageResult<Photo> page =
                    photos.listByOwner(owner, pageSize, cursor);
            Set<String> photoIds = new HashSet<>();
            for (Photo photo : page.items()) {
                if (!matchesOwner(photo, owner)) continue;
                if (!photo.isShared() && !userId.equals(photo.getGuestId())) continue;
                if ("mine".equals(normalizedFilter) && !userId.equals(photo.getGuestId())) continue;
                if ("shared_by_me".equals(normalizedFilter)
                        && !userId.equals(photo.getSharedByUserId())) continue;
                if (!requestedGuests.isEmpty() && !requestedGuests.contains(photo.getGuestId())) continue;
                photoIds.add(photo.getPhotoId());
            }
            Set<String> liked = photoIds.isEmpty() ? Set.of() : likes.likedPhotoIds(userId, photoIds);
            for (Photo photo : page.items()) {
                if (!matchesOwner(photo, owner)
                        || (!photo.isShared() && !userId.equals(photo.getGuestId()))
                        || ("mine".equals(normalizedFilter) && !userId.equals(photo.getGuestId()))
                        || ("shared_by_me".equals(normalizedFilter)
                                && !userId.equals(photo.getSharedByUserId()))
                        || (!requestedGuests.isEmpty() && !requestedGuests.contains(photo.getGuestId()))) {
                    continue;
                }
                result.add(toListItem(photo, liked.contains(photo.getPhotoId())));
                if (result.size() == pageSize) break;
            }
            cursor = page.nextToken();
            next = cursor;
            if (cursor == null || cursor.isBlank()) break;
        }
        return new PhotosService.ListPage(result, next);
    }

    public PhotosService.RetryProcessingResult retry(
            String userId, String collectionId, String photoId
    ) {
        collections.get(userId, collectionId);
        Photo photo = requirePhoto(collectionId, photoId);
        if (!userId.equals(photo.getGuestId())) {
            throw new PhotoNotOwnedException(photoId);
        }
        String errorCode = photo.getProcessingErrorCode();
        if (!"failed".equalsIgnoreCase(photo.getStatus())
                || (errorCode != null
                        && Set.of("invalid_image", "source_missing", "invalid_key").contains(errorCode))) {
            throw new IllegalArgumentException("Photo processing is not retryable");
        }
        processingQueue.enqueue(new PhotoProcessingQueue.Job(
                photo.getStoragePartitionId(), photo.getPhotoId(), photo.getS3KeyOriginal(),
                true, UUID.randomUUID().toString()
        ));
        photos.markRetryRequested(photo.getStoragePartitionId(), photo.getPhotoId());
        return new PhotosService.RetryProcessingResult(photo.getPhotoId(), "retrying");
    }

    public void delete(String userId, String collectionId, List<String> photoIds) {
        var collection = collections.get(userId, collectionId);
        if (photoIds == null || photoIds.isEmpty() || photoIds.size() > 50) {
            throw new IllegalArgumentException("Delete between 1 and 50 photos");
        }
        for (String photoId : photoIds) {
            Photo photo = requirePhoto(collectionId, photoId);
            if (!userId.equals(photo.getGuestId()) && !userId.equals(collection.ownerId())) {
                throw new PhotoNotOwnedException(photoId);
            }
            deleteKey(photo.getS3KeyOriginal());
            deleteKey(variantKey(photo.getS3KeyOriginal(), "_m"));
            deleteKey(variantKey(photo.getS3KeyOriginal(), "_s"));
            likes.deleteAllByPhotoId(photo.getPhotoId());
            photos.deleteById(photo.getPhotoId());
        }
    }

    public List<Photo> share(String userId, String collectionId, List<String> photoIds) {
        return changeVisibility(userId, collectionId, photoIds, true);
    }

    public List<Photo> unshare(String userId, String collectionId, List<String> photoIds) {
        return changeVisibility(userId, collectionId, photoIds, false);
    }

    public PhotosService.SocialShareLink createSocialShareLink(
            String userId, String collectionId, String photoId, String variant
    ) {
        collections.get(userId, collectionId);
        Photo photo = requireVisiblePhoto(userId, collectionId, photoId);
        String original = photo.getS3KeyOriginal();
        String key = switch (variant == null ? "medium" : variant.trim().toLowerCase()) {
            case "original" -> original;
            case "small" -> photo.getS3KeySmall() == null
                    ? variantKey(original, "_s") : photo.getS3KeySmall();
            default -> photo.getS3KeyMedium() == null
                    ? variantKey(original, "_m") : photo.getS3KeyMedium();
        };
        CloudFrontSignedUrlService.SignedUrlResult signed = cdn.signForSocialShare(key);
        if (signed.url() != null && !signed.url().isBlank()) {
            return new PhotosService.SocialShareLink(signed.url(), signed.expiresAt());
        }
        Instant expiresAt = Instant.now(clock).plus(GET_URL_TTL);
        return new PhotosService.SocialShareLink(
                presigner.presignGet(bucket, key, GET_URL_TTL).toString(), expiresAt
        );
    }

    public boolean like(String userId, String collectionId, String photoId) {
        collections.get(userId, collectionId);
        Photo photo = requireVisiblePhoto(userId, collectionId, photoId);
        likes.like(photo.getStoragePartitionId(), photo.getPhotoId(), userId, Instant.now(clock));
        return true;
    }

    public boolean unlike(String userId, String collectionId, String photoId) {
        collections.get(userId, collectionId);
        Photo photo = requireVisiblePhoto(userId, collectionId, photoId);
        likes.unlike(photo.getPhotoId(), userId);
        return false;
    }

    public void purgeMetadata(String collectionId) {
        String cursor = null;
        do {
            PhotosRepository.PageResult<Photo> page = photos.listByOwner(
                    PhotoOwner.collection(collectionId), 50, cursor
            );
            for (Photo photo : page.items()) {
                likes.deleteAllByPhotoId(photo.getPhotoId());
                photos.deleteById(photo.getPhotoId());
            }
            cursor = page.nextToken();
        } while (cursor != null && !cursor.isBlank());
    }

    public PhotosService.PhotoRecoveryResult recoverInternal(
            String collectionId, String photoId, String originalKey, Instant createdAt
    ) {
        collections.ensureActiveForInternalWork(collectionId);
        String expectedPrefix = "colecciones/" + collectionId + "/guests/";
        if (originalKey == null || !originalKey.startsWith(expectedPrefix)
                || !originalKey.endsWith("/private/" + photoId + ".jpg")) {
            throw new IllegalArgumentException("Invalid collection photo key");
        }
        Photo existing = photos.findById(photoId).orElse(null);
        if (existing != null) {
            if (!matchesOwner(existing, PhotoOwner.collection(collectionId))
                    || !originalKey.equals(existing.getS3KeyOriginal())) {
                throw new IllegalArgumentException("Collection photo recovery conflict");
            }
            return new PhotosService.PhotoRecoveryResult(existing, false);
        }
        String[] parts = originalKey.split("/");
        if (parts.length != 6) throw new IllegalArgumentException("Invalid collection photo key");
        Photo recovered = photos.completeUpload(new Photo(
                photoId,
                PhotoOwner.collection(collectionId),
                parts[3],
                createdAt == null ? Instant.now(clock) : createdAt,
                Instant.now(clock),
                "uploaded",
                originalKey,
                null,
                null,
                null,
                parts[3],
                null,
                true,
                0,
                null,
                null,
                null
        ));
        processingQueue.enqueue(new PhotoProcessingQueue.Job(
                recovered.getStoragePartitionId(), photoId, originalKey, false,
                UUID.randomUUID().toString()
        ));
        return new PhotosService.PhotoRecoveryResult(recovered, true);
    }

    private PhotosService.ListItem toListItem(Photo photo, boolean liked) {
        String original = photo.getS3KeyOriginal();
        String medium = photo.getS3KeyMedium() == null ? variantKey(original, "_m") : photo.getS3KeyMedium();
        String small = photo.getS3KeySmall() == null ? variantKey(original, "_s") : photo.getS3KeySmall();
        boolean ready = "ready".equalsIgnoreCase(photo.getStatus());
        return new PhotosService.ListItem(
                photo.getPhotoId(), photo.getGuestId(), photo.getCreatedAt(), photo.getUploadedAt(),
                photo.getStatus(), signedUrl(original), ready ? signedUrl(medium) : null,
                ready ? signedUrl(small) : null, true, photo.getOwnerName(),
                photo.getSharedByUserId(), photo.getSharedByName(), liked,
                photo.getProcessingAttempts(), photo.getProcessingErrorCode(),
                "failed".equalsIgnoreCase(photo.getStatus())
                        && (photo.getProcessingErrorCode() == null
                                || !Set.of("invalid_image", "source_missing", "invalid_key")
                                        .contains(photo.getProcessingErrorCode()))
        );
    }

    private List<Photo> changeVisibility(
            String userId, String collectionId, List<String> photoIds, boolean shared
    ) {
        collections.get(userId, collectionId);
        if (photoIds == null || photoIds.isEmpty() || photoIds.size() > 50) {
            throw new IllegalArgumentException("Select between 1 and 50 photos");
        }
        List<Photo> changed = new ArrayList<>(photoIds.size());
        for (String photoId : photoIds) {
            Photo photo = requirePhoto(collectionId, photoId);
            if (!userId.equals(photo.getGuestId())) throw new PhotoNotOwnedException(photoId);
            if (photo.isShared() == shared) {
                changed.add(photo);
                continue;
            }
            if (!"ready".equalsIgnoreCase(photo.getStatus())) {
                throw new IllegalArgumentException("Only processed photos can be shared");
            }
            String oldOriginal = photo.getS3KeyOriginal();
            String newOriginal = shared
                    ? sharedKey(collectionId, photo.getPhotoId())
                    : originalKey(collectionId, photo.getGuestId(), photo.getPhotoId());
            String oldMedium = photo.getS3KeyMedium() == null
                    ? variantKey(oldOriginal, "_m") : photo.getS3KeyMedium();
            String oldSmall = photo.getS3KeySmall() == null
                    ? variantKey(oldOriginal, "_s") : photo.getS3KeySmall();
            String newMedium = variantKey(newOriginal, "_m");
            String newSmall = variantKey(newOriginal, "_s");

            storage.copy(bucket, oldOriginal, bucket, newOriginal);
            storage.copy(bucket, oldMedium, bucket, newMedium);
            storage.copy(bucket, oldSmall, bucket, newSmall);
            Photo updated = new Photo(
                    photo.getPhotoId(), photo.getOwner(), photo.getGuestId(), photo.getCreatedAt(),
                    photo.getUploadedAt(), photo.getStatus(), newOriginal, newMedium, newSmall,
                    photo.getOwnerName(), shared ? userId : null,
                    shared ? photo.getOwnerName() : null, shared, photo.getProcessingAttempts(),
                    photo.getProcessingErrorCode(), photo.getProcessingLeaseUntilEpoch(),
                    photo.getProcessingRetryAtEpoch()
            );
            if (!photos.updateVisibility(photo, updated)) {
                throw new CollectionConflictException("Photo visibility changed concurrently; refresh and retry");
            }
            deleteKeyBestEffort(oldOriginal);
            deleteKeyBestEffort(oldMedium);
            deleteKeyBestEffort(oldSmall);
            changed.add(updated);
        }
        return changed;
    }

    private String signedUrl(String key) {
        if (key == null || key.isBlank()) return null;
        var signed = cdn.signForParticipants(key);
        return signed.url() == null || signed.url().isBlank()
                ? presigner.presignGet(bucket, key, GET_URL_TTL).toString()
                : signed.url();
    }

    private Photo requirePhoto(String collectionId, String photoId) {
        Photo photo = photos.findById(photoId)
                .orElseThrow(() -> new PhotoNotFoundException(photoId));
        if (!matchesOwner(photo, PhotoOwner.collection(collectionId))) {
            throw new PhotoNotFoundException(photoId);
        }
        return photo;
    }

    private Photo requireVisiblePhoto(String userId, String collectionId, String photoId) {
        Photo photo = requirePhoto(collectionId, photoId);
        if (!photo.isShared() && !userId.equals(photo.getGuestId())) {
            throw new PhotoNotFoundException(photoId);
        }
        return photo;
    }

    private static boolean matchesOwner(Photo photo, PhotoOwner owner) {
        return photo != null && photo.getOwner().equals(owner);
    }

    private void deleteKey(String key) {
        if (key == null || key.isBlank()) return;
        storage.delete(bucket, key);
    }

    private void deleteKeyBestEffort(String key) {
        try {
            deleteKey(key);
        } catch (RuntimeException ignored) {
            // The new DynamoDB keys are already committed; old copies are harmless orphans.
        }
    }

    private static String originalKey(String collectionId, String userId, String photoId) {
        return "colecciones/" + collectionId + "/guests/" + userId + "/private/" + photoId + ".jpg";
    }

    private static String sharedKey(String collectionId, String photoId) {
        return "colecciones/" + collectionId + "/shared/" + photoId + ".jpg";
    }

    private static String variantKey(String original, String suffix) {
        if (original == null || original.isBlank()) return null;
        return original.endsWith(".jpg")
                ? original.substring(0, original.length() - 4) + suffix + ".jpg"
                : original + suffix;
    }

    private static void require(String value, String name) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(name + " is required");
    }
}
