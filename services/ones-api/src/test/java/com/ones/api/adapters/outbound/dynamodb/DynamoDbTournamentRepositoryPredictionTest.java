package com.ones.api.adapters.outbound.dynamodb;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;

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
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsRequest;

class DynamoDbTournamentRepositoryPredictionTest {

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
}
