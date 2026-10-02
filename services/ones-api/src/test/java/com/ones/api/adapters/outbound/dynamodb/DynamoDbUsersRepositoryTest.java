package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.domain.users.User;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.PutItemEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;

class DynamoDbUsersRepositoryTest {

    private static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");
    private static final Instant CLAIM = Instant.parse("2026-10-02T03:00:00Z");

    private DynamoDbTable<DynamoUserItem> table;
    private DynamoDbUsersRepository repo;

    @BeforeEach
    @SuppressWarnings("unchecked")
    void setUp() {
        table = mock(DynamoDbTable.class);
        DynamoDbEnhancedClient client = mock(DynamoDbEnhancedClient.class);
        when(client.table(anyString(), any(TableSchema.class))).thenReturn((DynamoDbTable) table);
        repo = new DynamoDbUsersRepository(client, new SimpleMeterRegistry(), "ones-users", false);
    }

    private static User disabled() {
        return new User("u1", "a@b.com", "Ana", null, null, null, null, "google", null, true, T0, T0,
                User.STATUS_DISABLED, T0, null);
    }

    @Test
    @SuppressWarnings("unchecked")
    void upsertIfStatus_putsWithStatusCondition() {
        assertTrue(repo.upsertIfStatus(disabled().withClosing(CLAIM), User.STATUS_DISABLED));

        ArgumentCaptor<PutItemEnhancedRequest<DynamoUserItem>> req = ArgumentCaptor.forClass(PutItemEnhancedRequest.class);
        verify(table).putItem(req.capture());
        assertEquals("#st = :expected", req.getValue().conditionExpression().expression());
        assertEquals("DISABLED", req.getValue().conditionExpression().expressionValues().get(":expected").s());
        assertEquals("CLOSING", req.getValue().item().getStatus());
        assertEquals(CLAIM.toString(), req.getValue().item().getClosingAt());
    }

    @Test
    @SuppressWarnings("unchecked")
    void upsertIfStatus_nullExpected_requiresExistingRowWithoutStatus() {
        repo.upsertIfStatus(disabled(), null);

        ArgumentCaptor<PutItemEnhancedRequest<DynamoUserItem>> req = ArgumentCaptor.forClass(PutItemEnhancedRequest.class);
        verify(table).putItem(req.capture());
        assertEquals("attribute_exists(#id) AND attribute_not_exists(#st)", req.getValue().conditionExpression().expression());
    }

    @Test
    @SuppressWarnings("unchecked")
    void upsertIfClosing_conditionsOnStatusAndClosingAt() {
        repo.upsertIfClosing(disabled().withClosing(CLAIM).withLifecycle(User.STATUS_CLOSED, CLAIM, "t", null), CLAIM);

        ArgumentCaptor<PutItemEnhancedRequest<DynamoUserItem>> req = ArgumentCaptor.forClass(PutItemEnhancedRequest.class);
        verify(table).putItem(req.capture());
        assertEquals("#st = :closing AND #ca = :closingAt", req.getValue().conditionExpression().expression());
        assertEquals(CLAIM.toString(), req.getValue().conditionExpression().expressionValues().get(":closingAt").s());
    }

    @Test
    @SuppressWarnings("unchecked")
    void conditionalCheckFailed_returnsFalse() {
        doThrow(ConditionalCheckFailedException.builder().message("no").build())
                .when(table).putItem(any(PutItemEnhancedRequest.class));

        assertFalse(repo.upsertIfStatus(disabled(), User.STATUS_ACTIVE));
    }
}
