package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.List;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.collections.ports.CollectionsRepository;
import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionType;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.BatchGetItemEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ReadBatch;
import software.amazon.awssdk.enhanced.dynamodb.model.PageIterable;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.PutItemRequest;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemRequest;
import software.amazon.awssdk.services.dynamodb.model.ReturnValue;

@Repository
public class DynamoDbCollectionsRepository implements CollectionsRepository {
    private static final String OWNER_INDEX = "gsi1";

    private final DynamoDbTable<DynamoCollectionItem> table;
    private final DynamoDbEnhancedClient enhancedClient;
    private final DynamoDbClient dynamoDbClient;
    private final String tableName;

    public DynamoDbCollectionsRepository(
            DynamoDbEnhancedClient enhancedClient,
            DynamoDbClient dynamoDbClient,
            @Value("${ones.dynamodb.collections-table-name:ones-collections}") String tableName
    ) {
        this.enhancedClient = enhancedClient;
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoCollectionItem.class));
        this.dynamoDbClient = dynamoDbClient;
        this.tableName = tableName;
    }

    @Override
    public Collection save(Collection collection) {
        table.putItem(toItem(collection));
        return collection;
    }

    @Override
    public boolean saveIfAbsent(Collection collection) {
        try {
            dynamoDbClient.putItem(PutItemRequest.builder()
                    .tableName(tableName)
                    .item(toAttributes(collection))
                    .conditionExpression("attribute_not_exists(collectionId)")
                    .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return false;
        }
    }

    @Override
    public Optional<Collection> findById(String id) {
        if (id == null || id.isBlank()) return Optional.empty();
        return Optional.ofNullable(table.getItem(Key.builder().partitionValue(id.trim()).build()))
                .map(DynamoDbCollectionsRepository::toDomain);
    }

    @Override
    public List<Collection> findByIds(List<String> ids) {
        if (ids == null || ids.isEmpty()) return List.of();
        Set<String> unique = new HashSet<>();
        List<Key> keys = new ArrayList<>();
        for (String id : ids) {
            if (id != null && !id.isBlank() && unique.add(id)) {
                keys.add(Key.builder().partitionValue(id).build());
            }
        }
        List<Collection> results = new ArrayList<>();
        for (int start = 0; start < keys.size(); start += 100) {
            ReadBatch.Builder<DynamoCollectionItem> batch = ReadBatch.builder(DynamoCollectionItem.class)
                    .mappedTableResource(table);
            keys.subList(start, Math.min(start + 100, keys.size())).forEach(batch::addGetItem);
            enhancedClient.batchGetItem(BatchGetItemEnhancedRequest.builder()
                            .readBatches(batch.build()).build())
                    .resultsForTable(table)
                    .forEach(item -> {
                        if (!Boolean.TRUE.equals(item.getDeleting())) results.add(toDomain(item));
                    });
        }
        return List.copyOf(results);
    }

    @Override
    public List<Collection> listByOwnerId(String ownerId, int limit) {
        if (ownerId == null || ownerId.isBlank()) return List.of();
        var request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(
                        Key.builder().partitionValue(ownerId.trim()).build()))
                .limit(Math.min(Math.max(limit, 1), 100))
                .scanIndexForward(false)
                .build();
        DynamoDbIndex<DynamoCollectionItem> index = table.index(OWNER_INDEX);
        int pageSize = Math.min(Math.max(limit, 1), 100);
        return PageIterable.create(index.query(request)).items().stream()
                .limit(pageSize)
                .filter(item -> !Boolean.TRUE.equals(item.getDeleting()))
                .map(DynamoDbCollectionsRepository::toDomain)
                .toList();
    }

    @Override
    public boolean markDeleting(String collectionId, String ownerId) {
        try {
            dynamoDbClient.updateItem(UpdateItemRequest.builder()
                    .tableName(tableName)
                    .key(Map.of("collectionId", AttributeValue.fromS(collectionId)))
                    .updateExpression("SET #deleting = :true, #joinEnabled = :false, #updatedAt = :updatedAt "
                            + "REMOVE #joinTokenHash")
                    .conditionExpression("#ownerId = :ownerId AND "
                            + "(attribute_not_exists(#deleting) OR #deleting = :false)")
                    .expressionAttributeNames(Map.of(
                            "#ownerId", "ownerId",
                            "#deleting", "deleting",
                            "#joinEnabled", "joinEnabled",
                            "#joinTokenHash", "joinTokenHash",
                            "#updatedAt", "updatedAt"
                    ))
                    .expressionAttributeValues(Map.of(
                            ":ownerId", AttributeValue.fromS(ownerId),
                            ":true", AttributeValue.fromBool(true),
                            ":false", AttributeValue.fromBool(false),
                            ":updatedAt", AttributeValue.fromS(Instant.now().toString())
                    ))
                    .returnValues(ReturnValue.NONE)
                    .build());
            return true;
        } catch (ConditionalCheckFailedException e) {
            return findById(collectionId)
                    .filter(collection -> ownerId.equals(collection.ownerId()) && collection.deleting())
                    .isPresent();
        }
    }

    @Override
    public void deleteById(String collectionId) {
        if (collectionId == null || collectionId.isBlank()) return;
        table.deleteItem(Key.builder().partitionValue(collectionId.trim()).build());
    }

    static DynamoCollectionItem toItem(Collection collection) {
        DynamoCollectionItem item = new DynamoCollectionItem();
        item.setCollectionId(collection.id());
        item.setOwnerId(collection.ownerId());
        item.setName(collection.name());
        item.setDescription(collection.description());
        item.setType(collection.type().name());
        item.setCoverKey(collection.coverKey());
        item.setPurpose(collection.purpose());
        item.setCreatedAt(collection.createdAt().toString());
        item.setUpdatedAt(collection.updatedAt().toString());
        item.setJoinEnabled(collection.joinEnabled());
        item.setJoinTokenHash(collection.joinTokenHash());
        item.setDeleting(collection.deleting());
        item.setPartnerSlotKey(collection.partnerSlotKey());
        item.setGsi1pk(collection.ownerId());
        item.setGsi1sk(collection.createdAt() + "#" + collection.id());
        return item;
    }

    static Collection toDomain(DynamoCollectionItem item) {
        return new Collection(
                item.getCollectionId(), item.getOwnerId(), item.getName(), item.getDescription(),
                CollectionType.from(item.getType()), item.getCoverKey(), item.getPurpose(),
                Instant.parse(item.getCreatedAt()), Instant.parse(item.getUpdatedAt()),
                Boolean.TRUE.equals(item.getJoinEnabled()), item.getJoinTokenHash(),
                Boolean.TRUE.equals(item.getDeleting()), item.getPartnerSlotKey()
        );
    }

    private static Map<String, AttributeValue> toAttributes(Collection collection) {
        var item = toItem(collection);
        var attributes = new java.util.HashMap<String, AttributeValue>();
        attributes.put("collectionId", AttributeValue.fromS(item.getCollectionId()));
        attributes.put("ownerId", AttributeValue.fromS(item.getOwnerId()));
        attributes.put("name", AttributeValue.fromS(item.getName()));
        attributes.put("type", AttributeValue.fromS(item.getType()));
        attributes.put("createdAt", AttributeValue.fromS(item.getCreatedAt()));
        attributes.put("updatedAt", AttributeValue.fromS(item.getUpdatedAt()));
        attributes.put("joinEnabled", AttributeValue.fromBool(Boolean.TRUE.equals(item.getJoinEnabled())));
        attributes.put("deleting", AttributeValue.fromBool(Boolean.TRUE.equals(item.getDeleting())));
        attributes.put("gsi1pk", AttributeValue.fromS(item.getGsi1pk()));
        attributes.put("gsi1sk", AttributeValue.fromS(item.getGsi1sk()));
        putOptional(attributes, "description", item.getDescription());
        putOptional(attributes, "coverKey", item.getCoverKey());
        putOptional(attributes, "purpose", item.getPurpose());
        putOptional(attributes, "joinTokenHash", item.getJoinTokenHash());
        putOptional(attributes, "partnerSlotKey", item.getPartnerSlotKey());
        return attributes;
    }

    private static void putOptional(Map<String, AttributeValue> attributes, String key, String value) {
        if (value != null) attributes.put(key, AttributeValue.fromS(value));
    }
}
