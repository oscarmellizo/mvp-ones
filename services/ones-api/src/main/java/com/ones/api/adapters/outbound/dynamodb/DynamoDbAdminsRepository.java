package com.ones.api.adapters.outbound.dynamodb;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.admin.ports.AdminsRepository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

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
}
