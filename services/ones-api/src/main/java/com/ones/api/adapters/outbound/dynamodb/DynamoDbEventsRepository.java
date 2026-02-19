package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.model.PageIterable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;

@Repository
public class DynamoDbEventsRepository implements EventsRepository {

    private static final String GSI1_NAME = "gsi1";

    private final DynamoDbTable<DynamoEventItem> table;

    public DynamoDbEventsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.table-name:ones-events}") String tableName
    ) {
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
    public List<Event> listByOwnerId(String ownerId, int limit) {
        DynamoDbIndex<DynamoEventItem> index = table.index(GSI1_NAME);

        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(ownerId).build()))
                .limit(limit)
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

        item.setEventTypeId(e.getEventTypeId());
        item.setLocation(e.getLocation());
        item.setStartAt(e.getStartAt().toString());
        item.setEndAt(e.getEndAt().toString());
        item.setCoverKey(e.getCoverKey());

        item.setGsi1pk(e.getOwnerId());
        item.setGsi1sk(e.getCreatedAt().toString());
        return item;
    }

    private static Event toDomain(DynamoEventItem item) {
        Instant createdAt = Instant.parse(item.getCreatedAt());
        Instant startAt = item.getStartAt() != null ? Instant.parse(item.getStartAt()) : createdAt;
        Instant endAt = item.getEndAt() != null ? Instant.parse(item.getEndAt()) : startAt;
        String eventTypeId = item.getEventTypeId() != null ? item.getEventTypeId() : "";
        String location = item.getLocation() != null ? item.getLocation() : "";
        String coverKey = item.getCoverKey();
        return new Event(
                item.getEventId(),
                item.getOwnerId(),
                createdAt,
                item.getTitle(),
                eventTypeId,
                location,
                startAt,
                endAt,
                coverKey
        );
    }
}
