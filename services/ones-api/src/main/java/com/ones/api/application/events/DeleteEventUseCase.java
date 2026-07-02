package com.ones.api.application.events;

import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

@Service
public class DeleteEventUseCase {

    private static final Logger log = LoggerFactory.getLogger(DeleteEventUseCase.class);

    private final EventsRepository eventsRepository;
    private final PhotosRepository photosRepository;
    private final PhotoLikesRepository photoLikesRepository;
    private final InvitationsRepository invitationsRepository;
    private final ObjectStorage objectStorage;

    private final String photosBucket;
    private final String coversFinalBucket;

    public DeleteEventUseCase(
            EventsRepository eventsRepository,
            PhotosRepository photosRepository,
            PhotoLikesRepository photoLikesRepository,
            InvitationsRepository invitationsRepository,
            ObjectStorage objectStorage,
            @Value("${ones.s3.events.photos.bucket}") String photosBucket,
            @Value("${ones.s3.events.covers.final-bucket}") String coversFinalBucket
    ) {
        this.eventsRepository = eventsRepository;
        this.photosRepository = photosRepository;
        this.photoLikesRepository = photoLikesRepository;
        this.invitationsRepository = invitationsRepository;
        this.objectStorage = objectStorage;
        this.photosBucket = photosBucket;
        this.coversFinalBucket = coversFinalBucket;
    }

    public void execute(String requesterUserId, String eventId) {
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new IllegalArgumentException("Missing requesterUserId");
        }
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        Event event = eventsRepository.findById(eventId.trim())
                .orElseThrow(() -> new EventNotFoundException(eventId));

        if (!requesterUserId.trim().equals(event.getOwnerId())) {
            throw new EventForbiddenException(eventId);
        }

        List<Photo> ownerPhotos = new ArrayList<>();
        String nextToken = null;
        do {
            PhotosRepository.PageResult<Photo> page =
                    photosRepository.listByEventId(event.getEventId(), 50, nextToken);
            for (Photo photo : page.items()) {
                if (!event.getOwnerId().equals(photo.getGuestId())) {
                    throw new EventHasGuestPhotosException(eventId);
                }
                ownerPhotos.add(photo);
            }
            nextToken = page.nextToken();
        } while (nextToken != null && !nextToken.isBlank());

        for (Photo photo : ownerPhotos) {
            deletePhotoS3BestEffort(photo);
            try {
                photoLikesRepository.deleteAllByPhotoId(photo.getPhotoId());
            } catch (Exception e) {
                log.warn("[DeleteEventUseCase] failed to delete likes photoId={} err={}", photo.getPhotoId(), e.toString());
            }
            try {
                photosRepository.deleteById(photo.getPhotoId());
            } catch (Exception e) {
                log.warn("[DeleteEventUseCase] failed to delete photo record photoId={} err={}", photo.getPhotoId(), e.toString());
            }
        }

        String coverKey = event.getCoverKey();
        if (coverKey != null && !coverKey.isBlank()) {
            try {
                objectStorage.delete(coversFinalBucket, coverKey.trim());
            } catch (Exception e) {
                log.warn("[DeleteEventUseCase] failed to delete cover S3 key={} err={}", coverKey, e.toString());
            }
        }

        invitationsRepository.deleteAllByEventId(event.getEventId());

        eventsRepository.deleteById(event.getEventId());

        log.info("[DeleteEventUseCase] deleted eventId={} ownerId={} photos={}", eventId, requesterUserId, ownerPhotos.size());
    }

    private void deletePhotoS3BestEffort(Photo photo) {
        String keyOrig = photo.getS3KeyOriginal();
        String keyMedium = photo.getS3KeyMedium();
        String keySmall = photo.getS3KeySmall();
        if ((keyMedium == null || keyMedium.isBlank()) && keyOrig != null && !keyOrig.isBlank()) {
            keyMedium = variantKeyFromOriginal(keyOrig, "_m");
        }
        if ((keySmall == null || keySmall.isBlank()) && keyOrig != null && !keyOrig.isBlank()) {
            keySmall = variantKeyFromOriginal(keyOrig, "_s");
        }
        deleteS3BestEffort(keyOrig);
        deleteS3BestEffort(keyMedium);
        deleteS3BestEffort(keySmall);
    }

    private void deleteS3BestEffort(String key) {
        if (key == null || key.isBlank()) return;
        try {
            objectStorage.delete(photosBucket, key.trim());
        } catch (Exception e) {
            log.warn("[DeleteEventUseCase] S3 delete best-effort failed key={} err={}", key, e.toString());
        }
    }

    private static String variantKeyFromOriginal(String originalKey, String suffix) {
        if (originalKey == null || originalKey.isBlank()) return null;
        String key = originalKey.trim();
        String sfx = suffix != null ? suffix : "";
        if (key.endsWith(".jpg")) return key.substring(0, key.length() - 4) + sfx + ".jpg";
        if (key.endsWith(".jpeg")) return key.substring(0, key.length() - 5) + sfx + ".jpeg";
        return key + sfx;
    }
}
