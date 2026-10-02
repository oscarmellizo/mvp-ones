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

/**
 * Borra un evento completo (fotos de todos los invitados, portada, invitaciones y el evento).
 * Es estricto: si algo no se pudo borrar lanza, para que quien llama pueda reintentar.
 * Borrar una clave S3 inexistente no falla, así que los reintentos son idempotentes.
 */
@Service
public class EventPurger {

    private static final Logger log = LoggerFactory.getLogger(EventPurger.class);

    private final EventsRepository eventsRepository;
    private final PhotosRepository photosRepository;
    private final PhotoLikesRepository photoLikesRepository;
    private final InvitationsRepository invitationsRepository;
    private final ObjectStorage objectStorage;

    private final String photosBucket;
    private final String coversFinalBucket;

    public EventPurger(
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

    /** Devuelve el número de fotos borradas. Lanza si alguna foto o la portada no se pudo borrar (el evento se conserva). */
    public int purge(Event event) {
        List<Photo> all = new ArrayList<>();
        String next = null;
        do {
            PhotosRepository.PageResult<Photo> page = photosRepository.listByEventId(event.getEventId(), 50, next);
            all.addAll(page.items());
            next = page.nextToken();
        } while (next != null && !next.isBlank());

        // Se intenta con todas las fotos aunque alguna falle, para dejar lo mínimo pendiente.
        int failed = 0;
        Exception firstCause = null;
        for (Photo photo : all) {
            try {
                purgePhoto(photo);
            } catch (Exception e) {
                failed++;
                if (firstCause == null) firstCause = e;
                log.warn("[EventPurger] failed to purge photoId={} err={}", photo.getPhotoId(), e.toString());
            }
        }
        if (failed > 0) {
            throw new IllegalStateException(
                    "Failed to purge " + failed + " photo(s) of eventId=" + event.getEventId(), firstCause);
        }

        String coverKey = event.getCoverKey();
        if (coverKey != null && !coverKey.isBlank()) {
            objectStorage.delete(coversFinalBucket, coverKey.trim());
        }

        invitationsRepository.deleteAllByEventId(event.getEventId());
        eventsRepository.deleteById(event.getEventId());
        return all.size();
    }

    /** Borra S3, likes y registro de la foto, en ese orden; si algo falla lanza y conserva el registro. */
    public void purgePhoto(Photo photo) {
        String keyOrig = photo.getS3KeyOriginal();
        String keyMedium = photo.getS3KeyMedium();
        String keySmall = photo.getS3KeySmall();
        if ((keyMedium == null || keyMedium.isBlank()) && keyOrig != null && !keyOrig.isBlank()) {
            keyMedium = variantKeyFromOriginal(keyOrig, "_m");
        }
        if ((keySmall == null || keySmall.isBlank()) && keyOrig != null && !keyOrig.isBlank()) {
            keySmall = variantKeyFromOriginal(keyOrig, "_s");
        }
        deleteS3(keyOrig);
        deleteS3(keyMedium);
        deleteS3(keySmall);
        photoLikesRepository.deleteAllByPhotoId(photo.getPhotoId());
        photosRepository.deleteById(photo.getPhotoId());
    }

    private void deleteS3(String key) {
        if (key == null || key.isBlank()) return;
        objectStorage.delete(photosBucket, key.trim());
    }

    private static String variantKeyFromOriginal(String originalKey, String suffix) {
        String key = originalKey.trim();
        if (key.endsWith(".jpg")) return key.substring(0, key.length() - 4) + suffix + ".jpg";
        if (key.endsWith(".jpeg")) return key.substring(0, key.length() - 5) + suffix + ".jpeg";
        return key + suffix;
    }
}
