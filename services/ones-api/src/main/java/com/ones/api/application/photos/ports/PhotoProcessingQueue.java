package com.ones.api.application.photos.ports;

public interface PhotoProcessingQueue {

    void enqueue(Job job);

    record Job(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            boolean manualRetry,
            String jobId
    ) {
    }
}
