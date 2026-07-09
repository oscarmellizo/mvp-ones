package com.ones.api.application.photos;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.GoneException;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.QueryRequest;
import software.amazon.awssdk.services.dynamodb.model.QueryResponse;

import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class PhotosWsPublisher {

    private static final Logger log = LoggerFactory.getLogger(PhotosWsPublisher.class);

    private final DynamoDbClient dynamoDbClient;
    private final ApiGatewayManagementApiClient wsClient;
    private final ObjectMapper objectMapper;
    private final String subscriptionsTable;

    public PhotosWsPublisher(
            DynamoDbClient dynamoDbClient,
            ApiGatewayManagementApiClient wsClient,
            ObjectMapper objectMapper,
            @Value("${ones.ws.subscriptions-table-name:ones-photos-ws-subscriptions}") String subscriptionsTable
    ) {
        this.dynamoDbClient = dynamoDbClient;
        this.wsClient = wsClient;
        this.objectMapper = objectMapper;
        this.subscriptionsTable = subscriptionsTable;
    }

    public void publishPhotoUploaded(
            String eventId,
            String uploaderName,
            int photoCount,
            String eventTitle
    ) {
        if (subscriptionsTable == null || subscriptionsTable.isBlank()) {
            log.warn("ones.ws.subscriptions-table-name not configured; skipping photo.uploaded publish");
            return;
        }

        List<String> connectionIds = queryConnectionIds(eventId);
        if (connectionIds.isEmpty()) {
            log.debug("publishPhotoUploaded: no subscribers for eventId={}", eventId);
            return;
        }

        String payload;
        try {
            payload = objectMapper.writeValueAsString(Map.of(
                    "type", "photo.uploaded",
                    "eventId", eventId,
                    "uploaderName", uploaderName,
                    "photoCount", photoCount,
                    "eventTitle", eventTitle
            ));
        } catch (Exception e) {
            log.error("publishPhotoUploaded: failed to serialize payload for eventId={}", eventId, e);
            return;
        }

        SdkBytes data = SdkBytes.fromString(payload, StandardCharsets.UTF_8);
        for (String connectionId : connectionIds) {
            try {
                wsClient.postToConnection(
                        PostToConnectionRequest.builder()
                                .connectionId(connectionId)
                                .data(data)
                                .build()
                );
            } catch (GoneException e) {
                log.debug("publishPhotoUploaded: stale connectionId={} for eventId={}", connectionId, eventId);
            } catch (Exception e) {
                log.warn("publishPhotoUploaded: failed to post to connectionId={} for eventId={}: {}",
                        connectionId, eventId, e.getMessage());
            }
        }
    }

    private List<String> queryConnectionIds(String eventId) {
        List<String> result = new ArrayList<>();
        Map<String, AttributeValue> lastKey = null;
        do {
            QueryRequest.Builder reqBuilder = QueryRequest.builder()
                    .tableName(subscriptionsTable)
                    .keyConditionExpression("eventId = :eid")
                    .expressionAttributeValues(Map.of(
                            ":eid", AttributeValue.fromS(eventId)
                    ))
                    .projectionExpression("connectionId");
            if (lastKey != null) {
                reqBuilder = reqBuilder.exclusiveStartKey(lastKey);
            }
            QueryResponse resp = dynamoDbClient.query(reqBuilder.build());
            for (Map<String, AttributeValue> item : resp.items()) {
                AttributeValue cid = item.get("connectionId");
                if (cid != null && cid.s() != null && !cid.s().isBlank()) {
                    result.add(cid.s());
                }
            }
            lastKey = resp.hasLastEvaluatedKey() ? resp.lastEvaluatedKey() : null;
        } while (lastKey != null);
        return result;
    }
}
