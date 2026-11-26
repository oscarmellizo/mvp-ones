package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.collections.ports.CollectionMembersRepository;
import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionMember;
import com.ones.api.domain.collections.CollectionType;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.PageIterable;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.ConditionCheck;
import software.amazon.awssdk.services.dynamodb.model.Delete;
import software.amazon.awssdk.services.dynamodb.model.Put;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItem;
import software.amazon.awssdk.services.dynamodb.model.TransactWriteItemsRequest;
import software.amazon.awssdk.services.dynamodb.model.TransactionCanceledException;
import software.amazon.awssdk.services.dynamodb.model.Update;

@Repository
public class DynamoDbCollectionMembersRepository implements CollectionMembersRepository {
    private final DynamoDbTable<DynamoCollectionMemberItem> table;
    private final DynamoDbClient dynamoDbClient;
    private final String membersTableName;
    private final String collectionsTableName;

    public DynamoDbCollectionMembersRepository(
            DynamoDbEnhancedClient enhancedClient,
            DynamoDbClient dynamoDbClient,
            @Value("${ones.dynamodb.collection-members-table-name:ones-collection-members}") String membersTableName,
            @Value("${ones.dynamodb.collections-table-name:ones-collections}") String collectionsTableName
    ) {
        this.table = enhancedClient.table(membersTableName, TableSchema.fromBean(DynamoCollectionMemberItem.class));
        this.dynamoDbClient = dynamoDbClient;
        this.membersTableName = membersTableName;
        this.collectionsTableName = collectionsTableName;
    }

    @Override
    public boolean add(Collection collection, CollectionMember member) {
        Map<String, AttributeValue> memberItem = toAttributes(member);
        Put put = Put.builder()
                .tableName(membersTableName)
                .item(memberItem)
                .conditionExpression("attribute_not_exists(collectionId) AND attribute_not_exists(memberKey)")
                .build();

        if (collection.type() != CollectionType.COUPLE) {
            try {
                dynamoDbClient.putItem(b -> b.tableName(membersTableName).item(memberItem)
                        .conditionExpression("attribute_not_exists(collectionId) AND attribute_not_exists(memberKey)"));
                return true;
            } catch (ConditionalCheckFailedException e) {
                return false;
            }
        }

        Update reserveSlot = Update.builder()
                .tableName(collectionsTableName)
                .key(Map.of("collectionId", AttributeValue.fromS(collection.id())))
                .updateExpression("SET partnerSlotKey = :memberKey")
                .conditionExpression("attribute_not_exists(partnerSlotKey)")
                .expressionAttributeValues(Map.of(":memberKey", AttributeValue.fromS(member.memberKey())))
                .build();
        try {
            dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                    .transactItems(
                            TransactWriteItem.builder().put(put).build(),
                            TransactWriteItem.builder().update(reserveSlot).build()
                    )
                    .build());
            return true;
        } catch (TransactionCanceledException e) {
            return false;
        }
    }

    @Override
    public CollectionMember save(CollectionMember member) {
        DynamoCollectionMemberItem item = toItem(member);
        table.putItem(item);
        return member;
    }

    @Override
    public boolean transition(Collection collection, CollectionMember current, CollectionMember next) {
        Update updateMember = Update.builder()
                .tableName(membersTableName)
                .key(Map.of(
                        "collectionId", AttributeValue.fromS(current.collectionId()),
                        "memberKey", AttributeValue.fromS(current.memberKey())
                ))
                .updateExpression("SET #status = :nextStatus, updatedAt = :updatedAt"
                        + (next.userId() == null ? "" : ", userId = :userId"))
                .conditionExpression("#status = :currentStatus")
                .expressionAttributeNames(Map.of("#status", "status"))
                .expressionAttributeValues(statusValues(current, next))
                .build();

        boolean releasingCoupleSlot = collection.type() == CollectionType.COUPLE
                && next.status() == CollectionMember.Status.REJECTED
                && current.memberKey().equals(collection.partnerSlotKey());
        if (!releasingCoupleSlot) {
            try {
                dynamoDbClient.updateItem(b -> b.tableName(membersTableName)
                        .key(Map.of(
                                "collectionId", AttributeValue.fromS(current.collectionId()),
                                "memberKey", AttributeValue.fromS(current.memberKey())
                        ))
                        .updateExpression(updateMember.updateExpression())
                        .conditionExpression(updateMember.conditionExpression())
                        .expressionAttributeNames(updateMember.expressionAttributeNames())
                        .expressionAttributeValues(updateMember.expressionAttributeValues()));
                return true;
            } catch (ConditionalCheckFailedException e) {
                return false;
            }
        }

        Update releaseSlot = Update.builder()
                .tableName(collectionsTableName)
                .key(Map.of("collectionId", AttributeValue.fromS(collection.id())))
                .updateExpression("REMOVE partnerSlotKey")
                .conditionExpression("partnerSlotKey = :memberKey")
                .expressionAttributeValues(Map.of(":memberKey", AttributeValue.fromS(current.memberKey())))
                .build();
        try {
            dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                    .transactItems(
                            TransactWriteItem.builder().update(updateMember).build(),
                            TransactWriteItem.builder().update(releaseSlot).build()
                    )
                    .build());
            return true;
        } catch (TransactionCanceledException e) {
            return false;
        }
    }

    @Override
    public boolean acceptInvitation(Collection collection, CollectionMember pending, String userId, Instant now) {
        if (userId == null || userId.isBlank() || pending.email() == null || pending.email().isBlank()) {
            return false;
        }
        String acceptedKey = userKey(userId);
        CollectionMember accepted = new CollectionMember(
                collection.id(), acceptedKey, userId, pending.email(), CollectionMember.Status.ACCEPTED,
                pending.invitedByUserId(), pending.createdAt(), now
        );
        Delete deletePending = Delete.builder()
                .tableName(membersTableName)
                .key(Map.of(
                        "collectionId", AttributeValue.fromS(pending.collectionId()),
                        "memberKey", AttributeValue.fromS(pending.memberKey())
                ))
                .conditionExpression("#status = :pending")
                .expressionAttributeNames(Map.of("#status", "status"))
                .expressionAttributeValues(Map.of(":pending", AttributeValue.fromS("PENDING")))
                .build();
        Put addAccepted = Put.builder()
                .tableName(membersTableName)
                .item(toAttributes(accepted))
                .conditionExpression("attribute_not_exists(collectionId) AND attribute_not_exists(memberKey)")
                .build();
        List<TransactWriteItem> writes = new ArrayList<>();
        writes.add(TransactWriteItem.builder().delete(deletePending).build());
        writes.add(TransactWriteItem.builder().put(addAccepted).build());
        if (collection.type() == CollectionType.COUPLE) {
            Update transferSlot = Update.builder()
                    .tableName(collectionsTableName)
                    .key(Map.of("collectionId", AttributeValue.fromS(collection.id())))
                    .updateExpression("SET partnerSlotKey = :acceptedKey")
                    .conditionExpression("partnerSlotKey = :pendingKey")
                    .expressionAttributeValues(Map.of(
                            ":pendingKey", AttributeValue.fromS(pending.memberKey()),
                            ":acceptedKey", AttributeValue.fromS(acceptedKey)
                    ))
                    .build();
            writes.add(TransactWriteItem.builder().update(transferSlot).build());
        }
        try {
            dynamoDbClient.transactWriteItems(b -> b.transactItems(writes));
            return true;
        } catch (TransactionCanceledException e) {
            return false;
        }
    }

    @Override
    public Optional<CollectionMember> find(String collectionId, String memberKey) {
        if (collectionId == null || memberKey == null) return Optional.empty();
        return Optional.ofNullable(table.getItem(Key.builder()
                        .partitionValue(collectionId).sortValue(memberKey).build()))
                .map(DynamoDbCollectionMembersRepository::toDomain);
    }

    @Override
    public Optional<CollectionMember> findByCollectionAndUser(String collectionId, String userId) {
        if (collectionId == null || userId == null) return Optional.empty();
        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder()
                        .partitionValue(collectionId).sortValue(userId).build()))
                .limit(1)
                .build();
        return PageIterable.create(table.index("byCollectionUser").query(request)).items().stream()
                .findFirst()
                .map(DynamoDbCollectionMembersRepository::toDomain);
    }

    @Override
    public Optional<CollectionMember> findByCollectionAndEmail(String collectionId, String email) {
        if (collectionId == null || email == null) return Optional.empty();
        String normalized = email.trim().toLowerCase(java.util.Locale.ROOT);
        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder()
                        .partitionValue(normalized).sortValue(collectionId).build()))
                .limit(1)
                .build();
        return PageIterable.create(table.index("byInviteeEmail").query(request)).items().stream()
                .findFirst()
                .map(DynamoDbCollectionMembersRepository::toDomain);
    }

    @Override
    public List<CollectionMember> listByCollection(String collectionId, int limit) {
        if (collectionId == null || collectionId.isBlank()) return List.of();
        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(collectionId).build()))
                .limit(Math.min(Math.max(limit, 1), 200))
                .build();
        int pageSize = Math.min(Math.max(limit, 1), 200);
        return PageIterable.create(table.query(request)).items().stream()
                .limit(pageSize)
                .map(DynamoDbCollectionMembersRepository::toDomain)
                .toList();
    }

    @Override
    public PageResult<CollectionMember> pageByCollection(
            String collectionId,
            int limit,
            String nextToken
    ) {
        if (collectionId == null || collectionId.isBlank()) {
            return new PageResult<>(List.of(), null);
        }
        int pageSize = Math.min(Math.max(limit, 1), 200);
        QueryEnhancedRequest.Builder request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(
                        Key.builder().partitionValue(collectionId).build()))
                .limit(pageSize);
        if (nextToken != null && !nextToken.isBlank()) {
            String memberKey;
            try {
                memberKey = new String(Base64.getUrlDecoder().decode(nextToken), java.nio.charset.StandardCharsets.UTF_8);
            } catch (IllegalArgumentException e) {
                throw new IllegalArgumentException("Invalid collection member cursor", e);
            }
            request.exclusiveStartKey(Map.of(
                    "collectionId", AttributeValue.fromS(collectionId),
                    "memberKey", AttributeValue.fromS(memberKey)
            ));
        }
        var page = table.query(request.build()).iterator().next();
        String cursor = null;
        if (page.lastEvaluatedKey() != null && page.lastEvaluatedKey().get("memberKey") != null) {
            cursor = Base64.getUrlEncoder().withoutPadding().encodeToString(
                    page.lastEvaluatedKey().get("memberKey").s()
                            .getBytes(java.nio.charset.StandardCharsets.UTF_8));
        }
        return new PageResult<>(
                page.items().stream().map(DynamoDbCollectionMembersRepository::toDomain).toList(),
                cursor
        );
    }

    @Override
    public List<CollectionMember> listByUser(String userId, int limit) {
        if (userId == null || userId.isBlank()) return List.of();
        DynamoDbIndex<DynamoCollectionMemberItem> index = table.index("byUserId");
        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(userId).build()))
                .limit(Math.min(Math.max(limit, 1), 200))
                .build();
        int pageSize = Math.min(Math.max(limit, 1), 200);
        return PageIterable.create(index.query(request)).items().stream()
                .limit(pageSize)
                .map(DynamoDbCollectionMembersRepository::toDomain)
                .filter(CollectionMember::accepted)
                .toList();
    }

    @Override
    public void remove(Collection collection, CollectionMember member) {
        Map<String, AttributeValue> key = Map.of(
                "collectionId", AttributeValue.fromS(member.collectionId()),
                "memberKey", AttributeValue.fromS(member.memberKey())
        );
        if (collection.type() != CollectionType.COUPLE
                || !member.memberKey().equals(collection.partnerSlotKey())) {
            dynamoDbClient.deleteItem(b -> b.tableName(membersTableName).key(key));
            return;
        }

        Delete delete = Delete.builder().tableName(membersTableName).key(key).build();
        Update releaseSlot = Update.builder()
                .tableName(collectionsTableName)
                .key(Map.of("collectionId", AttributeValue.fromS(collection.id())))
                .updateExpression("REMOVE partnerSlotKey")
                .conditionExpression("partnerSlotKey = :memberKey")
                .expressionAttributeValues(Map.of(":memberKey", AttributeValue.fromS(member.memberKey())))
                .build();
        dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                .transactItems(
                        TransactWriteItem.builder().delete(delete).build(),
                        TransactWriteItem.builder().update(releaseSlot).build()
                )
                .build());
    }

    @Override
    public void deleteByCollectionId(String collectionId) {
        if (collectionId == null || collectionId.isBlank()) return;
        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(
                        Key.builder().partitionValue(collectionId.trim()).build()))
                .limit(100)
                .build();
        for (var page : table.query(request)) {
            for (DynamoCollectionMemberItem item : page.items()) {
                table.deleteItem(Key.builder()
                        .partitionValue(item.getCollectionId())
                        .sortValue(item.getMemberKey())
                        .build());
            }
        }
    }

    @Override
    public boolean transferOwnership(
            Collection collection,
            String newOwnerId,
            CollectionMember formerOwnerMembership
    ) {
        Instant now = formerOwnerMembership.updatedAt();
        Map<String, AttributeValue> updateValues = Map.of(
                ":previousOwner", AttributeValue.fromS(collection.ownerId()),
                ":newOwner", AttributeValue.fromS(newOwnerId),
                ":updatedAt", AttributeValue.fromS(now.toString()),
                ":false", AttributeValue.fromBool(false)
        );
        Map<String, String> names = Map.of(
                "#ownerId", "ownerId",
                "#ownerPk", "gsi1pk",
                "#updatedAt", "updatedAt",
                "#deleting", "deleting"
        );
        Map<String, AttributeValue> membership = new HashMap<>();
        membership.put("collectionId", AttributeValue.fromS(formerOwnerMembership.collectionId()));
        membership.put("memberKey", AttributeValue.fromS(formerOwnerMembership.memberKey()));
        membership.put("userId", AttributeValue.fromS(formerOwnerMembership.userId()));
        membership.put("status", AttributeValue.fromS(formerOwnerMembership.status().name()));
        membership.put("invitedByUserId", AttributeValue.fromS(formerOwnerMembership.invitedByUserId()));
        membership.put("createdAt", AttributeValue.fromS(formerOwnerMembership.createdAt().toString()));
        membership.put("updatedAt", AttributeValue.fromS(now.toString()));
        try {
            dynamoDbClient.transactWriteItems(TransactWriteItemsRequest.builder()
                    .transactItems(
                            TransactWriteItem.builder().update(Update.builder()
                                    .tableName(collectionsTableName)
                                    .key(Map.of("collectionId", AttributeValue.fromS(collection.id())))
                                    .updateExpression("SET #ownerId = :newOwner, #ownerPk = :newOwner, #updatedAt = :updatedAt")
                                    .conditionExpression("#ownerId = :previousOwner AND (attribute_not_exists(#deleting) OR #deleting = :false)")
                                    .expressionAttributeNames(names)
                                    .expressionAttributeValues(updateValues)
                                    .build()).build(),
                            TransactWriteItem.builder().put(Put.builder()
                                    .tableName(membersTableName)
                                    .item(membership)
                                    .build()).build(),
                            TransactWriteItem.builder().conditionCheck(ConditionCheck.builder()
                                    .tableName(membersTableName)
                                    .key(Map.of(
                                            "collectionId", AttributeValue.fromS(collection.id()),
                                            "memberKey", AttributeValue.fromS("USER#" + newOwnerId)
                                    ))
                                    .conditionExpression("#status = :accepted AND #userId = :newOwner")
                                    .expressionAttributeNames(Map.of(
                                            "#status", "status",
                                            "#userId", "userId"
                                    ))
                                    .expressionAttributeValues(Map.of(
                                            ":accepted", AttributeValue.fromS(CollectionMember.Status.ACCEPTED.name()),
                                            ":newOwner", AttributeValue.fromS(newOwnerId)
                                    ))
                                    .build()).build()
                    )
                    .build());
            return true;
        } catch (ConditionalCheckFailedException | TransactionCanceledException e) {
            return false;
        }
    }

    private static DynamoCollectionMemberItem toItem(CollectionMember member) {
        DynamoCollectionMemberItem item = new DynamoCollectionMemberItem();
        item.setCollectionId(member.collectionId());
        item.setMemberKey(member.memberKey());
        item.setUserId(member.userId());
        item.setInviteeEmail(member.email());
        item.setStatus(member.status().name());
        item.setInvitedByUserId(member.invitedByUserId());
        item.setCreatedAt(member.createdAt().toString());
        item.setUpdatedAt(member.updatedAt().toString());
        return item;
    }

    private static CollectionMember toDomain(DynamoCollectionMemberItem item) {
        return new CollectionMember(
                item.getCollectionId(), item.getMemberKey(), item.getUserId(), item.getInviteeEmail(),
                CollectionMember.Status.valueOf(item.getStatus()), item.getInvitedByUserId(),
                Instant.parse(item.getCreatedAt()), Instant.parse(item.getUpdatedAt())
        );
    }

    private static Map<String, AttributeValue> toAttributes(CollectionMember member) {
        Map<String, AttributeValue> result = new HashMap<>();
        result.put("collectionId", AttributeValue.fromS(member.collectionId()));
        result.put("memberKey", AttributeValue.fromS(member.memberKey()));
        result.put("status", AttributeValue.fromS(member.status().name()));
        result.put("createdAt", AttributeValue.fromS(member.createdAt().toString()));
        result.put("updatedAt", AttributeValue.fromS(member.updatedAt().toString()));
        putOptional(result, "userId", member.userId());
        putOptional(result, "inviteeEmail", member.email());
        putOptional(result, "invitedByUserId", member.invitedByUserId());
        return result;
    }

    private static Map<String, AttributeValue> statusValues(
            CollectionMember current,
            CollectionMember next
    ) {
        Map<String, AttributeValue> values = new HashMap<>();
        values.put(":currentStatus", AttributeValue.fromS(current.status().name()));
        values.put(":nextStatus", AttributeValue.fromS(next.status().name()));
        values.put(":updatedAt", AttributeValue.fromS(next.updatedAt().toString()));
        if (next.userId() != null) values.put(":userId", AttributeValue.fromS(next.userId()));
        return values;
    }

    private static void putOptional(Map<String, AttributeValue> map, String key, String value) {
        if (value != null && !value.isBlank()) map.put(key, AttributeValue.fromS(value));
    }

    static String userKey(String userId) {
        return "USER#" + userId.trim();
    }
}
