package com.ones.api.application.events.ports;

import java.time.Instant;
import java.util.Optional;

public interface CoverPreviewsRepository {

    void save(String coverId, String ownerId, Instant createdAt, String tempBucket, String tempKey);

    Optional<CoverPreview> findById(String coverId);

    void deleteById(String coverId);

    record CoverPreview(String coverId, String ownerId, Instant createdAt, String tempBucket, String tempKey) {
    }
}
