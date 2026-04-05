package com.ones.api.adapters.outbound.dynamodb;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.frames.ports.FramesRepository;
import com.ones.api.domain.frames.Frame;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;

@Repository
public class DynamoDbFramesRepository implements FramesRepository {

    private final DynamoDbTable<DynamoFrameItem> table;

    public DynamoDbFramesRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.frames-table-name:ones-frames}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoFrameItem.class));
    }

    @Override
    public Optional<Frame> findById(String frameId) {
        if (frameId == null || frameId.isBlank()) {
            return Optional.empty();
        }
        DynamoFrameItem item = table.getItem(Key.builder().partitionValue(frameId.trim()).build());
        return Optional.ofNullable(item).map(DynamoDbFramesRepository::toDomain);
    }

    @Override
    public Frame upsert(Frame frame) {
        if (frame == null || frame.getFrameId() == null || frame.getFrameId().isBlank()) {
            throw new IllegalArgumentException("frame.frameId is required");
        }
        table.putItem(toItem(frame));
        return frame;
    }

    @Override
    public void deleteById(String frameId) {
        if (frameId == null || frameId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(frameId.trim()).build());
    }

    @Override
    public ListResult list(String status, int limit, String nextToken) {
        int resolvedLimit = limit <= 0 ? 50 : Math.min(limit, 200);

        String normalizedStatus = status != null ? status.trim().toLowerCase() : "";
        if (normalizedStatus.isBlank()) {
            normalizedStatus = "active";
        }
        String gsi1pk = "status#" + normalizedStatus;

        DynamoDbIndex<DynamoFrameItem> index = table.index("gsi1");

        QueryEnhancedRequest.Builder req = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(gsi1pk).build()))
                .limit(resolvedLimit)
                .scanIndexForward(true);

        Map<String, AttributeValue> eks = decodeExclusiveStartKey(nextToken);
        if (eks != null && !eks.isEmpty()) {
            req = req.exclusiveStartKey(eks);
        }

        List<Frame> out = new ArrayList<>();
        String outNextToken = null;

        for (Page<DynamoFrameItem> page : index.query(req.build())) {
            for (DynamoFrameItem item : page.items()) {
                out.add(toDomain(item));
            }
            Map<String, AttributeValue> lek = page.lastEvaluatedKey();
            if (lek != null && !lek.isEmpty()) {
                outNextToken = encodeExclusiveStartKey(lek);
            }
            break;
        }

        return new ListResult(out, outNextToken);
    }

    private static String encodeExclusiveStartKey(Map<String, AttributeValue> key) {
        String frameId = s(key.get("frameId"));
        String gsi1pk = s(key.get("gsi1pk"));
        String gsi1sk = s(key.get("gsi1sk"));

        String raw = String.join("|",
                frameId == null ? "" : frameId,
                gsi1pk == null ? "" : gsi1pk,
                gsi1sk == null ? "" : gsi1sk
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

        String frameId = parts[0];
        String gsi1pk = parts[1];
        String gsi1sk = parts[2];

        if (frameId.isBlank() || gsi1pk.isBlank() || gsi1sk.isBlank()) {
            return null;
        }

        return Map.of(
                "frameId", AttributeValue.builder().s(frameId).build(),
                "gsi1pk", AttributeValue.builder().s(gsi1pk).build(),
                "gsi1sk", AttributeValue.builder().s(gsi1sk).build()
        );
    }

    private static String s(AttributeValue v) {
        return v != null ? v.s() : null;
    }

    private static DynamoFrameItem toItem(Frame f) {
        DynamoFrameItem item = new DynamoFrameItem();
        item.setFrameId(f.getFrameId());
        item.setName(f.getName());
        item.setStatus(f.getStatus() != null ? f.getStatus().name() : null);
        item.setSortOrder(f.getSortOrder());
        item.setAssetKey(f.getAssetKey());
        item.setCreatedAt(f.getCreatedAt() != null ? f.getCreatedAt().toString() : null);
        item.setUpdatedAt(f.getUpdatedAt() != null ? f.getUpdatedAt().toString() : null);
        item.setCreatedBy(f.getCreatedBy());
        item.setUpdatedBy(f.getUpdatedBy());

        String normalizedStatus = f.getStatus() != null ? f.getStatus().name().toLowerCase() : "inactive";

        item.setGsi1pk("status#" + normalizedStatus);

        String ts = f.getCreatedAt() != null ? f.getCreatedAt().toString() : Instant.EPOCH.toString();
        String order = f.getSortOrder() != null ? String.format("%09d", f.getSortOrder()) : "999999999";
        item.setGsi1sk(order + "#" + ts + "#" + f.getFrameId());

        return item;
    }

    private static Frame toDomain(DynamoFrameItem item) {
        Frame.Status status;
        try {
            status = item.getStatus() != null ? Frame.Status.valueOf(item.getStatus()) : Frame.Status.inactive;
        } catch (Exception e) {
            status = Frame.Status.inactive;
        }

        Instant createdAt = item.getCreatedAt() != null && !item.getCreatedAt().isBlank()
                ? Instant.parse(item.getCreatedAt())
                : Instant.EPOCH;
        Instant updatedAt = item.getUpdatedAt() != null && !item.getUpdatedAt().isBlank()
                ? Instant.parse(item.getUpdatedAt())
                : createdAt;

        return new Frame(
                item.getFrameId(),
                item.getName(),
                status,
                item.getSortOrder(),
                item.getAssetKey(),
                createdAt,
                updatedAt,
                item.getCreatedBy(),
                item.getUpdatedBy()
        );
    }
}
