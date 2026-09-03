package com.ones.realtime.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionRequest;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbBean;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondaryPartitionKey;
import software.amazon.awssdk.enhanced.dynamodb.mapper.annotations.DynamoDbSecondarySortKey;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

public class SendToUserHandler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @DynamoDbBean
    public static class ConnectionItem {
        private String connectionId;
        private String userId;
        private String createdAt;
        @DynamoDbPartitionKey
        public String getConnectionId() { return connectionId; }
        public void setConnectionId(String v) { connectionId = v; }
        @DynamoDbSecondaryPartitionKey(indexNames = {"byUserId"})
        public String getUserId() { return userId; }
        public void setUserId(String v) { userId = v; }
        @DynamoDbSecondarySortKey(indexNames = {"byUserId"})
        public String getCreatedAt() { return createdAt; }
        public void setCreatedAt(String v) { createdAt = v; }
    }

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        try {
            String userId = getString(event, "userId");
            String message = getString(event, "message");
            String dataBase64 = getString(event, "dataBase64");
            if (userId == null || userId.isBlank()) return resp(400, "missing userId");

            String region = Optional.ofNullable(System.getenv("AWS_REGION")).orElse("us-east-1");
            String endpoint = System.getenv("WS_MGMT_ENDPOINT");
            if (endpoint == null || endpoint.isBlank()) {
                String apiId = System.getenv("WS_API_ID");
                String stage = Optional.ofNullable(System.getenv("WS_STAGE")).orElse("dev");
                if (apiId != null && !apiId.isBlank()) {
                    endpoint = "https://" + apiId + ".execute-api." + region + ".amazonaws.com/" + stage;
                }
            }
            if (endpoint == null || endpoint.isBlank()) return resp(400, "missing endpoint");

            ApiGatewayManagementApiClient mgmt = ApiGatewayManagementApiClient.builder()
                    .region(Region.of(region))
                    .endpointOverride(URI.create(endpoint))
                    .build();

            DynamoDbClient ddb = DynamoDbClient.builder().region(Region.of(region)).build();
            DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder().dynamoDbClient(ddb).build();
            String tableName = Optional.ofNullable(System.getenv("ONES_WS_CONNECTIONS_TABLE")).orElse("ones-dev-ws-connections");
            DynamoDbTable<ConnectionItem> table = enhanced.table(tableName, TableSchema.fromBean(ConnectionItem.class));

            int attempted = 0, success = 0, failed = 0;
            byte[] payload = message != null ? message.getBytes(StandardCharsets.UTF_8)
                    : (dataBase64 != null ? java.util.Base64.getDecoder().decode(dataBase64) : new byte[0]);
            SdkBytes bytes = SdkBytes.fromByteArray(payload);
            DynamoDbIndex<ConnectionItem> index = table.index("byUserId");
            QueryEnhancedRequest req = QueryEnhancedRequest.builder()
                    .queryConditional(QueryConditional.keyEqualTo(
                            software.amazon.awssdk.enhanced.dynamodb.Key.builder().partitionValue(userId).build()))
                    .scanIndexForward(false)
                    .limit(200)
                    .build();
            for (var page : index.query(req)) {
                for (var it : page.items()) {
                    attempted++;
                    try {
                        mgmt.postToConnection(PostToConnectionRequest.builder()
                                .connectionId(it.getConnectionId())
                                .data(bytes)
                                .build());
                        success++;
                    } catch (Exception e) {
                        failed++;
                    }
                }
            }
            Map<String, Object> out = new HashMap<>();
            out.put("statusCode", 200);
            out.put("attempted", attempted);
            out.put("success", success);
            out.put("failed", failed);
            return out;
        } catch (Exception e) {
            return resp(500, "Internal Error");
        }
    }

    private static String getString(Map<String, Object> map, String key) {
        Object v = map != null ? map.get(key) : null;
        return v != null ? v.toString() : null;
    }

    private static Map<String, Object> resp(int code, String body) {
        return Map.of("statusCode", code, "body", body);
    }
}
