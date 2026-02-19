package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoDbCoverPreviewsRepository {

    private final DynamoDbTable<DynamoCoverPreviewItem> table;

    public DynamoDbCoverPreviewsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.cover-previews-table-name:ones-cover-previews}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoCoverPreviewItem.class));
    }

    public void save(String coverId, String ownerId, Instant createdAt, String tempBucket, String tempKey) {
        DynamoCoverPreviewItem item = new DynamoCoverPreviewItem();
        item.setCoverId(coverId);
        item.setOwnerId(ownerId);
        item.setCreatedAt(createdAt.toString());
        item.setTempBucket(tempBucket);
        item.setTempKey(tempKey);
        table.putItem(item);
    }

    public Optional<DynamoCoverPreviewItem> findById(String coverId) {
        DynamoCoverPreviewItem item = table.getItem(Key.builder().partitionValue(coverId).build());
        return Optional.ofNullable(item);
    }

    public void deleteById(String coverId) {
        table.deleteItem(Key.builder().partitionValue(coverId).build());
    }
}
