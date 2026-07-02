package com.ones.api.infrastructure.migrations;

import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
@Profile("migrate-photos-status")
public class PhotosStatusMigration implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(PhotosStatusMigration.class);
    private static final String MIGRATION_ACTOR = "system-migration";

    private final PhotosRepository photosRepository;

    public PhotosStatusMigration(PhotosRepository photosRepository) {
        this.photosRepository = photosRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        log.info("Starting photos status migration (uploaded -> ready)...");

        try {
            int count = 0;
            String cursor = null;

            while (true) {
                PhotosRepository.PageResult<Photo> page = photosRepository.listAll(100, cursor);
                
                if (page.items().isEmpty()) {
                    break;
                }

                for (Photo photo : page.items()) {
                    String status = photo.getStatus();
                    if (status != null && status.trim().equalsIgnoreCase("uploaded")) {
                        Photo updated = new Photo(
                            photo.getPhotoId(),
                            photo.getEventId(),
                            photo.getGuestId(),
                            photo.getCreatedAt(),
                            photo.getUploadedAt(),
                            "ready",
                            photo.getS3KeyOriginal(),
                            photo.getS3KeyMedium(),
                            photo.getS3KeySmall(),
                            photo.getOwnerName(),
                            photo.getSharedByUserId(),
                            photo.getSharedByName()
                        );
                        photosRepository.upsert(updated);
                        count++;
                        log.info("Updated photo status: {} (eventId: {})", photo.getPhotoId(), photo.getEventId());
                    }
                }

                cursor = page.nextToken();
                if (cursor == null || cursor.isEmpty()) {
                    break;
                }
            }

            log.info("Photos status migration completed successfully. Total photos updated: {}", count);
        } catch (Exception e) {
            log.error("Failed to migrate photos status", e);
            throw e;
        }
    }
}
