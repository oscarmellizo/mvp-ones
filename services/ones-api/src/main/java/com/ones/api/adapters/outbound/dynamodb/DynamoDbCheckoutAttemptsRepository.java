package com.ones.api.adapters.outbound.dynamodb;

import com.ones.api.application.subscriptions.ports.CheckoutAttemptsRepository;
import com.ones.api.domain.subscriptions.CheckoutAttempt;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.*;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;

import java.time.Instant;
import java.util.Optional;

@Repository
public class DynamoDbCheckoutAttemptsRepository implements CheckoutAttemptsRepository {

    private static final Logger log = LoggerFactory.getLogger(DynamoDbCheckoutAttemptsRepository.class);

    private final DynamoDbTable<DynamoCheckoutAttemptItem> table;

    public DynamoDbCheckoutAttemptsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.mp-checkout-attempts-table-name:ones-mp-checkout-attempts}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoCheckoutAttemptItem.class));
    }

    @Override
    public CheckoutAttempt create(CheckoutAttempt attempt) {
        // Soft concurrency control: check for existing active attempt first
        Optional<CheckoutAttempt> existing = findActiveByPayerEmailLower(attempt.getPayerEmailLower());
        if (existing.isPresent()) {
            throw new IllegalStateException("Active checkout attempt already exists for payerEmailLower");
        }
        table.putItem(toItem(attempt));
        return attempt;
    }

    @Override
    public Optional<CheckoutAttempt> findActiveByPayerEmailLower(String payerEmailLower) {
        if (payerEmailLower == null || payerEmailLower.isBlank()) return Optional.empty();
        QueryEnhancedRequest req = QueryEnhancedRequest.builder()
                .queryConditional(QueryConditional.keyEqualTo(Key.builder().partitionValue(payerEmailLower.trim()).build()))
                .limit(5)
                .scanIndexForward(false) // latest first
                .build();
        for (Page<DynamoCheckoutAttemptItem> page : table.query(req)) {
            for (DynamoCheckoutAttemptItem i : page.items()) {
                boolean active = "created".equalsIgnoreCase(i.getStatus());
                boolean notExpired = i.getExpiresAt() == null || i.getExpiresAt() > Instant.now().getEpochSecond();
                if (active && notExpired) {
                    return Optional.of(toDomain(i));
                }
            }
        }
        return Optional.empty();
    }

    @Override
    public void markCompleted(String payerEmailLower, String createdAt) {
        if (payerEmailLower == null || payerEmailLower.isBlank() || createdAt == null || createdAt.isBlank()) {
            return;
        }
        DynamoCheckoutAttemptItem key = new DynamoCheckoutAttemptItem();
        key.setPayerEmailLower(payerEmailLower.trim());
        key.setCreatedAt(createdAt);
        DynamoCheckoutAttemptItem existing = table.getItem(Key.builder().partitionValue(key.getPayerEmailLower()).sortValue(key.getCreatedAt()).build());
        if (existing == null) return;
        existing.setStatus("completed");
        table.putItem(existing);
    }

    private static DynamoCheckoutAttemptItem toItem(CheckoutAttempt a) {
        DynamoCheckoutAttemptItem i = new DynamoCheckoutAttemptItem();
        i.setPayerEmailLower(a.getPayerEmailLower());
        i.setCreatedAt(a.getCreatedAt());
        i.setStatus(a.getStatus());
        i.setUserId(a.getUserId());
        i.setPlanId(a.getPlanId());
        i.setExpiresAt(a.getExpiresAt());
        i.setMercadoPagoPlanId(a.getMercadoPagoPlanId());
        i.setPreapprovalId(a.getPreapprovalId());
        i.setPaymentId(a.getPaymentId());
        return i;
    }

    private static CheckoutAttempt toDomain(DynamoCheckoutAttemptItem i) {
        return new CheckoutAttempt(
                i.getPayerEmailLower(),
                i.getCreatedAt(),
                i.getStatus(),
                i.getUserId(),
                i.getPlanId(),
                i.getExpiresAt(),
                i.getMercadoPagoPlanId(),
                i.getPreapprovalId(),
                i.getPaymentId()
        );
    }
}
