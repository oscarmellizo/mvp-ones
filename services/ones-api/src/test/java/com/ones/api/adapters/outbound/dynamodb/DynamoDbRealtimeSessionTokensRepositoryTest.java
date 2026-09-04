package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;

import java.time.Instant;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.ones.api.domain.realtime.RealtimeSessionToken;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

public class DynamoDbRealtimeSessionTokensRepositoryTest {

    private DynamoDbEnhancedClient enhancedClient;
    private DynamoDbRealtimeSessionTokensRepository repo;

    @BeforeEach
    void setUp() {
        enhancedClient = Mockito.mock(DynamoDbEnhancedClient.class);
        @SuppressWarnings("unchecked")
        DynamoDbTable<DynamoRealtimeSessionTokenItem> table = (DynamoDbTable<DynamoRealtimeSessionTokenItem>) Mockito.mock(DynamoDbTable.class);
        when(enhancedClient.table(anyString(), any(TableSchema.class))).thenReturn(table);
        doNothing().when(table).putItem(any(DynamoRealtimeSessionTokenItem.class));
        when(table.getItem(any(Key.class))).thenReturn(null);
        repo = new DynamoDbRealtimeSessionTokensRepository(enhancedClient, "test-ws-sessions");
    }

    @Test
    void upsert_doesNotThrow() {
        RealtimeSessionToken t = new RealtimeSessionToken(
                "tok-abc",
                "user-1",
                Instant.parse("2024-01-01T00:00:00Z"),
                Instant.parse("2024-01-01T00:02:00Z")
        );
        assertDoesNotThrow(() -> repo.upsert(t));
    }

    @Test
    void findByToken_emptyWhenMissing() {
        assertTrue(repo.findByToken("nope").isEmpty());
    }
}
