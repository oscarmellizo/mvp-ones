package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;

import com.ones.api.adapters.outbound.dynamodb.DynamoDbEventComplementsRepository;
import com.ones.api.adapters.outbound.dynamodb.DynamoEventComplementItem;
import com.ones.api.application.complements.EventComplementModule;
import com.ones.api.application.complements.EventComplementsService;

import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

class EventComplementPersistenceTest {

    @Test
    void enhancedDynamoSchemaPersistsEnabledFlag() {
        DynamoEventComplementItem item = new DynamoEventComplementItem();
        item.setEventId("event-1");
        item.setComplementId("tournament");
        item.setEnabled(true);

        Map<String, AttributeValue> attributes =
                TableSchema.fromBean(DynamoEventComplementItem.class).itemToMap(item, true);

        assertEquals(Boolean.TRUE, attributes.get("enabled").bool());
    }

    @Test
    void legacyRowWithoutEnabledFlagRemainsVisible() {
        DynamoDbEventComplementsRepository repository = mock(DynamoDbEventComplementsRepository.class);
        DynamoEventComplementItem legacyItem = new DynamoEventComplementItem();
        legacyItem.setEventId("event-1");
        legacyItem.setComplementId("tournament");
        legacyItem.setTabLabel("Torneo");
        when(repository.listByEventId("event-1")).thenReturn(List.of(legacyItem));

        EventComplementModule tournamentModule = new EventComplementModule() {
            @Override
            public String id() {
                return "tournament";
            }

            @Override
            public String displayName() {
                return "Torneo 4 Equipos";
            }

            @Override
            public String defaultTabLabel() {
                return "Torneo";
            }

            @Override
            public void initialize(String eventId, String ownerId) {
            }
        };
        EventComplementsService service =
                new EventComplementsService(repository, List.of(tournamentModule), Clock.systemUTC());

        assertTrue(service.list("event-1").get(0).enabled());
    }
}
