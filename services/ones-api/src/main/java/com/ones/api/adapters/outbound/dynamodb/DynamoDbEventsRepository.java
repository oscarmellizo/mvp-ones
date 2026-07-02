package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.model.BatchGetItemEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ReadBatch;
import software.amazon.awssdk.enhanced.dynamodb.model.PageIterable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;

@Repository
public class DynamoDbEventsRepository implements EventsRepository {

    private static final String GSI1_NAME = "gsi1";

    private final DynamoDbTable<DynamoEventItem> table;
    private final DynamoDbEnhancedClient enhancedClient;

    public DynamoDbEventsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.table-name:ones-events}") String tableName
    ) {
        this.enhancedClient = enhancedClient;
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoEventItem.class));
    }

    @Override
    public Event save(Event event) {
        DynamoEventItem item = toItem(event);
        table.putItem(item);
        return event;
    }

    @Override
    public Optional<Event> findById(String eventId) {
        DynamoEventItem item = table.getItem(Key.builder().partitionValue(eventId).build());
        return Optional.ofNullable(item).map(DynamoDbEventsRepository::toDomain);
    }

    @Override
    public List<Event> findByIds(List<String> eventIds) {
        if (eventIds == null || eventIds.isEmpty()) {
            return List.of();
        }

        Set<String> seen = new HashSet<>();
        List<Key> keys = new ArrayList<>(eventIds.size());
        for (String raw : eventIds) {
            if (raw == null || raw.isBlank()) continue;
            String id = raw.trim();
            if (seen.add(id)) {
                keys.add(Key.builder().partitionValue(id).build());
            }
        }
        if (keys.isEmpty()) {
            return List.of();
        }

        ReadBatch.Builder<DynamoEventItem> read = ReadBatch.builder(DynamoEventItem.class)
                .mappedTableResource(table);
        for (Key k : keys) {
            read.addGetItem(k);
        }

        BatchGetItemEnhancedRequest request = BatchGetItemEnhancedRequest.builder()
                .readBatches(read.build())
                .build();

        List<Event> out = new ArrayList<>();
        enhancedClient.batchGetItem(request)
                .resultsForTable(table)
                .forEach(item -> out.add(toDomain(item)));
        return out;
    }

    @Override
    public void deleteById(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(eventId.trim()).build());
    }

    @Override
    public List<Event> listByOwnerId(String ownerId, int limit) {
        int resolvedLimit = limit <= 0 ? 50 : Math.min(limit, 200);
        DynamoDbIndex<DynamoEventItem> index = table.index(GSI1_NAME);

        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(ownerId).build()))
                .limit(resolvedLimit)
                .scanIndexForward(false)
                .build();

        PageIterable<DynamoEventItem> pages = PageIterable.create(index.query(request));
        return pages.items().stream().map(DynamoDbEventsRepository::toDomain).toList();
    }

    private static DynamoEventItem toItem(Event e) {
        DynamoEventItem item = new DynamoEventItem();
        item.setEventId(e.getEventId());
        item.setOwnerId(e.getOwnerId());
        item.setCreatedAt(e.getCreatedAt().toString());
        item.setTitle(e.getTitle());

        item.setObjective(e.getObjective());
        item.setLocation(e.getLocation());
        item.setStartAt(e.getStartAt().toString());
        item.setEndAt(e.getEndAt().toString());
        item.setCoverKey(e.getCoverKey());
        item.setAllowGuestInvites(e.isAllowGuestInvites());
        item.setInviteLinkEnabled(e.isInviteLinkEnabled());

        item.setFrameIds(e.getFrameIds());

        item.setGsi1pk(e.getOwnerId());
        item.setGsi1sk(e.getCreatedAt().toString());
        return item;
    }

    private static Event toDomain(DynamoEventItem item) {
        Instant createdAt = Instant.parse(item.getCreatedAt());
        Instant startAt = item.getStartAt() != null ? Instant.parse(item.getStartAt()) : createdAt;
        Instant endAt = item.getEndAt() != null ? Instant.parse(item.getEndAt()) : startAt;
        String objective = item.getObjective() != null ? item.getObjective() : "";
        String location = item.getLocation() != null ? item.getLocation() : "";
        String coverKey = item.getCoverKey();
        boolean allowGuestInvites = item.getAllowGuestInvites() == null ? true : item.getAllowGuestInvites();
        boolean inviteLinkEnabled = item.getInviteLinkEnabled() == null ? true : item.getInviteLinkEnabled();
        java.util.List<String> frameIds = item.getFrameIds();
        return new Event(
                item.getEventId(),
                item.getOwnerId(),
                createdAt,
                item.getTitle(),
                objective,
                location,
                startAt,
                endAt,
                coverKey,
                allowGuestInvites,
                inviteLinkEnabled,
                frameIds
        );
    }
}
