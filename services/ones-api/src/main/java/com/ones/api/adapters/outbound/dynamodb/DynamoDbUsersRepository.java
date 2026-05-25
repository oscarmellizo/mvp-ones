package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Expression;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ResourceNotFoundException;

@Repository
public class DynamoDbUsersRepository implements UsersRepository {

    private static final Logger log = LoggerFactory.getLogger(DynamoDbUsersRepository.class);

    private final DynamoDbTable<DynamoUserItem> table;
    private final Counter scanFallbackCounter;
    private final boolean failOnScanFallback;

    public DynamoDbUsersRepository(
            DynamoDbEnhancedClient enhancedClient,
            MeterRegistry meterRegistry,
            @Value("${ones.dynamodb.users-table-name:ones-users}") String tableName,
            @Value("${ones.dynamodb.fail-on-scan-fallback:false}") boolean failOnScanFallback
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoUserItem.class));
        this.scanFallbackCounter = Counter.builder("ones.dynamodb.scan_fallback")
                .tag("repository", "users")
                .tag("operation", "findByEmail")
                .register(meterRegistry);
        this.failOnScanFallback = failOnScanFallback;
    }

    @Override
    public Optional<User> findById(String userId) {
        DynamoUserItem item = table.getItem(Key.builder().partitionValue(userId).build());
        return Optional.ofNullable(item).map(DynamoDbUsersRepository::toDomain);
    }

    @Override
    public Optional<User> findByEmail(String email) {
        if (email == null || email.isBlank()) {
            return Optional.empty();
        }

        String normalizedEmail = email.trim().toLowerCase();
        Optional<User> byIndex = findByEmailUsingIndex(normalizedEmail);
        if (byIndex.isPresent()) {
            return byIndex;
        }

        if (failOnScanFallback) {
            throw new IllegalStateException("DynamoDB Scan fallback disabled for users.findByEmail; missing GSI byEmail");
        }

        log.warn("Falling back to DynamoDB Scan for findByEmail; consider creating GSI byEmail");
        scanFallbackCounter.increment();

        Expression filter = Expression.builder()
                .expression("#email = :email")
                .expressionNames(Map.of("#email", "email"))
                .expressionValues(Map.of(":email", AttributeValue.builder().s(normalizedEmail).build()))
                .build();

        ScanEnhancedRequest request = ScanEnhancedRequest.builder()
                .filterExpression(filter)
                .limit(1)
                .build();

        return table.scan(request)
                .items()
                .stream()
                .findFirst()
                .map(DynamoDbUsersRepository::toDomain);
    }

    private Optional<User> findByEmailUsingIndex(String normalizedEmail) {
        try {
            DynamoDbIndex<DynamoUserItem> index = table.index("byEmail");
            QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                    .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(normalizedEmail).build()))
                    .limit(1)
                    .build();

            for (var page : index.query(request)) {
                for (var item : page.items()) {
                    return Optional.of(toDomain(item));
                }
            }
            return Optional.empty();
        } catch (ResourceNotFoundException e) {
            return Optional.empty();
        } catch (Exception e) {
            String msg = e.getMessage();
            if (msg != null && msg.toLowerCase().contains("byemail")) {
                return Optional.empty();
            }
            throw e;
        }
    }

    @Override
    public User upsert(User user) {
        table.putItem(toItem(user));
        return user;
    }

    @Override
    public void deleteById(String userId) {
        if (userId == null || userId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(userId.trim()).build());
    }

    private static DynamoUserItem toItem(User u) {
        DynamoUserItem item = new DynamoUserItem();
        item.setUserId(u.getUserId());
        item.setEmail(u.getEmail());
        item.setName(u.getName());
        item.setGivenName(u.getGivenName());
        item.setFamilyName(u.getFamilyName());
        item.setPicture(u.getPicture());
        item.setPreferredName(u.getPreferredName());
        item.setProvider(u.getProvider());
        item.setCreatedAt(u.getCreatedAt().toString());
        item.setUpdatedAt(u.getUpdatedAt().toString());
        return item;
    }

    private static User toDomain(DynamoUserItem item) {
        return new User(
                item.getUserId(),
                item.getEmail(),
                item.getName(),
                item.getGivenName(),
                item.getFamilyName(),
                item.getPicture(),
                item.getPreferredName(),
                item.getProvider(),
                null, // languagePreference - will be added to DynamoUserItem later
                Instant.parse(item.getCreatedAt()),
                Instant.parse(item.getUpdatedAt())
        );
    }
}
