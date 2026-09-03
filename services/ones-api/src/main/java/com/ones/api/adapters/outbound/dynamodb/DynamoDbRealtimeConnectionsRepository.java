package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.realtime.ports.RealtimeConnectionsRepository;
import com.ones.api.domain.realtime.RealtimeConnection;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;

@Repository
public class DynamoDbRealtimeConnectionsRepository implements RealtimeConnectionsRepository {

    private final DynamoDbTable<DynamoRealtimeConnectionItem> table;

    public DynamoDbRealtimeConnectionsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.ws-connections-table-name:ones-dev-ws-connections}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoRealtimeConnectionItem.class));
    }

    @Override
    public RealtimeConnection upsert(RealtimeConnection c) {
        DynamoRealtimeConnectionItem it = new DynamoRealtimeConnectionItem();
        it.setConnectionId(c.getConnectionId());
        it.setUserId(c.getUserId());
        it.setCreatedAt(c.getCreatedAt().toString());
        table.putItem(it);
        return c;
    }

    @Override
    public void deleteByConnectionId(String connectionId) {
        if (connectionId == null || connectionId.isBlank()) return;
        table.deleteItem(Key.builder().partitionValue(connectionId.trim()).build());
    }

    @Override
    public List<RealtimeConnection> listByUserId(String userId, int limit) {
        if (userId == null || userId.isBlank()) return List.of();
        int resolvedLimit = limit <= 0 ? 50 : Math.min(limit, 200);
        DynamoDbIndex<DynamoRealtimeConnectionItem> index = table.index("byUserId");
        QueryEnhancedRequest req = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(userId.trim()).build()))
                .limit(resolvedLimit)
                .scanIndexForward(false)
                .build();
        List<RealtimeConnection> out = new ArrayList<>();
        for (var page : index.query(req)) {
            for (var it : page.items()) {
                Instant created = it.getCreatedAt() != null ? Instant.parse(it.getCreatedAt()) : Instant.EPOCH;
                out.add(new RealtimeConnection(it.getConnectionId(), it.getUserId(), created));
            }
        }
        return out;
    }
}
