package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.configuration.CacheConfig;
import com.ones.api.domain.invitations.Invitation;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Expression;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ResourceNotFoundException;

@Repository
public class DynamoDbInvitationsRepository implements InvitationsRepository {

    private static final Logger log = LoggerFactory.getLogger(DynamoDbInvitationsRepository.class);

    private final DynamoDbTable<DynamoInvitationItem> table;
    private final Counter scanFallbackCounter;
    private final boolean failOnScanFallback;

    public DynamoDbInvitationsRepository(
            DynamoDbEnhancedClient enhancedClient,
            MeterRegistry meterRegistry,
            @Value("${ones.dynamodb.invitations-table-name:ones-dev-event-invitations}") String tableName,
            @Value("${ones.dynamodb.fail-on-scan-fallback:false}") boolean failOnScanFallback
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoInvitationItem.class));
        this.scanFallbackCounter = Counter.builder("ones.dynamodb.scan_fallback")
                .tag("repository", "invitations")
                .tag("operation", "listByEventId")
                .register(meterRegistry);
        this.failOnScanFallback = failOnScanFallback;
    }

    @Override
    public Optional<Invitation> findByInviteeEmailAndEventId(String inviteeEmail, String eventId) {
        if (inviteeEmail == null || inviteeEmail.isBlank() || eventId == null || eventId.isBlank()) {
            return Optional.empty();
        }
        DynamoInvitationItem item = table.getItem(Key.builder()
                .partitionValue(inviteeEmail.trim().toLowerCase())
                .sortValue(eventId.trim())
                .build());
        return Optional.ofNullable(item).map(DynamoDbInvitationsRepository::toDomain);
    }

    @Override
    @CacheEvict(
            cacheNames = CacheConfig.INVITATIONS_BY_EVENT_CACHE,
            allEntries = true
    )
    public Invitation upsert(Invitation invitation) {
        table.putItem(toItem(invitation));
        return invitation;
    }

    @Override
    public List<Invitation> listByInviteeEmail(String inviteeEmail, int limit) {
        if (inviteeEmail == null || inviteeEmail.isBlank()) {
            return List.of();
        }

        int resolvedLimit = limit <= 0 ? 50 : Math.min(limit, 200);

        QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder()
                        .partitionValue(inviteeEmail.trim().toLowerCase())
                        .build()))
                .limit(resolvedLimit)
                .scanIndexForward(false)
                .build();

        return table.query(request)
                .items()
                .stream()
                .map(DynamoDbInvitationsRepository::toDomain)
                .toList();
    }

    @Override
    @Cacheable(
            cacheNames = CacheConfig.INVITATIONS_BY_EVENT_CACHE,
            key = "#eventId + ':' + #limit",
            sync = true
    )
    public List<Invitation> listByEventId(String eventId, int limit) {
        if (eventId == null || eventId.isBlank()) {
            return List.of();
        }

        String normalizedEventId = eventId.trim();
        int resolvedLimit = limit <= 0 ? 50 : Math.min(limit, 200);
        try {
            DynamoDbIndex<DynamoInvitationItem> index = table.index("byEventId");
            QueryEnhancedRequest request = QueryEnhancedRequest.builder()
                    .queryConditional(QueryConditional.keyEqualTo(Key.builder()
                            .partitionValue(normalizedEventId)
                            .build()))
                    .limit(resolvedLimit)
                    .build();

            List<Invitation> out = new ArrayList<>();
            for (var page : index.query(request)) {
                for (var item : page.items()) {
                    out.add(toDomain(item));
                }
            }
            return out;
        } catch (ResourceNotFoundException e) {
            log.warn("Falling back to DynamoDB Scan for listByEventId; consider creating GSI byEventId (eventId={}, limit={})",
                    normalizedEventId,
                    resolvedLimit);
            if (failOnScanFallback) {
                throw new IllegalStateException("DynamoDB Scan fallback disabled for invitations.listByEventId; missing GSI byEventId", e);
            }
            scanFallbackCounter.increment();
            return scanByEventId(normalizedEventId, resolvedLimit);
        } catch (Exception e) {
            String msg = e.getMessage();
            if (msg != null && msg.toLowerCase().contains("byeventid")) {
                log.warn("Falling back to DynamoDB Scan for listByEventId; consider creating GSI byEventId (eventId={}, limit={})",
                        normalizedEventId,
                        resolvedLimit);
                if (failOnScanFallback) {
                    throw new IllegalStateException("DynamoDB Scan fallback disabled for invitations.listByEventId; missing GSI byEventId", e);
                }
                scanFallbackCounter.increment();
                return scanByEventId(normalizedEventId, resolvedLimit);
            }
            throw e;
        }
    }

    private List<Invitation> scanByEventId(String eventId, int limit) {
        Expression filter = Expression.builder()
                .expression("eventId = :eid")
                .putExpressionValue(":eid", AttributeValue.builder().s(eventId).build())
                .build();

        ScanEnhancedRequest request = ScanEnhancedRequest.builder()
                .filterExpression(filter)
                .limit(limit)
                .build();

        return table.scan(request)
                .items()
                .stream()
                .map(DynamoDbInvitationsRepository::toDomain)
                .toList();
    }

    @Override
    public List<Invitation> listAcceptedByInviteeEmail(String inviteeEmail, int limit) {
        return listByInviteeEmail(inviteeEmail, limit).stream()
                .filter(i -> i.getStatus() == Invitation.Status.accepted)
                .toList();
    }

    private static DynamoInvitationItem toItem(Invitation inv) {
        DynamoInvitationItem item = new DynamoInvitationItem();
        item.setInviteeEmail(inv.getInviteeEmail());
        item.setEventId(inv.getEventId());
        item.setInviteeUserId(inv.getInviteeUserId());
        item.setEventOwnerId(inv.getEventOwnerId());
        item.setStatus(inv.getStatus().name());
        item.setCreatedAt(inv.getCreatedAt().toString());
        item.setUpdatedAt(inv.getUpdatedAt().toString());
        item.setEventTitle(inv.getEventTitle());
        item.setEventLocation(inv.getEventLocation());
        item.setEventStartAt(inv.getEventStartAt().toString());
        item.setEventEndAt(inv.getEventEndAt().toString());
        item.setExpiresAt(computeExpiresAt(inv));
        return item;
    }

    private static Long computeExpiresAt(Invitation inv) {
        if (inv == null) return null;
        try {
            if (inv.getStatus() == Invitation.Status.invited) {
                Instant end = inv.getEventEndAt();
                if (end == null) return null;
                return end.plus(7, ChronoUnit.DAYS).getEpochSecond();
            }
            Instant updated = inv.getUpdatedAt();
            if (updated == null) return null;
            return updated.getEpochSecond();
        } catch (Exception ignored) {
            return null;
        }
    }

    private static Invitation toDomain(DynamoInvitationItem item) {
        Instant createdAt = item.getCreatedAt() != null ? Instant.parse(item.getCreatedAt()) : Instant.EPOCH;
        Instant updatedAt = item.getUpdatedAt() != null ? Instant.parse(item.getUpdatedAt()) : createdAt;
        Instant startAt = item.getEventStartAt() != null ? Instant.parse(item.getEventStartAt()) : createdAt;
        Instant endAt = item.getEventEndAt() != null ? Instant.parse(item.getEventEndAt()) : startAt;

        Invitation.Status status;
        try {
            status = Invitation.Status.valueOf(item.getStatus());
        } catch (Exception e) {
            status = Invitation.Status.invited;
        }

        return new Invitation(
                item.getEventId(),
                item.getInviteeEmail(),
                item.getInviteeUserId(),
                item.getEventOwnerId(),
                status,
                createdAt,
                updatedAt,
                item.getEventTitle() != null ? item.getEventTitle() : "",
                item.getEventLocation(),
                startAt,
                endAt
        );
    }
}
