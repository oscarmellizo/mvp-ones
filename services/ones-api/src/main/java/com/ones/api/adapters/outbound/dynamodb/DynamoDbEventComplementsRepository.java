package com.ones.api.adapters.outbound.dynamodb;

import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;

@Repository
public class DynamoDbEventComplementsRepository {

    private final DynamoDbTable<DynamoEventComplementItem> table;

    public DynamoDbEventComplementsRepository(
            DynamoDbEnhancedClient client,
            @Value("${ones.dynamodb.event-complements-table-name:ones-dev-event-complements}") String tableName
    ) {
        this.table = client.table(tableName, TableSchema.fromBean(DynamoEventComplementItem.class));
    }

    public Optional<DynamoEventComplementItem> find(String eventId, String complementId) {
        return Optional.ofNullable(table.getItem(Key.builder()
                .partitionValue(eventId)
                .sortValue(complementId)
                .build()));
    }

    public List<DynamoEventComplementItem> listByEventId(String eventId) {
        return table.query(r -> r.queryConditional(
                        QueryConditional.keyEqualTo(Key.builder().partitionValue(eventId).build())))
                .items()
                .stream()
                .toList();
    }

    public void save(DynamoEventComplementItem item) {
        table.putItem(item);
    }

    public void deleteByEventId(String eventId) {
        listByEventId(eventId).forEach(item -> table.deleteItem(Key.builder()
                .partitionValue(item.getEventId())
                .sortValue(item.getComplementId())
                .build()));
    }
}
