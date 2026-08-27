package com.ones.api.adapters.outbound.dynamodb;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.push.ports.DeviceTokensRepository;
import com.ones.api.domain.push.DeviceToken;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;

@Repository
public class DynamoDbDeviceTokensRepository implements DeviceTokensRepository {

    private final DynamoDbTable<DynamoDeviceTokenItem> table;

    public DynamoDbDeviceTokensRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.device-tokens-table-name:ones-dev-device-tokens}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoDeviceTokenItem.class));
    }

    @Override
    public DeviceToken upsert(DeviceToken t) {
        DynamoDeviceTokenItem it = toItem(t);
        table.putItem(it);
        return t;
    }

    @Override
    public void deleteByUserAndTokenHash(String userId, String platform, String tokenHash) {
        if (userId == null || userId.isBlank() || platform == null || platform.isBlank() || tokenHash == null || tokenHash.isBlank()) {
            return;
        }
        String sk = platform.trim().toLowerCase() + "#" + tokenHash.trim().toLowerCase();
        table.deleteItem(Key.builder().partitionValue(userId.trim()).sortValue(sk).build());
    }

    @Override
    public java.util.List<DeviceToken> listByUserId(String userId, int limit) {
        if (userId == null || userId.isBlank()) return java.util.List.of();
        var qb = table.query(r -> r.queryConditional(QueryConditional.keyEqualTo(k -> k.partitionValue(userId.trim()))).limit(limit > 0 ? limit : 100));
        java.util.List<DeviceToken> out = new java.util.ArrayList<>();
        qb.items().forEach(it -> out.add(fromItem(it)));
        return out;
    }

    public static String sha256(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Unable to compute sha256", e);
        }
    }

    private static DynamoDeviceTokenItem toItem(DeviceToken t) {
        DynamoDeviceTokenItem it = new DynamoDeviceTokenItem();
        it.setUserId(t.getUserId());
        it.setSk(t.getPlatform().toLowerCase() + "#" + t.getTokenHash());
        it.setPlatform(t.getPlatform().toLowerCase());
        it.setToken(t.getToken());
        it.setTokenHash(t.getTokenHash());
        it.setCreatedAt(t.getCreatedAt().toString());
        it.setLastUsedAt(t.getLastUsedAt() != null ? t.getLastUsedAt().toString() : null);
        it.setEnabled(t.isEnabled());
        it.setDeviceInfo(t.getDeviceInfo());
        return it;
    }

    private static DeviceToken fromItem(DynamoDeviceTokenItem it) {
        return new DeviceToken(
                it.getUserId(),
                it.getPlatform(),
                it.getToken(),
                it.getTokenHash(),
                java.time.Instant.parse(it.getCreatedAt()),
                it.getLastUsedAt() != null ? java.time.Instant.parse(it.getLastUsedAt()) : java.time.Instant.parse(it.getCreatedAt()),
                it.getEnabled() != null ? it.getEnabled() : Boolean.TRUE,
                it.getDeviceInfo()
        );
    }
}
