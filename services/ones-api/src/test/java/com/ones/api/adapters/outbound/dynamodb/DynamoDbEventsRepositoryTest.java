package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.Test;

import com.ones.api.domain.events.Event;

class DynamoDbEventsRepositoryTest {

    @Test
    void preservesEventCodeWhenMappingToAndFromDynamoDb() {
        Event original = new Event(
                "event-123",
                "owner-1",
                Instant.parse("2025-01-01T00:00:00Z"),
                "Birthday",
                "celebration",
                "San Jose",
                Instant.parse("2025-01-02T18:00:00Z"),
                Instant.parse("2025-01-02T22:00:00Z"),
                null,
                true,
                true,
                List.of("frame-1"),
                "123456");

        DynamoEventItem item = DynamoDbEventsRepository.toItem(original);
        Event restored = DynamoDbEventsRepository.toDomain(item);

        assertEquals("123456", item.getEventCode());
        assertEquals("123456", restored.getEventCode());
    }
}
