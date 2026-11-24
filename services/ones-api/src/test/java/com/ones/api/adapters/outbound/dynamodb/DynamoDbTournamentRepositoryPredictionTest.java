package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.domain.tournament.TournamentModels.MatchScore;
import com.ones.api.domain.tournament.TournamentModels.UserPrediction;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.Put;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.DeleteItemRequest;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsRequest;

class DynamoDbTournamentRepositoryPredictionTest {

    @Test
    void claimsARecalculationOnceForAnEventAndVersion() {
        DynamoDbClient dynamoDbClient = mock(DynamoDbClient.class);
        DynamoDbTournamentRepository repository = repository(dynamoDbClient);

        assertTrue(repository.claimScoreRecalculation("event-1", 4, 100_000, 40_000));

        ArgumentCaptor<PutItemRequest> putCaptor = ArgumentCaptor.forClass(PutItemRequest.class);
        verify(dynamoDbClient).putItem(putCaptor.capture());
        PutItemRequest put = putCaptor.getValue();
        assertEquals("EVENT#event-1#SCORE_RECALC", put.item().get("pk").s());
        assertEquals(
                "attribute_not_exists(#pk) OR #requestedAt < :cutoff OR #stateVersion < :version",
                put.conditionExpression());
        assertEquals("4", put.item().get("stateVersion").n());
        assertEquals("100000", put.item().get("requestedAt").n());
        assertEquals("40000", put.expressionAttributeValues().get(":cutoff").n());
    }

    @Test
    void returnsFalseWhenAnotherManagerAlreadyClaimedTheRecalculation() {
        DynamoDbClient dynamoDbClient = mock(DynamoDbClient.class);
        when(dynamoDbClient.putItem(any(PutItemRequest.class)))
                .thenThrow(ConditionalCheckFailedException.builder().message("already claimed").build());
        DynamoDbTournamentRepository repository = repository(dynamoDbClient);

        assertFalse(repository.claimScoreRecalculation("event-1", 4, 100_000, 40_000));
    }

    @Test
    void releasesOnlyTheMatchingRecalculationClaim() {
        DynamoDbClient dynamoDbClient = mock(DynamoDbClient.class);
        DynamoDbTournamentRepository repository = repository(dynamoDbClient);

        repository.releaseScoreRecalculation("event-1", 4, 100_000);

        ArgumentCaptor<DeleteItemRequest> deleteCaptor = ArgumentCaptor.forClass(DeleteItemRequest.class);
        verify(dynamoDbClient).deleteItem(deleteCaptor.capture());
        assertEquals("EVENT#event-1#SCORE_RECALC", deleteCaptor.getValue().key().get("pk").s());
        assertEquals("100000", deleteCaptor.getValue().expressionAttributeValues().get(":requestedAt").n());
    }

    @Test
    void omitsExpressionValuesForFirstPrediction() {
        DynamoDbClient dynamoDbClient = mock(DynamoDbClient.class);
        DynamoDbTournamentRepository repository = new DynamoDbTournamentRepository(
                mock(DynamoDbEnhancedClient.class),
                dynamoDbClient,
                new ObjectMapper().findAndRegisterModules(),
                "ones-tournaments");
        repository.savePredictionIfOpen(prediction(), 0);

        ArgumentCaptor<TransactWriteItemsRequest> requestCaptor =
                ArgumentCaptor.forClass(TransactWriteItemsRequest.class);
        verify(dynamoDbClient).transactWriteItems(requestCaptor.capture());
        Put forecastPut = requestCaptor.getValue().transactItems().get(1).put();
        assertFalse(forecastPut.hasExpressionAttributeValues());
    }

    @Test
    void usesOnlyVersionPlaceholderWhenUpdatingPrediction() {
        DynamoDbClient dynamoDbClient = mock(DynamoDbClient.class);
        DynamoDbTournamentRepository repository = new DynamoDbTournamentRepository(
                mock(DynamoDbEnhancedClient.class),
                dynamoDbClient,
                new ObjectMapper().findAndRegisterModules(),
                "ones-tournaments");

        repository.savePredictionIfOpen(prediction(), 1);

        ArgumentCaptor<TransactWriteItemsRequest> requestCaptor =
                ArgumentCaptor.forClass(TransactWriteItemsRequest.class);
        verify(dynamoDbClient).transactWriteItems(requestCaptor.capture());
        Put forecastPut = requestCaptor.getValue().transactItems().get(1).put();
        assertEquals(Map.of("#version", "version"), forecastPut.expressionAttributeNames());
        assertEquals("1", forecastPut.expressionAttributeValues().get(":expected").n());
    }

    private static UserPrediction prediction() {
        return new UserPrediction(
                "event-1",
                "user-1",
                "Tester",
                Map.of("rr-1", new MatchScore(1, 0)),
                null,
                null,
                0,
                0,
                0,
                -1,
                1,
                Instant.parse("2026-01-01T00:00:00Z"));
    }

    private static DynamoDbTournamentRepository repository(DynamoDbClient dynamoDbClient) {
        return new DynamoDbTournamentRepository(
                mock(DynamoDbEnhancedClient.class),
                dynamoDbClient,
                new ObjectMapper().findAndRegisterModules(),
                "ones-tournaments");
    }
}
