package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionMember;
import com.ones.api.domain.collections.CollectionType;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsRequest;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsResponse;

class DynamoDbCollectionMembersRepositoryTest {
    @SuppressWarnings("unchecked")
    @Test
    void coupleInviteUsesAtomicConditionalReservationForItsOnlyMemberSlot() {
        DynamoDbEnhancedClient enhancedClient = mock(DynamoDbEnhancedClient.class);
        DynamoDbTable<DynamoCollectionMemberItem> table = mock(DynamoDbTable.class);
        when(enhancedClient.table(anyString(), any(TableSchema.class))).thenReturn(table);
        DynamoDbClient dynamoDbClient = mock(DynamoDbClient.class);
        when(dynamoDbClient.transactWriteItems(any(TransactWriteItemsRequest.class)))
                .thenReturn(TransactWriteItemsResponse.builder().build());

        DynamoDbCollectionMembersRepository repository = new DynamoDbCollectionMembersRepository(
                enhancedClient, dynamoDbClient, "members", "collections"
        );
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        Collection collection = new Collection(
                "c-1", "owner", "Pareja", null, CollectionType.COUPLE,
                null, null, now, now, false, null, false, null
        );
        CollectionMember pending = new CollectionMember(
                "c-1", "EMAIL#partner@example.com", null, "partner@example.com",
                CollectionMember.Status.PENDING, "owner", now, now
        );

        assertTrue(repository.add(collection, pending));

        ArgumentCaptor<TransactWriteItemsRequest> request =
                ArgumentCaptor.forClass(TransactWriteItemsRequest.class);
        verify(dynamoDbClient).transactWriteItems(request.capture());
        assertEquals(2, request.getValue().transactItems().size());
        assertEquals(
                "attribute_not_exists(partnerSlotKey)",
                request.getValue().transactItems().get(1).update().conditionExpression()
        );
    }
}
