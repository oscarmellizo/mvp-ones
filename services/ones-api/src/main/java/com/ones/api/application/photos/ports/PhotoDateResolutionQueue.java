package com.ones.api.application.photos.ports;

public interface PhotoDateResolutionQueue {

    boolean isConfigured();

    void enqueue(Job job);

    record Job(
            String eventId,
            String photoId,
            String originalFilename,
            String metadataCreatedAt,
            Integer deviceUtcOffsetMinutes
    ) {
    }
}
