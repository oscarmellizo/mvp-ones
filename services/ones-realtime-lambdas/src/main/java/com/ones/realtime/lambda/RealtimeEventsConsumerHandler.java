package com.ones.realtime.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.QueryRequest;
import software.amazon.awssdk.services.dynamodb.model.QueryResponse;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

public class RealtimeEventsConsumerHandler implements RequestHandler<SQSEvent, Void> {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Override
    public Void handleRequest(SQSEvent event, Context context) {
        String enable = System.getenv("ENABLE_REALTIME_DISPATCH");
        boolean enabled = enable != null && enable.equalsIgnoreCase("true");

        if (event == null || event.getRecords() == null || event.getRecords().isEmpty()) {
            return null;
        }
        int processed = 0, skipped = 0, errors = 0;
        for (SQSEvent.SQSMessage msg : event.getRecords()) {
            try {
                Map<String, Object> payload = MAPPER.readValue(msg.getBody(), new TypeReference<Map<String, Object>>() {});
                String type = str(payload.get("type"));
                if (type == null) { skipped++; continue; }
                Map<String, Object> data = getMap(payload.get("data"));

                // Filter by supported types
                if (!isSupportedType(type)) { skipped++; continue; }

                if (!enabled) { processed++; continue; }

                dispatch(type, data);
                processed++;
            } catch (Exception e) {
                errors++;
            }
        }
        System.out.println("[RealtimeConsumer] processed=" + processed + " skipped=" + skipped + " errors=" + errors);
        return null;
    }

    private boolean isSupportedType(String type) {
        return switch (type) {
            case "photo.uploaded", "event.updated", "invitation.created", "invitation.responded" -> true;
            default -> false;
        };
    }

    private void dispatch(String type, Map<String, Object> data) throws Exception {
        String region = Optional.ofNullable(System.getenv("AWS_REGION")).orElse("us-east-1");
        String apiId = System.getenv("WS_API_ID");
        String stage = Optional.ofNullable(System.getenv("WS_STAGE")).orElse("dev");
        String wsConnectionsTable = System.getenv("ONES_WS_CONNECTIONS_TABLE");
        String invitationsTable = System.getenv("INVITATIONS_TABLE_NAME");
        String usersTable = System.getenv("USERS_TABLE_NAME");

        if (apiId == null || apiId.isBlank() || wsConnectionsTable == null || wsConnectionsTable.isBlank()) {
            return; // misconfigured
        }

        ApiGatewayManagementApiClient mgmt = ApiGatewayManagementApiClient.builder()
                .region(Region.of(region))
                .endpointOverride(URI.create("https://" + apiId + ".execute-api." + region + ".amazonaws.com/" + stage))
                .build();
        DynamoDbClient ddb = DynamoDbClient.builder().region(Region.of(region)).build();

        Set<String> recipients = switch (type) {
            case "photo.uploaded" -> resolvePhotoUploadedRecipients(ddb, invitationsTable, data);
            case "event.updated" -> resolveEventUpdatedRecipients(ddb, invitationsTable, data);
            case "invitation.created" -> resolveInvitationCreatedRecipients(ddb, usersTable, data);
            case "invitation.responded" -> resolveInvitationRespondedRecipients(data);
            default -> Collections.emptySet();
        };
        if (recipients.isEmpty()) return;

        byte[] payload = buildRealtimePayload(type, data);
        SdkBytes bytes = SdkBytes.fromByteArray(payload);

        for (String userId : recipients) {
            try {
                for (String connectionId : listConnectionIdsByUserId(ddb, wsConnectionsTable, userId)) {
                    try {
                        mgmt.postToConnection(PostToConnectionRequest.builder()
                                .connectionId(connectionId)
                                .data(bytes)
                                .build());
                    } catch (Exception ignored) { }
                }
            } catch (Exception ignored) { }
        }
    }

    private Set<String> resolvePhotoUploadedRecipients(DynamoDbClient ddb, String invitationsTable, Map<String, Object> data) {
        String eventId = str(data.get("eventId"));
        String uploaderUserId = str(data.get("uploaderUserId"));
        if (eventId == null || invitationsTable == null) return Set.of();
        return listAcceptedInviteeUserIdsByEventId(ddb, invitationsTable, eventId, uploaderUserId, true);
    }

    private Set<String> resolveEventUpdatedRecipients(DynamoDbClient ddb, String invitationsTable, Map<String, Object> data) {
        String eventId = str(data.get("eventId"));
        String ownerId = str(data.get("ownerId"));
        if (eventId == null || invitationsTable == null) return Set.of();
        Set<String> ids = listAcceptedInviteeUserIdsByEventId(ddb, invitationsTable, eventId, null, false);
        if (ownerId != null && !ownerId.isBlank()) ids.add(ownerId);
        return ids;
    }

    private Set<String> resolveInvitationCreatedRecipients(DynamoDbClient ddb, String usersTable, Map<String, Object> data) {
        String email = optLower(str(data.get("inviteeEmail")));
        if (email == null || usersTable == null) return Set.of();
        try {
            QueryResponse qr = ddb.query(QueryRequest.builder()
                    .tableName(usersTable)
                    .indexName("byEmail")
                    .keyConditionExpression("email = :e")
                    .expressionAttributeValues(Map.of(":e", AttributeValue.builder().s(email).build()))
                    .limit(1)
                    .build());
            if (!qr.hasItems() || qr.items().isEmpty()) return Set.of();
            String userId = orNull(qr.items().get(0).get("userId"));
            return userId != null ? Set.of(userId) : Set.of();
        } catch (Exception e) {
            return Set.of();
        }
    }

    private Set<String> resolveInvitationRespondedRecipients(Map<String, Object> data) {
        String ownerId = str(data.get("ownerId"));
        return (ownerId != null && !ownerId.isBlank()) ? Set.of(ownerId) : Set.of();
    }

    private Set<String> listAcceptedInviteeUserIdsByEventId(DynamoDbClient ddb, String invitationsTable, String eventId, String excludeUserId, boolean includeOwner) {
        try {
            QueryResponse qr = ddb.query(QueryRequest.builder()
                    .tableName(invitationsTable)
                    .indexName("byEventId")
                    .keyConditionExpression("eventId = :e")
                    .expressionAttributeValues(Map.of(":e", AttributeValue.builder().s(eventId).build()))
                    .build());
            Set<String> out = new HashSet<>();
            String ownerId = null;
            for (Map<String, AttributeValue> item : qr.items()) {
                String status = orNull(item.get("status"));
                String uid = orNull(item.get("inviteeUserId"));
                if (ownerId == null) ownerId = orNull(item.get("eventOwnerId"));
                if (!"accepted".equalsIgnoreCase(status)) continue;
                if (uid == null || uid.isBlank()) continue;
                if (excludeUserId != null && excludeUserId.equals(uid)) continue;
                out.add(uid);
            }
            if (includeOwner && ownerId != null && (excludeUserId == null || !excludeUserId.equals(ownerId))) {
                out.add(ownerId);
            }
            return out;
        } catch (Exception e) {
            return Set.of();
        }
    }

    private List<String> listConnectionIdsByUserId(DynamoDbClient ddb, String tableName, String userId) {
        try {
            QueryResponse qr = ddb.query(QueryRequest.builder()
                    .tableName(tableName)
                    .indexName("byUserId")
                    .keyConditionExpression("userId = :u")
                    .expressionAttributeValues(Map.of(":u", AttributeValue.builder().s(userId).build()))
                    .scanIndexForward(false)
                    .limit(200)
                    .build());
            return qr.items().stream()
                    .map(m -> orNull(m.get("connectionId")))
                    .filter(Objects::nonNull)
                    .collect(Collectors.toList());
        } catch (Exception e) {
            return List.of();
        }
    }

    private byte[] buildRealtimePayload(String type, Map<String, Object> data) throws Exception {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("type", type);
        String eventId = str(data.get("eventId"));
        if (eventId != null) {
            out.put("entityType", "event");
            out.put("entityId", eventId);
            out.put("route", "/events/" + eventId);
        }
        switch (type) {
            case "photo.uploaded" -> {
                int count = asInt(data.get("photoCount"));
                String uploaderName = str(data.get("uploaderName"));
                String who = (uploaderName != null && !uploaderName.isBlank()) ? uploaderName.trim() : "Alguien";
                String eventTitle = str(data.get("eventTitle"));
                String title = "Nuevas fotos en el evento";
                String body = count <= 1 ? (who + " subió una foto" + (eventTitle != null && !eventTitle.isBlank() ? (" · " + eventTitle) : ""))
                        : (who + " subió " + count + " fotos" + (eventTitle != null && !eventTitle.isBlank() ? (" · " + eventTitle) : ""));
                out.put("title", title);
                out.put("body", body);
            }
            case "event.updated" -> {
                String title = "Evento actualizado";
                String body = str(data.get("title"));
                out.put("title", title);
                out.put("body", body != null ? body : "");
            }
            case "invitation.created" -> {
                out.put("title", "Fuiste invitado a un evento");
                out.put("body", Optional.ofNullable(str(data.get("eventTitle"))).orElse(""));
            }
            case "invitation.responded" -> {
                out.put("title", "Respuesta a tu invitación");
                String invitee = Optional.ofNullable(str(data.get("inviteeEmail"))).orElse("Invitado");
                String status = Optional.ofNullable(str(data.get("status"))).orElse("");
                out.put("body", invitee + " → " + status.toLowerCase());
            }
        }
        out.put("occurredAt", Instant.now().toString());
        return MAPPER.writeValueAsBytes(out);
    }

    private static String str(Object o) {
        return o == null ? null : o.toString();
    }

    private static String orNull(AttributeValue v) {
        if (v == null) return null;
        if (v.s() != null) return v.s();
        if (v.n() != null) return v.n();
        return null;
    }

    private static Map<String, Object> getMap(Object o) {
        if (o instanceof Map<?, ?> m) {
            @SuppressWarnings("unchecked")
            Map<String, Object> casted = (Map<String, Object>) m;
            return casted;
        }
        return Collections.emptyMap();
    }

    private static int asInt(Object o) {
        try { return Integer.parseInt(String.valueOf(o)); } catch (Exception e) { return 0; }
    }

    private static String optLower(String s) {
        return s != null ? s.trim().toLowerCase() : null;
    }
}
