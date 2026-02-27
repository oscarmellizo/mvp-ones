package com.ones.api.configuration;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.stereotype.Component;

import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.DescribeTableRequest;
import software.amazon.awssdk.services.dynamodb.model.ResourceNotFoundException;

@Component
public class DynamoDbIndexesHealthIndicator implements HealthIndicator {

    private final DynamoDbClient dynamoDbClient;
    private final Clock clock;

    private final boolean enabled;
    private final boolean failOnMissingIndex;
    private final Duration cacheTtl;

    private final String usersTableName;
    private final String invitationsTableName;

    private volatile Instant lastCheckedAt;
    private volatile Health lastHealth;

    public DynamoDbIndexesHealthIndicator(
            DynamoDbClient dynamoDbClient,
            Clock clock,
            @Value("${ones.dynamodb.healthcheck.enabled:true}") boolean enabled,
            @Value("${ones.dynamodb.healthcheck.fail-on-missing-index:false}") boolean failOnMissingIndex,
            @Value("${ones.dynamodb.healthcheck.cache-ttl-seconds:60}") long cacheTtlSeconds,
            @Value("${ones.dynamodb.users-table-name:ones-users}") String usersTableName,
            @Value("${ones.dynamodb.invitations-table-name:ones-dev-event-invitations}") String invitationsTableName
    ) {
        this.dynamoDbClient = dynamoDbClient;
        this.clock = clock;
        this.enabled = enabled;
        this.failOnMissingIndex = failOnMissingIndex;
        this.cacheTtl = Duration.ofSeconds(cacheTtlSeconds);
        this.usersTableName = usersTableName;
        this.invitationsTableName = invitationsTableName;
    }

    @Override
    public Health health() {
        if (!enabled) {
            return Health.up().withDetail("enabled", false).build();
        }

        Instant now = Instant.now(clock);
        Health cached = this.lastHealth;
        Instant checkedAt = this.lastCheckedAt;
        if (cached != null && checkedAt != null && checkedAt.plus(cacheTtl).isAfter(now)) {
            return cached;
        }

        Health computed = computeHealth();
        this.lastHealth = computed;
        this.lastCheckedAt = now;
        return computed;
    }

    private Health computeHealth() {
        List<String> missing = new ArrayList<>();

        if (usersTableName != null && !usersTableName.isBlank()) {
            if (!hasGsi(usersTableName.trim(), "byEmail")) {
                missing.add("users.byEmail");
            }
        }

        if (invitationsTableName != null && !invitationsTableName.isBlank()) {
            if (!hasGsi(invitationsTableName.trim(), "byEventId")) {
                missing.add("invitations.byEventId");
            }
        }

        Health.Builder builder;
        if (missing.isEmpty()) {
            builder = Health.up();
        } else {
            builder = failOnMissingIndex ? Health.down() : Health.up();
        }

        return builder
                .withDetail("missingIndexes", missing)
                .withDetail("failOnMissingIndex", failOnMissingIndex)
                .build();
    }

    private boolean hasGsi(String tableName, String indexName) {
        try {
            var resp = dynamoDbClient.describeTable(DescribeTableRequest.builder().tableName(tableName).build());
            var table = resp.table();
            if (table == null || table.globalSecondaryIndexes() == null) {
                return false;
            }
            Set<String> names = new HashSet<>();
            for (var gsi : table.globalSecondaryIndexes()) {
                if (gsi != null && gsi.indexName() != null) {
                    names.add(gsi.indexName());
                }
            }
            return names.contains(indexName);
        } catch (ResourceNotFoundException e) {
            return false;
        }
    }
}
