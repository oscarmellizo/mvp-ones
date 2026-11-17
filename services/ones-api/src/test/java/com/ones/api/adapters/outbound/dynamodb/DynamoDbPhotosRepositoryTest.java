package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.ReturnValue;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemRequest;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemResponse;

class DynamoDbPhotosRepositoryTest {

    private static final Instant CREATED_AT = Instant.parse("2025-01-01T12:00:00Z");

    @Test
    void sharedFlagRoundTripsAndMissingLegacyValueDefaultsToPrivate() {
        Photo shared = new Photo(
                "photo-1",
                "event-1",
                "uploader-1",
                CREATED_AT,
                CREATED_AT,
                "retrying",
                "eventos/event-1/guests/uploader-1/private/photo-1.jpg",
                null,
                null,
                "Uploader",
                "uploader-1",
                "Uploader",
                true,
                3,
                "s3_unavailable",
                1735733100000L,
                1735732800000L
        );

        DynamoPhotoItem item = DynamoDbPhotosRepository.toItem(shared);
        Photo restored = DynamoDbPhotosRepository.toDomain(item);

        assertTrue(item.getShared());
        assertTrue(restored.isShared());
        assertEquals(3, restored.getProcessingAttempts());
        assertEquals("s3_unavailable", restored.getProcessingErrorCode());
        assertEquals(1735733100000L, restored.getProcessingLeaseUntilEpoch());

        item.setShared(null);
        item.setProcessingAttempts(null);
        assertFalse(DynamoDbPhotosRepository.toDomain(item).isShared());
        assertEquals(0, DynamoDbPhotosRepository.toDomain(item).getProcessingAttempts());
    }

    @Test
    void completeUploadUsesConditionalIdempotentUpdateAndPreservesReadyStatus() {
        DynamoDbClient client = mock(DynamoDbClient.class);
        DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder()
                .dynamoDbClient(client)
                .build();
        DynamoDbPhotosRepository repository =
                new DynamoDbPhotosRepository(enhanced, client, "photos");
        when(client.updateItem(any(UpdateItemRequest.class)))
                .thenReturn(UpdateItemResponse.builder().build());

        repository.completeUpload(photo(true));

        ArgumentCaptor<UpdateItemRequest> captor =
                ArgumentCaptor.forClass(UpdateItemRequest.class);
        verify(client).updateItem(captor.capture());
        UpdateItemRequest request = captor.getValue();
        assertTrue(request.conditionExpression().contains("attribute_not_exists(#s3KeyOriginal)"));
        assertTrue(request.updateExpression().contains("#status = if_not_exists(#status, :status)"));
        assertTrue(request.expressionAttributeValues().get(":shared").bool());
        assertEquals("photo-1", request.key().get("photoId").s());
        assertEquals(ReturnValue.ALL_NEW, request.returnValues());
    }

    @Test
    void thumbnailUpdateDoesNotOverwriteShareState() {
        DynamoDbClient client = mock(DynamoDbClient.class);
        DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder()
                .dynamoDbClient(client)
                .build();
        DynamoDbPhotosRepository repository =
                new DynamoDbPhotosRepository(enhanced, client, "photos");
        when(client.updateItem(any(UpdateItemRequest.class)))
                .thenReturn(UpdateItemResponse.builder().attributes(photoAttributes("ready", 1)).build());

        repository.markReadyInternal(
                "event-1",
                "photo-1",
                "eventos/event-1/guests/uploader-1/private/photo-1.jpg",
                "eventos/event-1/guests/uploader-1/private/photo-1_m.jpg",
                "eventos/event-1/guests/uploader-1/private/photo-1_s.jpg",
                CREATED_AT
        );

        ArgumentCaptor<UpdateItemRequest> captor =
                ArgumentCaptor.forClass(UpdateItemRequest.class);
        verify(client).updateItem(captor.capture());
        UpdateItemRequest request = captor.getValue();
        assertTrue(request.updateExpression().contains("#status = :ready"));
        assertFalse(request.updateExpression().contains("#shared"));
        assertFalse(request.updateExpression().contains("#sharedByUserId"));
        assertTrue(request.conditionExpression().contains("attribute_exists(#photoId)"));
    }

    @Test
    void processingClaimIsConditionalAndPreservesShareFields() {
        DynamoDbClient client = mock(DynamoDbClient.class);
        DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder()
                .dynamoDbClient(client)
                .build();
        DynamoDbPhotosRepository repository =
                new DynamoDbPhotosRepository(enhanced, client, "photos");
        when(client.updateItem(any(UpdateItemRequest.class)))
                .thenReturn(UpdateItemResponse.builder().attributes(photoAttributes("processing", 4)).build());

        PhotosRepository.ProcessingClaim result = repository.claimProcessing(
                "event-1",
                "photo-1",
                "eventos/event-1/guests/uploader-1/private/photo-1.jpg",
                false,
                CREATED_AT,
                CREATED_AT.plusSeconds(180)
        );

        assertEquals(PhotosRepository.ProcessingClaimStatus.CLAIMED, result.status());
        assertTrue(result.photo().isShared());
        assertEquals("processing", result.photo().getStatus());
        assertEquals(4, result.photo().getProcessingAttempts());
        ArgumentCaptor<UpdateItemRequest> captor = ArgumentCaptor.forClass(UpdateItemRequest.class);
        verify(client).updateItem(captor.capture());
        UpdateItemRequest request = captor.getValue();
        assertTrue(request.conditionExpression().contains("attribute_exists(#photoId)"));
        assertTrue(request.conditionExpression().contains("#s3KeyOriginal = :s3KeyOriginal"));
        assertTrue(request.updateExpression().contains("#processingLeaseUntilEpoch"));
        assertFalse(request.updateExpression().contains("#shared"));
    }

    @Test
    void failedProcessingUpdateKeepsSharedFlagAndDoesNotRecreateDeletedPhoto() {
        DynamoDbClient client = mock(DynamoDbClient.class);
        DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder()
                .dynamoDbClient(client)
                .build();
        DynamoDbPhotosRepository repository =
                new DynamoDbPhotosRepository(enhanced, client, "photos");
        when(client.updateItem(any(UpdateItemRequest.class)))
                .thenReturn(UpdateItemResponse.builder().attributes(photoAttributes("failed", 5)).build());

        var updated = repository.markProcessingFailed(
                "event-1",
                "photo-1",
                "eventos/event-1/guests/uploader-1/private/photo-1.jpg",
                "retry_exhausted"
        );

        assertTrue(updated.isPresent());
        assertTrue(updated.get().isShared());
        assertEquals("retry_exhausted", updated.get().getProcessingErrorCode());
        ArgumentCaptor<UpdateItemRequest> captor = ArgumentCaptor.forClass(UpdateItemRequest.class);
        verify(client).updateItem(captor.capture());
        assertTrue(captor.getValue().conditionExpression().contains("attribute_exists(#photoId)"));
        assertFalse(captor.getValue().updateExpression().contains("#shared"));
    }

    private static Photo photo(boolean shared) {
        return new Photo(
                "photo-1",
                "event-1",
                "uploader-1",
                CREATED_AT,
                CREATED_AT,
                "uploaded",
                "eventos/event-1/guests/uploader-1/private/photo-1.jpg",
                null,
                null,
                "Uploader",
                "uploader-1",
                "Uploader",
                shared
        );
    }

    private static Map<String, AttributeValue> photoAttributes(String status, int attempts) {
        return Map.ofEntries(
                Map.entry("photoId", AttributeValue.fromS("photo-1")),
                Map.entry("eventId", AttributeValue.fromS("event-1")),
                Map.entry("eventSortKey", AttributeValue.fromS(CREATED_AT + "#photo-1")),
                Map.entry("guestId", AttributeValue.fromS("uploader-1")),
                Map.entry("createdAt", AttributeValue.fromS(CREATED_AT.toString())),
                Map.entry("uploadedAt", AttributeValue.fromS(CREATED_AT.toString())),
                Map.entry("status", AttributeValue.fromS(status)),
                Map.entry("s3KeyOriginal", AttributeValue.fromS("eventos/event-1/guests/uploader-1/private/photo-1.jpg")),
                Map.entry("shared", AttributeValue.fromBool(true)),
                Map.entry("processingAttempts", AttributeValue.fromN(Integer.toString(attempts))),
                Map.entry("processingErrorCode", AttributeValue.fromS("retry_exhausted"))
        );
    }
}
