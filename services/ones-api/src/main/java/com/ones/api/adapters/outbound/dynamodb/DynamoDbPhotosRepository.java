package com.ones.api.adapters.outbound.dynamodb;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

@Repository
public class DynamoDbPhotosRepository implements PhotosRepository {

    private final DynamoDbTable<DynamoPhotoItem> table;

    public DynamoDbPhotosRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.photos-table-name:ones-photos}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoPhotoItem.class));
    }

    @Override
    public Optional<Photo> findById(String photoId) {
        if (photoId == null || photoId.isBlank()) {
            return Optional.empty();
        }
        DynamoPhotoItem item = table.getItem(Key.builder().partitionValue(photoId.trim()).build());
        return Optional.ofNullable(item).map(DynamoDbPhotosRepository::toDomain);
    }

    @Override
    public Photo upsert(Photo photo) {
        table.putItem(toItem(photo));
        return photo;
    }

    @Override
    public PageResult<Photo> listByEventId(String eventId, int limit, String nextToken) {
        if (eventId == null || eventId.isBlank()) {
            return new PageResult<>(List.of(), null);
        }

        int resolvedLimit = limit <= 0 ? 10 : Math.min(limit, 50);

        DynamoDbIndex<DynamoPhotoItem> index = table.index("byEventId");

        QueryEnhancedRequest.Builder req = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(eventId.trim()).build()))
                .limit(resolvedLimit)
                .scanIndexForward(false);

        Map<String, AttributeValue> eks = decodeExclusiveStartKey(nextToken);
        if (eks != null && !eks.isEmpty()) {
            req = req.exclusiveStartKey(eks);
        }

        List<Photo> out = new ArrayList<>();
        String outNextToken = null;

        for (Page<DynamoPhotoItem> page : index.query(req.build())) {
            for (DynamoPhotoItem item : page.items()) {
                out.add(toDomain(item));
            }
            Map<String, AttributeValue> lek = page.lastEvaluatedKey();
            if (lek != null && !lek.isEmpty()) {
                outNextToken = encodeExclusiveStartKey(lek);
            }
            break;
        }

        return new PageResult<>(out, outNextToken);
    }

    private static String encodeExclusiveStartKey(Map<String, AttributeValue> key) {
        String photoId = s(key.get("photoId"));
        String eventId = s(key.get("eventId"));
        String eventSortKey = s(key.get("eventSortKey"));

        String raw = String.join("|",
                photoId == null ? "" : photoId,
                eventId == null ? "" : eventId,
                eventSortKey == null ? "" : eventSortKey
        );

        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    private static Map<String, AttributeValue> decodeExclusiveStartKey(String nextToken) {
        if (nextToken == null || nextToken.isBlank()) {
            return null;
        }

        byte[] decoded;
        try {
            decoded = Base64.getUrlDecoder().decode(nextToken.trim());
        } catch (Exception e) {
            return null;
        }

        String raw = new String(decoded, StandardCharsets.UTF_8);
        String[] parts = raw.split("\\|", -1);
        if (parts.length < 3) {
            return null;
        }

        String photoId = parts[0];
        String eventId = parts[1];
        String eventSortKey = parts[2];

        if (photoId.isBlank() || eventId.isBlank() || eventSortKey.isBlank()) {
            return null;
        }

        return Map.of(
                "photoId", AttributeValue.builder().s(photoId).build(),
                "eventId", AttributeValue.builder().s(eventId).build(),
                "eventSortKey", AttributeValue.builder().s(eventSortKey).build()
        );
    }

    private static String s(AttributeValue v) {
        return v != null ? v.s() : null;
    }

    private static DynamoPhotoItem toItem(Photo p) {
        DynamoPhotoItem item = new DynamoPhotoItem();
        item.setPhotoId(p.getPhotoId());
        item.setEventId(p.getEventId());
        item.setEventSortKey(eventSortKey(p.getCreatedAt(), p.getPhotoId()));
        item.setGuestId(p.getGuestId());
        item.setCreatedAt(p.getCreatedAt().toString());
        item.setUploadedAt(p.getUploadedAt() != null ? p.getUploadedAt().toString() : null);
        item.setStatus(p.getStatus());
        item.setS3KeyOriginal(p.getS3KeyOriginal());
        item.setS3KeyMedium(p.getS3KeyMedium());
        item.setS3KeySmall(p.getS3KeySmall());
        return item;
    }

    private static Photo toDomain(DynamoPhotoItem item) {
        Instant createdAt = item.getCreatedAt() != null ? Instant.parse(item.getCreatedAt()) : Instant.EPOCH;
        Instant uploadedAt = item.getUploadedAt() != null && !item.getUploadedAt().isBlank()
                ? Instant.parse(item.getUploadedAt())
                : null;

        return new Photo(
                item.getPhotoId(),
                item.getEventId(),
                item.getGuestId(),
                createdAt,
                uploadedAt,
                item.getStatus(),
                item.getS3KeyOriginal(),
                item.getS3KeyMedium(),
                item.getS3KeySmall()
        );
    }

    private static String eventSortKey(Instant createdAt, String photoId) {
        String ts = createdAt != null ? createdAt.toString() : Instant.EPOCH.toString();
        String id = photoId != null ? photoId : "";
        return ts + "#" + id;
    }
}
