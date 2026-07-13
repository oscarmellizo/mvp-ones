package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.subscriptions.UserSubscription;

import software.amazon.awssdk.core.pagination.sync.SdkIterable;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.enhanced.dynamodb.model.Page;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;

@Repository
public class DynamoDbUserSubscriptionsRepository implements UserSubscriptionsRepository {

    private final DynamoDbTable<DynamoUserSubscriptionItem> table;

    public DynamoDbUserSubscriptionsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.user-subscriptions-table-name:ones-user-subscriptions}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoUserSubscriptionItem.class));
    }

    @Override
    public Optional<UserSubscription> findByUserId(String userId) {
        if (userId == null || userId.isBlank()) {
            return Optional.empty();
        }
        DynamoUserSubscriptionItem item = table.getItem(
                Key.builder().partitionValue(userId.trim()).build()
        );
        return Optional.ofNullable(item).map(DynamoDbUserSubscriptionsRepository::toDomain);
    }

    @Override
    public Optional<UserSubscription> findByMercadoPagoPreapprovalId(String preapprovalId) {
        if (preapprovalId == null || preapprovalId.isBlank()) {
            return Optional.empty();
        }
        DynamoDbIndex<DynamoUserSubscriptionItem> index = table.index("byMercadoPagoPreapprovalId");
        QueryConditional queryConditional = QueryConditional.keyEqualTo(
                Key.builder().partitionValue(preapprovalId.trim()).build()
        );
        SdkIterable<Page<DynamoUserSubscriptionItem>> pages = index.query(queryConditional);
        return pages.stream()
                .flatMap(page -> page.items().stream())
                .findFirst()
                .map(DynamoDbUserSubscriptionsRepository::toDomain);
    }

    @Override
    public UserSubscription upsert(UserSubscription subscription) {
        table.putItem(toItem(subscription));
        return subscription;
    }

    @Override
    public void deleteByUserId(String userId) {
        if (userId == null || userId.isBlank()) {
            return;
        }
        table.deleteItem(Key.builder().partitionValue(userId.trim()).build());
    }

    private static DynamoUserSubscriptionItem toItem(UserSubscription s) {
        DynamoUserSubscriptionItem item = new DynamoUserSubscriptionItem();
        item.setUserId(s.getUserId());
        item.setPlanId(s.getPlanId());
        item.setStatus(s.getStatus());
        item.setMercadoPagoPreapprovalId(s.getMercadoPagoPreapprovalId());
        item.setStartedAt(s.getStartedAt() != null ? s.getStartedAt().toString() : null);
        item.setExpiresAt(s.getExpiresAt() != null ? s.getExpiresAt().toString() : null);
        item.setNextPaymentDate(s.getNextPaymentDate() != null ? s.getNextPaymentDate().toString() : null);
        item.setCancelledAt(s.getCancelledAt() != null ? s.getCancelledAt().toString() : null);
        item.setUpdatedAt(s.getUpdatedAt().toString());
        return item;
    }

    private static UserSubscription toDomain(DynamoUserSubscriptionItem item) {
        return new UserSubscription(
                item.getUserId(),
                item.getPlanId(),
                item.getStatus(),
                item.getMercadoPagoPreapprovalId(),
                parseInstant(item.getStartedAt()),
                parseInstant(item.getExpiresAt()),
                parseInstant(item.getNextPaymentDate()),
                parseInstant(item.getCancelledAt()),
                Instant.parse(item.getUpdatedAt())
        );
    }

    private static Instant parseInstant(String value) {
        return value != null && !value.isBlank() ? Instant.parse(value) : null;
    }
}
