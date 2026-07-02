package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.photos.ports.PhotoLikesRepository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.BatchGetItemEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ReadBatch;

@Repository
public class DynamoDbPhotoLikesRepository implements PhotoLikesRepository {

    private static final Logger log = LoggerFactory.getLogger(DynamoDbPhotoLikesRepository.class);

    private final DynamoDbEnhancedClient enhancedClient;
    private final DynamoDbTable<DynamoPhotoLikeItem> table;

    public DynamoDbPhotoLikesRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.photo-likes-table-name:ones-photo-likes}") String tableName
    ) {
        this.enhancedClient = enhancedClient;
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoPhotoLikeItem.class));
    }

    @Override
    public Set<String> likedPhotoIds(String userId, Set<String> photoIds) {
        Set<String> out = new HashSet<>();
        if (userId == null || userId.isBlank()) {
            return out;
        }
        if (photoIds == null || photoIds.isEmpty()) {
            return out;
        }

        try {
            return likedPhotoIdsInternal(userId, photoIds);
        } catch (Exception e) {
            log.warn("[DynamoDbPhotoLikesRepository.likedPhotoIds] failed userId={} photoIdsCount={} err={}",
                    userId,
                    photoIds.size(),
                    e.toString());
            return out;
        }
    }

    private Set<String> likedPhotoIdsInternal(String userId, Set<String> photoIds) {
        Set<String> out = new HashSet<>();

        ReadBatch.Builder<DynamoPhotoLikeItem> read = ReadBatch.builder(DynamoPhotoLikeItem.class)
                .mappedTableResource(table);

        int added = 0;
        for (String rawPhotoId : photoIds) {
            if (rawPhotoId == null || rawPhotoId.isBlank()) continue;
            String pid = rawPhotoId.trim();
            read.addGetItem(Key.builder().partitionValue(pid).sortValue(userId.trim()).build());
            added++;
            if (added >= 100) break;
        }

        if (added == 0) {
            return out;
        }

        BatchGetItemEnhancedRequest req = BatchGetItemEnhancedRequest.builder()
                .readBatches(read.build())
                .build();

        enhancedClient.batchGetItem(req)
                .resultsForTable(table)
                .forEach(item -> {
                    if (item == null) return;
                    String pid = item.getPhotoId();
                    String uid = item.getUserId();
                    if (pid == null || pid.isBlank()) return;
                    if (uid == null || uid.isBlank()) return;
                    if (!uid.trim().equals(userId.trim())) return;
                    out.add(pid.trim());
                });

        return out;
    }

    @Override
    public void like(String eventId, String photoId, String userId, Instant createdAt) {
        if (photoId == null || photoId.isBlank()) return;
        if (userId == null || userId.isBlank()) return;

        Instant ts = createdAt != null ? createdAt : Instant.now();

        DynamoPhotoLikeItem item = new DynamoPhotoLikeItem();
        item.setPhotoId(photoId.trim());
        item.setUserId(userId.trim());
        item.setEventId(eventId);
        item.setCreatedAt(ts.toString());
        item.setGsi1pk("user#" + userId.trim());
        item.setGsi1sk(ts.toString() + "#" + photoId.trim());

        try {
            table.putItem(item);
        } catch (Exception e) {
            log.warn("[DynamoDbPhotoLikesRepository.like] failed eventId={} photoId={} userId={} err={}",
                    eventId,
                    photoId,
                    userId,
                    e.toString());
        }
    }

    @Override
    public void unlike(String photoId, String userId) {
        if (photoId == null || photoId.isBlank()) return;
        if (userId == null || userId.isBlank()) return;

        try {
            table.deleteItem(Key.builder().partitionValue(photoId.trim()).sortValue(userId.trim()).build());
        } catch (Exception e) {
            log.warn("[DynamoDbPhotoLikesRepository.unlike] failed photoId={} userId={} err={}",
                    photoId,
                    userId,
                    e.toString());
        }
    }

    @Override
    public void deleteAllByPhotoId(String photoId) {
        if (photoId == null || photoId.isBlank()) return;
        try {
            QueryEnhancedRequest req = QueryEnhancedRequest.builder()
                    .queryConditional(QueryConditional.keyEqualTo(
                            Key.builder().partitionValue(photoId.trim()).build()))
                    .build();
            table.query(req).items().forEach(item -> {
                try {
                    table.deleteItem(Key.builder()
                            .partitionValue(item.getPhotoId())
                            .sortValue(item.getUserId())
                            .build());
                } catch (Exception e) {
                    log.warn("[DynamoDbPhotoLikesRepository.deleteAllByPhotoId] delete item failed photoId={} userId={} err={}",
                            item.getPhotoId(), item.getUserId(), e.toString());
                }
            });
        } catch (Exception e) {
            log.warn("[DynamoDbPhotoLikesRepository.deleteAllByPhotoId] failed photoId={} err={}",
                    photoId, e.toString());
        }
    }
}
