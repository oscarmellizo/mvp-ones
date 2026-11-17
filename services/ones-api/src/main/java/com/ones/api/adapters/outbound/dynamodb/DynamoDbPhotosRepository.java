package com.ones.api.adapters.outbound.dynamodb;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.DynamoDbClient;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ConditionalCheckFailedException;
import software.amazon.awssdk.services.dynamodb.model.GetItemRequest;
import software.amazon.awssdk.services.dynamodb.model.ReturnValue;
import software.amazon.awssdk.services.dynamodb.model.UpdateItemRequest;

@Repository
public class DynamoDbPhotosRepository implements PhotosRepository {

    private final DynamoDbTable<DynamoPhotoItem> table;
    private final DynamoDbClient dynamoDbClient;
    private final String tableName;

    public DynamoDbPhotosRepository(
            DynamoDbEnhancedClient enhancedClient,
            DynamoDbClient dynamoDbClient,
            @Value("${ones.dynamodb.photos-table-name:ones-photos}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoPhotoItem.class));
        this.dynamoDbClient = dynamoDbClient;
        this.tableName = tableName;
    }

    @Override
    public Optional<Photo> findById(String photoId) {
        if (photoId == null || photoId.isBlank()) {
            return Optional.empty();
        }
        DynamoPhotoItem item = table.getItem(Key.builder().partitionValue(photoId.trim()).build());
        return Optional.ofNullable(item).map(DynamoDbPhotosRepository::toDomain);
    }

    @Override
    public Photo upsert(Photo photo) {
        table.putItem(toItem(photo));
        return photo;
    }

    @Override
    public Photo completeUpload(Photo photo) {
        Map<String, String> names = new HashMap<>(Map.of(
                "#photoId", "photoId",
                "#eventId", "eventId",
                "#eventSortKey", "eventSortKey",
                "#guestId", "guestId",
                "#createdAt", "createdAt",
                "#uploadedAt", "uploadedAt",
                "#status", "status",
                "#s3KeyOriginal", "s3KeyOriginal",
                "#shared", "shared",
                "#sharedByUserId", "sharedByUserId"
        ));
        Map<String, AttributeValue> values = new HashMap<>(Map.of(
                ":eventId", AttributeValue.fromS(photo.getEventId()),
                ":eventSortKey", AttributeValue.fromS(eventSortKey(photo.getCreatedAt(), photo.getPhotoId())),
                ":guestId", AttributeValue.fromS(photo.getGuestId()),
                ":internal", AttributeValue.fromS("internal"),
                ":createdAt", AttributeValue.fromS(photo.getCreatedAt().toString()),
                ":uploadedAt", AttributeValue.fromS(photo.getUploadedAt().toString()),
                ":status", AttributeValue.fromS(photo.getStatus()),
                ":s3KeyOriginal", AttributeValue.fromS(photo.getS3KeyOriginal()),
                ":shared", AttributeValue.fromBool(true),
                ":sharedByUserId", AttributeValue.fromS(photo.getSharedByUserId())
        ));
        StringBuilder updateExpression = new StringBuilder(
                "SET #eventId = :eventId, #eventSortKey = :eventSortKey, #guestId = :guestId, "
                        + "#createdAt = :createdAt, #uploadedAt = if_not_exists(#uploadedAt, :uploadedAt), "
                        + "#status = if_not_exists(#status, :status), #s3KeyOriginal = :s3KeyOriginal, "
                        + "#shared = :shared, #sharedByUserId = :sharedByUserId"
        );
        if (photo.getOwnerName() != null && !photo.getOwnerName().isBlank()) {
            names.put("#ownerName", "ownerName");
            values.put(":ownerName", AttributeValue.fromS(photo.getOwnerName()));
            updateExpression.append(", #ownerName = :ownerName");
        }
        if (photo.getSharedByName() != null && !photo.getSharedByName().isBlank()) {
            names.put("#sharedByName", "sharedByName");
            values.put(":sharedByName", AttributeValue.fromS(photo.getSharedByName()));
            updateExpression.append(", #sharedByName = :sharedByName");
        }

        UpdateItemRequest request = UpdateItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("photoId", AttributeValue.fromS(photo.getPhotoId())))
                .updateExpression(updateExpression.toString())
                .conditionExpression(
                        "attribute_not_exists(#photoId) OR (#eventId = :eventId "
                                + "AND attribute_not_exists(#s3KeyOriginal) "
                                + "AND (attribute_not_exists(#guestId) OR #guestId = :guestId OR #guestId = :internal))"
                )
                .expressionAttributeNames(names)
                .expressionAttributeValues(values)
                .build();

        try {
            Map<String, AttributeValue> attributes = dynamoDbClient.updateItem(request.toBuilder()
                    .returnValues(ReturnValue.ALL_NEW)
                    .build()).attributes();
            return attributes == null || attributes.isEmpty() ? photo : toDomain(fromAttributes(attributes));
        } catch (ConditionalCheckFailedException e) {
            Photo existing = findByIdConsistent(photo.getPhotoId()).orElse(null);
            if (existing == null
                    || !photo.getEventId().equals(existing.getEventId())
                    || !photo.getGuestId().equals(existing.getGuestId())
                    || !photo.getS3KeyOriginal().equals(existing.getS3KeyOriginal())) {
                throw new IllegalStateException("Photo upload conflicts with an existing photo", e);
            }
            return existing;
        }
    }

    @Override
    public ProcessingClaim claimProcessing(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            boolean manualRetry,
            Instant now,
            Instant leaseUntil
    ) {
        Map<String, String> names = new HashMap<>(Map.of(
                "#photoId", "photoId",
                "#eventId", "eventId",
                "#s3KeyOriginal", "s3KeyOriginal",
                "#status", "status",
                "#processingAttempts", "processingAttempts",
                "#processingErrorCode", "processingErrorCode",
                "#processingLeaseUntilEpoch", "processingLeaseUntilEpoch",
                "#processingRetryAtEpoch", "processingRetryAtEpoch"
        ));
        Map<String, AttributeValue> values = new HashMap<>(Map.of(
                ":eventId", AttributeValue.fromS(eventId),
                ":s3KeyOriginal", AttributeValue.fromS(s3KeyOriginal),
                ":uploaded", AttributeValue.fromS("uploaded"),
                ":processing", AttributeValue.fromS("processing"),
                ":retrying", AttributeValue.fromS("retrying"),
                ":zero", AttributeValue.fromN("0"),
                ":now", AttributeValue.fromN(Long.toString(now.toEpochMilli())),
                ":leaseUntil", AttributeValue.fromN(Long.toString(leaseUntil.toEpochMilli())),
                ":attempt", AttributeValue.fromN("1")
        ));
        String eligibleStatuses = "#status = :uploaded OR #status = :retrying OR "
                + "(#status = :processing AND "
                + "(attribute_not_exists(#processingLeaseUntilEpoch) OR #processingLeaseUntilEpoch <= :now))";
        if (manualRetry) {
            values.put(":failed", AttributeValue.fromS("failed"));
            eligibleStatuses += " OR #status = :failed";
        }

        UpdateItemRequest request = UpdateItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("photoId", AttributeValue.fromS(photoId)))
                .updateExpression(
                        "SET #status = :processing, "
                                + "#processingAttempts = if_not_exists(#processingAttempts, :zero) + :attempt, "
                                + "#processingLeaseUntilEpoch = :leaseUntil "
                                + "REMOVE #processingErrorCode, #processingRetryAtEpoch"
                )
                .conditionExpression(
                        "attribute_exists(#photoId) AND #eventId = :eventId "
                                + "AND #s3KeyOriginal = :s3KeyOriginal AND (" + eligibleStatuses + ")"
                )
                .expressionAttributeNames(names)
                .expressionAttributeValues(values)
                .returnValues(ReturnValue.ALL_NEW)
                .build();

        try {
            Map<String, AttributeValue> attributes = dynamoDbClient.updateItem(request).attributes();
            if (attributes == null || attributes.isEmpty()) {
                return new ProcessingClaim(ProcessingClaimStatus.CONFLICT, null);
            }
            return new ProcessingClaim(ProcessingClaimStatus.CLAIMED, toDomain(fromAttributes(attributes)));
        } catch (ConditionalCheckFailedException e) {
            Photo existing = findByIdConsistent(photoId).orElse(null);
            if (existing == null) {
                return new ProcessingClaim(ProcessingClaimStatus.NOT_FOUND, null);
            }
            if (!eventId.equals(existing.getEventId())
                    || !s3KeyOriginal.equals(existing.getS3KeyOriginal())) {
                return new ProcessingClaim(ProcessingClaimStatus.CONFLICT, existing);
            }
            String status = existing.getStatus() != null ? existing.getStatus().trim().toLowerCase() : "";
            if ("ready".equals(status)) {
                return new ProcessingClaim(ProcessingClaimStatus.READY, existing);
            }
            if ("failed".equals(status) && !manualRetry) {
                return new ProcessingClaim(ProcessingClaimStatus.FAILED, existing);
            }
            if ("processing".equals(status)
                    && existing.getProcessingLeaseUntilEpoch() != null
                    && existing.getProcessingLeaseUntilEpoch() > now.toEpochMilli()) {
                return new ProcessingClaim(ProcessingClaimStatus.BUSY, existing);
            }
            return new ProcessingClaim(ProcessingClaimStatus.BUSY, existing);
        }
    }

    @Override
    public Optional<Photo> markProcessingRetrying(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String errorCode,
            Instant retryAt
    ) {
        Map<String, String> names = Map.of(
                "#photoId", "photoId",
                "#eventId", "eventId",
                "#s3KeyOriginal", "s3KeyOriginal",
                "#status", "status",
                "#processingErrorCode", "processingErrorCode",
                "#processingRetryAtEpoch", "processingRetryAtEpoch",
                "#processingLeaseUntilEpoch", "processingLeaseUntilEpoch"
        );
        Map<String, AttributeValue> values = Map.of(
                ":eventId", AttributeValue.fromS(eventId),
                ":s3KeyOriginal", AttributeValue.fromS(s3KeyOriginal),
                ":processing", AttributeValue.fromS("processing"),
                ":retrying", AttributeValue.fromS("retrying"),
                ":errorCode", AttributeValue.fromS(errorCode),
                ":retryAt", AttributeValue.fromN(Long.toString(retryAt.toEpochMilli()))
        );
        try {
            Map<String, AttributeValue> attributes = dynamoDbClient.updateItem(UpdateItemRequest.builder()
                    .tableName(tableName)
                    .key(Map.of("photoId", AttributeValue.fromS(photoId)))
                    .updateExpression(
                            "SET #status = :retrying, #processingErrorCode = :errorCode, "
                                    + "#processingRetryAtEpoch = :retryAt "
                                    + "REMOVE #processingLeaseUntilEpoch"
                    )
                    .conditionExpression("#eventId = :eventId AND #s3KeyOriginal = :s3KeyOriginal "
                            + "AND (#status = :processing OR #status = :retrying)")
                    .expressionAttributeNames(names)
                    .expressionAttributeValues(values)
                    .returnValues(ReturnValue.ALL_NEW)
                    .build()).attributes();
            return attributes == null || attributes.isEmpty()
                    ? Optional.empty()
                    : Optional.of(toDomain(fromAttributes(attributes)));
        } catch (ConditionalCheckFailedException e) {
            return findByIdConsistent(photoId)
                    .filter(photo -> eventId.equals(photo.getEventId()))
                    .filter(photo -> s3KeyOriginal.equals(photo.getS3KeyOriginal()))
                    .filter(photo -> "ready".equalsIgnoreCase(photo.getStatus()));
        }
    }

    @Override
    public Optional<Photo> markProcessingFailed(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String errorCode
    ) {
        Map<String, String> names = Map.of(
                "#photoId", "photoId",
                "#eventId", "eventId",
                "#s3KeyOriginal", "s3KeyOriginal",
                "#status", "status",
                "#processingErrorCode", "processingErrorCode",
                "#processingLeaseUntilEpoch", "processingLeaseUntilEpoch",
                "#processingRetryAtEpoch", "processingRetryAtEpoch"
        );
        Map<String, AttributeValue> values = Map.of(
                ":eventId", AttributeValue.fromS(eventId),
                ":s3KeyOriginal", AttributeValue.fromS(s3KeyOriginal),
                ":failed", AttributeValue.fromS("failed"),
                ":ready", AttributeValue.fromS("ready"),
                ":errorCode", AttributeValue.fromS(errorCode)
        );
        try {
            Map<String, AttributeValue> attributes = dynamoDbClient.updateItem(UpdateItemRequest.builder()
                    .tableName(tableName)
                    .key(Map.of("photoId", AttributeValue.fromS(photoId)))
                    .updateExpression(
                            "SET #status = :failed, #processingErrorCode = :errorCode "
                                    + "REMOVE #processingLeaseUntilEpoch, #processingRetryAtEpoch"
                    )
                    .conditionExpression("attribute_exists(#photoId) AND #eventId = :eventId "
                            + "AND #s3KeyOriginal = :s3KeyOriginal AND #status <> :ready")
                    .expressionAttributeNames(names)
                    .expressionAttributeValues(values)
                    .returnValues(ReturnValue.ALL_NEW)
                    .build()).attributes();
            return attributes == null || attributes.isEmpty()
                    ? Optional.empty()
                    : Optional.of(toDomain(fromAttributes(attributes)));
        } catch (ConditionalCheckFailedException e) {
            return findByIdConsistent(photoId)
                    .filter(photo -> eventId.equals(photo.getEventId()))
                    .filter(photo -> s3KeyOriginal.equals(photo.getS3KeyOriginal()))
                    .filter(photo -> "ready".equalsIgnoreCase(photo.getStatus()));
        }
    }

    @Override
    public Optional<Photo> markRetryRequested(String eventId, String photoId) {
        Map<String, String> names = Map.of(
                "#photoId", "photoId",
                "#eventId", "eventId",
                "#status", "status",
                "#processingErrorCode", "processingErrorCode",
                "#processingLeaseUntilEpoch", "processingLeaseUntilEpoch",
                "#processingRetryAtEpoch", "processingRetryAtEpoch"
        );
        Map<String, AttributeValue> values = Map.of(
                ":eventId", AttributeValue.fromS(eventId),
                ":failed", AttributeValue.fromS("failed"),
                ":retrying", AttributeValue.fromS("retrying")
        );
        try {
            Map<String, AttributeValue> attributes = dynamoDbClient.updateItem(UpdateItemRequest.builder()
                    .tableName(tableName)
                    .key(Map.of("photoId", AttributeValue.fromS(photoId)))
                    .updateExpression(
                            "SET #status = :retrying "
                                    + "REMOVE #processingErrorCode, #processingLeaseUntilEpoch, #processingRetryAtEpoch"
                    )
                    .conditionExpression("attribute_exists(#photoId) AND #eventId = :eventId AND #status = :failed")
                    .expressionAttributeNames(names)
                    .expressionAttributeValues(values)
                    .returnValues(ReturnValue.ALL_NEW)
                    .build()).attributes();
            return attributes == null || attributes.isEmpty()
                    ? Optional.empty()
                    : Optional.of(toDomain(fromAttributes(attributes)));
        } catch (ConditionalCheckFailedException e) {
            return findByIdConsistent(photoId)
                    .filter(photo -> eventId.equals(photo.getEventId()))
                    .filter(photo -> "processing".equalsIgnoreCase(photo.getStatus())
                            || "retrying".equalsIgnoreCase(photo.getStatus())
                            || "ready".equalsIgnoreCase(photo.getStatus()));
        }
    }

    private Optional<Photo> findByIdConsistent(String photoId) {
        Map<String, AttributeValue> attributes = dynamoDbClient.getItem(GetItemRequest.builder()
                .tableName(tableName)
                .key(Map.of("photoId", AttributeValue.fromS(photoId.trim())))
                .consistentRead(true)
                .build()).item();
        if (attributes == null || attributes.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(toDomain(fromAttributes(attributes)));
    }

    private static DynamoPhotoItem fromAttributes(Map<String, AttributeValue> attributes) {
        DynamoPhotoItem item = new DynamoPhotoItem();
        item.setPhotoId(s(attributes.get("photoId")));
        item.setEventId(s(attributes.get("eventId")));
        item.setEventSortKey(s(attributes.get("eventSortKey")));
        item.setGuestId(s(attributes.get("guestId")));
        item.setCreatedAt(s(attributes.get("createdAt")));
        item.setUploadedAt(s(attributes.get("uploadedAt")));
        item.setStatus(s(attributes.get("status")));
        item.setS3KeyOriginal(s(attributes.get("s3KeyOriginal")));
        item.setS3KeyMedium(s(attributes.get("s3KeyMedium")));
        item.setS3KeySmall(s(attributes.get("s3KeySmall")));
        item.setOwnerName(s(attributes.get("ownerName")));
        item.setSharedByUserId(s(attributes.get("sharedByUserId")));
        item.setSharedByName(s(attributes.get("sharedByName")));
        AttributeValue shared = attributes.get("shared");
        item.setShared(shared != null && Boolean.TRUE.equals(shared.bool()));
        item.setProcessingAttempts(n(attributes.get("processingAttempts")) == null
                ? 0
                : n(attributes.get("processingAttempts")).intValue());
        item.setProcessingErrorCode(s(attributes.get("processingErrorCode")));
        item.setProcessingLeaseUntilEpoch(n(attributes.get("processingLeaseUntilEpoch")));
        item.setProcessingRetryAtEpoch(n(attributes.get("processingRetryAtEpoch")));
        return item;
    }

    @Override
    public Photo markReadyInternal(
            String eventId,
            String photoId,
            String s3KeyOriginal,
            String s3KeyMedium,
            String s3KeySmall,
            Instant now
    ) {
        Map<String, String> names = new HashMap<>(Map.of(
                "#photoId", "photoId",
                "#eventId", "eventId",
                "#s3KeyOriginal", "s3KeyOriginal",
                "#status", "status",
                "#processingErrorCode", "processingErrorCode",
                "#processingLeaseUntilEpoch", "processingLeaseUntilEpoch",
                "#processingRetryAtEpoch", "processingRetryAtEpoch"
        ));
        Map<String, AttributeValue> values = new HashMap<>(Map.of(
                ":eventId", AttributeValue.fromS(eventId),
                ":s3KeyOriginal", AttributeValue.fromS(s3KeyOriginal.trim()),
                ":ready", AttributeValue.fromS("ready")
        ));
        StringBuilder updateExpression = new StringBuilder("SET #status = :ready");
        if (s3KeyMedium != null && !s3KeyMedium.isBlank()) {
            names.put("#s3KeyMedium", "s3KeyMedium");
            values.put(":s3KeyMedium", AttributeValue.fromS(s3KeyMedium.trim()));
            updateExpression.append(", #s3KeyMedium = :s3KeyMedium");
        }
        if (s3KeySmall != null && !s3KeySmall.isBlank()) {
            names.put("#s3KeySmall", "s3KeySmall");
            values.put(":s3KeySmall", AttributeValue.fromS(s3KeySmall.trim()));
            updateExpression.append(", #s3KeySmall = :s3KeySmall");
        }
        updateExpression.append(" REMOVE #processingErrorCode, #processingLeaseUntilEpoch, #processingRetryAtEpoch");

        try {
            Map<String, AttributeValue> attributes = dynamoDbClient.updateItem(UpdateItemRequest.builder()
                    .tableName(tableName)
                    .key(Map.of("photoId", AttributeValue.fromS(photoId)))
                    .updateExpression(updateExpression.toString())
                    .conditionExpression(
                            "attribute_exists(#photoId) AND #eventId = :eventId "
                                    + "AND #s3KeyOriginal = :s3KeyOriginal"
                    )
                    .expressionAttributeNames(names)
                    .expressionAttributeValues(values)
                    .returnValues(ReturnValue.ALL_NEW)
                    .build()).attributes();
            return attributes == null || attributes.isEmpty() ? findByIdConsistent(photoId)
                    .orElseThrow(() -> new IllegalArgumentException("Photo does not exist"))
                    : toDomain(fromAttributes(attributes));
        } catch (ConditionalCheckFailedException e) {
            Photo existing = findByIdConsistent(photoId).orElse(null);
            if (existing == null) {
                throw new IllegalArgumentException("Photo does not exist", e);
            }
            if (!eventId.equals(existing.getEventId())
                    || !s3KeyOriginal.trim().equals(existing.getS3KeyOriginal())) {
                throw new IllegalArgumentException("Photo does not belong to event or original key", e);
            }
            if ("ready".equalsIgnoreCase(existing.getStatus())) {
                return existing;
            }
            throw new IllegalArgumentException("Photo cannot be marked ready", e);
        }
    }

    @Override
    public void deleteById(String photoId) {
        if (photoId == null || photoId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(photoId.trim()).build());
    }

    @Override
    public PageResult<Photo> listByEventId(String eventId, int limit, String nextToken) {
        if (eventId == null || eventId.isBlank()) {
            return new PageResult<>(List.of(), null);
        }

        int resolvedLimit = limit <= 0 ? 10 : Math.min(limit, 50);

        DynamoDbIndex<DynamoPhotoItem> index = table.index("byEventId");

        QueryEnhancedRequest.Builder req = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(eventId.trim()).build()))
                .limit(resolvedLimit)
                .scanIndexForward(false);

        Map<String, AttributeValue> eks = decodeExclusiveStartKey(nextToken);
        if (eks != null && !eks.isEmpty()) {
            req = req.exclusiveStartKey(eks);
        }

        List<Photo> out = new ArrayList<>();
        String outNextToken = null;

        for (Page<DynamoPhotoItem> page : index.query(req.build())) {
            for (DynamoPhotoItem item : page.items()) {
                out.add(toDomain(item));
            }
            Map<String, AttributeValue> lek = page.lastEvaluatedKey();
            if (lek != null && !lek.isEmpty()) {
                outNextToken = encodeExclusiveStartKey(lek);
            }
            break;
        }

        return new PageResult<>(out, outNextToken);
    }

    @Override
    public PageResult<Photo> listByGuestId(String guestId, int limit, String nextToken) {
        if (guestId == null || guestId.isBlank()) {
            return new PageResult<>(List.of(), null);
        }

        int resolvedLimit = limit <= 0 ? 10 : Math.min(limit, 50);

        DynamoDbIndex<DynamoPhotoItem> index = table.index("byGuestId");

        QueryEnhancedRequest.Builder req = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(guestId.trim()).build()))
                .limit(resolvedLimit)
                .scanIndexForward(false);

        Map<String, AttributeValue> eks = decodeExclusiveStartKey(nextToken);
        if (eks != null && !eks.isEmpty()) {
            req = req.exclusiveStartKey(eks);
        }

        List<Photo> out = new ArrayList<>();
        String outNextToken = null;

        for (Page<DynamoPhotoItem> page : index.query(req.build())) {
            for (DynamoPhotoItem item : page.items()) {
                out.add(toDomain(item));
            }
            Map<String, AttributeValue> lek = page.lastEvaluatedKey();
            if (lek != null && !lek.isEmpty()) {
                outNextToken = encodeExclusiveStartKey(lek);
            }
            break;
        }

        return new PageResult<>(out, outNextToken);
    }

    @Override
    public PageResult<Photo> listAll(int limit, String nextToken) {
        int resolvedLimit = limit <= 0 ? 100 : Math.min(limit, 100);

        software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest.Builder req = 
            software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest.builder()
                .limit(resolvedLimit);

        List<Photo> out = new ArrayList<>();
        String outNextToken = null;

        for (Page<DynamoPhotoItem> page : table.scan(req.build())) {
            for (DynamoPhotoItem item : page.items()) {
                out.add(toDomain(item));
            }
            Map<String, AttributeValue> lek = page.lastEvaluatedKey();
            if (lek != null && !lek.isEmpty()) {
                outNextToken = encodeScanExclusiveStartKey(lek);
            }
            break;
        }

        return new PageResult<>(out, outNextToken);
    }

    @Override
    public long countByEventId(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            return 0;
        }
        DynamoDbIndex<DynamoPhotoItem> index = table.index("byEventId");

        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(eventId.trim()).build()))
                .limit(10000)
                .build();

        return index.query(request).stream()
                .flatMap(page -> page.items().stream())
                .count();
    }

    private static String encodeScanExclusiveStartKey(Map<String, AttributeValue> key) {
        String photoId = s(key.get("photoId"));
        String raw = photoId == null ? "" : photoId;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    private static Map<String, AttributeValue> decodeScanExclusiveStartKey(String nextToken) {
        if (nextToken == null || nextToken.isBlank()) {
            return null;
        }

        byte[] decoded;
        try {
            decoded = Base64.getUrlDecoder().decode(nextToken.trim());
        } catch (Exception e) {
            return null;
        }

        String photoId = new String(decoded, StandardCharsets.UTF_8);
        if (photoId.isBlank()) {
            return null;
        }

        return Map.of("photoId", AttributeValue.builder().s(photoId).build());
    }

    private static String encodeExclusiveStartKey(Map<String, AttributeValue> key) {
        String photoId = s(key.get("photoId"));
        String eventId = s(key.get("eventId"));
        String eventSortKey = s(key.get("eventSortKey"));

        String raw = String.join("|",
                photoId == null ? "" : photoId,
                eventId == null ? "" : eventId,
                eventSortKey == null ? "" : eventSortKey
        );

        return Base64.getUrlEncoder().withoutPadding().encodeToString(raw.getBytes(StandardCharsets.UTF_8));
    }

    private static Map<String, AttributeValue> decodeExclusiveStartKey(String nextToken) {
        if (nextToken == null || nextToken.isBlank()) {
            return null;
        }

        byte[] decoded;
        try {
            decoded = Base64.getUrlDecoder().decode(nextToken.trim());
        } catch (Exception e) {
            return null;
        }

        String raw = new String(decoded, StandardCharsets.UTF_8);
        String[] parts = raw.split("\\|", -1);
        if (parts.length < 3) {
            return null;
        }

        String photoId = parts[0];
        String eventId = parts[1];
        String eventSortKey = parts[2];

        if (photoId.isBlank() || eventId.isBlank() || eventSortKey.isBlank()) {
            return null;
        }

        return Map.of(
                "photoId", AttributeValue.builder().s(photoId).build(),
                "eventId", AttributeValue.builder().s(eventId).build(),
                "eventSortKey", AttributeValue.builder().s(eventSortKey).build()
        );
    }

    private static String s(AttributeValue v) {
        return v != null ? v.s() : null;
    }

    static DynamoPhotoItem toItem(Photo p) {
        DynamoPhotoItem item = new DynamoPhotoItem();
        item.setPhotoId(p.getPhotoId());
        item.setEventId(p.getEventId());
        item.setEventSortKey(eventSortKey(p.getCreatedAt(), p.getPhotoId()));
        item.setGuestId(p.getGuestId());
        item.setCreatedAt(p.getCreatedAt().toString());
        item.setUploadedAt(p.getUploadedAt() != null ? p.getUploadedAt().toString() : null);
        item.setStatus(p.getStatus());
        item.setS3KeyOriginal(p.getS3KeyOriginal());
        item.setS3KeyMedium(p.getS3KeyMedium());
        item.setS3KeySmall(p.getS3KeySmall());
        item.setOwnerName(p.getOwnerName());
        item.setSharedByUserId(p.getSharedByUserId());
        item.setSharedByName(p.getSharedByName());
        item.setShared(p.isShared());
        item.setProcessingAttempts(p.getProcessingAttempts());
        item.setProcessingErrorCode(p.getProcessingErrorCode());
        item.setProcessingLeaseUntilEpoch(p.getProcessingLeaseUntilEpoch());
        item.setProcessingRetryAtEpoch(p.getProcessingRetryAtEpoch());
        return item;
    }

    static Photo toDomain(DynamoPhotoItem item) {
        Instant createdAt = item.getCreatedAt() != null ? Instant.parse(item.getCreatedAt()) : Instant.EPOCH;
        Instant uploadedAt = item.getUploadedAt() != null && !item.getUploadedAt().isBlank()
                ? Instant.parse(item.getUploadedAt())
                : null;

        return new Photo(
                item.getPhotoId(),
                item.getEventId(),
                item.getGuestId(),
                createdAt,
                uploadedAt,
                item.getStatus(),
                item.getS3KeyOriginal(),
                item.getS3KeyMedium(),
                item.getS3KeySmall(),
                item.getOwnerName(),
                item.getSharedByUserId(),
                item.getSharedByName(),
                Boolean.TRUE.equals(item.getShared()),
                item.getProcessingAttempts() != null ? item.getProcessingAttempts() : 0,
                item.getProcessingErrorCode(),
                item.getProcessingLeaseUntilEpoch(),
                item.getProcessingRetryAtEpoch()
        );
    }

    private static Long n(AttributeValue value) {
        if (value == null || value.n() == null) {
            return null;
        }
        try {
            return Long.parseLong(value.n());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static String eventSortKey(Instant createdAt, String photoId) {
        String ts = createdAt != null ? createdAt.toString() : Instant.EPOCH.toString();
        String id = photoId != null ? photoId : "";
        return ts + "#" + id;
    }
}
