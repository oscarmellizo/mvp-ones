package com.ones.api.application.photos;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

@Service
public class PhotosService {

    private final PhotosRepository photosRepository;
    private final GetEventUseCase getEventUseCase;
    private final EventsRepository eventsRepository;
    private final ObjectStoragePresigner objectStoragePresigner;
    private final ObjectStorage objectStorage;
    private final Clock clock;

    private final String photosBucket;
    private final long putPresignTtlMinutes;
    private final long getPresignTtlMinutes;

    public PhotosService(
            PhotosRepository photosRepository,
            GetEventUseCase getEventUseCase,
            EventsRepository eventsRepository,
            ObjectStoragePresigner objectStoragePresigner,
            ObjectStorage objectStorage,
            Clock clock,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket,
            @Value("${ones.s3.events.photos.put-presign-ttl-minutes:15}") long putPresignTtlMinutes,
            @Value("${ones.s3.events.photos.get-presign-ttl-minutes:15}") long getPresignTtlMinutes
    ) {
        this.photosRepository = photosRepository;
        this.getEventUseCase = getEventUseCase;
        this.eventsRepository = eventsRepository;
        this.objectStoragePresigner = objectStoragePresigner;
        this.objectStorage = objectStorage;
        this.clock = clock;
        this.photosBucket = photosBucket;
        this.putPresignTtlMinutes = putPresignTtlMinutes;
        this.getPresignTtlMinutes = getPresignTtlMinutes;
    }

    public PresignPutResult presignPut(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            String contentType
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        String guestId = requesterUserId;
        String key = originalKey(event.getEventId(), guestId, photoId);

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(Duration.ofMinutes(putPresignTtlMinutes));

        String resolvedContentType = (contentType == null || contentType.isBlank()) ? "image/jpeg" : contentType.trim();

        String putUrl = objectStoragePresigner
                .presignPut(photosBucket, key, Duration.ofMinutes(putPresignTtlMinutes), resolvedContentType)
                .toString();

        return new PresignPutResult(photoId, putUrl, key, expiresAt);
    }

    public Photo complete(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            Instant createdAt,
            String s3KeyOriginal
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");
        require(s3KeyOriginal, "s3KeyOriginal");

        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Instant now = Instant.now(clock);
        Instant resolvedCreatedAt = createdAt != null ? createdAt : now;

        Photo photo = new Photo(
                photoId,
                event.getEventId(),
                requesterUserId,
                resolvedCreatedAt,
                now,
                "uploaded",
                s3KeyOriginal,
                null,
                null
        );

        return photosRepository.upsert(photo);
    }

    public ListPage list(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            int limit,
            String nextToken,
            String scope
    ) {
        require(eventId, "eventId");

        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        String resolvedScope = scope != null ? scope.trim().toLowerCase() : "";

        int resolvedLimit = limit <= 0 ? 10 : Math.min(limit, 50);

        boolean guestOnly = "guest".equals(resolvedScope);
        boolean sharedOnly = "shared".equals(resolvedScope);

        List<ListItem> out = new ArrayList<>(resolvedLimit);
        String cursor = nextToken;
        String outNextToken = null;

        while (out.size() < resolvedLimit) {
            PhotosRepository.PageResult<Photo> page = photosRepository.listByEventId(eventId, resolvedLimit, cursor);

            for (Photo p : page.items()) {
                boolean isShared = isShared(p);

                if (sharedOnly && !isShared) {
                    continue;
                }

                if (guestOnly) {
                    if (p.getGuestId() == null || !p.getGuestId().equals(requesterUserId)) {
                        continue;
                    }
                    if (isShared) {
                        continue;
                    }
                }

                String originalUrl = presignGetIfAny(p.getS3KeyOriginal());
                String mediumUrl = presignGetIfAny(p.getS3KeyMedium());
                String smallUrl = presignGetIfAny(p.getS3KeySmall());

                out.add(new ListItem(
                        p.getPhotoId(),
                        p.getGuestId(),
                        p.getCreatedAt(),
                        p.getUploadedAt(),
                        p.getStatus(),
                        originalUrl,
                        mediumUrl,
                        smallUrl
                ));

                if (out.size() >= resolvedLimit) {
                    break;
                }
            }

            if (page.nextToken() == null || page.nextToken().isBlank()) {
                outNextToken = null;
                break;
            }

            cursor = page.nextToken();
            outNextToken = cursor;
        }

        return new ListPage(out, outNextToken);
    }

    public List<Photo> sharePhotos(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            List<String> photoIds
    ) {
        require(eventId, "eventId");
        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        if (photoIds == null || photoIds.isEmpty()) {
            return List.of();
        }

        List<Photo> updated = new ArrayList<>(photoIds.size());
        for (String rawId : photoIds) {
            if (rawId == null || rawId.isBlank()) {
                continue;
            }
            String photoId = rawId.trim();

            Photo existing = photosRepository.findById(photoId).orElse(null);
            if (existing == null) {
                continue;
            }

            if (existing.getEventId() == null || !existing.getEventId().equals(eventId)) {
                continue;
            }

            Event event = eventsRepository.findById(eventId.trim()).orElse(null);
            if (event == null) {
                continue;
            }

            boolean isOwner = requesterUserId != null && requesterUserId.equals(event.getOwnerId());
            boolean isPhotoOwner = requesterUserId != null && requesterUserId.equals(existing.getGuestId());
            if (!isOwner && !isPhotoOwner) {
                continue;
            }

            if (isShared(existing)) {
                updated.add(existing);
                continue;
            }

            String nextOriginal = sharedKey(eventId, photoId, "");
            String nextMedium = sharedKey(eventId, photoId, "_m");
            String nextSmall = sharedKey(eventId, photoId, "_s");

            String sourceOriginal = existing.getS3KeyOriginal();
            String sourceMedium = existing.getS3KeyMedium();
            String sourceSmall = existing.getS3KeySmall();

            if ((sourceMedium == null || sourceMedium.isBlank()) && sourceOriginal != null && !sourceOriginal.isBlank()) {
                sourceMedium = variantKeyFromOriginal(sourceOriginal, "_m");
            }
            if ((sourceSmall == null || sourceSmall.isBlank()) && sourceOriginal != null && !sourceOriginal.isBlank()) {
                sourceSmall = variantKeyFromOriginal(sourceOriginal, "_s");
            }

            moveIfPresent(sourceOriginal, nextOriginal);
            moveIfPresent(sourceMedium, nextMedium);
            moveIfPresent(sourceSmall, nextSmall);

            Photo next = new Photo(
                    existing.getPhotoId(),
                    existing.getEventId(),
                    existing.getGuestId(),
                    existing.getCreatedAt(),
                    existing.getUploadedAt(),
                    existing.getStatus(),
                    nextOriginal,
                    nextMedium,
                    nextSmall
            );

            updated.add(photosRepository.upsert(next));
        }

        return updated;
    }

    public Photo markReady(
            String requesterUserId,
            String requesterEmail,
            String eventId,
            String photoId,
            String s3KeyMedium,
            String s3KeySmall
    ) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Photo existing = photosRepository.findById(photoId).orElse(null);
        if (existing == null) {
            Instant now = Instant.now(clock);
            Photo created = new Photo(
                    photoId,
                    eventId,
                    requesterUserId,
                    now,
                    now,
                    "ready",
                    null,
                    s3KeyMedium,
                    s3KeySmall
            );
            return photosRepository.upsert(created);
        }

        Photo updated = new Photo(
                existing.getPhotoId(),
                existing.getEventId(),
                existing.getGuestId(),
                existing.getCreatedAt(),
                existing.getUploadedAt(),
                "ready",
                existing.getS3KeyOriginal(),
                s3KeyMedium != null && !s3KeyMedium.isBlank() ? s3KeyMedium.trim() : existing.getS3KeyMedium(),
                s3KeySmall != null && !s3KeySmall.isBlank() ? s3KeySmall.trim() : existing.getS3KeySmall()
        );

        return photosRepository.upsert(updated);
    }

    public Photo markReadyInternal(String eventId, String photoId, String s3KeyMedium, String s3KeySmall) {
        require(eventId, "eventId");
        require(photoId, "photoId");

        Event event = eventsRepository.findById(eventId.trim()).orElse(null);
        if (event == null) {
            throw new IllegalArgumentException("Missing event");
        }

        Photo existing = photosRepository.findById(photoId).orElse(null);
        Instant now = Instant.now(clock);

        if (existing == null) {
            Photo created = new Photo(
                    photoId,
                    event.getEventId(),
                    "internal",
                    now,
                    now,
                    "ready",
                    null,
                    s3KeyMedium,
                    s3KeySmall
            );
            return photosRepository.upsert(created);
        }

        Photo updated = new Photo(
                existing.getPhotoId(),
                existing.getEventId(),
                existing.getGuestId(),
                existing.getCreatedAt(),
                existing.getUploadedAt(),
                "ready",
                existing.getS3KeyOriginal(),
                s3KeyMedium != null && !s3KeyMedium.isBlank() ? s3KeyMedium.trim() : existing.getS3KeyMedium(),
                s3KeySmall != null && !s3KeySmall.isBlank() ? s3KeySmall.trim() : existing.getS3KeySmall()
        );

        return photosRepository.upsert(updated);
    }

    private String presignGetIfAny(String key) {
        if (key == null || key.isBlank()) {
            return null;
        }
        return objectStoragePresigner
                .presignGet(photosBucket, key.trim(), Duration.ofMinutes(getPresignTtlMinutes))
                .toString();
    }

    private static String originalKey(String eventId, String guestId, String photoId) {
        return "eventos/" + eventId + "/guests/" + guestId + "/private/" + photoId + ".jpg";
    }

    private static String sharedBaseKey(String eventId, String photoId) {
        return "eventos/" + eventId + "/shared/" + photoId;
    }

    private static boolean isShared(Photo p) {
        if (p == null) {
            return false;
        }
        return isSharedKey(p.getS3KeyOriginal()) || isSharedKey(p.getS3KeyMedium()) || isSharedKey(p.getS3KeySmall());
    }

    private static boolean isSharedKey(String key) {
        if (key == null || key.isBlank()) {
            return false;
        }
        return key.contains("/shared/");
    }

    private static String sharedKey(String eventId, String photoId, String suffix) {
        if (eventId == null || eventId.isBlank() || photoId == null || photoId.isBlank()) {
            return null;
        }
        String sfx = suffix != null ? suffix : "";
        return sharedBaseKey(eventId.trim(), photoId.trim()) + sfx + ".jpg";
    }

    private static String variantKeyFromOriginal(String originalKey, String suffix) {
        if (originalKey == null || originalKey.isBlank()) {
            return null;
        }
        String key = originalKey.trim();
        String sfx = suffix != null ? suffix : "";
        if (key.endsWith(".jpg")) {
            return key.substring(0, key.length() - 4) + sfx + ".jpg";
        }
        if (key.endsWith(".jpeg")) {
            return key.substring(0, key.length() - 5) + sfx + ".jpeg";
        }
        return key + sfx;
    }

    private void moveIfPresent(String sourceKey, String destinationKey) {
        if (sourceKey == null || sourceKey.isBlank() || destinationKey == null || destinationKey.isBlank()) {
            return;
        }
        String src = sourceKey.trim();
        String dst = destinationKey.trim();
        if (src.equals(dst)) {
            return;
        }
        objectStorage.copy(photosBucket, src, photosBucket, dst);
        try {
            objectStorage.delete(photosBucket, src);
        } catch (Exception ignored) {
        }
    }

    private static void require(String s, String name) {
        if (s == null || s.isBlank()) {
            throw new IllegalArgumentException("Missing " + name);
        }
    }

    public record PresignPutResult(String photoId, String putUrl, String s3KeyOriginal, Instant expiresAt) {
    }

    public record ListPage(List<ListItem> items, String nextToken) {
    }

    public record ListItem(
            String photoId,
            String guestId,
            Instant createdAt,
            Instant uploadedAt,
            String status,
            String originalUrl,
            String mediumUrl,
            String smallUrl
    ) {
    }
}
