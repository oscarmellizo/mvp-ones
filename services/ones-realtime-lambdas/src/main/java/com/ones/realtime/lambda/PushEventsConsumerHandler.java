package com.ones.realtime.lambda;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.amazonaws.services.lambda.runtime.events.SQSEvent;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.pinpoint.PinpointClient;
import software.amazon.awssdk.services.pinpoint.model.AddressConfiguration;
import software.amazon.awssdk.services.pinpoint.model.APNSMessage;
import software.amazon.awssdk.services.pinpoint.model.ChannelType;
import software.amazon.awssdk.services.pinpoint.model.DirectMessageConfiguration;
import software.amazon.awssdk.services.pinpoint.model.GCMMessage;
import software.amazon.awssdk.services.pinpoint.model.MessageRequest;
import software.amazon.awssdk.services.pinpoint.model.SendMessagesRequest;
import software.amazon.awssdk.services.pinpoint.model.SendMessagesResponse;
import software.amazon.awssdk.services.pinpoint.model.MessageResult;

public class PushEventsConsumerHandler implements RequestHandler<SQSEvent, Void> {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    @Override
    public Void handleRequest(SQSEvent event, Context context) {
        String enable = System.getenv("ENABLE_PUSH_DISPATCH");
        boolean pushEnabled = enable != null && enable.equalsIgnoreCase("true");
        int processed = 0, skipped = 0, errors = 0;
        try {
            if (event == null || event.getRecords() == null) return null;

            Region region = Optional.ofNullable(System.getenv("AWS_REGION")).map(Region::of).orElse(Region.US_EAST_1);
            String appId = System.getenv("PINPOINT_APP_ID");
            String deviceTokensTable = Optional.ofNullable(System.getenv("DEVICE_TOKENS_TABLE_NAME")).orElse("ones-dev-device-tokens");
            String notificationsTable = Optional.ofNullable(System.getenv("NOTIFICATIONS_TABLE_NAME")).orElse("ones-dev-notifications");
            String invitationsTable = System.getenv("INVITATIONS_TABLE_NAME");
            String usersTable = System.getenv("USERS_TABLE_NAME");
            if (appId == null || appId.isBlank()) {
                System.out.println("[PushConsumer] Missing PINPOINT_APP_ID; skipping push dispatch");
            }
            PinpointClient pinpoint = (appId != null && !appId.isBlank()) ? PinpointClient.builder().region(region).build() : null;
            DynamoDbClient ddb = DynamoDbClient.builder().region(region).build();
            DynamoDbEnhancedClient enhanced = DynamoDbEnhancedClient.builder().dynamoDbClient(ddb).build();
            DynamoDbTable<DeviceTokenItem> tokens = enhanced.table(deviceTokensTable, TableSchema.fromBean(DeviceTokenItem.class));

            for (var msg : event.getRecords()) {
                try {
                    Map<String, Object> payload = MAPPER.readValue(msg.getBody(), new TypeReference<Map<String, Object>>(){});
                    String type = str(payload.get("type"));
                    Map<String, Object> data = getMap(payload.get("data"));
                    if (type == null) { skipped++; continue; }
                    Set<String> recipients = resolveRecipients(ddb, invitationsTable, usersTable, type, data);
                    if (recipients.isEmpty()) { skipped++; continue; }

                    String titleBody[] = buildTitleBody(type, data);
                    Map<String, String> dataMap = buildDataMap(type, data);
                    Instant now = Instant.now();
                    String eventId = dataMap.get("entityId");
                    String route = dataMap.get("route");

                    for (String userId : recipients) {
                        // Persist in-app notification (always)
                        persistNotification(ddb, notificationsTable, userId,
                                UUID.randomUUID().toString(), type, titleBody[0], titleBody[1],
                                "open", dataMap.get("entityType"), eventId, route, now);

                        // Send push only if enabled and configured
                        if (pushEnabled && pinpoint != null) {
                            List<DeviceTokenItem> list = listTokens(tokens, userId, 100);
                            Map<String, AddressConfiguration> addresses = new HashMap<>();
                            for (DeviceTokenItem t : list) {
                                if (Boolean.FALSE.equals(t.getEnabled())) continue;
                                String token = t.getToken();
                                ChannelType ch = mapChannel(t.getPlatform());
                                if (token == null || token.isBlank() || ch == null) continue;
                                addresses.put(token, AddressConfiguration.builder().channelType(ch).build());
                            }
                            if (!addresses.isEmpty()) {
                                GCMMessage gcm = GCMMessage.builder().title(titleBody[0]).body(titleBody[1]).data(dataMap).priority("high").build();
                                APNSMessage apns = APNSMessage.builder().title(titleBody[0]).body(titleBody[1]).badge(1).sound("default").build();
                                DirectMessageConfiguration dmc = DirectMessageConfiguration.builder().gcmMessage(gcm).apnsMessage(apns).build();
                                MessageRequest mr = MessageRequest.builder().addresses(addresses).messageConfiguration(dmc).build();
                                SendMessagesRequest req = SendMessagesRequest.builder().applicationId(appId).messageRequest(mr).build();
                                try {
                                    SendMessagesResponse resp = pinpoint.sendMessages(req);
                                    System.out.println("[PushConsumer] sent user=" + userId + " results=" + summarize(resp));
                                } catch (Exception ex) {
                                    System.out.println("[PushConsumer] send failed user=" + userId + " err=" + ex);
                                }
                            }
                        }
                    }

                    processed++;
                } catch (Exception e) {
                    errors++;
                }
            }
        } finally {
            System.out.println("[PushConsumer] processed=" + processed + " skipped=" + skipped + " errors=" + errors);
        }
        return null;
    }

    private static String[] buildTitleBody(String type, Map<String, Object> data) {
        if ("photo.uploaded".equals(type)) {
            int count = asInt(data.get("photoCount"));
            String uploader = str(data.get("uploaderName"));
            String who = (uploader != null && !uploader.isBlank()) ? uploader : "Alguien";
            String eventTitle = str(data.get("eventTitle"));
            String title = "Nuevas fotos en el evento";
            String body = count <= 1 ? (who + " subió una foto" + (eventTitle != null && !eventTitle.isBlank() ? (" · " + eventTitle) : ""))
                    : (who + " subió " + count + " fotos" + (eventTitle != null && !eventTitle.isBlank() ? (" · " + eventTitle) : ""));
            return new String[]{title, body};
        }
        if ("event.updated".equals(type)) {
            return new String[]{"Evento actualizado", Optional.ofNullable(str(data.get("title"))).orElse("")};
        }
        if ("invitation.created".equals(type)) {
            return new String[]{"Fuiste invitado a un evento", Optional.ofNullable(str(data.get("eventTitle"))).orElse("")};
        }
        if ("invitation.responded".equals(type)) {
            String invitee = Optional.ofNullable(str(data.get("inviteeEmail"))).orElse("Invitado");
            String status = Optional.ofNullable(str(data.get("status"))).orElse("");
            return new String[]{"Respuesta a tu invitación", invitee + " → " + status.toLowerCase()};
        }
        return new String[]{type, ""};
    }

    private static Map<String, String> buildDataMap(String type, Map<String, Object> data) {
        Map<String, String> out = new HashMap<>();
        String eventId = str(data.get("eventId"));
        if (eventId != null) {
            out.put("entityType", "event");
            out.put("entityId", eventId);
            out.put("route", "/events/" + eventId);
        }
        out.put("type", type);
        out.put("occurredAt", Instant.now().toString());
        return out;
    }

    private static Set<String> resolveRecipients(DynamoDbClient ddb, String invitationsTable, String usersTable, String type, Map<String, Object> data) {
        if ("event.updated".equals(type)) {
            String eventId = str(data.get("eventId"));
            String ownerId = str(data.get("ownerId"));
            Set<String> ids = listAcceptedInviteeUserIdsByEventId(ddb, invitationsTable, eventId, null);
            if (ownerId != null && !ownerId.isBlank()) ids.add(ownerId);
            return ids;
        }
        if ("invitation.created".equals(type)) {
            // Resolve by inviteeEmail similar to realtime consumer
            String email = str(data.get("inviteeEmail"));
            String userId = findUserIdByEmail(ddb, usersTable, email);
            return (userId != null) ? Set.of(userId) : Set.of();
        }
        if ("invitation.responded".equals(type)) {
            String ownerId = str(data.get("ownerId"));
            return (ownerId != null && !ownerId.isBlank()) ? Set.of(ownerId) : Set.of();
        }
        if ("photo.uploaded".equals(type)) {
            String eventId = str(data.get("eventId"));
            String uploaderUserId = str(data.get("uploaderUserId"));
            Set<String> ids = listAcceptedInviteeUserIdsByEventId(ddb, invitationsTable, eventId, uploaderUserId);
            // include owner if resolvable from invitations
            String ownerId = findOwnerIdByEventId(ddb, invitationsTable, eventId);
            if (ownerId != null && (uploaderUserId == null || !ownerId.equals(uploaderUserId))) ids.add(ownerId);
            return ids;
        }
        return Set.of();
    }

    private static Set<String> listAcceptedInviteeUserIdsByEventId(DynamoDbClient ddb, String invitationsTable, String eventId, String excludeUserId) {
        if (ddb == null || invitationsTable == null || eventId == null) return new HashSet<>();
        try {
            var qr = ddb.query(b -> b
                    .tableName(invitationsTable)
                    .indexName("byEventId")
                    .keyConditionExpression("eventId = :e")
                    .expressionAttributeValues(Map.of(":e", software.amazon.awssdk.services.dynamodb.model.AttributeValue.builder().s(eventId).build()))
            );
            Set<String> out = new HashSet<>();
            for (var item : qr.items()) {
                var status = item.get("status");
                var uid = item.get("inviteeUserId");
                if (status == null || status.s() == null || !"accepted".equalsIgnoreCase(status.s())) continue;
                if (uid == null || uid.s() == null) continue;
                String id = uid.s();
                if (excludeUserId != null && excludeUserId.equals(id)) continue;
                out.add(id);
            }
            return out;
        } catch (Exception e) { return new HashSet<>(); }
    }

    private static String findUserIdByEmail(DynamoDbClient ddb, String usersTable, String email) {
        if (ddb == null || usersTable == null || email == null || email.isBlank()) return null;
        try {
            var qr = ddb.query(b -> b
                    .tableName(usersTable)
                    .indexName("byEmail")
                    .keyConditionExpression("email = :e")
                    .expressionAttributeValues(Map.of(":e", software.amazon.awssdk.services.dynamodb.model.AttributeValue.builder().s(email.trim().toLowerCase()).build()))
                    .limit(1)
            );
            if (!qr.hasItems() || qr.items().isEmpty()) return null;
            var userId = qr.items().get(0).get("userId");
            return userId != null ? userId.s() : null;
        } catch (Exception e) { return null; }
    }

    private static String findOwnerIdByEventId(DynamoDbClient ddb, String invitationsTable, String eventId) {
        if (ddb == null || invitationsTable == null || eventId == null) return null;
        try {
            var qr = ddb.query(b -> b
                    .tableName(invitationsTable)
                    .indexName("byEventId")
                    .keyConditionExpression("eventId = :e")
                    .expressionAttributeValues(Map.of(":e", software.amazon.awssdk.services.dynamodb.model.AttributeValue.builder().s(eventId).build()))
                    .limit(1)
            );
            if (!qr.hasItems() || qr.items().isEmpty()) return null;
            var owner = qr.items().get(0).get("eventOwnerId");
            return owner != null ? owner.s() : null;
        } catch (Exception e) { return null; }
    }

    private static void persistNotification(
            DynamoDbClient ddb,
            String table,
            String userId,
            String id,
            String type,
            String title,
            String body,
            String actionType,
            String entityType,
            String entityId,
            String route,
            Instant now
    ) {
        if (ddb == null || table == null || table.isBlank() || userId == null || userId.isBlank()) return;
        try {
            Map<String, software.amazon.awssdk.services.dynamodb.model.AttributeValue> item = new HashMap<>();
            item.put("userId", avS(userId.trim()));
            item.put("sk", avS(now.toString() + "#" + id));
            item.put("id", avS(id));
            item.put("type", avS(type));
            item.put("title", avS(title != null ? title : ""));
            item.put("body", avS(body != null ? body : ""));
            item.put("createdAt", avS(now.toString()));
            item.put("status", avS("CREATED"));
            item.put("priority", avS("MEDIUM"));
            if (actionType != null) item.put("actionType", avS(actionType));
            if (entityType != null) item.put("entityType", avS(entityType));
            if (entityId != null) item.put("entityId", avS(entityId));
            if (route != null) item.put("route", avS(route));
            ddb.putItem(b -> b.tableName(table).item(item));
        } catch (Exception ignored) {}
    }

    private static software.amazon.awssdk.services.dynamodb.model.AttributeValue avS(String s) {
        return s == null ? software.amazon.awssdk.services.dynamodb.model.AttributeValue.builder().nul(true).build()
                : software.amazon.awssdk.services.dynamodb.model.AttributeValue.builder().s(s).build();
    }

    private static List<DeviceTokenItem> listTokens(DynamoDbTable<DeviceTokenItem> table, String userId, int limit) {
        try {
            var it = table.query(r -> r.queryConditional(QueryConditional.keyEqualTo(k -> k.partitionValue(userId))).limit(limit > 0 ? limit : 100));
            List<DeviceTokenItem> out = new ArrayList<>();
            it.items().forEach(out::add);
            return out;
        } catch (Exception e) { return List.of(); }
    }

    public static class DeviceTokenItem {
        private String userId;
        private String sk; // platform#tokenHash
        private String platform;
        private String token;
        private Boolean enabled;

        public String getUserId() { return userId; }
        public void setUserId(String userId) { this.userId = userId; }
        public String getSk() { return sk; }
        public void setSk(String sk) { this.sk = sk; }
        public String getPlatform() { return platform; }
        public void setPlatform(String platform) { this.platform = platform; }
        public String getToken() { return token; }
        public void setToken(String token) { this.token = token; }
        public Boolean getEnabled() { return enabled; }
        public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    }

    private static ChannelType mapChannel(String platform) {
        if (platform == null) return null;
        String p = platform.trim().toLowerCase();
        return switch (p) {
            case "android", "gcm", "fcm" -> ChannelType.GCM;
            case "ios", "apns" -> ChannelType.APNS;
            default -> null;
        };
    }

    private static String summarize(SendMessagesResponse resp) {
        try {
            Map<String, MessageResult> res = resp.messageResponse().result();
            return res.entrySet().stream().map(e -> e.getKey()+":"+e.getValue().statusCode()).collect(Collectors.joining(","));
        } catch (Exception e) { return ""; }
    }

    private static Map<String, Object> getMap(Object o) {
        if (o instanceof Map<?, ?> m) {
            @SuppressWarnings("unchecked") Map<String, Object> c = (Map<String, Object>) m; return c;
        }
        return Collections.emptyMap();
    }

    private static int asInt(Object o) { try { return Integer.parseInt(String.valueOf(o)); } catch (Exception e) { return 0; } }
    private static String str(Object o) { return o == null ? null : o.toString(); }
}
