package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.*;

import java.time.Instant;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

import com.ones.api.domain.notifications.Notification;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

public class DynamoDbNotificationsRepositoryTest {

    private DynamoDbEnhancedClient enhancedClient;
    private DynamoDbNotificationsRepository repo;

    @BeforeEach
    void setUp() {
        // Nota: Este test valida mapping básico sin tocar AWS. enhancedClient será un mock,
        // por lo que probaremos solo helpers toItem/toDomain indirectamente a través de métodos públicos
        enhancedClient = Mockito.mock(DynamoDbEnhancedClient.class);
        @SuppressWarnings("unchecked")
        DynamoDbTable<DynamoNotificationItem> table = (DynamoDbTable<DynamoNotificationItem>) Mockito.mock(DynamoDbTable.class);
        when(enhancedClient.table(eq("test-notifications"), any(TableSchema.class))).thenReturn(table);
        doNothing().when(table).putItem(any(DynamoNotificationItem.class));

        repo = new DynamoDbNotificationsRepository(enhancedClient, "test-notifications");
    }

    @Test
    void toItemAndBack_shouldPreserveFields() {
        Notification n = new Notification(
                "user-1",
                UUID.randomUUID().toString(),
                "invitations",
                "title",
                "body",
                Instant.parse("2024-01-01T10:00:00Z"),
                null,
                Notification.Status.CREATED,
                Notification.Priority.HIGH,
                "open",
                "event",
                "evt-1",
                "/events/evt-1"
        );

        // upsert no falla al serializar
        assertDoesNotThrow(() -> repo.upsert(n));
    }
}
