package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.admin.ports.AdminsRepository;
import com.ones.api.domain.admin.AdminUser;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

@Repository
public class DynamoDbAdminsRepository implements AdminsRepository {

    private final DynamoDbTable<DynamoAdminItem> table;

    public DynamoDbAdminsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.admins-table-name:ones-admins}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoAdminItem.class));
    }

    @Override
    public boolean isActiveAdmin(String email) {
        if (email == null || email.isBlank()) {
            return false;
        }

        String normalized = email.trim().toLowerCase();
        DynamoAdminItem item = table.getItem(Key.builder().partitionValue(normalized).build());
        if (item == null || item.getStatus() == null) {
            return false;
        }

        return "active".equalsIgnoreCase(item.getStatus().trim());
    }

    @Override
    public Optional<AdminUser> findByEmail(String email) {
        if (email == null || email.isBlank()) {
            return Optional.empty();
        }

        String normalized = email.trim().toLowerCase();
        DynamoAdminItem item = table.getItem(Key.builder().partitionValue(normalized).build());
        return Optional.ofNullable(item).map(DynamoDbAdminsRepository::toDomain);
    }

    @Override
    public ListResult list(int limit, String nextToken) {
        int safeLimit = limit <= 0 ? 50 : Math.min(limit, 200);

        ScanEnhancedRequest.Builder req = ScanEnhancedRequest.builder().limit(safeLimit);
        if (nextToken != null && !nextToken.isBlank()) {
            String normalizedToken = nextToken.trim().toLowerCase();
            req.exclusiveStartKey(Map.of(
                    "email", AttributeValue.builder().s(normalizedToken).build()
            ));
        }

        List<AdminUser> out = new ArrayList<>();
        String outNextToken = null;

        for (var page : table.scan(req.build())) {
            for (var item : page.items()) {
                out.add(toDomain(item));
            }

            Map<String, AttributeValue> lek = page.lastEvaluatedKey();
            if (lek != null && !lek.isEmpty()) {
                AttributeValue v = lek.get("email");
                outNextToken = v != null ? v.s() : null;
            } else {
                outNextToken = null;
            }
            break;
        }

        return new ListResult(out, outNextToken);
    }

    @Override
    public AdminUser upsert(AdminUser adminUser) {
        if (adminUser == null || adminUser.getEmail() == null || adminUser.getEmail().isBlank()) {
            throw new IllegalArgumentException("adminUser.email is required");
        }

        String normalized = adminUser.getEmail().trim().toLowerCase();
        AdminUser.Status status = adminUser.getStatus() != null ? adminUser.getStatus() : AdminUser.Status.inactive;
        Instant createdAt = adminUser.getCreatedAt() != null ? adminUser.getCreatedAt() : Instant.EPOCH;
        Instant updatedAt = adminUser.getUpdatedAt() != null ? adminUser.getUpdatedAt() : createdAt;
        String createdBy = adminUser.getCreatedBy();
        String updatedBy = adminUser.getUpdatedBy();

        AdminUser normalizedAdmin = new AdminUser(normalized, status, createdAt, updatedAt, createdBy, updatedBy);
        table.putItem(toItem(normalizedAdmin));
        return normalizedAdmin;
    }

    private static DynamoAdminItem toItem(AdminUser admin) {
        DynamoAdminItem item = new DynamoAdminItem();
        item.setEmail(admin.getEmail() != null ? admin.getEmail().trim().toLowerCase() : null);
        item.setStatus(admin.getStatus() != null ? admin.getStatus().name() : null);
        item.setCreatedAt(admin.getCreatedAt() != null ? admin.getCreatedAt().toString() : null);
        item.setUpdatedAt(admin.getUpdatedAt() != null ? admin.getUpdatedAt().toString() : null);
        item.setCreatedBy(admin.getCreatedBy());
        item.setUpdatedBy(admin.getUpdatedBy());
        return item;
    }

    private static AdminUser toDomain(DynamoAdminItem item) {
        AdminUser.Status status;
        try {
            status = item.getStatus() != null ? AdminUser.Status.valueOf(item.getStatus()) : AdminUser.Status.inactive;
        } catch (Exception e) {
            status = AdminUser.Status.inactive;
        }

        Instant createdAt = item.getCreatedAt() != null ? Instant.parse(item.getCreatedAt()) : Instant.EPOCH;
        Instant updatedAt = item.getUpdatedAt() != null ? Instant.parse(item.getUpdatedAt()) : createdAt;
        return new AdminUser(
                item.getEmail(),
                status,
                createdAt,
                updatedAt,
                item.getCreatedBy(),
                item.getUpdatedBy()
        );
    }
}
