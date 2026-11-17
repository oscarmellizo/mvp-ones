package com.ones.api.application.photos;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anySet;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.net.URL;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.application.photos.ports.PhotoProcessingQueue;
import com.ones.api.application.users.GetUserByIdUseCase;
import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

class PhotosServiceAutoShareTest {

    private static final String EVENT_ID = "event-1";
    private static final String UPLOADER_ID = "uploader-1";
    private static final String UPLOADER_EMAIL = "uploader@example.com";
    private static final String PHOTO_ID = "photo-1";
    private static final Instant CREATED_AT = Instant.parse("2025-01-01T12:00:00Z");
    private static final String ORIGINAL_KEY =
            "eventos/event-1/guests/uploader-1/private/photo-1.jpg";

    private final FakePhotosRepository photos = new FakePhotosRepository();
    private final GetEventUseCase eventAccess = mock(GetEventUseCase.class);
    private final EventsRepository events = mock(EventsRepository.class);
    private final PreferredNamesCacheRepository names =
            mock(PreferredNamesCacheRepository.class);
    private final GetUserByIdUseCase users = mock(GetUserByIdUseCase.class);
    private final PhotoLikesRepository likes = mock(PhotoLikesRepository.class);
    private final PhotoProcessingQueue processingQueue = mock(PhotoProcessingQueue.class);
    private final ObjectStorage storage = mock(ObjectStorage.class);
    private final ObjectStoragePresigner presigner = mock(ObjectStoragePresigner.class);
    private final CloudFrontSignedUrlService cdn = mock(CloudFrontSignedUrlService.class);
    private final Event event = mock(Event.class);
    private PhotosService service;

    @BeforeEach
    void setUp() throws Exception {
        when(event.getEventId()).thenReturn(EVENT_ID);
        when(event.getOwnerId()).thenReturn("owner-1");
        when(eventAccess.execute(anyString(), anyString(), eq(EVENT_ID))).thenReturn(event);
        when(events.findById(EVENT_ID)).thenReturn(Optional.of(event));
        when(names.getMany(anySet())).thenAnswer(invocation -> {
            Map<String, PreferredNamesCacheRepository.CachedPreferredName> cached =
                    new HashMap<>();
            Set<String> userIds = invocation.getArgument(0);
            Instant expiresAt = Instant.now().plusSeconds(3600);
            for (String userId : userIds) {
                cached.put(userId, new PreferredNamesCacheRepository.CachedPreferredName(
                        userId,
                        userId.equals(UPLOADER_ID) ? "Uploader" : "Member",
                        Instant.now(),
                        expiresAt
                ));
            }
            return cached;
        });
        when(likes.likedPhotoIds(anyString(), anySet())).thenReturn(Set.of());
        when(cdn.signForParticipants(anyString())).thenReturn(
                new CloudFrontSignedUrlService.SignedUrlResult(
                        "https://cdn.example/photo.jpg",
                        Instant.now().plusSeconds(3600)
                )
        );
        when(presigner.presignGet(anyString(), anyString(), any()))
                .thenReturn(new URL("https://s3.example/photo.jpg"));
        service = new PhotosService(
                photos, likes, processingQueue, eventAccess, events, null, users, names,
                presigner, storage, cdn, null, Clock.systemUTC(), "photos", 15, false
        );
    }

    @Test
    void completeMarksNewPhotoSharedAndVisibleToAnotherEventMember() {
        Photo photo = complete();
        photos.upsert(new Photo(
                "photo-private",
                EVENT_ID,
                "another-uploader",
                CREATED_AT,
                CREATED_AT,
                "ready",
                "eventos/event-1/guests/another-uploader/private/photo-private.jpg",
                null,
                null
        ));

        assertTrue(photo.isShared());
        assertEquals(UPLOADER_ID, photo.getSharedByUserId());
        assertEquals("Uploader", photo.getSharedByName());
        assertEquals(ORIGINAL_KEY, photo.getS3KeyOriginal());
        verify(processingQueue).enqueue(org.mockito.ArgumentMatchers.argThat(job ->
                !job.manualRetry()
                        && EVENT_ID.equals(job.eventId())
                        && PHOTO_ID.equals(job.photoId())
                        && ORIGINAL_KEY.equals(job.s3KeyOriginal())
        ));

        PhotosService.ListPage page = service.list(
                "member-1", "member@example.com", EVENT_ID, 10, null, null
        );
        assertEquals(List.of(PHOTO_ID), page.items().stream()
                .map(PhotosService.ListItem::photoId).toList());
        assertTrue(page.items().get(0).shared());

        when(eventAccess.execute("stranger", "stranger@example.com", EVENT_ID))
                .thenThrow(new IllegalStateException("Event access denied"));
        assertThrows(IllegalStateException.class, () -> service.list(
                "stranger", "stranger@example.com", EVENT_ID, 10, null, null
        ));
    }

    @Test
    void completeRejectsKeyNotGeneratedForThisPhotoAndUser() {
        assertThrows(IllegalArgumentException.class, () -> service.complete(
                UPLOADER_ID,
                UPLOADER_EMAIL,
                EVENT_ID,
                PHOTO_ID,
                CREATED_AT,
                "eventos/event-2/guests/uploader-1/private/photo-1.jpg"
        ));
        assertTrue(photos.items.isEmpty());
    }

    @Test
    void completeStillSucceedsIfBackupQueueSendFails() {
        doThrow(new IllegalStateException("queue unavailable"))
                .when(processingQueue).enqueue(any());

        Photo photo = assertDoesNotThrow(this::complete);

        assertTrue(photo.isShared());
        verify(processingQueue).enqueue(any());
    }

    @Test
    void thumbnailCallbackBeforeCompleteDoesNotCreateRecordAndRetryDoesNotReshare() {
        assertThrows(IllegalArgumentException.class, () -> service.markReadyInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY,
                ORIGINAL_KEY.replace(".jpg", "_m.jpg"),
                ORIGINAL_KEY.replace(".jpg", "_s.jpg")
        ));

        Photo uploaded = complete();
        assertEquals("uploaded", uploaded.getStatus());

        Photo ready = photos.findById(PHOTO_ID).orElseThrow();
        ready = service.markReadyInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY,
                ORIGINAL_KEY.replace(".jpg", "_m.jpg"),
                ORIGINAL_KEY.replace(".jpg", "_s.jpg")
        );
        assertTrue(ready.isShared());
        assertEquals("ready", ready.getStatus());
        assertEquals(ORIGINAL_KEY.replace(".jpg", "_m.jpg"), ready.getS3KeyMedium());

        service.unsharePhotos(UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, List.of(PHOTO_ID));
        assertFalse(complete().isShared());
        assertFalse(photos.findById(PHOTO_ID).orElseThrow().isShared());
    }

    @Test
    void manualProcessingRetryUsesStoredKeyAndIsLimitedToUploader() {
        complete();
        photos.items.put(PHOTO_ID, new Photo(
                PHOTO_ID, EVENT_ID, UPLOADER_ID, CREATED_AT, CREATED_AT,
                "failed", ORIGINAL_KEY, null, null, "Uploader", UPLOADER_ID, "Uploader", true,
                5, "retry_exhausted", null, null
        ));

        assertThrows(RuntimeException.class, () -> service.retryFailedProcessing(
                "member-1", "member@example.com", EVENT_ID, PHOTO_ID
        ));

        PhotosService.RetryProcessingResult result = service.retryFailedProcessing(
                UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, PHOTO_ID
        );

        assertEquals("retrying", result.status());
        assertEquals("retrying", photos.findById(PHOTO_ID).orElseThrow().getStatus());
        verify(processingQueue).enqueue(org.mockito.ArgumentMatchers.argThat(job ->
                job.manualRetry()
                        && EVENT_ID.equals(job.eventId())
                        && PHOTO_ID.equals(job.photoId())
                        && ORIGINAL_KEY.equals(job.s3KeyOriginal())
        ));
    }

    @Test
    void processingFailureIsVisibleAndCanBeRetriedWithoutChangingShareState() {
        Photo completed = complete();
        assertTrue(completed.isShared());

        PhotosRepository.ProcessingClaim claim = service.claimProcessingInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY, false
        );
        assertEquals(PhotosRepository.ProcessingClaimStatus.CLAIMED, claim.status());
        assertTrue(claim.photo().isShared());

        Photo retrying = service.markProcessingRetryingInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY, "s3_unavailable", Instant.now().plusSeconds(5)
        ).orElseThrow();
        assertEquals("retrying", retrying.getStatus());
        assertEquals("s3_unavailable", retrying.getProcessingErrorCode());
        assertTrue(retrying.isShared());

        Photo failed = service.markProcessingFailedInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY, "retry_exhausted"
        ).orElseThrow();
        assertEquals("failed", failed.getStatus());
        assertTrue(failed.isShared());

        PhotosService.ListItem item = service.list(
                "member-1", "member@example.com", EVENT_ID, 10, null, null
        ).items().get(0);
        assertEquals("failed", item.status());
        assertTrue(item.processingRetryable());
        assertEquals("retry_exhausted", item.processingErrorCode());

        PhotosService.RetryProcessingResult retried = service.retryFailedProcessing(
                UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, PHOTO_ID
        );
        assertEquals("retrying", retried.status());
        Photo claimedAgain = service.claimProcessingInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY, true
        ).photo();
        assertEquals("processing", claimedAgain.getStatus());
        assertTrue(claimedAgain.isShared());
    }

    @Test
    void retryAfterUnsharingNeverMakesPhotoSharedAgain() {
        complete();
        service.unsharePhotos(UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, List.of(PHOTO_ID));
        service.markProcessingFailedInternal(EVENT_ID, PHOTO_ID, ORIGINAL_KEY, "retry_exhausted");

        service.retryFailedProcessing(UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, PHOTO_ID);
        Photo claimed = service.claimProcessingInternal(
                EVENT_ID, PHOTO_ID, ORIGINAL_KEY, true
        ).photo();

        assertEquals("processing", claimed.getStatus());
        assertFalse(claimed.isShared());
    }

    @Test
    void thumbnailAfterCompletePreservesSharedState() {
        complete();

        Photo ready = service.markReadyInternal(
                EVENT_ID,
                PHOTO_ID,
                ORIGINAL_KEY,
                ORIGINAL_KEY.replace(".jpg", "_m.jpg"),
                ORIGINAL_KEY.replace(".jpg", "_s.jpg")
        );

        assertTrue(ready.isShared());
        assertEquals(UPLOADER_ID, ready.getSharedByUserId());
        assertTrue(photos.findById(PHOTO_ID).orElseThrow().isShared());
    }

    @Test
    void unsharingNewPrivateKeyDoesNotCopyObjectsAndAllowsDeletion() {
        complete();

        Photo unshared = service.unsharePhotos(
                UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, List.of(PHOTO_ID)
        ).get(0);

        assertFalse(unshared.isShared());
        assertEquals(ORIGINAL_KEY, unshared.getS3KeyOriginal());
        verify(storage, never()).copy(anyString(), anyString(), anyString(), anyString());

        service.deletePhotos(UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, List.of(PHOTO_ID));
        assertTrue(photos.items.isEmpty());
    }

    @Test
    void legacySharedKeyStillUsesTheExistingUnsharePath() {
        String sharedKey = "eventos/event-1/shared/photo-legacy.jpg";
        photos.upsert(new Photo(
                "photo-legacy", EVENT_ID, UPLOADER_ID, CREATED_AT, CREATED_AT,
                "ready", sharedKey, sharedKey.replace(".jpg", "_m.jpg"),
                sharedKey.replace(".jpg", "_s.jpg")
        ));

        Photo unshared = service.unsharePhotos(
                UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, List.of("photo-legacy")
        ).get(0);

        assertFalse(unshared.isShared());
        assertTrue(unshared.getS3KeyOriginal().contains("/private/"));
        verify(storage).copy("photos", sharedKey, "photos", unshared.getS3KeyOriginal());
    }

    private Photo complete() {
        return service.complete(
                UPLOADER_ID, UPLOADER_EMAIL, EVENT_ID, PHOTO_ID, CREATED_AT, ORIGINAL_KEY
        );
    }

    private static final class FakePhotosRepository implements PhotosRepository {
        private final Map<String, Photo> items = new HashMap<>();

        @Override
        public Optional<Photo> findById(String photoId) {
            return Optional.ofNullable(items.get(photoId));
        }

        @Override
        public Photo upsert(Photo photo) {
            items.put(photo.getPhotoId(), photo);
            return photo;
        }

        @Override
        public Photo completeUpload(Photo photo) {
            Photo existing = items.get(photo.getPhotoId());
            if (existing == null) {
                items.put(photo.getPhotoId(), new Photo(
                        photo.getPhotoId(), photo.getEventId(), photo.getGuestId(),
                        photo.getCreatedAt(), photo.getUploadedAt(), photo.getStatus(),
                        photo.getS3KeyOriginal(),
                        photo.getS3KeyMedium(),
                        photo.getS3KeySmall(),
                        photo.getOwnerName(), photo.getSharedByUserId(),
                        photo.getSharedByName(), true
                ));
                return items.get(photo.getPhotoId());
            }
            if (!photo.getEventId().equals(existing.getEventId())
                    || !photo.getGuestId().equals(existing.getGuestId())
                    || !photo.getS3KeyOriginal().equals(existing.getS3KeyOriginal())) {
                throw new IllegalStateException("Photo upload conflicts with an existing photo");
            }
            return existing;
        }

        @Override
        public ProcessingClaim claimProcessing(
                String eventId,
                String photoId,
                String s3KeyOriginal,
                boolean manualRetry,
                Instant now,
                Instant leaseUntil
        ) {
            Photo existing = items.get(photoId);
            if (existing == null) return new ProcessingClaim(ProcessingClaimStatus.NOT_FOUND, null);
            if (!eventId.equals(existing.getEventId()) || !s3KeyOriginal.equals(existing.getS3KeyOriginal())) {
                return new ProcessingClaim(ProcessingClaimStatus.CONFLICT, existing);
            }
            if ("ready".equalsIgnoreCase(existing.getStatus())) {
                return new ProcessingClaim(ProcessingClaimStatus.READY, existing);
            }
            if ("failed".equalsIgnoreCase(existing.getStatus()) && !manualRetry) {
                return new ProcessingClaim(ProcessingClaimStatus.FAILED, existing);
            }
            if ("processing".equalsIgnoreCase(existing.getStatus())
                    && existing.getProcessingLeaseUntilEpoch() != null
                    && existing.getProcessingLeaseUntilEpoch() > now.toEpochMilli()) {
                return new ProcessingClaim(ProcessingClaimStatus.BUSY, existing);
            }
            int attempts = "failed".equalsIgnoreCase(existing.getStatus())
                    ? 1
                    : existing.getProcessingAttempts() + 1;
            Photo claimed = new Photo(
                    existing.getPhotoId(), existing.getEventId(), existing.getGuestId(),
                    existing.getCreatedAt(), existing.getUploadedAt(), "processing",
                    existing.getS3KeyOriginal(), existing.getS3KeyMedium(), existing.getS3KeySmall(),
                    existing.getOwnerName(), existing.getSharedByUserId(), existing.getSharedByName(),
                    existing.isShared(), attempts, null, leaseUntil.toEpochMilli(), null
            );
            items.put(photoId, claimed);
            return new ProcessingClaim(ProcessingClaimStatus.CLAIMED, claimed);
        }

        @Override
        public Optional<Photo> markProcessingRetrying(
                String eventId,
                String photoId,
                String s3KeyOriginal,
                String errorCode,
                Instant retryAt
        ) {
            Photo existing = items.get(photoId);
            if (existing == null
                    || !eventId.equals(existing.getEventId())
                    || !s3KeyOriginal.equals(existing.getS3KeyOriginal())) {
                return Optional.empty();
            }
            Photo next = new Photo(
                    existing.getPhotoId(), existing.getEventId(), existing.getGuestId(),
                    existing.getCreatedAt(), existing.getUploadedAt(), "retrying",
                    existing.getS3KeyOriginal(), existing.getS3KeyMedium(), existing.getS3KeySmall(),
                    existing.getOwnerName(), existing.getSharedByUserId(), existing.getSharedByName(),
                    existing.isShared(), existing.getProcessingAttempts(), errorCode, null, retryAt.toEpochMilli()
            );
            items.put(photoId, next);
            return Optional.of(next);
        }

        @Override
        public Optional<Photo> markProcessingFailed(
                String eventId,
                String photoId,
                String s3KeyOriginal,
                String errorCode
        ) {
            Photo existing = items.get(photoId);
            if (existing == null
                    || !eventId.equals(existing.getEventId())
                    || !s3KeyOriginal.equals(existing.getS3KeyOriginal())) {
                return Optional.empty();
            }
            if ("ready".equalsIgnoreCase(existing.getStatus())) return Optional.of(existing);
            Photo next = new Photo(
                    existing.getPhotoId(), existing.getEventId(), existing.getGuestId(),
                    existing.getCreatedAt(), existing.getUploadedAt(), "failed",
                    existing.getS3KeyOriginal(), existing.getS3KeyMedium(), existing.getS3KeySmall(),
                    existing.getOwnerName(), existing.getSharedByUserId(), existing.getSharedByName(),
                    existing.isShared(), existing.getProcessingAttempts(), errorCode, null, null
            );
            items.put(photoId, next);
            return Optional.of(next);
        }

        @Override
        public Optional<Photo> markRetryRequested(String eventId, String photoId) {
            Photo existing = items.get(photoId);
            if (existing == null || !eventId.equals(existing.getEventId())) return Optional.empty();
            Photo next = new Photo(
                    existing.getPhotoId(), existing.getEventId(), existing.getGuestId(),
                    existing.getCreatedAt(), existing.getUploadedAt(), "retrying",
                    existing.getS3KeyOriginal(), existing.getS3KeyMedium(), existing.getS3KeySmall(),
                    existing.getOwnerName(), existing.getSharedByUserId(), existing.getSharedByName(),
                    existing.isShared(), existing.getProcessingAttempts(), null, null, null
            );
            items.put(photoId, next);
            return Optional.of(next);
        }

        @Override
        public Photo markReadyInternal(
                String eventId,
                String photoId,
                String s3KeyOriginal,
                String s3KeyMedium,
                String s3KeySmall,
                Instant now
        ) {
            Photo existing = items.get(photoId);
            if (existing == null || !eventId.equals(existing.getEventId())
                    || !s3KeyOriginal.equals(existing.getS3KeyOriginal())) {
                throw new IllegalArgumentException("Photo does not exist");
            }
            Photo ready = new Photo(
                    existing.getPhotoId(), existing.getEventId(), existing.getGuestId(),
                    existing.getCreatedAt(), existing.getUploadedAt(), "ready",
                    existing.getS3KeyOriginal(), s3KeyMedium, s3KeySmall,
                    existing.getOwnerName(), existing.getSharedByUserId(),
                    existing.getSharedByName(), existing.isShared(),
                    existing.getProcessingAttempts(), null, null, null
            );
            items.put(photoId, ready);
            return ready;
        }

        @Override
        public PageResult<Photo> listByEventId(String eventId, int limit, String nextToken) {
            List<Photo> matching = items.values().stream()
                    .filter(photo -> eventId.equals(photo.getEventId()))
                    .limit(limit)
                    .toList();
            return new PageResult<>(matching, null);
        }

        @Override
        public PageResult<Photo> listByGuestId(String guestId, int limit, String nextToken) {
            List<Photo> matching = items.values().stream()
                    .filter(photo -> guestId.equals(photo.getGuestId()))
                    .limit(limit)
                    .toList();
            return new PageResult<>(matching, null);
        }

        @Override
        public PageResult<Photo> listAll(int limit, String nextToken) {
            return new PageResult<>(new ArrayList<>(items.values()), null);
        }

        @Override
        public long countByEventId(String eventId) {
            return items.values().stream()
                    .filter(photo -> eventId.equals(photo.getEventId()))
                    .count();
        }

        @Override
        public void deleteById(String photoId) {
            items.remove(photoId);
        }
    }
}
