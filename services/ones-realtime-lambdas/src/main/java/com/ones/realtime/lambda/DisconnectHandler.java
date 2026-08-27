package com.ones.realtime.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.DeleteItemRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

import java.util.Map;
import java.util.Optional;

public class DisconnectHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        try {
            String connectionId = extractConnectionId(event);
            if (connectionId == null || connectionId.isBlank()) {
                return response(400, "missing_connectionId");
            }

            String region = Optional.ofNullable(System.getenv("AWS_REGION")).orElse("us-east-1");
            DynamoDbClient ddb = DynamoDbClient.builder().region(Region.of(region)).build();
            String connectionsTable = Optional.ofNullable(System.getenv("ONES_WS_CONNECTIONS_TABLE")).orElse("ones-dev-ws-connections");

            ddb.deleteItem(DeleteItemRequest.builder()
                    .tableName(connectionsTable)
                    .key(Map.of("connectionId", AttributeValue.builder().s(connectionId.trim()).build()))
                    .build());

            return response(200, "OK");
        } catch (Exception e) {
            return response(500, "Internal Error");
        }
    }

    @SuppressWarnings("unchecked")
    private static String extractConnectionId(Map<String, Object> event) {
        Map<String, Object> requestContext = (Map<String, Object>) event.get("requestContext");
        if (requestContext == null) return null;
        Object cid = requestContext.get("connectionId");
        return cid != null ? cid.toString() : null;
    }

    private static Map<String, Object> response(int statusCode, String body) {
        return Map.of("statusCode", statusCode, "body", body);
    }
}
