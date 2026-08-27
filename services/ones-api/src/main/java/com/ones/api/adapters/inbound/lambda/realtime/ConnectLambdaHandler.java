package com.ones.api.adapters.inbound.lambda.realtime;

import java.util.Map;
import java.util.Optional;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.ones.api.adapters.outbound.dynamodb.DynamoDbRealtimeConnectionsRepository;
import com.ones.api.adapters.outbound.dynamodb.DynamoDbRealtimeSessionTokensRepository;
import com.ones.api.application.realtime.SessionValidationService;
import com.ones.api.application.realtime.WebsocketConnectionService;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

public class ConnectLambdaHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        try {
            String connectionId = extractConnectionId(event);
            String sessionToken = extractQueryParam(event, "sessionToken");

            var region = Optional.ofNullable(System.getenv("AWS_REGION")).orElse("us-east-1");
            DynamoDbClient ddb = DynamoDbClient.builder().region(Region.of(region)).build();
            DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder().dynamoDbClient(ddb).build();

            String sessionsTable = Optional.ofNullable(System.getenv("ONES_WS_SESSIONS_TABLE")).orElse("ones-dev-ws-sessions");
            String connsTable = Optional.ofNullable(System.getenv("ONES_WS_CONNECTIONS_TABLE")).orElse("ones-dev-ws-connections");

            var sessionRepo = new DynamoDbRealtimeSessionTokensRepository(enhanced, sessionsTable);
            var connsRepo = new DynamoDbRealtimeConnectionsRepository(enhanced, connsTable);

            var clock = java.time.Clock.systemUTC();
            var sessionService = new SessionValidationService(sessionRepo, connsRepo, clock);
            var wsService = new WebsocketConnectionService(sessionService, sessionRepo);

            Optional<String> userId = wsService.connect(connectionId, sessionToken);
            if (userId.isEmpty()) {
                return response(401, "Unauthorized");
            }
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

    private static Map<String, Object> response(int statusCode, String body) {
        return Map.of(
                "statusCode", statusCode,
                "body", body
        );
    }
}
