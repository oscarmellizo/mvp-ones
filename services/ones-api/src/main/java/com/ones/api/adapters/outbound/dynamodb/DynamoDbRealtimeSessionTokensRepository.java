package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;
import com.ones.api.domain.realtime.RealtimeSessionToken;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoDbRealtimeSessionTokensRepository implements RealtimeSessionTokensRepository {

    private final DynamoDbTable<DynamoRealtimeSessionTokenItem> table;

    public DynamoDbRealtimeSessionTokensRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.ws-sessions-table-name:ones-dev-ws-sessions}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoRealtimeSessionTokenItem.class));
    }

    @Override
    public RealtimeSessionToken upsert(RealtimeSessionToken t) {
        DynamoRealtimeSessionTokenItem it = toItem(t);
        table.putItem(it);
        return t;
    }

    @Override
    public java.util.Optional<RealtimeSessionToken> findByToken(String token) {
        if (token == null || token.isBlank()) return java.util.Optional.empty();
        var it = table.getItem(Key.builder().partitionValue(token.trim()).build());
        return java.util.Optional.ofNullable(it).map(DynamoDbRealtimeSessionTokensRepository::toDomain);
    }

    @Override
    public void deleteByToken(String token) {
        if (token == null || token.isBlank()) return;
        table.deleteItem(Key.builder().partitionValue(token.trim()).build());
    }

    private static DynamoRealtimeSessionTokenItem toItem(RealtimeSessionToken t) {
        DynamoRealtimeSessionTokenItem it = new DynamoRealtimeSessionTokenItem();
        it.setToken(t.getToken());
        it.setUserId(t.getUserId());
        it.setCreatedAt(t.getCreatedAt().toString());
        it.setExpiresAt(t.getExpiresAt().toString());
        it.setTtl(t.getExpiresAt().getEpochSecond());
        return it;
    }

    private static RealtimeSessionToken toDomain(DynamoRealtimeSessionTokenItem it) {
        Instant created = it.getCreatedAt() != null ? Instant.parse(it.getCreatedAt()) : Instant.EPOCH;
        Instant expires = it.getExpiresAt() != null ? Instant.parse(it.getExpiresAt()) : created.plusSeconds(60);
        return new RealtimeSessionToken(it.getToken(), it.getUserId(), created, expires);
    }
}
