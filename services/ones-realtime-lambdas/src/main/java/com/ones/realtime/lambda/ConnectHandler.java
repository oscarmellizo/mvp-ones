package com.ones.realtime.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.DeleteItemRequest;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public class ConnectHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        try {
            String connectionId = extractConnectionId(event);
            String sessionToken = extractQueryParam(event, "sessionToken");
            if (connectionId == null || connectionId.isBlank() || sessionToken == null || sessionToken.isBlank()) {
                return response(401, "Unauthorized");
            }

            String region = Optional.ofNullable(System.getenv("AWS_REGION")).orElse("us-east-1");
            DynamoDbClient ddb = DynamoDbClient.builder().region(Region.of(region)).build();

            String sessionsTable = Optional.ofNullable(System.getenv("ONES_WS_SESSIONS_TABLE")).orElse("ones-dev-ws-sessions");
            String connectionsTable = Optional.ofNullable(System.getenv("ONES_WS_CONNECTIONS_TABLE")).orElse("ones-dev-ws-connections");

            Map<String, AttributeValue> key = Map.of("token", AttributeValue.builder().s(sessionToken.trim()).build());
            var getResp = ddb.getItem(GetItemRequest.builder().tableName(sessionsTable).key(key).build());
            if (getResp.item() == null || getResp.item().isEmpty()) {
                return response(401, "Unauthorized");
            }

            String userId = getString(getResp.item(), "userId");
            String expiresAt = getString(getResp.item(), "expiresAt");
            if (userId == null || userId.isBlank()) return response(401, "Unauthorized");
            if (expiresAt != null && !expiresAt.isBlank()) {
                Instant exp = Instant.parse(expiresAt);
                if (Instant.now().isAfter(exp)) return response(401, "Unauthorized");
            }

            Map<String, AttributeValue> item = new HashMap<>();
            item.put("connectionId", AttributeValue.builder().s(connectionId.trim()).build());
            item.put("userId", AttributeValue.builder().s(userId.trim()).build());
            item.put("createdAt", AttributeValue.builder().s(Instant.now().toString()).build());
            ddb.putItem(PutItemRequest.builder().tableName(connectionsTable).item(item).build());

            ddb.deleteItem(DeleteItemRequest.builder().tableName(sessionsTable).key(key).build());
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

    @SuppressWarnings("unchecked")
    private static String extractQueryParam(Map<String, Object> event, String key) {
        Map<String, Object> qs = (Map<String, Object>) event.get("queryStringParameters");
        if (qs == null) return null;
        Object v = qs.get(key);
        return v != null ? v.toString() : null;
    }

    private static String getString(Map<String, AttributeValue> item, String key) {
        AttributeValue v = item.get(key);
        return v == null ? null : v.s();
    }

    private static Map<String, Object> response(int statusCode, String body) {
        return Map.of("statusCode", statusCode, "body", body);
    }
}
