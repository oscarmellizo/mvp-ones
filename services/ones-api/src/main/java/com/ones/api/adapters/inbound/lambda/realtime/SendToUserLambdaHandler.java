package com.ones.api.adapters.inbound.lambda.realtime;

import java.net.URI;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.ones.api.adapters.outbound.dynamodb.DynamoDbRealtimeConnectionsRepository;
import com.ones.api.application.realtime.RealtimeDeliveryService;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;

public class SendToUserLambdaHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        try {
            String userId = extractString(event, "userId");
            String message = extractString(event, "message");
            String dataBase64 = extractString(event, "dataBase64");
            byte[] payload = message != null ? message.getBytes(java.nio.charset.StandardCharsets.UTF_8)
                    : (dataBase64 != null ? Base64.getDecoder().decode(dataBase64) : new byte[0]);

            String region = Optional.ofNullable(System.getenv("AWS_REGION")).orElse("us-east-1");
            String apiId = System.getenv("WS_API_ID");
            String stage = Optional.ofNullable(System.getenv("WS_STAGE")).orElse("dev");
            String endpoint = Optional.ofNullable(System.getenv("WS_MGMT_ENDPOINT"))
                    .orElse("https://" + apiId + ".execute-api." + region + ".amazonaws.com/" + stage);

            ApiGatewayManagementApiClient mgmt = ApiGatewayManagementApiClient.builder()
                    .region(Region.of(region))
                    .endpointOverride(URI.create(endpoint))
                    .build();

            String connsTable = Optional.ofNullable(System.getenv("ONES_WS_CONNECTIONS_TABLE")).orElse("ones-dev-ws-connections");
            DynamoDbClient ddb = DynamoDbClient.builder().region(Region.of(region)).build();
            DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder().dynamoDbClient(ddb).build();
            var repo = new DynamoDbRealtimeConnectionsRepository(enhanced, connsTable);

            var delivery = new RealtimeDeliveryService(repo);
            var result = delivery.deliverToUser(userId, payload, mgmt);

            return Map.of(
                    "statusCode", 200,
                    "attempted", result.getAttempted(),
                    "success", result.getSuccess(),
                    "removed", result.getRemoved(),
                    "failed", result.getFailed()
            );
        } catch (Exception e) {
            return Map.of("statusCode", 500, "error", "Internal Error");
        }
    }

    private static String extractString(Map<String, Object> map, String key) {
        Object v = map != null ? map.get(key) : null;
        return v != null ? v.toString() : null;
    }
}
