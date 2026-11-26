package com.ones.api.application.collections;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.HexFormat;
import java.util.Map;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;

@Component
public class CollectionJoinRateLimiter {
    private static final int MAX_ATTEMPTS_PER_MINUTE = 20;

    private final DynamoDbClient dynamoDbClient;
    private final String tableName;
    private final Clock clock;
    private final Counter attempts;
    private final Counter rejected;
    private final Timer updateLatency;

    public CollectionJoinRateLimiter(
            DynamoDbClient dynamoDbClient,
            Clock clock,
            MeterRegistry meterRegistry,
            @Value("${ones.dynamodb.collection-join-attempts-table-name:ones-collection-join-attempts}")
            String tableName
    ) {
        this.dynamoDbClient = dynamoDbClient;
        this.clock = clock;
        this.tableName = tableName;
        this.attempts = Counter.builder("ones.collections.qr_join.attempts").register(meterRegistry);
        this.rejected = Counter.builder("ones.collections.qr_join.rate_limited").register(meterRegistry);
        this.updateLatency = Timer.builder("ones.collections.qr_join.rate_limit.latency")
                .register(meterRegistry);
    }

    public boolean tryAcquire(String userId) {
        if (userId == null || userId.isBlank()) return false;
        attempts.increment();
        Instant now = Instant.now(clock);
        long minute = now.getEpochSecond() / 60;
        String key = digest(userId.trim()) + "#" + minute;
        long startedAt = System.nanoTime();
        try {
            dynamoDbClient.updateItem(request -> request
                    .tableName(tableName)
                    .key(Map.of("attemptKey", AttributeValue.fromS(key)))
                    .updateExpression("SET expiresAt = :expires ADD attempts :one")
                    .conditionExpression("attribute_not_exists(attempts) OR attempts < :max")
                    .expressionAttributeValues(Map.of(
                            ":expires", AttributeValue.fromN(Long.toString(now.plus(2, ChronoUnit.MINUTES).getEpochSecond())),
                            ":one", AttributeValue.fromN("1"),
                            ":max", AttributeValue.fromN(Integer.toString(MAX_ATTEMPTS_PER_MINUTE))
                    )));
            return true;
        } catch (ConditionalCheckFailedException e) {
            rejected.increment();
            return false;
        } finally {
            updateLatency.record(System.nanoTime() - startedAt, java.util.concurrent.TimeUnit.NANOSECONDS);
        }
    }

    private static String digest(String value) {
        try {
            return HexFormat.of().formatHex(
                    MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("Unable to hash collection QR rate limit key", e);
        }
    }
}
