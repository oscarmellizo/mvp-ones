package com.ones.api.application.photos;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.adapters.outbound.aws.SqsPhotoProcessingQueue;
import com.ones.api.application.photos.ports.PhotoProcessingQueue.Job;

import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.SendMessageRequest;

class PhotoProcessingQueueTest {

    @Test
    void enqueuesStoredPhotoKeyAndRetryMode() throws Exception {
        SqsClient client = mock(SqsClient.class);
        SqsPhotoProcessingQueue queue =
                new SqsPhotoProcessingQueue(client, new ObjectMapper(), "queue-url");

        queue.enqueue(new Job(
                "event-1",
                "photo-1",
                "eventos/event-1/guests/user-1/private/photo-1.jpg",
                true,
                "retry-1"
        ));

        ArgumentCaptor<SendMessageRequest> captor = ArgumentCaptor.forClass(SendMessageRequest.class);
        verify(client).sendMessage(captor.capture());
        var body = new ObjectMapper().readTree(captor.getValue().messageBody());
        assertEquals("event-1", body.get("eventId").asText());
        assertEquals("photo-1", body.get("photoId").asText());
        assertEquals("eventos/event-1/guests/user-1/private/photo-1.jpg", body.get("s3KeyOriginal").asText());
        assertEquals(true, body.get("manualRetry").asBoolean());
        assertEquals("retry-1", body.get("jobId").asText());
    }

    @Test
    void refusesToEnqueueWhenQueueUrlIsNotConfigured() {
        SqsPhotoProcessingQueue queue =
                new SqsPhotoProcessingQueue(mock(SqsClient.class), new ObjectMapper(), "");

        assertThrows(IllegalStateException.class, () -> queue.enqueue(
                new Job("event-1", "photo-1", "key", false, "job-1")
        ));
    }
}
