package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.when;

import java.time.Instant;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import com.ones.api.domain.push.DeviceToken;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.Key;

public class DynamoDbDeviceTokensRepositoryTest {

    private DynamoDbEnhancedClient enhancedClient;
    private DynamoDbDeviceTokensRepository repo;

    @BeforeEach
    void setUp() {
        enhancedClient = Mockito.mock(DynamoDbEnhancedClient.class);
        @SuppressWarnings("unchecked")
        DynamoDbTable<DynamoDeviceTokenItem> table = (DynamoDbTable<DynamoDeviceTokenItem>) Mockito.mock(DynamoDbTable.class);
        when(enhancedClient.table(anyString(), any(TableSchema.class))).thenReturn(table);
        doNothing().when(table).putItem(any(DynamoDeviceTokenItem.class));
        // deleteItem likely returns a value; no stub required for no-op
        repo = new DynamoDbDeviceTokensRepository(enhancedClient, "test-device-tokens");
    }

    @Test
    void upsert_doesNotThrow() {
        DeviceToken dt = new DeviceToken(
                "user-1",
                "android",
                "raw",
                "hash",
                Instant.parse("2024-01-01T00:00:00Z"),
                Instant.parse("2024-01-01T00:00:00Z"),
                true,
                "Pixel"
        );
        assertDoesNotThrow(() -> repo.upsert(dt));
    }

    @Test
    void delete_doesNotThrow() {
        assertDoesNotThrow(() -> repo.deleteByUserAndTokenHash("user-1", "android", "hash"));
    }
}
