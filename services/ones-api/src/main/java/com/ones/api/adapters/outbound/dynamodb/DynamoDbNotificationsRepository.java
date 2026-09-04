package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.notifications.ports.NotificationsRepository;
import com.ones.api.domain.notifications.Notification;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;

@Repository
public class DynamoDbNotificationsRepository implements NotificationsRepository {

    private final DynamoDbTable<DynamoNotificationItem> table;

    public DynamoDbNotificationsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.notifications-table-name:ones-dev-notifications}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoNotificationItem.class));
    }

    @Override
    public Notification upsert(Notification n) {
        if (n == null) return null;
        DynamoNotificationItem item = toItem(n);
        table.putItem(item);
        return n;
    }

    @Override
    public Optional<Notification> findByUserAndId(String userId, String id) {
        if (userId == null || userId.isBlank() || id == null || id.isBlank()) {
            return Optional.empty();
        }
        String pk = userId.trim();
        // We don't know createdAt, so we need a query by begins_with on SK. Keep simple by scanning user partition and filtering id.
        List<Notification> list = listByUserId(pk, 200);
        return list.stream().filter(n -> id.equals(n.getId())).findFirst();
    }

    @Override
    public List<Notification> listByUserId(String userId, int limit) {
        if (userId == null || userId.isBlank()) return List.of();
        int resolvedLimit = limit <= 0 ? 50 : Math.min(limit, 200);

        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(userId.trim()).build()))
                .limit(resolvedLimit)
                .scanIndexForward(false)
                .build();

        List<Notification> out = new ArrayList<>();
        for (var page : table.query(request)) {
            for (var it : page.items()) {
                out.add(toDomain(it));
            }
        }
        return out;
    }

    @Override
    public long countUnreadByUserId(String userId) {
        // For MVP, derive from list; later we can add a GSI status index
        return listByUserId(userId, 200).stream().filter(n -> n.getReadAt() == null).count();
    }

    @Override
    public Notification markRead(String userId, String id) {
        Optional<Notification> existing = findByUserAndId(userId, id);
        if (existing.isEmpty()) return null;
        Notification updated = existing.get().markRead(Instant.now());
        upsert(updated);
        return updated;
    }

    private static DynamoNotificationItem toItem(Notification n) {
        DynamoNotificationItem it = new DynamoNotificationItem();
        it.setUserId(n.getUserId());
        it.setSk(n.getCreatedAt().toString() + "#" + n.getId());
        it.setId(n.getId());
        it.setType(n.getType());
        it.setTitle(n.getTitle());
        it.setBody(n.getBody());
        it.setCreatedAt(n.getCreatedAt().toString());
        it.setReadAt(n.getReadAt() != null ? n.getReadAt().toString() : null);
        it.setStatus(n.getStatus() != null ? n.getStatus().name() : null);
        it.setPriority(n.getPriority() != null ? n.getPriority().name() : null);
        it.setActionType(n.getActionType());
        it.setEntityType(n.getEntityType());
        it.setEntityId(n.getEntityId());
        it.setRoute(n.getRoute());
        return it;
    }

    private static Notification toDomain(DynamoNotificationItem it) {
        Instant createdAt = it.getCreatedAt() != null ? Instant.parse(it.getCreatedAt()) : Instant.EPOCH;
        Instant readAt = it.getReadAt() != null && !it.getReadAt().isBlank() ? Instant.parse(it.getReadAt()) : null;
        Notification.Status status = null;
        if (it.getStatus() != null && !it.getStatus().isBlank()) {
            try { status = Notification.Status.valueOf(it.getStatus()); } catch (Exception ignored) {}
        }
        Notification.Priority priority = null;
        if (it.getPriority() != null && !it.getPriority().isBlank()) {
            try { priority = Notification.Priority.valueOf(it.getPriority()); } catch (Exception ignored) {}
        }
        return new Notification(
                it.getUserId(),
                it.getId(),
                it.getType(),
                it.getTitle(),
                it.getBody(),
                createdAt,
                readAt,
                status,
                priority,
                it.getActionType(),
                it.getEntityType(),
                it.getEntityId(),
                it.getRoute()
        );
    }
}
