package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.users.ports.PreferredNamesCacheRepository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.BatchGetItemEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ReadBatch;

@Repository
public class DynamoDbPreferredNamesCacheRepository implements PreferredNamesCacheRepository {

    private final DynamoDbEnhancedClient enhancedClient;
    private final DynamoDbTable<DynamoPreferredNameCacheItem> table;

    public DynamoDbPreferredNamesCacheRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.preferred-names-cache-table-name:ones-preferred-names-cache}") String tableName
    ) {
        this.enhancedClient = enhancedClient;
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoPreferredNameCacheItem.class));
    }

    @Override
    public Map<String, CachedPreferredName> getMany(Set<String> userIds) {
        Map<String, CachedPreferredName> out = new HashMap<>();
        if (userIds == null || userIds.isEmpty()) {
            return out;
        }

        List<String> normalized = new ArrayList<>(userIds.size());
        for (String raw : userIds) {
            if (raw == null || raw.isBlank()) continue;
            normalized.add(raw.trim());
        }

        int i = 0;
        while (i < normalized.size()) {
            int end = Math.min(i + 100, normalized.size());
            List<String> chunk = normalized.subList(i, end);

            ReadBatch.Builder<DynamoPreferredNameCacheItem> read = ReadBatch.builder(DynamoPreferredNameCacheItem.class)
                    .mappedTableResource(table);

            for (String id : chunk) {
                if (id == null || id.isBlank()) continue;
                read.addGetItem(Key.builder().partitionValue(id).build());
            }

            BatchGetItemEnhancedRequest req = BatchGetItemEnhancedRequest.builder()
                    .readBatches(read.build())
                    .build();

            enhancedClient.batchGetItem(req)
                    .resultsForTable(table)
                    .forEach(item -> {
                        if (item == null || item.getUserId() == null || item.getUserId().isBlank()) return;
                        Instant updatedAt = item.getUpdatedAt() != null && !item.getUpdatedAt().isBlank()
                                ? Instant.parse(item.getUpdatedAt())
                                : Instant.EPOCH;
                        Instant expiresAt = item.getExpiresAt() != null
                                ? Instant.ofEpochSecond(item.getExpiresAt())
                                : Instant.EPOCH;
                        out.put(item.getUserId(), new CachedPreferredName(item.getUserId(), item.getPreferredName(), updatedAt, expiresAt));
                    });

            i = end;
        }

        return out;
    }

    @Override
    public void put(String userId, String preferredName, Instant expiresAt, Instant updatedAt) {
        if (userId == null || userId.isBlank()) {
            return;
        }

        DynamoPreferredNameCacheItem item = new DynamoPreferredNameCacheItem();
        item.setUserId(userId.trim());
        item.setPreferredName(preferredName);
        item.setUpdatedAt((updatedAt == null ? Instant.EPOCH : updatedAt).toString());
        item.setExpiresAt(expiresAt == null ? null : expiresAt.getEpochSecond());
        table.putItem(item);
    }

    @Override
    public void delete(String userId) {
        if (userId == null || userId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(userId.trim()).build());
    }
}
