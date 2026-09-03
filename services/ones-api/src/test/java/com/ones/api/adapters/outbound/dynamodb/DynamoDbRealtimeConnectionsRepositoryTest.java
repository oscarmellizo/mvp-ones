package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.domain.realtime.RealtimeConnection;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.core.pagination.sync.SdkIterable;

public class DynamoDbRealtimeConnectionsRepositoryTest {

    private DynamoDbEnhancedClient enhancedClient;
    private DynamoDbTable<DynamoRealtimeConnectionItem> table;
    private DynamoDbIndex<DynamoRealtimeConnectionItem> index;
    private DynamoDbRealtimeConnectionsRepository repo;

    @BeforeEach
    void setUp() {
        enhancedClient = mock(DynamoDbEnhancedClient.class);
        table = mock(DynamoDbTable.class);
        index = mock(DynamoDbIndex.class);
        when(enhancedClient.table(any(), any(TableSchema.class))).thenReturn(table);
        when(table.index("byUserId")).thenReturn(index);
        repo = new DynamoDbRealtimeConnectionsRepository(enhancedClient, "ones-dev-ws-connections");
    }

    @Test
    void upsert_putsItem() {
        RealtimeConnection c = new RealtimeConnection("conn-1", "user-1", Instant.parse("2024-01-01T10:00:00Z"));
        repo.upsert(c);
        verify(table, times(1)).putItem(any(DynamoRealtimeConnectionItem.class));
    }

    @Test
    void deleteByConnectionId_deletesItem() {
        repo.deleteByConnectionId("conn-1");
        verify(table, times(1)).deleteItem(any(Key.class));
    }

    @Test
    void listByUserId_queriesIndex() {
        List<DynamoRealtimeConnectionItem> items = new ArrayList<>();
        DynamoRealtimeConnectionItem it = new DynamoRealtimeConnectionItem();
        it.setConnectionId("c1");
        it.setUserId("user-1");
        it.setCreatedAt("2024-01-01T10:00:00Z");
        items.add(it);

        @SuppressWarnings("unchecked")
        Page<DynamoRealtimeConnectionItem> page = mock(Page.class);
        when(page.items()).thenReturn(items);

        SdkIterable<Page<DynamoRealtimeConnectionItem>> iterable = new SdkIterable<>() {
            @Override
            public java.util.Iterator<Page<DynamoRealtimeConnectionItem>> iterator() {
                return java.util.List.<Page<DynamoRealtimeConnectionItem>>of(page).iterator();
            }
        };
        when(index.query(any(QueryEnhancedRequest.class))).thenReturn(iterable);

        List<RealtimeConnection> out = repo.listByUserId("user-1", 10);
        assertEquals(1, out.size());
        assertEquals("c1", out.get(0).getConnectionId());
        assertEquals("user-1", out.get(0).getUserId());
    }
}
