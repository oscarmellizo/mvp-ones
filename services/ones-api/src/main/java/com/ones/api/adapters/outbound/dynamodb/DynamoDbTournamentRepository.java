package com.ones.api.adapters.outbound.dynamodb;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Repository;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.domain.tournament.TournamentModels.TournamentState;
import com.ones.api.domain.tournament.TournamentModels.UserPrediction;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Expression;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.PutItemEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.ConditionCheck;
import software.amazon.awssdk.services.dynamodb.model.DeleteItemRequest;
import software.amazon.awssdk.services.dynamodb.model.Put;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.QueryRequest;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItem;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsRequest;

@Repository
public class DynamoDbTournamentRepository {

    private static final int SHARD_COUNT = 16;
    private final DynamoDbTable<DynamoTournamentItem> table;
    private final DynamoDbClient dynamoDbClient;
    private final ObjectMapper objectMapper;
    private final String tableName;

    public DynamoDbTournamentRepository(
            DynamoDbEnhancedClient enhancedClient,
            DynamoDbClient dynamoDbClient,
            ObjectMapper objectMapper,
            @Value("${ones.dynamodb.tournaments-table-name:ones-dev-tournaments}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoTournamentItem.class));
        this.dynamoDbClient = dynamoDbClient;
        this.objectMapper = objectMapper;
        this.tableName = tableName;
    }

    public Optional<TournamentState> findState(String eventId) {
        DynamoTournamentItem item = table.getItem(key("EVENT#" + eventId, "STATE"));
        return item == null ? Optional.empty() : Optional.of(read(item.getPayload(), TournamentState.class));
    }

    public Optional<TournamentState> findStateForUser(String eventId, String userId) {
        int shard = shardFor(userId);
        DynamoTournamentItem item = table.getItem(r -> r
                .key(key("EVENT#" + eventId + "#STATE#" + String.format("%02d", shard), "STATE"))
                .consistentRead(true));
        if (item == null) return findState(eventId);
        return Optional.of(read(item.getPayload(), TournamentState.class));
    }

    public void createState(TournamentState state) {
        DynamoTournamentItem item = stateItem(state);
        try {
            table.putItem(PutItemEnhancedRequest.builder(DynamoTournamentItem.class)
                    .item(item)
                    .conditionExpression(Expression.builder()
                            .expression("attribute_not_exists(#pk)")
                            .expressionNames(java.util.Map.of("#pk", "pk"))
                            .build())
                    .build());
        } catch (ConditionalCheckFailedException ignored) {
            // Module initialization is idempotent for retries after event creation.
        }
        TournamentState persisted = findState(state.eventId()).orElse(state);
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            table.putItem(stateReplicaItem(persisted, shard));
        }
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            DynamoTournamentItem gate = new DynamoTournamentItem();
            gate.setPk(gatePk(state.eventId(), shard));
            gate.setSk("GATE");
            gate.setGateStatus("NOT_STARTED");
            try {
                table.putItem(PutItemEnhancedRequest.builder(DynamoTournamentItem.class)
                        .item(gate)
                        .conditionExpression(Expression.builder()
                                .expression("attribute_not_exists(#pk)")
                                .expressionNames(java.util.Map.of("#pk", "pk"))
                                .build())
                        .build());
            } catch (ConditionalCheckFailedException ignored) {
                // A retry may find gates already created by an earlier activation attempt.
            }
        }
    }

    public boolean saveState(TournamentState state, long expectedVersion) {
        List<TransactWriteItem> writes = new ArrayList<>(SHARD_COUNT + 1);
        writes.add(TransactWriteItem.builder().put(Put.builder()
                .tableName(tableName)
                .item(toAttributeMap(stateItem(state)))
                .conditionExpression("#version = :expected")
                .expressionAttributeNames(java.util.Map.of("#version", "version"))
                .expressionAttributeValues(java.util.Map.of(
                        ":expected", AttributeValue.fromN(Long.toString(expectedVersion))))
                .build()).build());
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            writes.add(TransactWriteItem.builder().put(Put.builder()
                    .tableName(tableName)
                    .item(toAttributeMap(stateReplicaItem(state, shard)))
                    .build()).build());
        }
        try {
            dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                    .transactItems(writes)
                    .build());
            return true;
        } catch (software.amazon.awssdk.services.dynamodb.model.TransactionCanceledException e) {
            return false;
        }
    }

    public boolean saveStateAndGates(TournamentState state, long expectedVersion, String gateStatus) {
        List<TransactWriteItem> writes = new ArrayList<>(SHARD_COUNT * 2 + 1);
        writes.add(TransactWriteItem.builder().put(Put.builder()
                .tableName(tableName)
                .item(toAttributeMap(stateItem(state)))
                .conditionExpression("#version = :expected")
                .expressionAttributeNames(java.util.Map.of("#version", "version"))
                .expressionAttributeValues(java.util.Map.of(
                        ":expected", AttributeValue.fromN(Long.toString(expectedVersion))))
                .build()).build());
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            writes.add(TransactWriteItem.builder().put(Put.builder()
                    .tableName(tableName)
                    .item(toAttributeMap(stateReplicaItem(state, shard)))
                    .build()).build());
            writes.add(TransactWriteItem.builder().put(Put.builder()
                    .tableName(tableName)
                    .item(java.util.Map.of(
                            "pk", AttributeValue.fromS(gatePk(state.eventId(), shard)),
                            "sk", AttributeValue.fromS("GATE"),
                            "gateStatus", AttributeValue.fromS(gateStatus),
                            "version", AttributeValue.fromN(Long.toString(state.version()))))
                    .build()).build());
        }
        try {
            dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                    .transactItems(writes)
                    .build());
            return true;
        } catch (software.amazon.awssdk.services.dynamodb.model.TransactionCanceledException e) {
            return false;
        }
    }

    public boolean claimScoreRecalculation(
            String eventId,
            long stateVersion,
            long requestedAtMillis,
            long cooldownCutoffMillis
    ) {
        String pk = "EVENT#" + eventId + "#SCORE_RECALC";
        try {
            dynamoDbClient.putItem(PutItemRequest.builder()
                    .tableName(tableName)
                    .item(Map.of(
                            "pk", AttributeValue.fromS(pk),
                            "sk", AttributeValue.fromS("REQUEST"),
                            "stateVersion", AttributeValue.fromN(Long.toString(stateVersion)),
                            "requestedAt", AttributeValue.fromN(Long.toString(requestedAtMillis))))
                    .conditionExpression(
                            "attribute_not_exists(#pk) OR #requestedAt < :cutoff OR #stateVersion < :version")
                    .expressionAttributeNames(Map.of(
                            "#pk", "pk",
                            "#requestedAt", "requestedAt",
                            "#stateVersion", "stateVersion"))
                    .expressionAttributeValues(Map.of(
                            ":cutoff", AttributeValue.fromN(Long.toString(cooldownCutoffMillis)),
                            ":version", AttributeValue.fromN(Long.toString(stateVersion))))
                    .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return false;
        }
    }

    public void releaseScoreRecalculation(String eventId, long stateVersion, long requestedAtMillis) {
        dynamoDbClient.deleteItem(DeleteItemRequest.builder()
                .tableName(tableName)
                .key(Map.of(
                        "pk", AttributeValue.fromS("EVENT#" + eventId + "#SCORE_RECALC"),
                        "sk", AttributeValue.fromS("REQUEST")))
                .conditionExpression("#stateVersion = :version AND #requestedAt = :requestedAt")
                .expressionAttributeNames(Map.of(
                        "#stateVersion", "stateVersion",
                        "#requestedAt", "requestedAt"))
                .expressionAttributeValues(Map.of(
                        ":version", AttributeValue.fromN(Long.toString(stateVersion)),
                        ":requestedAt", AttributeValue.fromN(Long.toString(requestedAtMillis))))
                .build());
    }

    public Optional<UserPrediction> findPrediction(String eventId, String userId) {
        DynamoTournamentItem item = table.getItem(key("EVENT#" + eventId + "#USER#" + userId, "PREDICTION"));
        return item == null ? Optional.empty() : Optional.of(read(item.getPayload(), UserPrediction.class));
    }

    public boolean savePredictionIfOpen(
            UserPrediction prediction,
            long expectedPredictionVersion
    ) {
        DynamoTournamentItem forecast = predictionItem(prediction);
        int shard = shardFor(prediction.userId());
        var gateKey = java.util.Map.of(
                "pk", AttributeValue.fromS(gatePk(prediction.eventId(), shard)),
                "sk", AttributeValue.fromS("GATE"));

        String forecastCondition = expectedPredictionVersion == 0
                ? "attribute_not_exists(#pk)"
                : "#version = :expected";
        var forecastNames = new java.util.HashMap<String, String>();
        var forecastValueMap = new java.util.HashMap<String, AttributeValue>();
        if (expectedPredictionVersion == 0) {
            forecastNames.put("#pk", "pk");
        } else {
            forecastNames.put("#version", "version");
            forecastValueMap.put(":expected", AttributeValue.fromN(Long.toString(expectedPredictionVersion)));
        }
        Put.Builder forecastPut = Put.builder()
                .tableName(tableName)
                .item(toAttributeMap(forecast))
                .conditionExpression(forecastCondition)
                .expressionAttributeNames(forecastNames);
        if (!forecastValueMap.isEmpty()) {
            forecastPut.expressionAttributeValues(forecastValueMap);
        }

        try {
            dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                    .transactItems(
                            TransactWriteItem.builder().conditionCheck(ConditionCheck.builder()
                                    .tableName(tableName)
                                    .key(gateKey)
                                    .conditionExpression("#gateStatus = :open")
                                    .expressionAttributeNames(java.util.Map.of("#gateStatus", "gateStatus"))
                                    .expressionAttributeValues(java.util.Map.of(":open", AttributeValue.fromS("OPEN")))
                                    .build()).build(),
                            TransactWriteItem.builder().put(forecastPut.build()).build())
                    .build());
            return true;
        } catch (software.amazon.awssdk.services.dynamodb.model.TransactionCanceledException e) {
            return false;
        }
    }

    public List<UserPrediction> listPredictions(String eventId, int requestedLimit) {
        List<UserPrediction> result = new ArrayList<>();
        int limitPerShard = Math.max(1, (Math.min(500, Math.max(1, requestedLimit)) + SHARD_COUNT - 1) / SHARD_COUNT);
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            String shardKey = eventShardKey(eventId, shard);
            QueryRequest request = QueryRequest.builder()
                    .tableName(tableName)
                    .indexName("byEventShard")
                    .keyConditionExpression("#eventShardPk = :value")
                    .expressionAttributeNames(java.util.Map.of("#eventShardPk", "eventShardPk"))
                    .expressionAttributeValues(java.util.Map.of(":value", AttributeValue.fromS(shardKey)))
                    .limit(limitPerShard)
                    .build();
            dynamoDbClient.query(request).items().forEach(item -> {
                DynamoTournamentItem mapped = fromAttributeMap(item);
                if (mapped.getPayload() != null && "PREDICTION".equals(mapped.getSk())) {
                    result.add(read(mapped.getPayload(), UserPrediction.class));
                }
            });
        }
        return result.stream().limit(Math.min(500, Math.max(1, requestedLimit))).toList();
    }

    @Cacheable(
            cacheNames = com.ones.api.configuration.CacheConfig.TOURNAMENT_LEADERBOARD_CACHE,
            key = "#eventId + ':' + #limit",
            sync = true)
    public List<com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry> listLeaderboard(
            String eventId,
            int limit
    ) {
        List<com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry> result = new ArrayList<>();
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            QueryRequest request = QueryRequest.builder()
                    .tableName(tableName)
                    .keyConditionExpression("#pk = :pk AND begins_with(#sk, :prefix)")
                    .expressionAttributeNames(java.util.Map.of("#pk", "pk", "#sk", "sk"))
                    .expressionAttributeValues(java.util.Map.of(
                            ":pk", AttributeValue.fromS("EVENT#" + eventId + "#RANK#" + String.format("%02d", shard)),
                            ":prefix", AttributeValue.fromS("SCORE#")))
                    .limit(Math.max(1, limit))
                    .build();
            dynamoDbClient.queryPaginator(request).items().forEach(item -> {
                AttributeValue payload = item.get("payload");
                if (payload != null) {
                    result.add(read(payload.s(),
                            com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry.class));
                }
            });
        }
        List<com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry> sorted = result.stream()
                .sorted(java.util.Comparator.comparingInt(
                        com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry::points).reversed()
                        .thenComparing(java.util.Comparator.comparingInt(
                                com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry::exactCount).reversed())
                        .thenComparing(java.util.Comparator.comparingInt(
                                com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry::fivePointCount).reversed())
                        .thenComparing(com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry::userId))
                .limit(Math.max(1, limit))
                .toList();
        List<com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry> ranked = new ArrayList<>(sorted.size());
        int place = 0;
        com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry previous = null;
        for (int i = 0; i < sorted.size(); i++) {
            var current = sorted.get(i);
            if (previous == null
                    || current.points() != previous.points()
                    || current.exactCount() != previous.exactCount()
                    || current.fivePointCount() != previous.fivePointCount()) {
                place = i + 1;
            }
            ranked.add(new com.ones.api.domain.tournament.TournamentModels.LeaderboardEntry(
                    current.userId(), current.displayName(), current.points(),
                    current.exactCount(), current.fivePointCount(), place));
            previous = current;
        }
        return List.copyOf(ranked);
    }

    public void deleteByEventId(String eventId) {
        table.deleteItem(key("EVENT#" + eventId, "STATE"));
        table.deleteItem(key("EVENT#" + eventId + "#SCORE_RECALC", "REQUEST"));
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            table.deleteItem(key(
                    "EVENT#" + eventId + "#STATE#" + String.format("%02d", shard),
                    "STATE"));
        }
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            QueryRequest predictionsRequest = QueryRequest.builder()
                    .tableName(tableName)
                    .indexName("byEventShard")
                    .keyConditionExpression("#eventShardPk = :value")
                    .expressionAttributeNames(java.util.Map.of("#eventShardPk", "eventShardPk"))
                    .expressionAttributeValues(java.util.Map.of(
                            ":value", AttributeValue.fromS(eventShardKey(eventId, shard))))
                    .build();
            dynamoDbClient.queryPaginator(predictionsRequest).items().forEach(item ->
                    table.deleteItem(key(item.get("pk").s(), item.get("sk").s())));
        }
        for (int shard = 0; shard < SHARD_COUNT; shard++) {
            String rankPk = "EVENT#" + eventId + "#RANK#" + String.format("%02d", shard);
            var request = QueryRequest.builder()
                    .tableName(tableName)
                    .keyConditionExpression("#pk = :pk")
                    .expressionAttributeNames(java.util.Map.of("#pk", "pk"))
                    .expressionAttributeValues(java.util.Map.of(":pk", AttributeValue.fromS(rankPk)))
                    .build();
            dynamoDbClient.queryPaginator(request).items().forEach(item ->
                    table.deleteItem(key(item.get("pk").s(), item.get("sk").s())));
            table.deleteItem(key(gatePk(eventId, shard), "GATE"));
            String auditPk = "EVENT#" + eventId + "#AUDIT#" + String.format("%02d", shard);
            QueryRequest auditRequest = QueryRequest.builder()
                    .tableName(tableName)
                    .keyConditionExpression("#pk = :pk")
                    .expressionAttributeNames(Map.of("#pk", "pk"))
                    .expressionAttributeValues(Map.of(":pk", AttributeValue.fromS(auditPk)))
                    .build();
            dynamoDbClient.queryPaginator(auditRequest).items().forEach(item ->
                    table.deleteItem(key(item.get("pk").s(), item.get("sk").s())));
        }
    }

    public void appendAudit(
            String eventId,
            long version,
            String action,
            String actorId,
            String reason,
            Object before,
            Object after
    ) {
        int shard = (int) Math.floorMod(version, SHARD_COUNT);
        DynamoTournamentItem item = new DynamoTournamentItem();
        item.setPk("EVENT#" + eventId + "#AUDIT#" + String.format("%02d", shard));
        item.setSk("ACTION#" + version + "#" + action);
        item.setPayload(write(Map.of(
                "eventId", eventId,
                "version", version,
                "action", action,
                "actorId", actorId,
                "reason", reason == null ? "" : reason,
                "before", before == null ? Map.of() : before,
                "after", after == null ? Map.of() : after)));
        try {
            table.putItem(PutItemEnhancedRequest.builder(DynamoTournamentItem.class)
                    .item(item)
                    .conditionExpression(Expression.builder()
                            .expression("attribute_not_exists(#pk)")
                            .expressionNames(Map.of("#pk", "pk"))
                            .build())
                    .build());
        } catch (ConditionalCheckFailedException ignored) {
            // Retries of the same state transition keep one audit record.
        }
    }

    private DynamoTournamentItem stateItem(TournamentState state) {
        DynamoTournamentItem item = new DynamoTournamentItem();
        item.setPk("EVENT#" + state.eventId());
        item.setSk("STATE");
        item.setPayload(write(state));
        item.setVersion(state.version());
        item.setGroupStatus(state.groupPredictionPeriod().status().name());
        item.setKnockoutStatus(state.knockoutPredictionPeriod().status().name());
        item.setEventShardPk(eventShardKey(state.eventId(), 0));
        item.setEventShardSk("STATE");
        return item;
    }

    private DynamoTournamentItem stateReplicaItem(TournamentState state, int shard) {
        DynamoTournamentItem item = new DynamoTournamentItem();
        item.setPk("EVENT#" + state.eventId() + "#STATE#" + String.format("%02d", shard));
        item.setSk("STATE");
        item.setPayload(write(state));
        item.setVersion(state.version());
        item.setGroupStatus(state.groupPredictionPeriod().status().name());
        item.setKnockoutStatus(state.knockoutPredictionPeriod().status().name());
        return item;
    }

    private DynamoTournamentItem predictionItem(UserPrediction prediction) {
        DynamoTournamentItem item = new DynamoTournamentItem();
        item.setPk("EVENT#" + prediction.eventId() + "#USER#" + prediction.userId());
        item.setSk("PREDICTION");
        item.setPayload(write(prediction));
        item.setVersion(prediction.version());
        item.setEventShardPk(eventShardKey(prediction.eventId(), shardFor(prediction.userId())));
        item.setEventShardSk("USER#" + prediction.userId());
        return item;
    }

    private java.util.Map<String, AttributeValue> toAttributeMap(DynamoTournamentItem item) {
        var result = new java.util.HashMap<String, AttributeValue>();
        result.put("pk", AttributeValue.fromS(item.getPk()));
        result.put("sk", AttributeValue.fromS(item.getSk()));
        result.put("payload", AttributeValue.fromS(item.getPayload()));
        result.put("version", AttributeValue.fromN(Long.toString(item.getVersion())));
        if (item.getEventShardPk() != null) result.put("eventShardPk", AttributeValue.fromS(item.getEventShardPk()));
        if (item.getEventShardSk() != null) result.put("eventShardSk", AttributeValue.fromS(item.getEventShardSk()));
        if (item.getGroupStatus() != null) result.put("groupStatus", AttributeValue.fromS(item.getGroupStatus()));
        if (item.getKnockoutStatus() != null) result.put("knockoutStatus", AttributeValue.fromS(item.getKnockoutStatus()));
        if (item.getGateStatus() != null) result.put("gateStatus", AttributeValue.fromS(item.getGateStatus()));
        return result;
    }

    private DynamoTournamentItem fromAttributeMap(java.util.Map<String, AttributeValue> item) {
        DynamoTournamentItem mapped = new DynamoTournamentItem();
        mapped.setPk(item.get("pk").s());
        mapped.setSk(item.get("sk").s());
        mapped.setPayload(item.get("payload").s());
        return mapped;
    }

    private static Key key(String pk, String sk) {
        return Key.builder().partitionValue(pk).sortValue(sk).build();
    }

    private static int shardFor(String userId) {
        return Math.floorMod(userId.hashCode(), SHARD_COUNT);
    }

    private static String eventShardKey(String eventId, int shard) {
        return "EVENT#" + eventId + "#PRED#" + String.format("%02d", shard);
    }

    private static String gatePk(String eventId, int shard) {
        return "EVENT#" + eventId + "#GATE#" + String.format("%02d", shard);
    }

    private String write(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Could not serialize tournament record", e);
        }
    }

    private <T> T read(String json, Class<T> type) {
        try {
            return objectMapper.readValue(json, type);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Could not deserialize tournament record", e);
        }
    }
}
