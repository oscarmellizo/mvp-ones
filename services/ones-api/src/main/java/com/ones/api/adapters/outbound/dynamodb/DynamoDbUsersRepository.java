package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoDbUsersRepository implements UsersRepository {

    private final DynamoDbTable<DynamoUserItem> table;

    public DynamoDbUsersRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.users-table-name:ones-users}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoUserItem.class));
    }

    @Override
    public Optional<User> findById(String userId) {
        DynamoUserItem item = table.getItem(Key.builder().partitionValue(userId).build());
        return Optional.ofNullable(item).map(DynamoDbUsersRepository::toDomain);
    }

    @Override
    public User upsert(User user) {
        table.putItem(toItem(user));
        return user;
    }

    private static DynamoUserItem toItem(User u) {
        DynamoUserItem item = new DynamoUserItem();
        item.setUserId(u.getUserId());
        item.setEmail(u.getEmail());
        item.setName(u.getName());
        item.setGivenName(u.getGivenName());
        item.setFamilyName(u.getFamilyName());
        item.setPicture(u.getPicture());
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
                item.getProvider(),
                Instant.parse(item.getCreatedAt()),
                Instant.parse(item.getUpdatedAt())
        );
    }
}
