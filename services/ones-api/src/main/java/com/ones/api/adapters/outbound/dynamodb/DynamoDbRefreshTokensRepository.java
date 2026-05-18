package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;

import com.ones.api.application.auth.RefreshTokensRepository;
import com.ones.api.application.auth.RefreshTokenRotationRejectedException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ReturnValuesOnConditionCheckFailure;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItem;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsRequest;
import software.amazon.awssdk.services.dynamodb.model.Update;
import software.amazon.awssdk.services.dynamodb.model.Put;
import software.amazon.awssdk.services.dynamodb.model.TransactionCanceledException;

@Repository
public class DynamoDbRefreshTokensRepository implements RefreshTokensRepository {

    private final DynamoDbTable<DynamoRefreshTokenItem> table;
    private final DynamoDbClient dynamoDbClient;
    private final String tableName;

    public DynamoDbRefreshTokensRepository(
            DynamoDbEnhancedClient enhancedClient,
            DynamoDbClient dynamoDbClient,
            @Value("${ones.dynamodb.refresh-tokens-table-name:ones-refresh-tokens}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoRefreshTokenItem.class));
        this.dynamoDbClient = dynamoDbClient;
        this.tableName = tableName;
    }

    @Override
    public Optional<StoredRefreshToken> findByTokenHash(String tokenHash) {
        DynamoRefreshTokenItem item = table.getItem(Key.builder().partitionValue(tokenHash).build());
        return Optional.ofNullable(item).map(DynamoDbRefreshTokensRepository::toDomain);
    }

    @Override
    public void storeNew(StoredRefreshToken token) {
        table.putItem(toItem(token));
    }

    @Override
    public void rotateSingleUse(String oldTokenHash, StoredRefreshToken newToken, Instant rotatedAt) {
        if (oldTokenHash == null || oldTokenHash.isBlank()) {
            throw new IllegalArgumentException("oldTokenHash is required");
        }

        Map<String, AttributeValue> key = Map.of(
                "tokenHash", AttributeValue.builder().s(oldTokenHash).build()
        );

        Map<String, AttributeValue> exprValues = Map.of(
                ":rotatedAt", AttributeValue.builder().s(rotatedAt.toString()).build()
        );

        Update updateOld = Update.builder()
                .tableName(tableName)
                .key(key)
                .updateExpression("SET rotatedAt = :rotatedAt")
                .conditionExpression("attribute_not_exists(rotatedAt) AND attribute_not_exists(revokedAt)")
                .expressionAttributeValues(exprValues)
                .returnValuesOnConditionCheckFailure(ReturnValuesOnConditionCheckFailure.ALL_OLD)
                .build();

        Put putNew = Put.builder()
                .tableName(tableName)
                .item(toAttributeMap(newToken))
                .conditionExpression("attribute_not_exists(tokenHash)")
                .returnValuesOnConditionCheckFailure(ReturnValuesOnConditionCheckFailure.ALL_OLD)
                .build();

        TransactWriteItemsRequest tx = TransactWriteItemsRequest.builder()
                .transactItems(
                        TransactWriteItem.builder().update(updateOld).build(),
                        TransactWriteItem.builder().put(putNew).build()
                )
                .build();

        try {
            dynamoDbClient.transactWriteItems(tx);
        } catch (TransactionCanceledException e) {
            throw new RefreshTokenRotationRejectedException("Refresh token rotation rejected", e);
        }
    }

    @Override
    public void revoke(String tokenHash, Instant revokedAt) {
        if (tokenHash == null || tokenHash.isBlank()) {
            return;
        }

        Map<String, AttributeValue> key = Map.of(
                "tokenHash", AttributeValue.builder().s(tokenHash).build()
        );

        Map<String, AttributeValue> exprValues = Map.of(
                ":revokedAt", AttributeValue.builder().s(revokedAt.toString()).build()
        );

        Update update = Update.builder()
                .tableName(tableName)
                .key(key)
                .updateExpression("SET revokedAt = :revokedAt")
                .conditionExpression("attribute_not_exists(revokedAt)")
                .expressionAttributeValues(exprValues)
                .build();

        dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                .transactItems(TransactWriteItem.builder().update(update).build())
                .build());
    }

    private static StoredRefreshToken toDomain(DynamoRefreshTokenItem item) {
        return new StoredRefreshToken(
                item.getTokenHash(),
                item.getUserId(),
                item.getDeviceId(),
                item.getCreatedAt() != null ? Instant.parse(item.getCreatedAt()) : null,
                item.getExpiresAt() != null ? Instant.parse(item.getExpiresAt()) : null,
                item.getRevokedAt() != null ? Instant.parse(item.getRevokedAt()) : null,
                item.getRotatedAt() != null ? Instant.parse(item.getRotatedAt()) : null
        );
    }

    private static DynamoRefreshTokenItem toItem(StoredRefreshToken token) {
        DynamoRefreshTokenItem item = new DynamoRefreshTokenItem();
        item.setTokenHash(token.tokenHash());
        item.setUserId(token.userId());
        item.setDeviceId(token.deviceId());
        item.setCreatedAt(token.createdAt() != null ? token.createdAt().toString() : null);
        item.setExpiresAt(token.expiresAt() != null ? token.expiresAt().toString() : null);
        item.setRevokedAt(token.revokedAt() != null ? token.revokedAt().toString() : null);
        item.setRotatedAt(token.rotatedAt() != null ? token.rotatedAt().toString() : null);
        return item;
    }

    private static Map<String, AttributeValue> toAttributeMap(StoredRefreshToken token) {
        AttributeValue tokenHash = AttributeValue.builder().s(token.tokenHash()).build();
        AttributeValue userId = AttributeValue.builder().s(token.userId()).build();
        AttributeValue deviceId = AttributeValue.builder().s(token.deviceId()).build();
        AttributeValue createdAt = AttributeValue.builder().s(token.createdAt().toString()).build();
        AttributeValue expiresAt = AttributeValue.builder().s(token.expiresAt().toString()).build();

        return Map.of(
                "tokenHash", tokenHash,
                "userId", userId,
                "deviceId", deviceId,
                "createdAt", createdAt,
                "expiresAt", expiresAt
        );
    }
}
