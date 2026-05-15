package com.ones.api.application.photos.ports;

import java.time.Instant;
import java.util.Optional;

public interface PhotoShortLinksRepository {

    Optional<PhotoShortLink> findByCode(String code);

    PhotoShortLink create(PhotoShortLink link);

    record PhotoShortLink(
            String code,
            String eventId,
            String photoId,
            String variant,
            Instant createdAt,
            Instant expiresAt
    ) {
    }
}
