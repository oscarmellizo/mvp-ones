package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

import com.ones.api.application.eventtemplates.ports.EventTemplatesRepository;
import com.ones.api.domain.eventtemplates.EventTemplate;

@Repository
public class DynamoDbEventTemplatesRepository implements EventTemplatesRepository {

    private final DynamoDbTable<DynamoEventTemplateItem> table;

    public DynamoDbEventTemplatesRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.event-templates-table-name:ones-event-templates}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoEventTemplateItem.class));
    }

    @Override
    public Optional<EventTemplate> findById(String eventTemplateId) {
        if (eventTemplateId == null || eventTemplateId.isBlank()) {
            return Optional.empty();
        }
        Key key = Key.builder().partitionValue(eventTemplateId.trim()).build();
        DynamoEventTemplateItem item = table.getItem(key);
        if (item == null) {
            return Optional.empty();
        }
        return Optional.of(toDomain(item));
    }

    @Override
    public List<EventTemplate> list(EventTemplate.Status status) {
        String normalizedStatus = status != null ? status.name().toLowerCase() : "active";
        String gsi1pk = "LIST";
        String gsi1skPrefix = normalizedStatus + "#";

        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(
                    QueryConditional.sortBeginsWith(
                        Key.builder()
                            .partitionValue(gsi1pk)
                            .sortValue(gsi1skPrefix)
                            .build()
                    )
                )
                .build();

        List<EventTemplate> out = new ArrayList<>();
        for (Page<DynamoEventTemplateItem> page : table.index("gsi1").query(request)) {
            for (DynamoEventTemplateItem item : page.items()) {
                out.add(toDomain(item));
            }
        }
        return out;
    }

    @Override
    public EventTemplate upsert(EventTemplate eventTemplate) {
        DynamoEventTemplateItem item = toItem(eventTemplate);
        table.putItem(item);
        return eventTemplate;
    }

    @Override
    public void deleteById(String eventTemplateId) {
        if (eventTemplateId == null || eventTemplateId.isBlank()) {
            return;
        }
        Key key = Key.builder().partitionValue(eventTemplateId.trim()).build();
        table.deleteItem(key);
    }

    private static DynamoEventTemplateItem toItem(EventTemplate et) {
        DynamoEventTemplateItem item = new DynamoEventTemplateItem();
        item.setEventTemplateId(et.getEventTemplateId());
        item.setName(et.getName());
        item.setStatus(et.getStatus() != null ? et.getStatus().name() : null);
        item.setSortOrder(et.getSortOrder());
        item.setFrameIds(et.getFrameIds());
        item.setCreatedAt(et.getCreatedAt() != null ? et.getCreatedAt().toString() : null);
        item.setUpdatedAt(et.getUpdatedAt() != null ? et.getUpdatedAt().toString() : null);
        item.setCreatedBy(et.getCreatedBy());
        item.setUpdatedBy(et.getUpdatedBy());
        // GSI1 for listing by status+sortOrder
        item.setGsi1pk("LIST");
        String statusStr = et.getStatus() != null ? et.getStatus().name().toLowerCase() : "inactive";
        String order = et.getSortOrder() != null ? String.format("%010d", et.getSortOrder()) : "9999999999";
        item.setGsi1sk(statusStr + "#" + order);
        return item;
    }

    private static EventTemplate toDomain(DynamoEventTemplateItem item) {
        EventTemplate.Status status = null;
        String statusStr = item.getStatus();
        if (statusStr != null && !statusStr.isBlank()) {
            status = EventTemplate.Status.valueOf(statusStr.trim().toLowerCase());
        }
        Instant createdAt = null;
        String createdAtStr = item.getCreatedAt();
        if (createdAtStr != null && !createdAtStr.isBlank()) {
            createdAt = Instant.parse(createdAtStr);
        }
        Instant updatedAt = null;
        String updatedAtStr = item.getUpdatedAt();
        if (updatedAtStr != null && !updatedAtStr.isBlank()) {
            updatedAt = Instant.parse(updatedAtStr);
        }
        List<String> frameIds = item.getFrameIds();
        if (frameIds == null) {
            frameIds = new ArrayList<>();
        }
        return new EventTemplate(
                item.getEventTemplateId(),
                item.getName(),
                status,
                item.getSortOrder(),
                frameIds,
                createdAt,
                updatedAt,
                item.getCreatedBy(),
                item.getUpdatedBy()
        );
    }
}
