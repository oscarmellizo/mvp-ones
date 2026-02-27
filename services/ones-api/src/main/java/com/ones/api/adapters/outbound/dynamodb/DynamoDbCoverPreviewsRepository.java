package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.events.ports.CoverPreviewsRepository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoDbCoverPreviewsRepository implements CoverPreviewsRepository {

    private final DynamoDbTable<DynamoCoverPreviewItem> table;

    public DynamoDbCoverPreviewsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.cover-previews-table-name:ones-cover-previews}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoCoverPreviewItem.class));
    }

    @Override
    public void save(String coverId, String ownerId, Instant createdAt, String tempBucket, String tempKey) {
        DynamoCoverPreviewItem item = new DynamoCoverPreviewItem();
        item.setCoverId(coverId);
        item.setOwnerId(ownerId);
        item.setCreatedAt(createdAt.toString());
        item.setTempBucket(tempBucket);
        item.setTempKey(tempKey);
        table.putItem(item);
    }

    @Override
    public Optional<CoverPreview> findById(String coverId) {
        DynamoCoverPreviewItem item = table.getItem(Key.builder().partitionValue(coverId).build());
        return Optional.ofNullable(item).map(DynamoDbCoverPreviewsRepository::toDomain);
    }

    @Override
    public void deleteById(String coverId) {
        table.deleteItem(Key.builder().partitionValue(coverId).build());
    }

    private static CoverPreview toDomain(DynamoCoverPreviewItem item) {
        return new CoverPreview(
                item.getCoverId(),
                item.getOwnerId(),
                Instant.parse(item.getCreatedAt()),
                item.getTempBucket(),
                item.getTempKey()
        );
    }
}
