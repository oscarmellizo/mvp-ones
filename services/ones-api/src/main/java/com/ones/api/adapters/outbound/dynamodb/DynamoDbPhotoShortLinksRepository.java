package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.photos.ports.PhotoShortLinksRepository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoDbPhotoShortLinksRepository implements PhotoShortLinksRepository {

    private final DynamoDbTable<DynamoPhotoShortLinkItem> table;

    public DynamoDbPhotoShortLinksRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.photo-shortlinks-table-name:ones-photo-shortlinks}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoPhotoShortLinkItem.class));
    }

    @Override
    public Optional<PhotoShortLink> findByCode(String code) {
        if (code == null || code.isBlank()) {
            return Optional.empty();
        }
        DynamoPhotoShortLinkItem item = table.getItem(Key.builder().partitionValue(code.trim()).build());
        return Optional.ofNullable(item).map(DynamoDbPhotoShortLinksRepository::toDomain);
    }

    @Override
    public PhotoShortLink create(PhotoShortLink link) {
        table.putItem(toItem(link));
        return link;
    }

    private static DynamoPhotoShortLinkItem toItem(PhotoShortLink link) {
        DynamoPhotoShortLinkItem item = new DynamoPhotoShortLinkItem();
        item.setCode(link.code());
        item.setEventId(link.eventId());
        item.setPhotoId(link.photoId());
        item.setVariant(link.variant());
        item.setCreatedAt(link.createdAt() != null ? link.createdAt().toString() : Instant.EPOCH.toString());
        item.setExpiresAt(link.expiresAt() != null ? link.expiresAt().getEpochSecond() : null);
        return item;
    }

    private static PhotoShortLink toDomain(DynamoPhotoShortLinkItem item) {
        Instant createdAt = item.getCreatedAt() != null && !item.getCreatedAt().isBlank()
                ? Instant.parse(item.getCreatedAt())
                : Instant.EPOCH;
        Instant expiresAt = item.getExpiresAt() != null
                ? Instant.ofEpochSecond(item.getExpiresAt())
                : Instant.EPOCH;

        return new PhotoShortLink(
                item.getCode(),
                item.getEventId(),
                item.getPhotoId(),
                item.getVariant(),
                createdAt,
                expiresAt
        );
    }
}
